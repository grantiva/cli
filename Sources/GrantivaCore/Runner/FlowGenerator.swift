import Foundation

/// Generates Maestro YAML flow files from grantiva.yml screen configs.
public enum FlowGenerator {
    /// Generate a single Maestro YAML flow that navigates all screens and takes screenshots.
    public static func generate(
        screens: [GrantivaConfig.Screen],
        bundleId: String,
        environment: [String: String] = [:],
        platform: Platform = .ios
    ) -> String {
        var lines: [String] = []

        // Header
        lines.append("appId: \(FlowEnvironment.quoted(bundleId))")
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

        for screen in screens {
            if case .steps(let steps) = screen.path {
                for step in steps {
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
                        appendSelector("assertVisible", label, byId: step.assertVisibleById, exact: step.assertVisibleExact, to: &lines)
                    }
                    if let label = step.assertNotVisible {
                        appendSelector(
                            "assertNotVisible", label, byId: step.assertNotVisibleById, exact: step.assertNotVisibleExact, to: &lines
                        )
                    }
                    if let path = step.runFlow {
                        lines.append("- runFlow: \(FlowEnvironment.quoted(path))")
                        appendSettle(to: &lines)
                    }
                }
            }
            appendSettle(to: &lines)
            lines.append("- takeScreenshot: \(FlowEnvironment.quoted(screen.name))")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// Write a flow to a temporary file, returning the path.
    public static func writeTemp(
        screens: [GrantivaConfig.Screen],
        bundleId: String,
        environment: [String: String] = [:],
        platform: Platform = .ios,
        runFlowBaseDirectory: String = FileManager.default.currentDirectoryPath,
        disableAlertAutoAccept: Bool = false
    ) throws -> String {
        try writeTempStaged(
            screens: screens, bundleId: bundleId, environment: environment,
            platform: platform, runFlowBaseDirectory: runFlowBaseDirectory, disableAlertAutoAccept: disableAlertAutoAccept
        ).path
    }

    /// `writeTemp`, also returning the staged `runFlow` copies (staged copy →
    /// original file) made when `disableAlertAutoAccept` is set, so runner
    /// output can name the originals.
    static func writeTempStaged(
        screens: [GrantivaConfig.Screen],
        bundleId: String,
        environment: [String: String] = [:],
        platform: Platform = .ios,
        runFlowBaseDirectory: String = FileManager.default.currentDirectoryPath,
        disableAlertAutoAccept: Bool = false
    ) throws -> (path: String, pathMap: [String: String]) {
        // One directory per call: concurrent runs against different simulators
        // must not share (and delete) each other's generated flow.
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-flows-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let stager = disableAlertAutoAccept
            ? FlowAlertStager(directory: tempDir.appendingPathComponent("subflows").path)
            : nil
        var yaml = try FlowReferenceResolver.resolve(
            in: generate(screens: screens, bundleId: bundleId, environment: environment, platform: platform),
            relativeTo: runFlowBaseDirectory,
            mapFile: stager.map { $0.stage }
        )
        if disableAlertAutoAccept {
            yaml = FlowAlertPolicy.disableAutoAccept(in: yaml)
        }
        let flowPath = tempDir.appendingPathComponent("flow.yaml").path
        try yaml.write(toFile: flowPath, atomically: true, encoding: .utf8)
        return (flowPath, stager?.pathMap ?? [:])
    }

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

    /// `wait: N` must sleep N seconds unconditionally. The runner has no sleep
    /// command, and `waitForAnimationToEnd` is only an upper bound: it returns
    /// as soon as the screen is still. The runner's JS engine runs `evalScript`
    /// synchronously, so a deadline loop holds the flow for exactly N seconds.
    /// The loop spins one core for those N seconds; a sleep command in the
    /// runner is the real fix and belongs in the runner repo.
    static func sleepScript(seconds: Double) -> String {
        let ms = Int(seconds * 1000)
        return "${var grantivaWaitUntil = Date.now() + \(ms); while (Date.now() < grantivaWaitUntil) {}}"
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
