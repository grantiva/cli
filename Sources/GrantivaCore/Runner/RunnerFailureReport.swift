import Foundation

/// What a failed runner session leaves behind for `run --json`.
///
/// `runFlowFiles` throws when the runner exits non-zero, and the default
/// report dir is deleted as it unwinds, so the caller cannot read report.json
/// afterwards. The session fills this in from the report before throwing.
public final class RunnerFailureReport: @unchecked Sendable {
    private let lock = NSLock()
    private var storedCaptures: [ScreenCapture] = []
    private var storedReportDir: String?
    private var earlierCaptures: [ScreenCapture] = []
    private var storedScreens: [ScreenCapture] = []
    private var passedBeforeInterrupt = false

    public init() {}

    /// One capture per flow in the runner's report, with a step per command
    /// that ran (the failed one carries the runner's error message).
    public var captures: [ScreenCapture] {
        lock.lock()
        defer { lock.unlock() }
        return earlierCaptures + storedScreens + storedCaptures
    }

    /// The per-screen rows a failed screens session left (captured, failed,
    /// not reached), for `--continue-on-failure` and `--json`.
    public var screenCaptures: [ScreenCapture] {
        lock.lock()
        defer { lock.unlock() }
        return storedScreens
    }

    func recordScreens(_ captures: [ScreenCapture], preservedReportDir: String?) {
        lock.lock()
        defer { lock.unlock() }
        storedScreens = captures
        if storedReportDir == nil { storedReportDir = preservedReportDir }
    }

    /// True when the run's verdict was already `passed` (every expected flow
    /// in the report terminal and passing) before an interrupt ended it —
    /// how a `--keep-alive` session is released.
    public var passedBeforeInterruption: Bool {
        lock.lock()
        defer { lock.unlock() }
        return passedBeforeInterrupt
    }

    public func markPassedBeforeInterrupt() {
        lock.lock()
        defer { lock.unlock() }
        passedBeforeInterrupt = true
    }

    /// Captures from an earlier session of the same suite (the screens
    /// session before the flows), reported ahead of the failed session's.
    public func recordEarlierCaptures(_ captures: [ScreenCapture]) {
        lock.lock()
        defer { lock.unlock() }
        earlierCaptures += captures
    }

    /// The preserved `--report-dir`, or nil for an ephemeral one.
    public var reportDir: String? {
        lock.lock()
        defer { lock.unlock() }
        return storedReportDir
    }

    func record(
        reportDir: String, preservedReportDir: String?, screenshots: [String: [ScreenCapture.Screenshot]] = [:],
        pathMap: [String: String] = [:]
    ) {
        let captures = Self.captures(reportDir: reportDir, pathMap: pathMap).map { capture -> ScreenCapture in
            var capture = capture
            capture.screenshots = screenshots[capture.screenName] ?? []
            return capture
        }
        lock.lock()
        defer { lock.unlock() }
        storedCaptures = captures
        storedReportDir = preservedReportDir
    }

    /// `pathMap` names the user's files in each step (L19).
    static func captures(reportDir: String, pathMap: [String: String] = [:]) -> [ScreenCapture] {
        guard let report = RunnerReportSteps.report(in: reportDir) else { return [] }
        return (report.flows ?? []).map { flow in
            let name = flow.name ?? "flow"
            var steps = RunnerReportSteps.steps(RunnerReportSteps.commands(of: flow, in: reportDir), pathMap: pathMap)
            // A flow that did not pass must show a failed step even when no
            // command failed (setup error, skipped after fail-fast, cut off).
            if flow.status != "passed", !steps.contains(where: { $0.status == .failed }) {
                steps.append(StepResult(
                    action: "Run flow \"\(name)\"",
                    status: .failed,
                    duration: nil,
                    message: (flow.error ?? flow.status).map(OutputRewriter(replacements: pathMap).rewrite)
                ))
            }
            if steps.isEmpty {
                steps.append(StepResult(action: "Run flow \"\(name)\"", status: .passed, duration: nil))
            }
            return ScreenCapture(screenName: name, path: "", sizeBytes: 0, steps: steps, kind: .flow)
        }
    }
}
