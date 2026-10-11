import Foundation

/// HTTP client for a WebDriver-speaking UI driver: WebDriverAgent on iOS, the
/// UIAutomator2 server on Android. Built from closures so tests substitute fakes.
@available(macOS 15, *)
public struct DriverClient: Sendable {
    public var status: @Sendable () async throws -> WDAStatus
    public var hierarchy: @Sendable () async throws -> [String: Any]
    public var hierarchyXML: @Sendable () async throws -> String
    public var tapByLabel: @Sendable (_ label: String) async throws -> Void
    public var tapByCoordinate: @Sendable (_ x: Double, _ y: Double) async throws -> Void
    public var typeText: @Sendable (_ text: String) async throws -> Void
    public var swipe: @Sendable (_ direction: String) async throws -> Void
    public var screenshot: @Sendable () async throws -> Data
    /// `tapByLabel` that also says which attribute matched; nil for drivers
    /// that match one way only (the tap tools then report a label match).
    public var tapByLabelMatch: (@Sendable (_ label: String) async throws -> LabelMatch)?

    public init(
        status: @escaping @Sendable () async throws -> WDAStatus,
        hierarchy: @escaping @Sendable () async throws -> [String: Any],
        hierarchyXML: @escaping @Sendable () async throws -> String,
        tapByLabel: @escaping @Sendable (_ label: String) async throws -> Void,
        tapByCoordinate: @escaping @Sendable (_ x: Double, _ y: Double) async throws -> Void,
        typeText: @escaping @Sendable (_ text: String) async throws -> Void,
        swipe: @escaping @Sendable (_ direction: String) async throws -> Void,
        screenshot: @escaping @Sendable () async throws -> Data,
        tapByLabelMatch: (@Sendable (_ label: String) async throws -> LabelMatch)? = nil
    ) {
        self.status = status
        self.hierarchy = hierarchy
        self.hierarchyXML = hierarchyXML
        self.tapByLabel = tapByLabel
        self.tapByCoordinate = tapByCoordinate
        self.typeText = typeText
        self.swipe = swipe
        self.screenshot = screenshot
        self.tapByLabelMatch = tapByLabelMatch
    }
}

/// Which attribute a label tap matched on iOS: the accessibility label, then
/// WDA's `name` (the accessibility identifier, or an SF Symbol's name), then
/// a text field's placeholder.
public enum LabelMatch: String, Sendable, Equatable {
    case label
    case identifier
    case placeholder
}

@available(macOS 15, *)
public typealias WDAClient = DriverClient

// MARK: - Supporting Types

public struct WDAStatus: Sendable {
    public let sessionId: String?
    public let ready: Bool

    public init(sessionId: String?, ready: Bool) {
        self.sessionId = sessionId
        self.ready = ready
    }
}

// MARK: - Live Implementation

