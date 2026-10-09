import Foundation

/// One HTTP round trip. Injected so the client is testable without a socket.
public struct UIAutomator2Transport: Sendable {
    public var send: @Sendable (URLRequest) async throws -> (Data, Int)

    public init(send: @escaping @Sendable (URLRequest) async throws -> (Data, Int)) {
        self.send = send
    }

    public static let live = UIAutomator2Transport { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

/// A forwarded local port and the session the runner holds on the device.
public struct UIAutomator2Endpoint: Sendable, Equatable {
    public let localPort: Int
    public let sessionID: String

    public init(localPort: Int, sessionID: String) {
        self.localPort = localPort
        self.sessionID = sessionID
    }

    public var baseURL: String { "http://127.0.0.1:\(localPort)/wd/hub" }
}

/// Talks to the UIAutomator2 server directly: the runner does not proxy it
/// (spike result, 2026-10-07). The server listens on device port 6790; the
/// CLI forwards a local port to it and reuses the runner's session.
public enum UIAutomator2 {
    public static let devicePort = 6790

    /// Forwards a fresh local port and finds the runner's session. On any
    /// failure the forward is removed again so nothing leaks.
    public static func attach(
        adb: ADB, serial: String, transport: UIAutomator2Transport = .live
    ) async throws -> UIAutomator2Endpoint {
        let port = try await adb.forward(serial: serial, devicePort: devicePort)
        do {
            return try await endpoint(localPort: port, serial: serial, transport: transport)
        } catch {
            _ = try? await adb.removeForward(serial: serial, localPort: port)
            throw error
        }
    }

    /// For a port forwarded earlier (`runner start` records it).
    public static func endpoint(
        localPort: Int, serial: String, transport: UIAutomator2Transport = .live
    ) async throws -> UIAutomator2Endpoint {
        let sessionID: String?
        do {
            sessionID = try await self.sessionID(localPort: localPort, transport: transport)
        } catch {
            throw GrantivaError.commandFailed(
                "The UIAutomator2 server on \(serial) is not answering on local port \(localPort): \(error.localizedDescription)", 1
            )
        }
        guard let sessionID else {
            throw GrantivaError.invalidArgument(
                "No UIAutomator2 session on \(serial). Hold one with `grantiva run --keep-alive` or `grantiva runner start` first."
            )
        }
        return UIAutomator2Endpoint(localPort: localPort, sessionID: sessionID)
    }

    /// `GET /wd/hub/sessions` → the first session id, or nil when the server
    /// is up but holds none.
    public static func sessionID(localPort: Int, transport: UIAutomator2Transport = .live) async throws -> String? {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(localPort)/wd/hub/sessions")!, timeoutInterval: 10)
        request.httpMethod = "GET"
        let (data, status) = try await transport.send(request)
        guard status == 200 else {
            throw GrantivaError.commandFailed("GET /wd/hub/sessions failed (HTTP \(status))", 1)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let sessions = json["value"] as? [[String: Any]] ?? []
        return sessions.first?["id"] as? String ?? sessions.first?["sessionId"] as? String
    }

    /// An XPath 1.0 string literal for `value`: double-quoted when it has no
    /// double quote, single-quoted when it has no single quote, else a
    /// `concat()` of double-quoted pieces joined by `'"'`.
    public static func xpathLiteral(_ value: String) -> String {
        if !value.contains("\"") { return "\"\(value)\"" }
        if !value.contains("'") { return "'\(value)'" }
        let parts = value.split(separator: "\"", omittingEmptySubsequences: false).map { "\"\($0)\"" }
        return "concat(" + parts.joined(separator: ", '\"', ") + ")"
    }

    /// Matches a node by accessibility description or visible text.
    public static func labelXPath(_ label: String) -> String {
        let literal = xpathLiteral(label)
        return "//*[@content-desc=\(literal) or @text=\(literal)]"
    }
}

/// The HTTP verbs the Android driver uses, as free functions so the
/// closures in `DriverClient.uiAutomator2` stay short.
enum UIAutomator2Requests {
    static func send(
        _ transport: UIAutomator2Transport, _ method: String, _ url: String,
        _ body: [String: Any]? = nil, failure: String
    ) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: url)!, timeoutInterval: 60)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, status) = try await transport.send(request)
        guard status == 200 else {
            throw GrantivaError.commandFailed("\(failure) (HTTP \(status))", 1)
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    static func sourceXML(_ transport: UIAutomator2Transport, session: String) async throws -> String {
        let json = try await send(transport, "GET", "\(session)/source", failure: "Failed to get hierarchy from UIAutomator2")
        guard let xml = json["value"] as? String, !xml.isEmpty else {
            throw GrantivaError.commandFailed("Empty hierarchy response", 1)
        }
        return xml
    }

    static func pointer(_ transport: UIAutomator2Transport, session: String, _ steps: [[String: Any]], failure: String) async throws {
        let body: [String: Any] = [
            "actions": [
                ["type": "pointer", "id": "finger1", "parameters": ["pointerType": "touch"], "actions": steps] as [String: Any]
            ]
        ]
        _ = try await send(transport, "POST", "\(session)/actions", body, failure: failure)
    }
}

extension DriverClient {
    /// The Android driver. Tap coordinates are dp, converted to pixels with
    /// `scale`; hierarchy bounds are reported in dp.
    public static func uiAutomator2(
        endpoint: UIAutomator2Endpoint, scale: Double, transport: UIAutomator2Transport = .live
    ) -> DriverClient {
        let base = endpoint.baseURL
        let session = "\(base)/session/\(endpoint.sessionID)"
        typealias R = UIAutomator2Requests

        return DriverClient(
            status: {
                let json = try await R.send(transport, "GET", "\(base)/status", failure: "UIAutomator2 not responding on port \(endpoint.localPort)")
                let ready = (json["value"] as? [String: Any])?["ready"] as? Bool ?? false
                return WDAStatus(sessionId: endpoint.sessionID, ready: ready)
            },
            hierarchy: {
                try UIAutomator2HierarchyXMLParser(xml: try await R.sourceXML(transport, session: session), scale: scale).parse()
            },
            hierarchyXML: { try await R.sourceXML(transport, session: session) },
            tapByLabel: { label in
                let found = try await R.send(
                    transport, "POST", "\(session)/elements",
                    ["strategy": "xpath", "selector": UIAutomator2.labelXPath(label)],
                    failure: "Failed to look up \"\(label)\""
                )
                guard let elements = found["value"] as? [[String: Any]], let first = elements.first,
                      let id = DriverClient.elementID(from: first) else {
                    throw GrantivaError.elementNotFound(label)
                }
                _ = try await R.send(transport, "POST", "\(session)/element/\(id)/click", [:], failure: "Failed to tap element \"\(label)\"")
            },
            tapByCoordinate: { x, y in
                try await R.pointer(transport, session: session, [
                    ["type": "pointerMove", "duration": 0, "x": Int((x * scale).rounded()), "y": Int((y * scale).rounded())],
                    ["type": "pointerDown", "button": 0],
                    ["type": "pause", "duration": 100],
                    ["type": "pointerUp", "button": 0],
                ], failure: "Failed to tap at (\(x), \(y))")
            },
            typeText: { text in
                var steps: [[String: String]] = []
                for character in text {
                    steps.append(["type": "keyDown", "value": String(character)])
                    steps.append(["type": "keyUp", "value": String(character)])
                }
                let body: [String: Any] = ["actions": [["type": "key", "id": "kb", "actions": steps] as [String: Any]]]
                _ = try await R.send(transport, "POST", "\(session)/actions", body, failure: "Failed to type text")
            },
            swipe: { direction in
                let size = try await R.send(transport, "GET", "\(session)/window/current/size", failure: "Failed to read the window size")
                let value = size["value"] as? [String: Any] ?? [:]
                let width = (value["width"] as? NSNumber)?.doubleValue ?? 1080
                let height = (value["height"] as? NSNumber)?.doubleValue ?? 2400
                let (startX, startY, endX, endY): (Double, Double, Double, Double)
                switch direction.lowercased() {
                case "up": (startX, startY, endX, endY) = (width / 2, height * 0.7, width / 2, height * 0.3)
                case "down": (startX, startY, endX, endY) = (width / 2, height * 0.3, width / 2, height * 0.7)
                case "left": (startX, startY, endX, endY) = (width * 0.8, height / 2, width * 0.2, height / 2)
                case "right": (startX, startY, endX, endY) = (width * 0.2, height / 2, width * 0.8, height / 2)
                default:
                    throw GrantivaError.invalidArgument("Invalid swipe direction \"\(direction)\". Use: up, down, left, right")
                }
                try await R.pointer(transport, session: session, [
                    ["type": "pointerMove", "duration": 0, "x": Int(startX), "y": Int(startY)],
                    ["type": "pointerDown", "button": 0],
                    ["type": "pointerMove", "duration": 300, "x": Int(endX), "y": Int(endY)],
                    ["type": "pointerUp", "button": 0],
                ], failure: "Failed to swipe \(direction)")
            },
            screenshot: {
                let json = try await R.send(transport, "GET", "\(session)/screenshot", failure: "Failed to take screenshot via UIAutomator2")
                guard let base64 = json["value"] as? String, let data = Data(base64Encoded: base64) else {
                    throw GrantivaError.invalidImage
                }
                return data
            }
        )
    }
}
