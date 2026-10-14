import Foundation

/// Generates Maestro YAML flow files from grantiva.yml screen configs.
public enum FlowGenerator {
    /// The name the generated screens flow carries, so the runner, the ready
    /// file and the report call the screens session `screens`, not `flow`.
    public static let screensFlowName = "screens"

    /// Generate a single Maestro YAML flow that navigates all screens and takes screenshots.
    public static func generate(
        screens: [GrantivaConfig.Screen],
        bundleId: String,
        environment: [String: String] = [:],
        platform: Platform = .ios
    ) -> String {
        generateWithMap(screens: screens, bundleId: bundleId, environment: environment, platform: platform).yaml
    }

    /// Which configured screen (and which of its steps) a generated
    /// top-level command came from. `step` is nil for the launch, the settle
    /// before a screenshot and the screenshot itself.
    public struct CommandOwner: Sendable, Equatable {
        public let screen: String
        public let step: Int?
    }

    /// The generated flow plus the owner of each of its top-level commands, in
    /// order, so the runner's per-command report can be read back per screen
    /// and per step.
    public static func generateWithMap(
        screens: [GrantivaConfig.Screen],
        bundleId: String,
        environment: [String: String] = [:],
        platform: Platform = .ios
    ) -> (yaml: String, owners: [CommandOwner]) {
        var lines: [String] = []
        var owners: [CommandOwner] = []
        func commandCount() -> Int { lines.filter { $0.hasPrefix("- ") }.count }
        func claim(_ owner: CommandOwner) {
            let count = commandCount()
            if count < owners.count { owners.removeLast(owners.count - count) }
            owners += Array(repeating: owner, count: count - owners.count)
        }

        // Header
        lines.append("appId: \(FlowEnvironment.quoted(bundleId))")
        lines.append("name: \(FlowEnvironment.quoted(screensFlowName))")
        lines.append("---")

        // launchApp creates the WDA session — required before any interaction.
        // `--env` values ride the runner's existing launchApp field for the
        // platform: `environment:` on iOS, `arguments:` (intent extras) on Android.
        if environment.isEmpty {
            lines.append("- launchApp")
        } else {
            lines.append("- launchApp:")
            lines.append("    \(FlowEnvironment.launchField(for: platform)):")
            for key in environment.keys.sorted() {
                lines.append("      \(key): \(FlowEnvironment.quoted(environment[key] ?? ""))")
            }
        }
        if platform == .android {
            lines += appDrawnWait
        }

        for (screenIndex, screen) in screens.enumerated() {
            if screenIndex == 0 { claim(CommandOwner(screen: screen.name, step: nil)) }
            if case .steps(let steps) = screen.path {
                for (stepIndex, step) in steps.enumerated() {
                    defer { claim(CommandOwner(screen: screen.name, step: stepIndex)) }
                    if let label = step.tap {
                        appendSelector("tapOn", label, byId: step.tapById, exact: step.tapExact, to: &lines)
                        appendSettle(to: &lines)
                    }
                    if let direction = step.swipe {
                        lines.append("- swipe:")
                        if let start = step.swipeStart, let end = step.swipeEnd {
                            lines.append("    start: \(FlowEnvironment.quoted(start))")
                            lines.append("    end: \(FlowEnvironment.quoted(end))")
                        } else {
                            lines.append("    direction: \(maestroSwipeDirection(direction))")
                        }
                        if let duration = step.swipeDuration {
                            lines.append("    duration: \(duration)")
                        }
                        if let from = step.swipeFrom {
                            if step.swipeFromById {
                                lines.append("    from:")
                                lines.append("      id: \(FlowEnvironment.quoted(from))")
                            } else {
                                lines.append("    from: \(FlowEnvironment.quoted(from))")
                            }
                        }
                        appendSettle(to: &lines)
                    }
                    if let text = step.type {
                        lines.append("- inputText: \(FlowEnvironment.quoted(text))")
                        appendSettle(to: &lines)
                    }
                    if let seconds = step.wait {
                        lines.append("- evalScript:")
                        lines.append("    script: \(FlowEnvironment.quoted(sleepScript(seconds: seconds)))")
                        lines.append("    label: \(FlowEnvironment.quoted(waitLabel(seconds: seconds)))")
                    }
                    if let seconds = step.settle {
                        // An explicit settle replaces the generated one before it.
                        if lines.suffix(2).first == "- waitForAnimationToEnd:" { lines.removeLast(2) }
                        lines.append("- waitForAnimationToEnd:")
                        lines.append("    timeout: \(Int(seconds * 1000))")
                    }
                    if let label = step.assertVisible {
                        if step.scrollUntilVisible {
                            appendScrollUntilVisible(label, step: step, to: &lines)
                        } else if let timeout = step.waitTimeout {
                            appendExtendedWait("visible", label, byId: step.assertVisibleById,
                                               exact: step.assertVisibleExact, timeout: timeout, to: &lines)
                        } else {
                            appendSelector("assertVisible", label, byId: step.assertVisibleById, exact: step.assertVisibleExact, to: &lines)
                        }
                    }
                    if let label = step.assertNotVisible {
                        if let timeout = step.waitTimeout {
                            appendExtendedWait("notVisible", label, byId: step.assertNotVisibleById,
                                               exact: step.assertNotVisibleExact, timeout: timeout, to: &lines)
                        } else {
                            appendSelector(
                                "assertNotVisible", label, byId: step.assertNotVisibleById, exact: step.assertNotVisibleExact, to: &lines
                            )
                        }
                    }
                    if let path = step.runFlow {
                        lines.append("- runFlow: \(FlowEnvironment.quoted(path))")
                        appendSettle(to: &lines)
                    }
                }
            }
            appendSettle(to: &lines)
            lines.append("- takeScreenshot: \(FlowEnvironment.quoted(screen.name))")
            claim(CommandOwner(screen: screen.name, step: nil))
        }

        return (lines.joined(separator: "\n") + "\n", owners)
    }