@available(macOS 15, *)
extension DriverClient {
    /// The iOS driver. `transport` defaults to URLSession; tests pass a stub
    /// that records each request.
    ///
    /// `retryDelay` is how long a label lookup waits before its one retry
    /// after WDA answers 400 (the app under test is still launching right
    /// after the session starts).
    public static func wda(
        port: UInt16, transport: UIAutomator2Transport = .live, retryDelay: Duration = .seconds(1)
    ) -> DriverClient {
        let base = "http://localhost:\(port)"

        return DriverClient(
            status: {
                let (data, status) = try await send(transport, "GET", "\(base)/status")
                guard status == 200 else {
                    throw GrantivaError.commandFailed("WDA not responding on port \(port)", 1)
                }
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                let sessionId = json["sessionId"] as? String
                let ready = (json["value"] as? [String: Any])?["ready"] as? Bool ?? (sessionId != nil)
                return WDAStatus(sessionId: sessionId, ready: ready)
            },
            hierarchy: {
                let xml = try await fetchHierarchyXML(base: base, port: port, transport: transport)
                let parser = WDAHierarchyXMLParser(xml: xml)
                return try parser.parse()
            },
            hierarchyXML: {
                try await fetchHierarchyXML(base: base, port: port, transport: transport)
            },
            tapByLabel: { label in
                _ = try await tapByLabel(label, base: base, port: port, transport: transport, retryDelay: retryDelay)
            },
            tapByCoordinate: { x, y in
                let sessionId = try await resolveSessionId(base: base, port: port, transport: transport)
                let body: [String: Any] = [
                    "actions": [
                        [
                            "type": "pointer",
                            "id": "finger1",
                            "parameters": ["pointerType": "touch"],
                            "actions": [
                                ["type": "pointerMove", "duration": 0, "x": Int(x), "y": Int(y)],
                                ["type": "pointerDown", "button": 0],
                                ["type": "pause", "duration": 100],
                                ["type": "pointerUp", "button": 0],
                            ],
                        ] as [String: Any]
                    ]
                ]
                let (data, status) = try await send(transport, "POST", "\(base)/session/\(sessionId)/actions", body)
                guard status == 200 else {
                    throw failure(data, fallback: GrantivaError.commandFailed("Failed to tap at (\(x), \(y))", 1))
                }
            },
            typeText: { text in
                let sessionId = try await resolveSessionId(base: base, port: port, transport: transport)
                // Keystrokes with nothing focused go nowhere and WDA still
                // answers 200, so ask for the focused element first.
                let (activeData, activeStatus) = try await send(transport, "GET", "\(base)/session/\(sessionId)/element/active")
                if activeStatus == 404 { throw noFocusedField(text) }
                guard activeStatus == 200 else {
                    throw failure(activeData, fallback: GrantivaError.networkError("Failed to read the focused element", activeStatus))
                }
                let body: [String: Any] = ["value": Array(text).map { String($0) }]
                // GrantivaAgent (WebDriverAgent) serves keystrokes at /wda/keys;
                // /keys is the W3C path some drivers use, kept as a fallback.
                var (data, status) = try await send(transport, "POST", "\(base)/session/\(sessionId)/wda/keys", body)
                if status == 404 {
                    (data, status) = try await send(transport, "POST", "\(base)/session/\(sessionId)/keys", body)
                }
                guard status == 200 else {
                    throw failure(data, fallback: GrantivaError.networkError("Failed to type text", status))
                }
            },
            swipe: { direction in
                let sessionId = try await resolveSessionId(base: base, port: port, transport: transport)
                // Get window size first for calculating swipe coordinates
                let (sizeData, _) = try await send(transport, "GET", "\(base)/session/\(sessionId)/window/size")
                let sizeJson = try JSONSerialization.jsonObject(with: sizeData) as? [String: Any] ?? [:]
                let value = sizeJson["value"] as? [String: Any] ?? [:]
                let width = value["width"] as? Double ?? 390.0
                let height = value["height"] as? Double ?? 844.0

                let centerX = width / 2
                let centerY = height / 2

                let (startX, startY, endX, endY): (Double, Double, Double, Double)
                switch direction.lowercased() {
                case "up":
                    startX = centerX; startY = height * 0.7
                    endX = centerX; endY = height * 0.3
                case "down":
                    startX = centerX; startY = height * 0.3
                    endX = centerX; endY = height * 0.7
                case "left":
                    startX = width * 0.8; startY = centerY
                    endX = width * 0.2; endY = centerY
                case "right":
                    startX = width * 0.2; startY = centerY
                    endX = width * 0.8; endY = centerY
                default:
                    throw GrantivaError.invalidArgument("Invalid swipe direction \"\(direction)\". Use: up, down, left, right")
                }

                let body: [String: Any] = [
                    "actions": [
                        [
                            "type": "pointer",
                            "id": "finger1",
                            "parameters": ["pointerType": "touch"],
                            "actions": [
                                ["type": "pointerMove", "duration": 0, "x": Int(startX), "y": Int(startY)],
                                ["type": "pointerDown", "button": 0],
                                ["type": "pointerMove", "duration": 300, "x": Int(endX), "y": Int(endY)],
                                ["type": "pointerUp", "button": 0],
                            ],
                        ] as [String: Any]
                    ]
                ]
                let (data, status) = try await send(transport, "POST", "\(base)/session/\(sessionId)/actions", body)
                guard status == 200 else {
                    throw failure(data, fallback: GrantivaError.commandFailed("Failed to swipe \(direction)", 1))
                }
            },
            screenshot: {
                let sessionId = try await resolveSessionId(base: base, port: port, transport: transport)
                let (data, status) = try await send(transport, "GET", "\(base)/session/\(sessionId)/screenshot")
                guard status == 200 else {
                    throw GrantivaError.commandFailed("Failed to take screenshot via WDA", 1)
                }
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                guard let base64 = json["value"] as? String,
                      let imageData = Data(base64Encoded: base64) else {
                    throw GrantivaError.invalidImage
                }
                return imageData
            },
            tapByLabelMatch: { label in
                try await tapByLabel(label, base: base, port: port, transport: transport, retryDelay: retryDelay)
            }
        )
    }

    /// Kept for callers written against the old name.
    public static func live(port: UInt16) -> DriverClient { wda(port: port) }

    // MARK: - Helpers

    /// Label first (what VoiceOver reads and `grantiva_a11y_tree` shows as
    /// `label`), then WDA's `name` (the accessibility identifier; for an SF
    /// Symbol, its name), then the placeholder: a SwiftUI `TextField("Name",
    /// ...)` has no label and shows "Name" as its placeholder, which is what
    /// a flow's `tapOn: "Name"` matches. The application element is excluded:
    /// it carries the app's display name as its label and would shadow a
    /// same-named back button.
    static let labelAttributes: [(attribute: String, match: LabelMatch)] = [
        ("label", .label), ("name", .identifier), ("placeholderValue", .placeholder),
    ]

