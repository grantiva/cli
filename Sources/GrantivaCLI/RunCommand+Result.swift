import Foundation
import ArgumentParser
import GrantivaCore

/// What `run` prints when it finishes: the plain-text result and the
/// `--json` document.
extension RunCommand {
    /// Emits the runner result and turns a failed step into the command's
    /// failure exit. Warned optional steps remain passing.
    static func emitRunResult(
        captures: [ScreenCapture], captureDir: String, json: Bool,
        resultOutput: ResultOutput, reportDir: String? = nil
    ) throws {
        let allPassed = captures.allSatisfy { $0.steps.allSatisfy { $0.status.isPassing } }
        if json {
            try resultOutput.emit(RunResult(
                screens: captures.map(RunResult.ScreenResult.init), allPassed: allPassed, reportDir: reportDir
            ))
        } else {
            for line in resultLines(captures: captures, captureDir: captureDir) {
                Output.line(line)
            }
        }
        if !allPassed { throw ExitCode.failure }
    }

    /// The plain-text result: one block per configured screen and per flow,
    /// then screens and flows counted separately (a flow's screenshots are
    /// not screens).
    /// `skippedFlows` (a failed fail-fast run) are shown as skipped, not as
    /// failures, and counted apart.
    static func resultLines(captures: [ScreenCapture], captureDir: String, skippedFlows: Set<String> = []) -> [String] {
        var lines: [String] = []
        for capture in captures {
            lines.append("\n  \(capture.screenName)")
            if capture.kind == .flow, skippedFlows.contains(capture.screenName) {
                lines.append("    - Skipped: not run")
                continue
            }
            for step in capture.steps {
                let icon: String
                switch step.status {
                case .passed: icon = "\u{2713}"
                case .warned: icon = "\u{26A0}"
                case .failed: icon = "\u{2717}"
                }
                lines.append("    \(icon) \(step.action)")
                if let msg = step.message {
                    lines.append("      \(msg)")
                }
            }
            for shot in capture.screenshots {
                lines.append("    \u{25B8} Screenshot: \(shot.name)")
            }
        }
        lines.append("")
        lines += summaryLines(captures: captures, skippedFlows: skippedFlows)
        lines.append("  Screenshots: \(captureDir)/")
        lines.append("")
        return lines
    }

    /// The text result of a suite that threw: the blocks of every screen and
    /// flow that ran, then the summary lines; nothing when nothing ran.
    static func failureLines(report: RunnerFailureReport, captureDir: String) -> [String] {
        let captures = report.captures
        guard !captures.isEmpty else { return [] }
        return resultLines(captures: captures, captureDir: captureDir, skippedFlows: report.skippedFlows)
    }

    static func summaryLines(captures: [ScreenCapture], skippedFlows: Set<String> = []) -> [String] {
        func passed(_ capture: ScreenCapture) -> Bool { capture.steps.allSatisfy { $0.status.isPassing } }
        let screens = captures.filter { $0.kind == .screen }
        let flows = captures.filter { $0.kind == .flow }
        var lines: [String] = []
        if !screens.isEmpty {
            let captured = screens.filter(passed).count
            lines.append("  Screens: \(screens.count) total, \(captured) captured, \(screens.count - captured) failed")
        }
        if !flows.isEmpty {
            let ok = flows.filter(passed).count
            let skipped = flows.filter { skippedFlows.contains($0.screenName) && !passed($0) }.count
            lines.append(
                "  Flows: \(flows.count) total, \(ok) passed, \(flows.count - ok - skipped) failed"
                    + (skipped > 0 ? ", \(skipped) skipped" : "")
            )
        }
        return lines
    }

    /// `--report-dir` as the run used it (absolute), or nil.
    static func absoluteReportDir(_ reportDir: String?) -> String? {
        guard let reportDir, !reportDir.isEmpty else { return nil }
        return reportDir.hasPrefix("/") ? reportDir : FileManager.default.currentDirectoryPath + "/" + reportDir
    }

    /// The `reportDir` a JSON document or ready file names: the absolute
    /// `--report-dir`, whenever that directory exists (pass or fail).
    static func existingReportDir(_ reportDir: String?) -> String? {
        guard let path = absoluteReportDir(reportDir) else { return nil }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue ? path : nil
    }

