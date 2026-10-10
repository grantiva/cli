import Foundation
import GrantivaCore
import MCP

/// UI automation tools: screenshot, tap, swipe, type, accessibility tree, accessibility check.
@available(macOS 15, *)
enum UITools {

    // MARK: - Tool Definitions

    static let definitions: [Tool] = [
        Tool(
            name: "grantiva_screenshot",
            description: "Take a screenshot of the device (iOS simulator or Android emulator). Returns a base64-encoded PNG image.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "format": .object([
                        "type": .string("string"),
                        "description": .string("Output format: 'base64' (default) or 'file'"),
                        "enum": .array([.string("base64"), .string("file")]),
                    ]),
                ]),
            ]),
            // Not read-only: format "file" writes .grantiva/mcp-screenshot.png into
            // the working directory. The base64 default reads only, but annotations
            // describe the tool, not one invocation, so the hint takes the safe value.
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_tap",
            description: "Tap on a UI element by accessibility label or by coordinates. After tapping, returns the updated accessibility tree so you can see what changed.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "label": .object([
                        "type": .string("string"),
                        "description": .string("Accessibility label of the element to tap"),
                    ]),
                    "x": .object([
                        "type": .string("number"),
                        "description": .string("X coordinate to tap, in the same unit as the hierarchy frames: points on iOS, dp on Android (used if label is not provided)"),
                    ]),
                    "y": .object([
                        "type": .string("number"),
                        "description": .string("Y coordinate to tap, in the same unit as the hierarchy frames: points on iOS, dp on Android (used if label is not provided)"),
                    ]),
                ]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_swipe",
            description: "Swipe on the device (iOS simulator or Android emulator) screen. After swiping, returns the updated accessibility tree.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "direction": .object([
                        "type": .string("string"),
                        "description": .string("Swipe direction: up, down, left, right"),
                        "enum": .array([.string("up"), .string("down"), .string("left"), .string("right")]),
                    ]),
                ]),
                "required": .array([.string("direction")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_type",
            description: "Type text into the currently focused field on the device (iOS simulator or Android emulator). After typing, returns the updated accessibility tree.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "text": .object([
                        "type": .string("string"),
                        "description": .string("Text to type"),
                    ]),
                ]),
                "required": .array([.string("text")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_a11y_tree",
            description: "Get the current accessibility tree (view hierarchy) of the running app. Returns a JSON tree of all UI elements with their labels, types, frames, and states.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
            ]),
            annotations: .init(readOnlyHint: true, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_a11y_check",
            description: "Run accessibility audit on the current screen. Checks for missing labels on interactive elements and tap targets smaller than 44pt (iOS) or 48dp (Android).",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
            ]),
            annotations: .init(readOnlyHint: true, openWorldHint: false)
        ),
    ]

    // MARK: - Handlers

    static func screenshot(
        driver: DriverClient,
        device: any DevicePlatform,
        session: RunnerSessionInfo,
        arguments: [String: Value]
    ) async throws -> CallTool.Result {
        let format = arguments["format"]?.stringValue ?? "base64"

        let imageData: Data
        // Prefer the platform's full-device screenshot when a device is known.
        if !session.udid.isEmpty {
            let tmpPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("grantiva-mcp-\(UUID().uuidString).png").path
            defer { try? FileManager.default.removeItem(atPath: tmpPath) }
            try await device.screenshot(deviceID: session.udid, to: tmpPath)
            imageData = try Data(contentsOf: URL(fileURLWithPath: tmpPath))
        } else {
            imageData = try await driver.screenshot()
        }

        if format == "file" {
            let outPath = ".grantiva/mcp-screenshot.png"
            try FileManager.default.createDirectory(atPath: ".grantiva", withIntermediateDirectories: true)
            try imageData.write(to: URL(fileURLWithPath: outPath))
            return CallTool.Result(
                content: [.text(text: "Screenshot saved to \(outPath)", annotations: nil, _meta: nil)]
            )
        }

        let base64 = imageData.base64EncodedString()
        return CallTool.Result(
            content: [.image(data: base64, mimeType: "image/png", annotations: nil, _meta: nil)]
        )
    }

    static func tap(driver: DriverClient, arguments: [String: Value]) async throws -> CallTool.Result {
        if let label = arguments["label"]?.stringValue {
            do {
                try await driver.tapByLabel(label)
            } catch let error as GrantivaError {
                guard case .elementNotFound = error else { throw error }
                return CallTool.Result(
                    content: [.text(text: "Error: \(error.localizedDescription)", annotations: nil, _meta: nil)],
                    isError: true
                )
            }
            // Brief settle time for animations
            try await Task.sleep(nanoseconds: 500_000_000)
            let tree = try await fetchHierarchyJSON(driver: driver)
            return CallTool.Result(
                content: [
                    .text(text: "Tapped on \"\(label)\". Updated hierarchy:\n\(tree)", annotations: nil, _meta: nil),
                ]
            )
        } else if let x = arguments["x"]?.doubleValue, let y = arguments["y"]?.doubleValue {
            try await driver.tapByCoordinate(x, y)
            try await Task.sleep(nanoseconds: 500_000_000)
            let tree = try await fetchHierarchyJSON(driver: driver)
            return CallTool.Result(
                content: [
                    .text(text: "Tapped at (\(Int(x)), \(Int(y))). Updated hierarchy:\n\(tree)", annotations: nil, _meta: nil),
                ]
            )
        } else {
            return CallTool.Result(
                content: [.text(text: "Error: provide either 'label' or both 'x' and 'y' coordinates.", annotations: nil, _meta: nil)],
                isError: true
            )
        }
    }

    static func swipe(driver: DriverClient, arguments: [String: Value]) async throws -> CallTool.Result {
        guard let direction = arguments["direction"]?.stringValue else {
            return CallTool.Result(
                content: [.text(text: "Error: 'direction' is required.", annotations: nil, _meta: nil)],
                isError: true
            )
        }
        try await driver.swipe(direction)
        try await Task.sleep(nanoseconds: 500_000_000)
        let tree = try await fetchHierarchyJSON(driver: driver)
        return CallTool.Result(
            content: [
                .text(text: "Swiped \(direction). Updated hierarchy:\n\(tree)", annotations: nil, _meta: nil),
            ]
        )
    }

    static func type(driver: DriverClient, arguments: [String: Value]) async throws -> CallTool.Result {
        guard let text = arguments["text"]?.stringValue else {
            return CallTool.Result(
                content: [.text(text: "Error: 'text' is required.", annotations: nil, _meta: nil)],
                isError: true
            )
        }
        try await driver.typeText(text)
        try await Task.sleep(nanoseconds: 300_000_000)
        let tree = try await fetchHierarchyJSON(driver: driver)
        return CallTool.Result(
            content: [
                .text(text: "Typed \"\(text)\". Updated hierarchy:\n\(tree)", annotations: nil, _meta: nil),
            ]
        )
    }

    static func a11yTree(driver: DriverClient) async throws -> CallTool.Result {
        let tree = try await fetchHierarchyJSON(driver: driver)
        return CallTool.Result(
            content: [.text(text: tree, annotations: nil, _meta: nil)]
        )
    }

    static func a11yCheck(driver: DriverClient, config: GrantivaConfig?, platform: Platform) async throws -> CallTool.Result {
        let hierarchy = try await driver.hierarchy()
        let rules = config?.a11y.rules ?? ["missing_label", "small_tap_target"]

        var violations: [[String: String]] = []
        checkViolations(element: hierarchy, rules: rules, platform: platform, violations: &violations)

        if violations.isEmpty {
            return CallTool.Result(
                content: [.text(text: "No accessibility violations found.", annotations: nil, _meta: nil)]
            )
        }

        let jsonData = try JSONSerialization.data(withJSONObject: violations, options: [.prettyPrinted, .sortedKeys])
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
        return CallTool.Result(
            content: [
                .text(
                    text: "Found \(violations.count) accessibility violation(s):\n\(jsonString)",
                    annotations: nil, _meta: nil
                ),
            ]
        )
    }

    static let iosInteractiveTypes = [
        "XCUIElementTypeButton", "XCUIElementTypeTextField", "XCUIElementTypeSecureTextField", "XCUIElementTypeSwitch",
        "XCUIElementTypeSlider", "XCUIElementTypeStepper", "XCUIElementTypeLink", "XCUIElementTypeSegmentedControl",
    ]
    static let androidInteractiveTypes = [
        "android.widget.Button", "android.widget.ImageButton", "android.widget.EditText", "android.widget.CheckBox",
        "android.widget.Switch", "android.widget.RadioButton", "android.widget.ToggleButton", "android.widget.SeekBar",
        "android.widget.Spinner",
    ]

    /// 44 pt on iOS (HIG), 48 dp on Android (Material).
    static func minimumTapTarget(for platform: Platform) -> Double {
        platform == .ios ? 44 : 48
    }

    /// Known interactive classes on either platform, or any Android node the
    /// framework marks clickable (Compose nodes carry no widget class).
    static func isInteractive(_ element: [String: Any]) -> Bool {
        let type = element["type"] as? String ?? ""
        return iosInteractiveTypes.contains(type) || androidInteractiveTypes.contains(type) || element["clickable"] as? Bool == true
    }

    /// True when any descendant carries a non-empty `label` or `name`.
    static func hasDescendantLabel(_ element: [String: Any]) -> Bool {
        guard let children = element["children"] as? [[String: Any]] else { return false }
        return children.contains { child in
            !(child["label"] as? String ?? "").isEmpty || !(child["name"] as? String ?? "").isEmpty
                || hasDescendantLabel(child)
        }
    }

    // MARK: - Private Helpers

    private static func fetchHierarchyJSON(driver: DriverClient) async throws -> String {
        let tree = try await driver.hierarchy()
        let data = try JSONSerialization.data(withJSONObject: tree, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Recursively check the hierarchy for accessibility violations.
    private static func checkViolations(
        element: [String: Any],
        rules: [String],
        platform: Platform,
        violations: inout [[String: String]]
    ) {
        let type = element["type"] as? String ?? ""
        let label = element["label"] as? String ?? ""
        let name = element["name"] as? String ?? ""
        let enabled = element["enabled"] as? Bool ?? true

        let isInteractive = Self.isInteractive(element)

        // Rule: missing_label
        // On Android a clickable container (a Compose or View row) usually
        // carries its text in a child, which TalkBack reads for the row.
        // Known widget classes keep the strict own-label rule.
        let labelledContainer = platform == .android && !androidInteractiveTypes.contains(type)
            && !iosInteractiveTypes.contains(type) && hasDescendantLabel(element)
        if rules.contains("missing_label") && isInteractive && enabled && !labelledContainer {
            if label.isEmpty && name.isEmpty {
                violations.append([
                    "rule": "missing_label",
                    "type": type,
                    "message": "Interactive element of type \(type) has no accessibility label or name.",
                ])
            }
        }

        // Rule: small_tap_target
        if rules.contains("small_tap_target") && isInteractive && enabled {
            if let frame = element["frame"] as? [String: String],
               let wStr = frame["width"], let hStr = frame["height"],
               let w = Double(wStr), let h = Double(hStr) {
                let minimum = minimumTapTarget(for: platform)
                let unit = platform == .ios ? "pt" : "dp"
                if w < minimum || h < minimum {
                    let desc = label.isEmpty ? (name.isEmpty ? type : name) : label
                    violations.append([
                        "rule": "small_tap_target",
                        "type": type,
                        "element": desc,
                        "size": "\(Int(w))x\(Int(h))",
                        "message": "Tap target \"\(desc)\" is \(Int(w))x\(Int(h))\(unit), below the \(Int(minimum))x\(Int(minimum))\(unit) minimum.",
                    ])
                }
            }
        }

        // Recurse into children
        if let children = element["children"] as? [[String: Any]] {
            for child in children {
                checkViolations(element: child, rules: rules, platform: platform, violations: &violations)
            }
        }
    }
}

// MARK: - Value Helpers

extension Value {
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var doubleValue: Double? {
        switch self {
        case .double(let d):
            return d
        case .int(let i):
            return Double(i)
        case .string(let s):
            return Double(s)
        default:
            return nil
        }
    }

    var intValue: Int? {
        switch self {
        case .int(let i):
            return i
        case .double(let d):
            return Int(d)
        case .string(let s):
            return Int(s)
        default:
            return nil
        }
    }

    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    var arrayValue: [Value]? {
        if case .array(let arr) = self { return arr }
        return nil
    }

    var objectValue: [String: Value]? {
        if case .object(let obj) = self { return obj }
        return nil
    }
}