    /// The `Wait Ns` label of each generated `wait:` step, keyed by its
    /// top-level command index in the generated flow.
    public static func waitLabels(inGenerated yaml: String) -> [Int: String] {
        let body = yaml.components(separatedBy: "\n---\n").last ?? yaml
        var labels: [Int: String] = [:]
        var index = -1
        var inEvalScript = false
        for line in body.components(separatedBy: "\n") {
            if line.hasPrefix("- ") {
                index += 1
                inEvalScript = line == "- evalScript:"
            } else if inEvalScript, line.hasPrefix("    label: ") {
                let raw = String(line.dropFirst("    label: ".count))
                labels[index] = raw.hasPrefix("\"") && raw.hasSuffix("\"") && raw.count >= 2 ? String(raw.dropFirst().dropLast()) : raw
            }
        }
        return labels
    }

    /// Write a flow to a temporary file, returning the path.
    public static func writeTemp(
        screens: [GrantivaConfig.Screen],
        bundleId: String,
        environment: [String: String] = [:],
        platform: Platform = .ios,
        runFlowBaseDirectory: String = FileManager.default.currentDirectoryPath,
        fileName: String = "flow.yaml"
    ) throws -> String {
        try writeTempWithMap(
            screens: screens, bundleId: bundleId, environment: environment, platform: platform,
            runFlowBaseDirectory: runFlowBaseDirectory, fileName: fileName
        ).path
    }

    /// `writeTemp` plus each rewritten `runFlow` path mapped back to the
    /// path as written in the config, for output rewriting.
    static func writeTempWithMap(
        screens: [GrantivaConfig.Screen],
        bundleId: String,
        environment: [String: String] = [:],
        platform: Platform = .ios,
        runFlowBaseDirectory: String = FileManager.default.currentDirectoryPath,
        fileName: String = "flow.yaml"
    ) throws -> (path: String, asWritten: [String: String], owners: [CommandOwner]) {
        // One directory per call: concurrent runs against different simulators
        // must not share (and delete) each other's generated flow.
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-flows-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        var asWritten: [String: String] = [:]
        let generated = generateWithMap(screens: screens, bundleId: bundleId, environment: environment, platform: platform)
        let yaml = try FlowReferenceResolver.resolve(
            in: generated.yaml,
            relativeTo: runFlowBaseDirectory,
            asWritten: &asWritten
        )
        // Named like the config file, so the runner's own lines read
        // `screens (grantiva.yml)` rather than naming a generated file.
        let flowPath = tempDir.appendingPathComponent(fileName).path
        try yaml.write(toFile: flowPath, atomically: true, encoding: .utf8)
        return (flowPath, asWritten, generated.owners)
    }

    /// How long the first screen waits for the app to draw after launch.
    static let appDrawnTimeoutMs = 10_000

    /// Android only (L44): after `launchApp`, wait (up to
    /// `appDrawnTimeoutMs`) until an element with text exists inside the
    /// app's content view, so the first screenshot is never the blank window
    /// a cold start shows before its first frame. The settle alone cannot
    /// tell: a window that has not drawn yet is static. Optional, so a first
    /// screen without text costs the timeout instead of failing; when the app
    /// has already drawn it is one lookup. iOS launches return once the app
    /// is running and drawn, so iOS gets nothing.
    static let appDrawnWait = [
        "- extendedWaitUntil:",
        "    visible:",
        "      text: \".+\"",
        "      childOf:",
        "        id: \"android:id/content\"",
        "    timeout: \(appDrawnTimeoutMs)",
        "    optional: true",
        "    label: \"Wait for the app to draw\"",
    ]