    /// A capture path as documents show it: relative to the working
    /// directory when under it, absolute otherwise.
    static func displayPath(_ path: String, cwd: String = FileManager.default.currentDirectoryPath) -> String {
        guard path.hasPrefix("/") else { return path }
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        for root in Set([cwd, URL(fileURLWithPath: cwd).resolvingSymlinksInPath().path]) {
            let prefix = root.hasSuffix("/") ? root : root + "/"
            if standardized.hasPrefix(prefix) { return String(standardized.dropFirst(prefix.count)) }
            if path.hasPrefix(prefix) { return String(path.dropFirst(prefix.count)) }
        }
        return path
    }

    /// The `--json` result. Passing and failing runs have the same shape:
    /// `reportDir` whenever `--report-dir` was given, `error` only on failure.
    /// `screens` holds one entry per configured screen (`kind: screen`) and
    /// one per flow (`kind: flow`), each with its steps; a flow's
    /// `takeScreenshot` captures are in its `screenshots`.
    struct RunResult: Codable, Sendable {
        let screens: [ScreenResult]
        let allPassed: Bool
        var error: String?
        var reportDir: String?

        init(screens: [ScreenResult], allPassed: Bool, error: String? = nil, reportDir: String? = nil) {
            self.screens = screens
            self.allPassed = allPassed
            self.error = error
            self.reportDir = reportDir
        }

        struct ScreenResult: Codable, Sendable {
            let name: String
            /// `screen` or `flow`.
            let kind: String
            let passed: Bool
            let steps: [StepResult]
            let screenshots: [Screenshot]

            struct StepResult: Codable, Sendable {
                let action: String
                let status: String
                /// Seconds, as the runner measured it; `null` when unknown.
                let duration: Double?
                let message: String?

                enum CodingKeys: String, CodingKey { case action, status, duration, message }

                /// `duration` is always written, as `null` when unknown.
                func encode(to encoder: Encoder) throws {
                    var c = encoder.container(keyedBy: CodingKeys.self)
                    try c.encode(action, forKey: .action)
                    try c.encode(status, forKey: .status)
                    try c.encode(duration, forKey: .duration)
                    try c.encodeIfPresent(message, forKey: .message)
                }
            }

            /// `path` is relative to the working directory when the file is
            /// under it (the default capture directory), absolute otherwise
            /// (a `--report-dir` elsewhere).
            struct Screenshot: Codable, Sendable {
                let name: String
                let path: String
            }

            init(_ capture: ScreenCapture) {
                name = capture.screenName
                kind = capture.kind.rawValue
                passed = capture.steps.allSatisfy { $0.status.isPassing }
                steps = capture.steps.map { step in
                    StepResult(action: step.action, status: step.status.rawValue, duration: step.duration, message: step.message)
                }
                let shots = capture.kind == .screen && !capture.path.isEmpty
                    ? [ScreenCapture.Screenshot(name: capture.screenName, path: capture.path)]
                    : capture.screenshots
                screenshots = shots.map { Screenshot(name: $0.name, path: RunCommand.displayPath($0.path)) }
            }
        }
    }

    /// The document for a suite that threw. Ctrl-C is how a `--keep-alive`
    /// session is released after its flows finish, so an interrupt whose
    /// flows all passed is a passing run (the ready file says `passed` too),
    /// not a failure.
    static func failureResult(error: Error, report: RunnerFailureReport, reportDir: String? = nil) -> RunResult {
        let screens = report.captures.map(RunResult.ScreenResult.init)
        // The directory the caller asked for (a mixed suite's screens session
        // reports into a subdirectory of it).
        let reportDir = reportDir ?? report.reportDir
        // Decided from the run's verdict, not the captures: the report may
        // list fewer flows than were requested.
        if report.passedBeforeInterruption, screens.allSatisfy(\.passed) {
            return RunResult(screens: screens, allPassed: true, reportDir: reportDir)
        }
        return RunResult(
            screens: screens, allPassed: false, error: failureMessage(error), reportDir: reportDir
        )
    }

}
