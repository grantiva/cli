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
    ///
    /// `baseDirectory` is where relative `runFlow` paths are read from. A
    /// sub-flow that takes screenshots is expanded in place, so each of its
    /// `takeScreenshot`s is a screen like one in the parent; other sub-flows
    /// stay a single `runFlow` step.
    public static func parse(
        _ content: String,
        sourceName: String = "<input>",
        allowUnsupportedCommands: Bool = false,
        baseDirectory: URL? = nil
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
                allowUnsupportedCommands: allowUnsupportedCommands,
                baseDirectory: baseDirectory
            )
        }

        var config = GrantivaConfig(bundleId: bundleId, screens: screens)
        config.environment = FlowEnvironment.headerEnvironment(content)
        config.warnings = FlowEnvironment.headerKeyWarnings(content).map { "\(sourceName): \($0)" }
        return config
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
            let flowConfig = try parse(contents, sourceName: filePath.path, baseDirectory: directory)

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
    /// Each `takeScreenshot` creates a screen boundary, including one inside a
    /// `runFlow` sub-flow (read from `baseDirectory`) or an inline
    /// `runFlow: {commands: [...]}` block.
    static func convertToScreens(
        _ commands: [Any],
        flowName: String?,
        sourceName: String,
        lineNumbers: [Int],
        allowUnsupportedCommands: Bool,
        baseDirectory: URL? = nil
    ) throws -> [GrantivaConfig.Screen] {
        var screens: [GrantivaConfig.Screen] = []
        var currentSteps: [GrantivaConfig.Screen.Step] = []
        var screenIndex = 0
        // Which file each screen name came from, to refuse a name used twice
        // across a parent and its sub-flow (one capture would overwrite the other).
        var origins: [String: String] = [:]

        func addScreen(_ screen: GrantivaConfig.Screen, from source: String) throws {
            if let earlier = origins[screen.name], earlier != source {
                throw GrantivaError.invalidArgument(
                    "\(source): screen \"\(screen.name)\" is also taken in \(earlier); give one of the takeScreenshot steps another name."
                )
            }
            origins[screen.name] = source
            screens.append(screen)
        }

        // The generated flow opens with its own launchApp, so a launchApp
        // before any other command is that one; a later one is a relaunch.
        var seenCommand = false

        func walk(_ commands: [Any], source: String, lines: [Int], directory: URL?, stack: [String]) throws {
            for (index, raw) in commands.enumerated() {
                if let expansion = expandableSubFlow(raw, source: source, line: lines[safe: index], directory: directory, stack: stack) {
                    try walk(
                        expansion.commands, source: expansion.source, lines: expansion.lines,
                        directory: expansion.directory, stack: expansion.path.map { stack + [$0] } ?? stack
                    )
                    continue
                }
                guard let command = parseCommand(raw) else { continue }
                defer { seenCommand = true }

                switch command {
                case .takeScreenshot(let name):
                    let screenName = name ?? "\(flowName ?? "Screen")_\(screenIndex)"
                    if currentSteps.isEmpty {
                        try addScreen(.init(name: screenName, path: .launch), from: source)
                    } else {
                        try addScreen(.init(name: screenName, path: .steps(currentSteps)), from: source)
                        currentSteps = []
                    }
                    screenIndex += 1

                case .launchApp:
                    if seenCommand { currentSteps.append(.init(app: .launchApp)) }

                case .stopApp(let app):
                    currentSteps.append(.init(app: app))

                case .unsupported(let name):
                    guard allowUnsupportedCommands else {
                        throw unsupportedCommand(name, sourceName: source, line: lines[safe: index])
                    }

                case .step(let step):
                    currentSteps.append(step)
                }
            }
        }

        let rootPath = baseDirectory.map { $0.appendingPathComponent((sourceName as NSString).lastPathComponent).standardizedFileURL.path }
        try walk(commands, source: sourceName, lines: lineNumbers, directory: baseDirectory, stack: rootPath.map { [$0] } ?? [])

        // Remaining steps after the last takeScreenshot → one more screen,
        // unless they only stop the app (a cleanup step with nothing to see).
        if currentSteps.contains(where: { $0.app == nil || $0.app == .launchApp }) {
            let name = "\(flowName ?? "Screen")_\(screenIndex)"
            screens.append(.init(name: name, path: .steps(currentSteps)))
        }

        // If no screens at all (e.g., just launchApp), add a launch screen
        if screens.isEmpty {
            screens.append(.init(name: flowName ?? "Launch", path: .launch))
        }

        return screens
    }

    private struct SubFlowExpansion {
        let commands: [Any]
        let source: String
        let lines: [Int]
        let directory: URL?
        /// The sub-flow file, nil for an inline block.
        let path: String?
    }

    /// A `runFlow` whose commands take a screenshot, to be walked in place.
    /// Anything else (no screenshot, a `when:` condition, a missing file, a
    /// cycle) stays a plain `runFlow` step for the runner to execute and report.
    private static func expandableSubFlow(_ raw: Any, source: String, line: Int?, directory: URL?, stack: [String]) -> SubFlowExpansion? {
        guard let dict = raw as? [String: Any], dict.count == 1, let value = dict["runFlow"] else { return nil }
        if let options = value as? [String: Any], options["file"] == nil, options["when"] == nil,
           let inline = options["commands"] as? [Any] {
            // Inline commands live in the parent file: an error in one names
            // the parent and the line of its `runFlow`.
            let parentLines = line.map { Array(repeating: $0, count: inline.count) } ?? []
            return SubFlowExpansion(commands: inline, source: source, lines: parentLines, directory: directory, path: nil)
        }
        let file = (value as? String) ?? ((value as? [String: Any]).flatMap { $0["when"] == nil ? $0["file"] as? String : nil })
        guard let file, let directory else { return nil }
        let url = NSString(string: file).isAbsolutePath
            ? URL(fileURLWithPath: file)
            : directory.appendingPathComponent(file)
        let path = url.standardizedFileURL.path
        guard !stack.contains(path),
              let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let section = splitDocuments(contents).commands ?? ""
        guard let commands = (try? Yams.load(yaml: section)) as? [Any],
              commands.contains(where: { ($0 as? [String: Any])?["takeScreenshot"] != nil }) else { return nil }
        return SubFlowExpansion(
            commands: commands, source: file, lines: commandLineNumbers(in: contents),
            directory: url.deletingLastPathComponent(), path: path
        )
    }

    // MARK: - Command Parsing

    enum ParsedCommand {
        case launchApp
        /// `stopApp` or `killApp`.
        case stopApp(GrantivaConfig.Screen.Step.AppCommand)
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
            case "stopApp": return .stopApp(.stopApp)
            case "killApp": return .stopApp(.killApp)
            case "back": return .unsupported(str)
            case "scroll": return .step(.init(swipe: "up")) // default scroll down = swipe up
            case "waitForAnimationToEnd": return .step(.init(settle: defaultSettleSeconds))
            default: return .unsupported(str)
            }
        }

        guard let dict = raw as? [String: Any] else { return nil }

        // --- Tap variants ---

        for gesture in [GrantivaConfig.Screen.Step.TapGesture.tap, .doubleTap, .longPress] {
            if let val = dict[gesture.rawValue] {
                return parseTapSelector(val, gesture: gesture)
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
                var step = GrantivaConfig.Screen.Step(assertVisible: label, assertVisibleById: byId)
                step.scrollUntilVisible = true
                step.scrollDirection = (val["direction"] as? String)?.lowercased()
                step.waitTimeout = asInt(val["timeout"])
                return .step(step)
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

        // `timeout:` is kept: it bounds the wait, and the runner's default
        // for a plain assertion is a different number.
        if let val = dict["extendedWaitUntil"] as? [String: Any] {
            let timeout = asInt(val["timeout"])
            if let (label, byId, exact) = exactSelector(val["visible"]) {
                var step = GrantivaConfig.Screen.Step(assertVisible: label, assertVisibleById: byId, assertVisibleExact: exact)
                step.waitTimeout = timeout
                return .step(step)
            }
            if let (label, byId, exact) = exactSelector(val["notVisible"]) {
                var step = GrantivaConfig.Screen.Step(assertNotVisible: label, assertNotVisibleById: byId, assertNotVisibleExact: exact)
                step.waitTimeout = timeout
                return .step(step)
            }
            // Older Grantiva form: `extendedWaitUntil: {text: X}`.
            if let (label, byId) = selector(val) {
                var step = GrantivaConfig.Screen.Step(assertVisible: label, assertVisibleById: byId)
                step.waitTimeout = timeout
                return .step(step)
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
        if dict.keys.contains("stopApp") { return .stopApp(.stopApp) }
        if dict.keys.contains("killApp") { return .stopApp(.killApp) }

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
    private static func parseTapSelector(_ val: Any, gesture: GrantivaConfig.Screen.Step.TapGesture) -> ParsedCommand {
        if let (label, byId) = selector(val) {
            var step = GrantivaConfig.Screen.Step(tap: label, tapById: byId)
            step.tapGesture = gesture
            return .step(step)
        }
        return .unsupported(gesture.rawValue)
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

    /// `selector` plus `exact: true` on the mapping form.
    private static func exactSelector(_ val: Any?) -> (label: String, byId: Bool, exact: Bool)? {
        guard let (label, byId) = selector(val) else { return nil }
        let exact = ((val as? [String: Any])?["exact"] as? Bool) ?? false
        return (label, byId, !byId && exact)
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
