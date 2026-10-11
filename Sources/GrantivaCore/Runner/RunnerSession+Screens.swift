import Foundation

/// Reading a screens session's outcome back per configured screen: the
/// generated flow is one runner flow called `screens`, and `FlowGenerator`
/// records which screen and step each of its commands came from.
extension RunnerSession {
    /// The screen the failing (or cut-off) command belongs to.
    static func screen(for failure: RunnerReportSteps.Failure?, owners: [FlowGenerator.CommandOwner]) -> String? {
        guard let index = failure?.commandIndex, owners.indices.contains(index) else { return nil }
        return owners[index].screen
    }

    static func screensTimeoutReason(seconds: UInt64, screen: String?) -> String {
        let at = screen.map { " It was at screen \"\($0)\"." } ?? ""
        return "grantiva killed the screens session after \(seconds)s (--timeout <seconds> to raise the cap).\(at)"
    }

    /// `Screen "Broken" failed at tapOn: text="No Such Element": Element not found ...`
    static func screenFailureLine(_ failure: RunnerReportSteps.Failure?, screen: String?) -> String? {
        guard let failure else { return nil }
        guard let screen else { return failure.line.isEmpty ? nil : failure.line }
        let detail = [failure.action, failure.message].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ": ")
        return detail.isEmpty ? "Screen \"\(screen)\" failed" : "Screen \"\(screen)\" failed at \(detail)"
    }

    /// One capture per configured screen. A screen whose screenshot the runner
    /// wrote is copied to `outputDir`; its steps carry the runner's status
    /// and measured duration. After a failure, the failing screen shows the
    /// failed step and the screens after it say they were not reached.
    static func screenCaptures(
        screens: [GrantivaConfig.Screen],
        reportDir: String,
        outputDir: String,
        owners: [FlowGenerator.CommandOwner],
        failure: RunnerReportSteps.Failure?,
        failedScreen: String?
    ) -> [ScreenCapture] {
        let fm = FileManager.default
        // A failure here shows up as a copy error on each captured screen.
        try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        let report = RunnerReportSteps.report(in: reportDir)
        let commands = report?.flows?.first.map { RunnerReportSteps.commands(of: $0, in: reportDir) } ?? []
        // Only a one-to-one command list can be attributed by position.
        let aligned = !commands.isEmpty && commands.count == owners.count

        let assetsDir = "\(reportDir)/assets"
        let flowDirs = ((try? fm.contentsOfDirectory(atPath: assetsDir)) ?? []).sorted()
        let screenshotDir = flowDirs.first.map { "\(assetsDir)/\($0)" } ?? assetsDir
        let files = ((try? fm.contentsOfDirectory(atPath: screenshotDir)) ?? []).sorted()

        var stoppedAt: String?
        return screens.map { screen in
            let configured = configuredSteps(for: screen)
            var steps = configured.enumerated().map { index, action -> StepResult in
                guard aligned else { return StepResult(action: action, status: .passed, duration: nil) }
                let mine = commands.indices.filter { position in
                    owners[position].screen == screen.name
                        && (screen.isLaunchOnly || owners[position].step == index)
                }.map { commands[$0] }
                return stepResult(action: action, commands: mine)
            }

            if stoppedAt == nil,
               let file = files.first(where: { screenshotName(in: $0) == screen.name }) {
                let source = "\(screenshotDir)/\(file)"
                let destination = "\(outputDir)/\(ScreenArtifact.fileName(for: screen.name))"
                do {
                    if fm.fileExists(atPath: destination) { try fm.removeItem(atPath: destination) }
                    try fm.copyItem(atPath: source, toPath: destination)
                    let size = try fm.attributesOfItem(atPath: destination)[.size] as? Int ?? 0
                    return ScreenCapture(screenName: screen.name, path: destination, sizeBytes: size, steps: steps)
                } catch {
                    // The runner took the shot but it could not be kept: say
                    // why instead of reporting it as never taken.
                    return ScreenCapture(screenName: screen.name, path: "", sizeBytes: 0, steps: steps + [
                        StepResult(
                            action: "Take screenshot", status: .failed, duration: nil,
                            message: "Could not copy \(file) to \(destination): \(error.localizedDescription)"
                        ),
                    ])
                }
            }

            if screen.name == failedScreen {
                stoppedAt = screen.name
                if !steps.contains(where: { $0.status == .failed }) {
                    steps.append(StepResult(
                        action: failure?.action.isEmpty == false ? failure!.action : "Take screenshot",
                        status: .failed, duration: nil, message: failure?.message
                    ))
                }
                return ScreenCapture(screenName: screen.name, path: "", sizeBytes: 0, steps: steps)
            }
            let message = stoppedAt.map { "Not captured: the screens session stopped at screen \"\($0)\"" }
                ?? "Screenshot not found in runner output"
            return ScreenCapture(screenName: screen.name, path: "", sizeBytes: 0, steps: [
                StepResult(action: "Take screenshot", status: .failed, duration: nil, message: message),
            ])
        }
    }

    private static func configuredSteps(for screen: GrantivaConfig.Screen) -> [String] {
        switch screen.path {
        case .launch: return ["Launch app"]
        case .steps(let steps): return steps.map(stepAction(for:))
        }
    }

    /// A configured step from the commands it generated: failed if any of
    /// them failed, its duration their sum (nil when none recorded one).
    private static func stepResult(action: String, commands: [RunnerReportSteps.FlowData.Command]) -> StepResult {
        let durations = commands.compactMap(\.duration)
        let duration = durations.isEmpty ? nil : RunnerReportSteps.seconds(durations.reduce(0, +))
        if let failed = commands.first(where: { ["failed", "error", "running"].contains($0.status ?? "") }) {
            let message = failed.status == "running" ? "Did not finish" : failed.error?.message
            return StepResult(action: action, status: .failed, duration: duration, message: message)
        }
        return StepResult(action: action, status: .passed, duration: duration)
    }
}

extension GrantivaConfig.Screen {
    var isLaunchOnly: Bool {
        if case .launch = path { return true }
        return false
    }
}
