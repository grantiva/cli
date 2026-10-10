import Foundation
import Yams

/// Parses Maestro flow YAML files into Grantiva's internal config model.
///
/// Maestro flows use a two-document YAML format separated by `---`:
/// ```yaml
/// appId: com.example.app
/// name: Login Flow
/// ---
/// - launchApp
/// - tapOn: "Login"
/// - inputText: "user@example.com"
/// - takeScreenshot: "Login Screen"
/// ```
///
/// Each `takeScreenshot` becomes a named screen in Grantiva. Commands between
/// screenshots become the navigation steps for that screen.
public struct MaestroFlowParser {

    // MARK: - Public API

    /// Parse a Maestro flow YAML string into a GrantivaConfig.
    public static func parse(
        _ content: String,
        sourceName: String = "<input>",
        allowUnsupportedCommands: Bool = false
    ) throws -> GrantivaConfig {
        let (configSection, commandsSection) = splitDocuments(content)

        // Parse config section
        var bundleId: String?
        var flowName: String?

        if let configSection,
           let config = try Yams.load(yaml: configSection) as? [String: Any] {
            bundleId = config["appId"] as? String
            flowName = config["name"] as? String
        }

        // Parse commands section
        var screens: [GrantivaConfig.Screen] = []

        if let commandsSection,
           let rawCommands = try Yams.load(yaml: commandsSection) as? [Any] {
            screens = try convertToScreens(
                rawCommands,
                flowName: flowName,
                sourceName: sourceName,
                lineNumbers: commandLineNumbers(in: content),
                allowUnsupportedCommands: allowUnsupportedCommands
            )
        }

        return GrantivaConfig(bundleId: bundleId, screens: screens)
    }