    static func tapByLabel(
        _ label: String, base: String, port: UInt16, transport: UIAutomator2Transport, retryDelay: Duration
    ) async throws -> LabelMatch {
        var sessionId = try await resolveSessionId(base: base, port: port, transport: transport)
        var retried = false
        var found: (id: String, match: LabelMatch)?
        var index = 0
        while index < labelAttributes.count, found == nil {
            let (attribute, match) = labelAttributes[index]
            let findBody: [String: Any] = [
                "using": "predicate string",
                "value": "\(attribute) == \(predicateLiteral(label)) AND type != \"XCUIElementTypeApplication\"",
            ]
            let (responseData, status) = try await send(
                transport, "POST", "\(base)/session/\(sessionId)/elements", findBody
            )
            // 404 is WebDriver's "no such element": try the next attribute.
            if status == 404 { index += 1; continue }
            // Right after the session starts WDA answers 400 while the app
            // is still launching: wait, resolve the session again and retry
            // once before reporting anything.
            if status == 400, !retried {
                retried = true
                try await Task.sleep(for: retryDelay)
                sessionId = try await resolveSessionId(base: base, port: port, transport: transport)
                continue
            }
            // Anything else is a real failure and must not read as "not found".
            guard status == 200 else {
                throw failure(responseData, fallback: GrantivaError.networkError(
                    "Failed to look up \"\(label)\"\(wdaMessage(responseData).map { ": \($0)" } ?? "")", status
                ))
            }
            let findJson = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] ?? [:]
            if let elements = findJson["value"] as? [[String: Any]], let first = elements.first, let id = elementID(from: first) {
                found = (id, match)
            }
            index += 1
        }
        guard let found else {
            throw GrantivaError.elementNotFound(label)
        }
        let (clickData, clickStatus) = try await send(
            transport, "POST", "\(base)/session/\(sessionId)/element/\(found.id)/click", [:]
        )
        guard clickStatus == 200 else {
            throw failure(clickData, fallback: GrantivaError.networkError("Failed to tap element \"\(label)\"", clickStatus))
        }
        return found.match
    }

    /// WDA's error message from a failed response body, if any.
    static func wdaMessage(_ data: Data) -> String? {
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = (json?["value"] as? [String: Any])?["message"] as? String
        return message.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The error for a failed WDA call: "the app is not running" when WDA
    /// says so (it answers 400 once the app under test has exited), else
    /// `fallback`.
    static func failure(_ data: Data, fallback: GrantivaError) -> GrantivaError {
        guard let message = wdaMessage(data), message.contains("is not running") else { return fallback }
        let app = message.range(of: #"bundle id '([^']+)'"#, options: .regularExpression)
            .map { String(message[$0].dropFirst("bundle id '".count).dropLast()) }
        return .unavailable(
            "\(app ?? "The app under test") is not running. Relaunch it (grantiva_run, or restart the session with grantiva runner stop and grantiva runner start)."
        )
    }

    /// What typing with no focused field reports, on both drivers.
    public static func noFocusedField(_ text: String) -> GrantivaError {
        .notFound("No focused text field: tap a field before typing \"\(text)\".")
    }

    static func elementID(from element: [String: Any]) -> String? {
        element["ELEMENT"] as? String
            ?? element["element-6066-11e4-a52e-4f735466cecf"] as? String
    }

    /// An NSPredicate string literal: double-quoted, with `\\` and `"` escaped.
    static func predicateLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func send(
        _ transport: UIAutomator2Transport, _ method: String, _ url: String, _ body: [String: Any]? = nil
    ) async throws -> (Data, Int) {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return try await transport.send(request)
    }

    /// The session WDA holds. Between `grantiva runner start --detach`
    /// returning and the runner opening its session, `/status` answers with
    /// no `sessionId`; that is a state to wait out, and the error says so.
    private static func resolveSessionId(base: String, port: UInt16, transport: UIAutomator2Transport) async throws -> String {
        let (data, status) = try await send(transport, "GET", "\(base)/status")
        guard status == 200 else {
            throw GrantivaError.unavailable(
                "WDA on port \(port) is not responding (HTTP \(status)). If the runner session just started, retry in a few seconds; otherwise restart it with grantiva runner stop and grantiva runner start."
            )
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if let sid = json["sessionId"] as? String {
            return sid
        }
        throw GrantivaError.unavailable(sessionStartingMessage(port: port))
    }

    /// The runner session exists but WDA has not opened its session yet.
    public static func sessionStartingMessage(port: UInt16) -> String {
        "The runner session is starting (WDA on port \(port) has no session yet). Retry in a few seconds."
    }

    private static func fetchHierarchyXML(base: String, port: UInt16, transport: UIAutomator2Transport) async throws -> String {
        let sessionId = try await resolveSessionId(base: base, port: port, transport: transport)
        let (data, status) = try await send(transport, "GET", "\(base)/session/\(sessionId)/source")
        guard status == 200 else {
            throw failure(data, fallback: GrantivaError.commandFailed("Failed to get hierarchy from WDA", 1))
        }
        // WDA returns JSON with a "value" key containing the XML source
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let value = json["value"] as? String {
            return value
        }
        if let raw = String(data: data, encoding: .utf8) {
            return raw
        }
        throw GrantivaError.commandFailed("Empty hierarchy response", 1)
    }
}

// MARK: - Failing (Test) Implementation

@available(macOS 15, *)
extension DriverClient {
    public static let failing = DriverClient(
        status: { throw GrantivaError.commandFailed("DriverClient.failing", 1) },
        hierarchy: { throw GrantivaError.commandFailed("DriverClient.failing", 1) },
        hierarchyXML: { throw GrantivaError.commandFailed("DriverClient.failing", 1) },
        tapByLabel: { _ in throw GrantivaError.commandFailed("DriverClient.failing", 1) },
        tapByCoordinate: { _, _ in throw GrantivaError.commandFailed("DriverClient.failing", 1) },
        typeText: { _ in throw GrantivaError.commandFailed("DriverClient.failing", 1) },
        swipe: { _ in throw GrantivaError.commandFailed("DriverClient.failing", 1) },
        screenshot: { throw GrantivaError.commandFailed("DriverClient.failing", 1) }
    )
}

// MARK: - XML Parser for WDA Hierarchy

/// Parses the XML page source from WebDriverAgent into a dictionary tree.
/// Shared between WDAClient and CLI dump-hierarchy command.
public class WDAHierarchyXMLParser: NSObject, XMLParserDelegate {
    private let xml: String
    private var stack: [NSMutableDictionary] = []
    private var root: [String: Any] = [:]
    private var conversionFailed = false

    public init(xml: String) {
        self.xml = xml
    }

    public func parse() throws -> [String: Any] {
        guard let data = xml.data(using: .utf8) else {
            throw GrantivaError.commandFailed("Failed to encode WDA hierarchy XML", 1)
        }
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse(), !conversionFailed, !root.isEmpty else {
            let detail = parser.parserError?.localizedDescription ?? "unexpected hierarchy structure"
            throw GrantivaError.commandFailed("Failed to parse WDA hierarchy XML: \(detail)", 1)
        }
        return root
    }

    public func parser(_ parser: XMLParser, didStartElement elementName: String,
                       namespaceURI: String?, qualifiedName: String?,
                       attributes: [String: String]) {
        let node = NSMutableDictionary()
        node["type"] = elementName

        if let label = attributes["label"], !label.isEmpty {
            node["label"] = label
        }
        if let name = attributes["name"], !name.isEmpty {
            node["name"] = name
        }
        if let identifier = attributes["identifier"], !identifier.isEmpty {
            node["identifier"] = identifier
        }
        if let value = attributes["value"], !value.isEmpty {
            node["value"] = value
        }
        if let placeholder = attributes["placeholderValue"], !placeholder.isEmpty {
            node["placeholderValue"] = placeholder
        }
        if let enabled = attributes["enabled"] {
            node["enabled"] = enabled == "true"
        }
        if let visible = attributes["visible"] {
            node["visible"] = visible == "true"
        }
        // Numbers, not the XML's strings: whole points as integers,
        // fractional ones as doubles.
        if let x = Self.number(attributes["x"]), let y = Self.number(attributes["y"]),
           let w = Self.number(attributes["width"]), let h = Self.number(attributes["height"]) {
            node["frame"] = ["x": x, "y": y, "width": w, "height": h]
        }

        node["children"] = NSMutableArray()

        if let parent = stack.last {
            (parent["children"] as? NSMutableArray)?.add(node)
        }

        stack.append(node)
    }

    static func number(_ text: String?) -> NSNumber? {
        guard let text, let value = Double(text), value.isFinite else { return nil }
        if value == value.rounded(), abs(value) < Double(Int.max) { return NSNumber(value: Int(value)) }
        return NSNumber(value: value)
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String,
                       namespaceURI: String?, qualifiedName: String?) {
        if let finished = stack.popLast(), stack.isEmpty {
            guard let dictionary = finished as? [String: Any] else {
                conversionFailed = true
                return
            }
            root = dictionary
        }
    }
}