    /// Upper bound for the settle wait after a tap, swipe, or typed text and
    /// before each screenshot. `waitForAnimationToEnd` returns as soon as two
    /// consecutive screenshots match, so this only costs time while the
    /// screen is still changing.
    static let settleTimeoutMs = 5000

    /// The runner dispatches a tap and returns before the app has rendered
    /// the destination; without a settle the next screenshot can show the
    /// previous screen. A settle directly after another settle (including a
    /// Maestro `waitForAnimationToEnd`) is skipped.
    private static func appendSettle(to lines: inout [String]) {
        if lines.suffix(2).first == "- waitForAnimationToEnd:" { return }
        lines.append(contentsOf: ["- waitForAnimationToEnd:", "    timeout: \(settleTimeoutMs)"])
    }

    /// `byId` selects by accessibility identifier (`id:`); `exact` requires
    /// the element's full text to equal the label; otherwise a text match.
    private static func appendSelector(
        _ command: String, _ label: String, byId: Bool, exact: Bool = false, to lines: inout [String]
    ) {
        if byId {
            lines.append("- \(command):")
            lines.append("    id: \(FlowEnvironment.quoted(label))")
        } else if exact {
            lines.append("- \(command):")
            lines.append("    text: \(FlowEnvironment.quoted(label))")
            lines.append("    exact: true")
        } else {
            lines.append("- \(command): \(FlowEnvironment.quoted(label))")
        }
    }

    /// Maestro `extendedWaitUntil` kept as written, so its `timeout` is the
    /// wait's real bound rather than the runner's default for an assertion.
    private static func appendExtendedWait(
        _ key: String, _ label: String, byId: Bool, exact: Bool, timeout: Int, to lines: inout [String]
    ) {
        lines.append("- extendedWaitUntil:")
        appendNestedSelector(key, label, byId: byId, exact: exact, to: &lines)
        lines.append("    timeout: \(timeout)")
    }

    /// Maestro `scrollUntilVisible` kept as a scroll, with its direction and
    /// timeout when the source gave them.
    private static func appendScrollUntilVisible(_ label: String, step: GrantivaConfig.Screen.Step, to lines: inout [String]) {
        lines.append("- scrollUntilVisible:")
        appendNestedSelector("element", label, byId: step.assertVisibleById, exact: step.assertVisibleExact, to: &lines)
        if let direction = step.scrollDirection {
            lines.append("    direction: \(direction.uppercased())")
        }
        if let timeout = step.waitTimeout {
            lines.append("    timeout: \(timeout)")
        }
        appendSettle(to: &lines)
    }

    private static func appendNestedSelector(_ key: String, _ label: String, byId: Bool, exact: Bool, to lines: inout [String]) {
        if byId {
            lines.append("    \(key):")
            lines.append("      id: \(FlowEnvironment.quoted(label))")
        } else if exact {
            lines.append("    \(key):")
            lines.append("      text: \(FlowEnvironment.quoted(label))")
            lines.append("      exact: true")
        } else {
            lines.append("    \(key): \(FlowEnvironment.quoted(label))")
        }
    }

    /// `wait: N` must sleep N seconds unconditionally. The runner has no sleep
    /// command, and `waitForAnimationToEnd` is only an upper bound: it returns
    /// as soon as the screen is still. The runner's JS engine runs `evalScript`
    /// synchronously. `Date.now()` is integral milliseconds, so the deadline
    /// rounds the requested duration up and includes one clock quantum;
    /// otherwise a sample late in the first millisecond can let `wait: 3`
    /// finish at 2999.x ms. This closes that quantization boundary; like every
    /// `Date.now()` deadline, it cannot protect against a wall-clock jump.
    /// The loop spins one core for those N seconds; a sleep command in the
    /// runner is the real fix and belongs in the runner repo.
    static func sleepScript(seconds: Double) -> String {
        let ms = sleepDeadlineMilliseconds(seconds: seconds)
        return "${var grantivaWaitUntil = Date.now() + \(ms); while (Date.now() < grantivaWaitUntil) {}}"
    }

    static func sleepDeadlineMilliseconds(seconds: Double) -> Int {
        Int(ceil(seconds * 1000)) + 1
    }

    /// The step's name in run reports, instead of the raw script.
    static func waitLabel(seconds: Double) -> String {
        let value = seconds == seconds.rounded() ? String(Int(seconds)) : String(seconds)
        return "Wait \(value)s"
    }

    private static func maestroSwipeDirection(_ direction: String) -> String {
        switch direction.lowercased() {
        case "up": return "UP"
        case "down": return "DOWN"
        case "left": return "LEFT"
        case "right": return "RIGHT"
        default: return direction.uppercased()
        }
    }
}