    /// Parse all Maestro flow files in a directory and merge into a single config.
    public static func loadDirectory(_ directory: URL) throws -> GrantivaConfig {
        let fm = FileManager.default
        let files = try fm.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".yaml") || $0.hasSuffix(".yml") }
            .sorted()

        guard !files.isEmpty else {
            throw GrantivaError.invalidArgument("No flow files found in \(directory.path)")
        }

        var allScreens: [GrantivaConfig.Screen] = []
        var bundleId: String?

        for file in files {
            let filePath = directory.appendingPathComponent(file)
            let contents = try String(contentsOf: filePath, encoding: .utf8)
            let flowConfig = try parse(contents, sourceName: filePath.path)

            if bundleId == nil {
                bundleId = flowConfig.bundleId
            }
            allScreens.append(contentsOf: flowConfig.screens)
        }

        return GrantivaConfig(bundleId: bundleId, screens: allScreens)
    }

    /// The `appId:` from a flow's header document, if it has one.
    public static func appId(in content: String) -> String? {
        guard let header = splitDocuments(content).config,
              let config = try? Yams.load(yaml: header) as? [String: Any],
              let appId = config["appId"] as? String,
              !appId.trimmingCharacters(in: .whitespaces).isEmpty
        else { return nil }
        return appId
    }

    /// Detect whether a YAML string is in Maestro format rather than Grantiva format.
    public static func isMaestroFormat(_ content: String) -> Bool {
        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("appId:") { return true }
            if trimmed.hasPrefix("- tapOn:") || trimmed == "- tapOn" { return true }
            if trimmed.hasPrefix("- launchApp") { return true }
            if trimmed.hasPrefix("- inputText:") { return true }
            if trimmed.hasPrefix("- assertVisible:") { return true }
            if trimmed.hasPrefix("- takeScreenshot:") { return true }
        }
        return false
    }

    /// Parse Maestro commands into Grantiva steps (for `runFlow` sub-flow support).
    public static func parseSteps(
        _ content: String,
        sourceName: String = "<input>",
        allowUnsupportedCommands: Bool = false
    ) throws -> [GrantivaConfig.Screen.Step] {
        let (_, commandsSection) = splitDocuments(content)
        let yaml = commandsSection ?? content

        guard let rawCommands = try Yams.load(yaml: yaml) as? [Any] else {
            return []
        }

        var steps: [GrantivaConfig.Screen.Step] = []
        let lineNumbers = commandLineNumbers(in: content)
        for (index, raw) in rawCommands.enumerated() {
            guard let parsed = parseCommand(raw) else { continue }
            switch parsed {
            case .step(let step):
                steps.append(step)
            case .unsupported(let command) where !allowUnsupportedCommands:
                throw unsupportedCommand(command, sourceName: sourceName, line: lineNumbers[safe: index])
            default:
                break
            }
        }
        return steps
    }

    // MARK: - Document Splitting

    /// Split a Maestro YAML into config and commands sections at the `---` separator.
    static func splitDocuments(_ content: String) -> (config: String?, commands: String?) {
        let lines = content.components(separatedBy: "\n")

        // Find --- separator (not at the very start of the file)
        var separatorIndex: Int?
        for (i, line) in lines.enumerated() {
            if i > 0 && line.trimmingCharacters(in: .whitespaces) == "---" {
                separatorIndex = i
                break
            }
        }

        if let idx = separatorIndex {
            let configPart = lines[0..<idx].joined(separator: "\n")
            let commandsPart = lines[(idx + 1)...].joined(separator: "\n")
            let trimmedConfig = configPart.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedCommands = commandsPart.trimmingCharacters(in: .whitespacesAndNewlines)
            return (
                trimmedConfig.isEmpty ? nil : configPart,
                trimmedCommands.isEmpty ? nil : commandsPart
            )
        }

        // No separator — check if content is a command array (starts with -) or config
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("-") {
            return (nil, content)
        }
        return (content, nil)
    }

    // MARK: - Command → Screen Conversion

    /// Convert a flat list of Maestro commands into Grantiva screens.
    /// Each `takeScreenshot` creates a screen boundary.
    static func convertToScreens(
        _ commands: [Any],
        flowName: String?,
        sourceName: String,
        lineNumbers: [Int],
        allowUnsupportedCommands: Bool
    ) throws -> [GrantivaConfig.Screen] {
        var screens: [GrantivaConfig.Screen] = []
        var currentSteps: [GrantivaConfig.Screen.Step] = []
        var screenIndex = 0

        for (index, raw) in commands.enumerated() {
            guard let command = parseCommand(raw) else { continue }

            switch command {
            case .takeScreenshot(let name):
                let screenName = name ?? "\(flowName ?? "Screen")_\(screenIndex)"
                if currentSteps.isEmpty {
                    screens.append(.init(name: screenName, path: .launch))
                } else {
                    screens.append(.init(name: screenName, path: .steps(currentSteps)))
                    currentSteps = []
                }
                screenIndex += 1

            case .launchApp, .stopApp:
                break

            case .unsupported(let name):
                guard allowUnsupportedCommands else {
                    throw unsupportedCommand(name, sourceName: sourceName, line: lineNumbers[safe: index])
                }

            case .step(let step):
                currentSteps.append(step)
            }
        }

        // Remaining steps after the last takeScreenshot → one more screen
        if !currentSteps.isEmpty {
            let name = "\(flowName ?? "Screen")_\(screenIndex)"
            screens.append(.init(name: name, path: .steps(currentSteps)))
        }

        // If no screens at all (e.g., just launchApp), add a launch screen
        if screens.isEmpty {
            screens.append(.init(name: flowName ?? "Launch", path: .launch))
        }

        return screens
    }

    // MARK: - Command Parsing

    enum ParsedCommand {
        case launchApp
        case stopApp
        case takeScreenshot(name: String?)
        case step(GrantivaConfig.Screen.Step)
        case unsupported(String)
    }

    /// Parse a single Maestro command (either a bare string or a dictionary).
    static func parseCommand(_ raw: Any) -> ParsedCommand? {
        // Bare string commands: "launchApp", "back", "stopApp", "scroll"
        if let str = raw as? String {
            switch str {
            case "launchApp": return .launchApp
            case "stopApp", "killApp": return .stopApp
            case "back": return .unsupported(str)
            case "scroll": return .step(.init(swipe: "up")) // default scroll down = swipe up
            case "waitForAnimationToEnd": return .step(.init(settle: defaultSettleSeconds))
            default: return .unsupported(str)
            }
        }

        guard let dict = raw as? [String: Any] else { return nil }

        // --- Tap variants ---

        for command in ["tapOn", "doubleTapOn", "longPressOn"] {
            if let val = dict[command] {
                return parseTapSelector(val, command: command)
            }
        }

        // --- Text input ---

        if let val = dict["inputText"] {
            if let text = val as? String {
                return .step(.init(type: text))
            }
            return .unsupported("inputText")
        }

        // --- Assertions ---

        if let val = dict["assertVisible"] {
            if let (label, byId) = selector(val) {
                return .step(.init(assertVisible: label, assertVisibleById: byId))
            }
            return .unsupported("assertVisible")
        }

        if let val = dict["assertNotVisible"] {
            if let (label, byId) = selector(val) {
                return .step(.init(assertNotVisible: label, assertNotVisibleById: byId))
            }
            return .unsupported("assertNotVisible")
        }

        // --- Swipe (direction, optionally from an element, or coordinates) ---

        if let val = dict["swipe"] as? [String: Any] {
            if let raw = val["direction"] as? String {
                let direction = raw.lowercased()
                guard GrantivaConfig.Screen.Step.swipeDirectionNames.contains(direction) else {
                    return .unsupported("swipe")
                }
                var step = GrantivaConfig.Screen.Step(swipe: direction)
                step.swipeDuration = asInt(val["duration"])
                if val["from"] != nil {
                    guard let (label, byId) = selector(val["from"]) else { return .unsupported("swipe") }
                    step.swipeFrom = label
                    step.swipeFromById = byId
                }
                return .step(step)
            }
            if let start = point(val["start"]), let end = point(val["end"]) {
                let dx = end.x - start.x
                let dy = end.y - start.y
                let direction: String
                if abs(dx) > abs(dy) {
                    direction = dx > 0 ? "right" : "left"
                } else {
                    direction = dy > 0 ? "down" : "up"
                }
                var step = GrantivaConfig.Screen.Step(swipe: direction)
                step.swipeDuration = asInt(val["duration"])
                // Maestro's `"x%, y%"` points are kept so the generated flow
                // swipes exactly there. Pixel points ("100, 200") and the
                // legacy `{x:, y:}` maps keep swiping by direction only: the
                // runner reads every start/end value as a percentage.
                if let start = val["start"] as? String, let end = val["end"] as? String,
                   start.contains("%"), end.contains("%") {
                    step.swipeStart = start
                    step.swipeEnd = end
                }
                return .step(step)
            }
            return .unsupported("swipe")
        }

        // --- Scroll → swipe (inverted: Maestro scroll down = finger swipe up) ---

        if dict.keys.contains("scroll") {
            let scrollDir: String
            if let obj = dict["scroll"] as? [String: Any] {
                scrollDir = obj["direction"] as? String ?? "down"
            } else {
                scrollDir = "down"
            }
            return .step(.init(swipe: invertDirection(scrollDir)))
        }

        // --- scrollUntilVisible → assertVisible ---

        if let val = dict["scrollUntilVisible"] as? [String: Any] {
            if let (label, byId) = selector(val["element"]) ?? selector(val) {
                return .step(.init(assertVisible: label, assertVisibleById: byId))
            }
            return .unsupported("scrollUntilVisible")
        }

        // --- Wait ---

        // A settle, not a sleep: it returns as soon as the screen is still.
        if dict.keys.contains("waitForAnimationToEnd") {
            let timeout = (dict["waitForAnimationToEnd"] as? [String: Any])?["timeout"]
            let seconds = asDouble(timeout).map { $0 / 1000.0 } ?? defaultSettleSeconds
            return .step(.init(settle: seconds))
        }

        if let val = dict["extendedWaitUntil"] as? [String: Any] {
            if let (label, byId) = selector(val["visible"]) {
                return .step(.init(assertVisible: label, assertVisibleById: byId))
            }
            if let (label, byId) = selector(val["notVisible"]) {
                return .step(.init(assertNotVisible: label, assertNotVisibleById: byId))
            }
            // Older Grantiva form: `extendedWaitUntil: {text: X}`.
            if let (label, byId) = selector(val) {
                return .step(.init(assertVisible: label, assertVisibleById: byId))
            }
            return .unsupported("extendedWaitUntil")
        }

        // --- Screenshots ---

        if let val = dict["takeScreenshot"] {
            return .takeScreenshot(name: val as? String)
        }

        // --- Sub-flows ---

        if let val = dict["runFlow"] {
            if let path = val as? String {
                return .step(.init(runFlow: path))
            }
            if let obj = val as? [String: Any], let file = obj["file"] as? String {
                return .step(.init(runFlow: file))
            }
            return .unsupported("runFlow")
        }

        // --- App lifecycle ---

        if dict.keys.contains("launchApp") { return .launchApp }
        if dict.keys.contains("stopApp") || dict.keys.contains("killApp") { return .stopApp }

        // --- Unsupported (safe to ignore for VRT) ---
        // pressKey, setPermissions, setOrientation, setLocation, repeat, retry,
        // evalScript, runScript, copyTextFrom, pasteText, assertTrue, startRecording,
        // stopRecording, openLink, setAirplaneMode, toggleAirplaneMode

        return .unsupported(dict.keys.sorted().first ?? "<unknown>")
    }

    // MARK: - Helpers

    /// Upper bound for `waitForAnimationToEnd` without a `timeout:`.
    static let defaultSettleSeconds = 5.0

    /// Parse a Maestro tap selector (string, or object with text/id).
    private static func parseTapSelector(_ val: Any, command: String) -> ParsedCommand {
        if let (label, byId) = selector(val) {
            return .step(.init(tap: label, tapById: byId))
        }
        return .unsupported(command)
    }

    /// A Maestro element selector: a bare string or `{text: X}` matches text,
    /// `{id: X}` matches the accessibility identifier.
    private static func selector(_ val: Any?) -> (label: String, byId: Bool)? {
        if let text = val as? String { return (text, false) }
        guard let obj = val as? [String: Any] else { return nil }
        if let text = obj["text"] as? String { return (text, false) }
        if let id = obj["id"] as? String { return (id, true) }
        return nil
    }

    /// A swipe point: Maestro's `"x%, y%"` string, or `{x:, y:}`.
    private static func point(_ val: Any?) -> (x: Double, y: Double)? {
        if let obj = val as? [String: Any] {
            return (asDouble(obj["x"]) ?? 0, asDouble(obj["y"]) ?? 0)
        }
        guard let str = val as? String else { return nil }
        let parts = str.split(separator: ",").map {
            Double($0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: ""))
        }
        guard parts.count == 2, let x = parts[0], let y = parts[1] else { return nil }
        return (x, y)
    }

    private static func unsupportedCommand(
        _ command: String,
        sourceName: String,
        line: Int?
    ) -> GrantivaError {
        let location = line.map { "\(sourceName):\($0)" } ?? sourceName
        return .invalidArgument("\(location): unsupported Maestro command '\(command)'")
    }

    private static func commandLineNumbers(in content: String) -> [Int] {
        content.components(separatedBy: "\n").enumerated().compactMap { index, line in
            let indentation = line.prefix { $0 == " " || $0 == "\t" }
            let trimmed = line.dropFirst(indentation.count)
            guard indentation.isEmpty, trimmed == "-" || trimmed.hasPrefix("- ") else { return nil }
            return index + 1
        }
    }

    /// Invert scroll direction to swipe direction.
    /// Maestro "scroll down" = see content below = finger swipe up.
    private static func invertDirection(_ scrollDir: String) -> String {
        switch scrollDir.lowercased() {
        case "down": return "up"
        case "up": return "down"
        case "left": return "right"
        case "right": return "left"
        default: return "up"
        }
    }

    /// Coerce a YAML number to whole milliseconds.
    private static func asInt(_ value: Any?) -> Int? {
        asDouble(value).map { Int($0) }
    }

    /// Coerce YAML number (Int or Double) to Double.
    private static func asDouble(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        return nil
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
