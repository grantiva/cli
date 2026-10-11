import Foundation

/// Thread-safe flag used to record whether grantiva itself terminated the
/// runner subprocess via its timeout task. Lets the error message distinguish
/// a grantiva-initiated kill from a runner-side crash.
final class KilledFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() { lock.lock(); value = true; lock.unlock() }
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
}

/// Orchestrates the grantiva-runner execution and collects screenshot results.
public enum RunnerSession {
    /// The error text for a failed runner: the reason, then the failed step
    /// from the runner's report (so the message stands on its own, as a
    /// `--json` `error` must), then any stderr the runner wrote, then the
    /// remedy when the failure is about the UI tree.
    ///
    /// When grantiva stopped the runner itself (`timedOut`), the runner's
    /// acknowledgement of the signal (`Received interrupt, cleaning up...`)
    /// is dropped: it would read as a Ctrl-C and contradict the reason.
    static func failureMessage(
        reason: String,
        stderr: String,
        failure: RunnerReportSteps.Failure? = nil,
        failedStep: String? = nil,
        timedOut: Bool = false,
        runnerOutputShown: Bool = !RunnerNarration.isSilenced
    ) -> String {
        var detail = String(stderr.suffix(2000))
        if timedOut {
            detail = detail.components(separatedBy: "\n")
                .filter { !isSignalAcknowledgement($0) }
                .joined(separator: "\n")
        }
        detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let step = failedStep ?? failure.map(\.line).flatMap { $0.isEmpty ? nil : $0 }

        var message = reason
        if let step {
            // A reason that is already a sentence takes no colon.
            message += reason.hasSuffix(".") ? "\n\(step)" : ": \(step)"
        }
        if !detail.isEmpty {
            message += (step == nil && !reason.hasSuffix(".")) ? ":\n\(detail)" : "\n\(detail)"
        } else if step == nil, !reason.hasSuffix(".") {
            message += runnerOutputShown ? "; see the runner output above." : "."
        }
        if failure?.wantsHierarchyHint == true {
            message += "\n\(RunnerReportSteps.hierarchyHint)"
        }
        return message
    }

    /// The runner's line for a signal it received (`Received interrupt,
    /// cleaning up...`, `Received terminated, ...`).
    static func isSignalAcknowledgement(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("Received ") && trimmed.contains("cleaning up")
    }

    /// Both spellings of a temp path (`/var/...` and `/private/var/...`).
    static func expandedPathMap(_ map: [String: String]) -> [String: String] {
        RunnerReportRewriter.expanded(map)
    }

    /// Run the embedded runner against a booted simulator.
    /// Generates a Maestro flow, executes it, and collects screenshots.
    public static func run(
        screens: [GrantivaConfig.Screen],
        bundleId: String,
        udid: String,
        platform: any DevicePlatform,
        runner: RunnerManager = .live,
        outputDir: String = ".grantiva/captures",
        appFile: String? = nil,
        keepAlive: Bool = false,
        snapshot: String = "failure",
        environment: [String: String] = [:],
        readyFile: String? = nil,
        expectedPixels: SimulatorProvisionResult.Dimensions? = nil,
        failFast: Bool = false,
        reportDir overrideReportDir: String? = nil,
        timeoutSeconds: UInt64 = 300,
        failureReport: RunnerFailureReport? = nil
    ) async throws -> [ScreenCapture] {
        // A runner invocation owns WDA on its target simulator until the
        // subprocess exits. Refuse overlapping ownership on the same UDID so a
        // concurrent invocation cannot replace or tear down this session.
        let readySignal = ReadyFileSignal(path: readyFile)
        let simulatorLease = try SimulatorLease.acquire(udid: udid, platform: platform.platform, directory: runner.leaseDirectory)
        defer { simulatorLease.release() }

        // Ensure runner is extracted
        try await runner.ensureAvailable()

        let runnerBin = runner.runnerPath()
        let runnerDir = runner.runnerDir()

        // Generate Maestro flow YAML, named like the config file so the
        // runner's lines (and errors such as a runFlow cycle) name the file
        // the user wrote rather than a temp copy.
        let configFileName = platform.platform.configFileName
        let generated = try FlowGenerator.writeTempWithMap(
            screens: screens, bundleId: bundleId, environment: environment, platform: platform.platform,
            fileName: configFileName
        )
        let flowPath = generated.path
        let outputPathMap = expandedPathMap(generated.asWritten.merging([flowPath: configFileName]) { _, new in new })
        simulatorLease.recordTemporaryDirectory((flowPath as NSString).deletingLastPathComponent)
        defer {
            try? FileManager.default.removeItem(
                atPath: (flowPath as NSString).deletingLastPathComponent
            )
        }

        // `--report-dir` is written to directly and survives the run so CI can
        // upload it; otherwise reports go to a temp dir wiped on return.
        let reportDir: String
        let preserveReportDir: Bool
        if let overrideReportDir, !overrideReportDir.isEmpty {
            reportDir = overrideReportDir.hasPrefix("/")
                ? overrideReportDir
                : FileManager.default.currentDirectoryPath + "/" + overrideReportDir
            preserveReportDir = true
        } else {
            reportDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("grantiva-report-\(UUID().uuidString)")
                .path
            preserveReportDir = false
            simulatorLease.recordTemporaryDirectory(reportDir)
        }
        // A capture that does not happen this run must not leave last run's
        // image behind for `diff compare` to pass against. Before the report
        // dir exists, so a throw here leaves nothing to clean up.
        try invalidateCaptures(of: screens, in: outputDir)
        try RunnerReportWorkspace.prepare(at: reportDir)
        // The ephemeral dir is deleted before a waiter could read it, so the
        // ready file names only a preserved --report-dir.
        let readyReportDir = preserveReportDir ? reportDir : nil
        // Defers fire in reverse order — trace must export before cleanup wipes
        // the report dir, so declare cleanup first, then the export.
        defer {
            if !preserveReportDir {
                try? FileManager.default.removeItem(atPath: reportDir)
            }
        }
        defer {
            if preserveReportDir {
                RunnerReportRewriter.rewrite(reportDir: reportDir, stagedPathMap: [flowPath: "screens"])
            }
        }
        defer {
            exportTraceArtifacts(
                reportDir: reportDir, outputDir: outputDir,
                snapshot: snapshot,
                requestedFlowPaths: ["screens"],
                stagedPathMap: [flowPath: "screens"]
            )
            if preserveReportDir, snapshot.lowercased() == "trailing" {
                RunnerTraceTrimmer.trimTrailing(reportDir: reportDir)
            }
        }

        // Freeze status bar for deterministic screenshots
        await platform.prepareForCapture(deviceID: udid)
        let restoreOnSignal = SignalRelay.shared.onTermination(Self.terminationCleanup(platform: platform, deviceID: udid))
        defer { SignalRelay.shared.removeCleanup(restoreOnSignal) }
        // Run the runner
        let args = runnerArguments(
            runnerBin: runnerBin,
            platform: platform,
            udid: udid,
            appFile: appFile,
            reportDir: reportDir,
            snapshot: snapshot,
            failFast: failFast,
            keepAlive: keepAlive,
            flowPaths: [flowPath]
        )

        // Keep-alive sessions block waiting for SIGINT; a normal cap would
        // kill them prematurely. Use an effectively-infinite timeout then.
        let timeoutSeconds: UInt64 = keepAlive ? 60 * 60 * 24 : timeoutSeconds

        // stdout is relayed to stderr so CI sees runner progress in real time;
        // stderr is captured for error reporting.
        let outcome = await runWithStatusBarCleanup(
            udid: udid,
            clear: { id in
                await platform.restoreAfterCapture(deviceID: id)
                await platform.cleanupOrphans(deviceID: id)
                platform.runnerFinished(runnerHome: runnerDir, deviceID: id)
            }
        ) {
            await RunnerExecution.run(RunnerExecution.Request(
                executable: runnerBin,
                arguments: Array(args.dropFirst()), // drop the binary path
                workingDirectory: runnerDir,
                lease: simulatorLease,
                keepAlive: keepAlive,
                timeoutSeconds: timeoutSeconds,
                pathMap: outputPathMap,
                reportDir: reportDir,
                readyReportDir: readyReportDir,
                expectedFlows: 1,
                environment: runnerEnvironment(platform: platform, runnerDir: runnerDir, deviceID: udid),
                readyFile: readySignal,
                platform: platform.platform,
                outputFilter: RunnerOutputFilter(
                    ephemeralReportDir: preserveReportDir ? nil : reportDir,
                    waitLabels: FlowGenerator.waitLabels(
                        inGenerated: FlowGenerator.generate(
                            screens: screens, bundleId: bundleId, environment: environment, platform: platform.platform
                        )
                    )
                )
            ))
        }

        guard outcome.terminationStatus == 0, !outcome.interrupted else {
            let verdict = outcome.interrupted ? "interrupted" : "failed"
            let failure = RunnerReportSteps.firstFailure(in: reportDir)
            let screen = Self.screen(for: failure, owners: generated.owners)
            let reason: String
            if outcome.interrupted {
                reason = "Runner interrupted"
            } else if outcome.timedOut {
                reason = Self.screensTimeoutReason(seconds: timeoutSeconds, screen: screen)
            } else {
                reason = "Runner failed (exit \(outcome.terminationStatus))"
            }
            if outcome.timedOut || outcome.interrupted {
                RunnerReportFinalizer.finalize(reportDir: reportDir, status: verdict, reason: reason)
            }
            readySignal.write(RunReadyState(
                status: verdict,
                flows: RunnerReportIndex.finalFlows(reportDir: reportDir, unfinishedAs: verdict),
                reportDir: readyReportDir
            ))
            failureReport?.recordScreens(
                Self.screenCaptures(
                    screens: screens, reportDir: reportDir, outputDir: outputDir, owners: generated.owners,
                    failure: failure, failedScreen: screen
                ),
                preservedReportDir: readyReportDir
            )
            let stderr = OutputRewriter(replacements: outputPathMap).rewrite(outcome.stderr)
            throw GrantivaError.commandFailed(
                // A timeout names the screen in its reason; anything else
                // names the failed screen and step.
                Self.failureMessage(
                    reason: reason, stderr: stderr,
                    failure: outcome.timedOut || outcome.interrupted ? nil : failure,
                    failedStep: outcome.timedOut || outcome.interrupted ? nil : Self.screenFailureLine(failure, screen: screen),
                    timedOut: outcome.timedOut
                ),
                outcome.terminationStatus
            )
        }

        readySignal.write(RunReadyState(
            status: "passed",
            flows: RunnerReportIndex.load(reportDir: reportDir)?.readyState.flows ?? [],
            reportDir: readyReportDir
        ))

        // The runner saves takeScreenshot outputs in assets/<flow-id>/cmd-NNN-<name>.png
        let assetsDir = "\(reportDir)/assets"
        guard FileManager.default.fileExists(atPath: assetsDir) else {
            throw GrantivaError.commandFailed(
                "Runner completed but no screenshots found in \(assetsDir)",
                1
            )
        }
        let captures = Self.screenCaptures(
            screens: screens, reportDir: reportDir, outputDir: outputDir, owners: generated.owners,
            failure: nil, failedScreen: nil
        )

        if let expectedPixels {
            try ScreenshotNormalizer.normalize(captures: captures, expectedPixels: expectedPixels)
        }
        return captures
    }

    /// True for the errors `run(screens:)` throws once the runner itself has
    /// run and failed (non-zero exit, timeout, no screenshots), as opposed to
    /// setup failures such as a simulator lease conflict or a runner that
    /// could not be extracted. The prefixes match the messages thrown above.
    public static func isRunnerOutcomeFailure(_ error: Error) -> Bool {
        guard case .commandFailed(let message, _) = error as? GrantivaError else { return false }
        return ["Runner failed", "Runner timed out", "Runner completed", "grantiva killed"].contains { message.hasPrefix($0) }
    }

    /// Removes the configured screens' previous captures before a capture run,
    /// so a failed or partial run leaves those screens missing rather than
    /// stale. Other files in the directory are left alone.
    public static func invalidateCaptures(of screens: [GrantivaConfig.Screen], in outputDir: String) throws {
        let fileManager = FileManager.default
        for screen in screens {
            // The legacy (percent-encoded) name too: diff compare still reads
            // it, so a stale one would stand in for a failed capture.
            let names = Set([ScreenArtifact.fileName(for: screen.name), ScreenArtifact.legacyFileName(for: screen.name)])
            for name in names {
                let path = "\(outputDir)/\(name)"
                if fileManager.fileExists(atPath: path) {
                    try fileManager.removeItem(atPath: path)
                }
            }
        }
    }

    /// Runner artifacts are cmd-<step>-<screenshot name>.png. Match the entire
    /// name, preserving hyphens, so a shorter name cannot claim another screen.
    static func screenshotName(in file: String) -> String? {
        guard file.hasPrefix("cmd-"), file.hasSuffix(".png") else { return nil }
        let parts = file.dropFirst(4).dropLast(4).split(separator: "-", maxSplits: 1)
        guard parts.count == 2, !parts[0].isEmpty,
              parts[0].allSatisfy({ $0.isNumber }) else { return nil }
        return String(parts[1])
    }

    /// Run a pre-existing Maestro YAML flow file directly, collecting any screenshots it takes.
    /// Throws on runner failure the same as `run()`.
    /// Back-compat thin wrapper — single flow = plural with one element.
    public static func runFlowFile(
        at flowPath: String,
        bundleId: String,
        udid: String,
        platform: any DevicePlatform,
        runner: RunnerManager = .live,
        outputDir: String = ".grantiva/captures",
        appFile: String? = nil,
        keepAlive: Bool = false,
        snapshot: String = "failure",
        expectedPixels: SimulatorProvisionResult.Dimensions? = nil
    ) async throws -> [ScreenCapture] {
        try await runFlowFiles(
            at: [flowPath], bundleId: bundleId, udid: udid,
            platform: platform, runner: runner, outputDir: outputDir, appFile: appFile,
            keepAlive: keepAlive, snapshot: snapshot, expectedPixels: expectedPixels
        )
    }

    /// Runs all provided Maestro flow files in a SINGLE grantiva-runner
    /// invocation. One WDA setup, one GrantivaAgent session, N flows run
    /// sequentially in order. The runner stops on first failure by default,
    /// matching user expectation ("don't waste cycles after something broke").
    ///
    /// Each flow file has its `appId` rewritten to the resolved bundleId in a
    /// temp copy so flows living outside the project or missing headers still
    /// launch the right app. Trace artifacts from every flow are exported
    /// under a per-flow prefix in `<outputDir>/trace/`.
    public static func runFlowFiles(
        at flowPaths: [String],
        bundleId: String,
        udid: String,
        platform: any DevicePlatform,
        runner: RunnerManager = .live,
        outputDir: String = ".grantiva/captures",
        appFile: String? = nil,
        keepAlive: Bool = false,
        snapshot: String = "failure",
        failFast: Bool = true,
        reportDir overrideReportDir: String? = nil,
        timeoutSeconds: UInt64 = 600,
        environment: [String: String] = [:],
        readyFile: String? = nil,
        expectedPixels: SimulatorProvisionResult.Dimensions? = nil,
        failureReport: RunnerFailureReport? = nil,
        readyLeadingFlows: [RunReadyState.Flow] = []
    ) async throws -> [ScreenCapture] {
        guard !flowPaths.isEmpty else { return [] }

        // An earlier session of the same suite (the screens session) is
        // listed first in the ready file, and its failure fails the verdict.
        let readySignal = ReadyFileSignal(path: readyFile, leadingFlows: readyLeadingFlows)
        let simulatorLease = try SimulatorLease.acquire(udid: udid, platform: platform.platform, directory: runner.leaseDirectory)
        defer { simulatorLease.release() }

        // Resolve relative paths against the working directory where the CLI was invoked,
        // not the runner binary's temp directory.
        let absoluteFlowPaths: [String] = flowPaths.map { p in
            p.hasPrefix("/") ? p : FileManager.default.currentDirectoryPath + "/" + p
        }

        try await runner.ensureAvailable()

        let runnerBin = runner.runnerPath()
        let runnerDir = runner.runnerDir()

        // Inject the resolved bundleId as appId into each flow YAML so the runner can
        // launch the app even when flow files live in a subdirectory and don't have appId,
        // or when grantiva.yml is not co-located with the flow file.
        let tempFlowDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-\(UUID().uuidString)")
            .path
        try FileManager.default.createDirectory(atPath: tempFlowDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempFlowDir) }
        simulatorLease.recordTemporaryDirectory(tempFlowDir)

        var tempFlowPaths: [String] = []
        let uniqueFlowNames = uniqueFlowNames(for: flowPaths)
        // Maps every staged copy back to the path the user actually passed, so
        // runner output and error messages never name a /var/folders temp file.
        var stagedPathMap: [String: String] = [:]
        // Each runFlow path the resolver made absolute → the path as written,
        // so step lines read `runFlow: sub.yaml`, not a rewritten path.
        var subFlowPathMap: [String: String] = [:]
        for (index, absoluteFlowPath) in absoluteFlowPaths.enumerated() {
            let originalContent = try String(contentsOfFile: absoluteFlowPath, encoding: .utf8)
            var injectedContent = injectAppId(originalContent, bundleId: bundleId)
            injectedContent = try FlowReferenceResolver.resolve(
                in: injectedContent,
                relativeTo: (absoluteFlowPath as NSString).deletingLastPathComponent,
                asWritten: &subFlowPathMap
            )
            // Header `env:` and `--env` go into launchApp for the platform's channel.
            let launchData = FlowEnvironment.apply(to: injectedContent, environment: environment, platform: platform.platform)
            injectedContent = launchData.yaml
            if !environment.isEmpty, !launchData.injected {
                FileHandle.standardError.write(Data(
                    "[grantiva] --env had no effect on \(flowPaths[index]): the flow has no launchApp step.\n".utf8
                ))
            }
            for warning in FlowEnvironment.headerKeyWarnings(injectedContent) {
                FileHandle.standardError.write(Data("[grantiva] \(flowPaths[index]): \(warning)\n".utf8))
            }
            // Stage each flow in its own numbered directory: the basename is kept
            // for readable runner output, but smoke/login.yaml and
            // regression/login.yaml must not overwrite each other.
            let originalFilename = URL(fileURLWithPath: absoluteFlowPath).lastPathComponent
            let stageDir = "\(tempFlowDir)/\(index)"
            try FileManager.default.createDirectory(atPath: stageDir, withIntermediateDirectories: true)
            let tempFlowPath = "\(stageDir)/\(originalFilename)"
            if let name = uniqueFlowNames[index] {
                injectedContent = injectFlowName(injectedContent, name: name)
            }
            try injectedContent.write(toFile: tempFlowPath, atomically: true, encoding: .utf8)
            tempFlowPaths.append(tempFlowPath)
            stagedPathMap[tempFlowPath] = flowPaths[index]
        }

        // Sub-flow paths first, so a staged top-level path always wins.
        let reportPathMap = subFlowPathMap.merging(stagedPathMap) { _, staged in staged }
        let outputPathMap = expandedPathMap(reportPathMap)

        // If the caller passed --report-dir, write reports straight to it and
        // preserve on exit so CI can upload them. Otherwise fall back to an
        // ephemeral tmp dir that's wiped with the rest of the session.
        let reportDir: String
        let preserveReportDir: Bool
        if let overrideReportDir, !overrideReportDir.isEmpty {
            let resolved = overrideReportDir.hasPrefix("/")
                ? overrideReportDir
                : FileManager.default.currentDirectoryPath + "/" + overrideReportDir
            reportDir = resolved
            preserveReportDir = true
        } else {
            reportDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("grantiva-report-\(UUID().uuidString)")
                .path
            preserveReportDir = false
            simulatorLease.recordTemporaryDirectory(reportDir)
        }
        // A preserved --report-dir may contain a terminal report and assets
        // from an earlier invocation. The ready watcher must never publish
        // that stale verdict, and capture collection must only see this run.
        // Keep unrelated caller files intact because the directory itself is
        // not owned by grantiva.
        try RunnerReportWorkspace.prepare(at: reportDir)
        // The ephemeral dir is deleted before a waiter could read it, so the
        // ready file names only a preserved --report-dir.
        let readyReportDir = preserveReportDir ? reportDir : nil
        // Defers fire in reverse order — trace must export before cleanup wipes
        // the report dir, so declare cleanup first, then the export.
        defer {
            if !preserveReportDir {
                try? FileManager.default.removeItem(atPath: reportDir)
            }
        }
        // Runs after capture collection and trace export, which both read the
        // staged paths from report.json, and on every exit path.
        defer {
            if preserveReportDir {
                RunnerReportRewriter.rewrite(reportDir: reportDir, stagedPathMap: reportPathMap)
            }
        }
        defer {
            exportTraceArtifacts(
                reportDir: reportDir, outputDir: outputDir, snapshot: snapshot,
                requestedFlowPaths: flowPaths, stagedPathMap: stagedPathMap
            )
            if preserveReportDir, snapshot.lowercased() == "trailing" {
                RunnerTraceTrimmer.trimTrailing(reportDir: reportDir)
            }
        }

        await platform.prepareForCapture(deviceID: udid)
        let restoreOnSignal = SignalRelay.shared.onTermination(Self.terminationCleanup(platform: platform, deviceID: udid))
        defer { SignalRelay.shared.removeCleanup(restoreOnSignal) }
        let args = runnerArguments(
            runnerBin: runnerBin,
            platform: platform,
            udid: udid,
            appFile: appFile,
            reportDir: reportDir,
            snapshot: snapshot,
            failFast: failFast,
            keepAlive: keepAlive,
            flowPaths: tempFlowPaths
        )

        // Keep-alive sessions block waiting for SIGINT; a normal cap would
        // kill them prematurely. Use an effectively-infinite timeout then.
        let effectiveTimeout: UInt64 = keepAlive ? 60 * 60 * 24 : timeoutSeconds

        let outcome = await runWithStatusBarCleanup(
            udid: udid,
            clear: { id in
                await platform.restoreAfterCapture(deviceID: id)
                await platform.cleanupOrphans(deviceID: id)
                platform.runnerFinished(runnerHome: runnerDir, deviceID: id)
            }
        ) {
            await RunnerExecution.run(RunnerExecution.Request(
                executable: runnerBin,
                arguments: Array(args.dropFirst()),
                workingDirectory: runnerDir,
                lease: simulatorLease,
                keepAlive: keepAlive,
                timeoutSeconds: effectiveTimeout,
                pathMap: outputPathMap,
                reportDir: reportDir,
                readyReportDir: readyReportDir,
                expectedFlows: flowPaths.count,
                environment: runnerEnvironment(platform: platform, runnerDir: runnerDir, deviceID: udid),
                readyFile: readySignal,
                platform: platform.platform,
                outputFilter: RunnerOutputFilter(ephemeralReportDir: preserveReportDir ? nil : reportDir)
            ))
        }

        let pathRewriter = OutputRewriter(replacements: outputPathMap)
        let stderr = pathRewriter.rewrite(outcome.stderr)

        // An interrupt is checked first: the runner may exit 0 on SIGTERM, and
        // either way the verdict is `interrupted`, not `passed` or `failed`.
        guard outcome.terminationStatus == 0, !outcome.interrupted else {
            let reason: String
            if outcome.interrupted {
                reason = "Runner interrupted"
            } else if outcome.timedOut {
                reason = "grantiva killed the runner after \(effectiveTimeout)s (--timeout <seconds> to raise the cap)."
                    + (RunnerNarration.isSilenced ? "" : " The runner's last output above shows how far it got.")
            } else {
                reason = "Runner failed (exit \(outcome.terminationStatus))"
            }
            let verdict = outcome.interrupted ? "interrupted" : "failed"
            if outcome.timedOut || outcome.interrupted {
                let why = outcome.timedOut
                    ? "grantiva stopped the run at the --timeout cap (\(effectiveTimeout)s)"
                    : "grantiva was interrupted"
                RunnerReportFinalizer.finalize(reportDir: reportDir, status: verdict, reason: why)
            }
            readySignal.write(RunReadyState(
                status: verdict,
                flows: RunnerReportIndex.finalFlows(reportDir: reportDir, unfinishedAs: verdict),
                reportDir: readyReportDir
            ))
            let failure = RunnerReportSteps.firstFailure(in: reportDir).map { failure in
                RunnerReportSteps.Failure(
                    flowName: failure.flowName, commandIndex: failure.commandIndex,
                    action: pathRewriter.rewrite(failure.action), message: failure.message.map(pathRewriter.rewrite),
                    errorType: failure.errorType, unfinished: failure.unfinished
                )
            }
            // Read before the ephemeral report dir is deleted on the way out.
            // The flows' named screenshots are kept too, best-effort.
            let screenshots = (try? RunnerArtifactCollector.collect(
                reportDir: reportDir, outputDir: outputDir,
                requestedFlowPaths: flowPaths, stagedPathMap: stagedPathMap
            )).map { entries in
                Dictionary(entries.map { ($0.screenName, $0.screenshots) }, uniquingKeysWith: { first, _ in first })
            } ?? [:]
            failureReport?.record(reportDir: reportDir, preservedReportDir: readyReportDir, screenshots: screenshots)
            // The same test the readiness watcher uses to publish `passed`:
            // the report can list fewer flows than were requested.
            if outcome.interrupted,
               let index = RunnerReportIndex.load(reportDir: reportDir),
               index.isComplete(expectedFlows: flowPaths.count),
               index.readyState.passed {
                failureReport?.markPassedBeforeInterrupt()
            }
            throw GrantivaError.commandFailed(
                Self.failureMessage(
                    reason: reason, stderr: stderr, failure: outcome.interrupted ? nil : failure,
                    timedOut: outcome.timedOut
                ),
                outcome.terminationStatus
            )
        }

        readySignal.write(RunReadyState(
            status: "passed",
            flows: RunnerReportIndex.load(reportDir: reportDir)?.readyState.flows ?? [],
            reportDir: readyReportDir
        ))

        // report.json is the runner's source of truth for flow order and asset
        // ownership. Never infer either from physical directory enumeration.
        // One entry per flow, with its real steps and named screenshots.
        let captures = try RunnerArtifactCollector.collect(
            reportDir: reportDir,
            outputDir: outputDir,
            requestedFlowPaths: flowPaths,
            stagedPathMap: stagedPathMap
        )

        if let expectedPixels {
            let shots = captures.flatMap(\.screenshots).map {
                ScreenCapture(screenName: $0.name, path: $0.path, sizeBytes: 0)
            }
            try ScreenshotNormalizer.normalize(captures: shots, expectedPixels: expectedPixels)
        }
        return captures
    }

    /// A synchronous cleanup for SignalRelay: the relay runs cleanups on its own
    /// queue after reaping the runner group and then exits, so the async restore
    /// is awaited here with a bounded wait.
    static func terminationCleanup(platform: any DevicePlatform, deviceID: String, timeout: TimeInterval = 15) -> @Sendable () -> Void {
        return {
            let done = DispatchSemaphore(value: 0)
            Task.detached {
                await platform.restoreAfterCapture(deviceID: deviceID)
                await platform.cleanupOrphans(deviceID: deviceID)
                done.signal()
            }
            _ = done.wait(timeout: .now() + timeout)
        }
    }

    static func runWithStatusBarCleanup<T>(
        udid: String,
        clear: (String) async -> Void,
        operation: () async -> T
    ) async -> T {
        let result = await operation()
        await clear(udid)
        return result
    }

    /// Extra environment for the runner process, supplied by the platform.
    static func runnerEnvironment(platform: any DevicePlatform, runnerDir: String, deviceID: String) -> [String: String] {
        platform.runnerEnvironment(runnerHome: runnerDir, deviceID: deviceID)
    }

    /// Builds the full runner argv (binary path first). Global flags go before
    /// `test`, test flags after; the platform supplies its own pieces of each.
    static func runnerArguments(
        runnerBin: String,
        platform: any DevicePlatform,
        udid: String,
        appFile: String?,
        reportDir: String,
        snapshot: String,
        failFast: Bool = false,
        keepAlive: Bool,
        flowPaths: [String]
    ) -> [String] {
        var args = [runnerBin] + platform.runnerGlobalArguments(deviceID: udid, appFile: appFile)
        args += ["test", "--output", reportDir, "--flatten"]
        args += platform.runnerTestArguments()
        args += ["--artifacts", runnerArtifactMode(for: snapshot)]
        if failFast {
            args += ["--fail-fast"]
        }
        if keepAlive {
            args += ["--keep-alive"]
        }
        args += flowPaths
        return args
    }

    /// Maps the CLI-facing snapshot mode to the runner's `--artifacts` value.
    /// - `failure` → only capture on failure (runner's default behavior).
    /// - `trailing`, `full` → capture every step; the CLI trims post-run if needed.
    static func runnerArtifactMode(for snapshot: String) -> String {
        switch snapshot.lowercased() {
        case "trailing", "full", "always":
            return "always"
        case "never", "off", "none":
            return "never"
        default:
            return "failure"
        }
    }

    /// Copies the runner's per-step artifacts (PNG screenshots + XML hierarchy
    /// dumps) out of the temp report dir into a user-visible `trace/` folder,
    /// applying the snapshot policy.
    ///
    /// - `failure`: no trace/ files written. The simctl post-failure shot from
    ///   RunCommand is still captured separately.
    /// - `trailing`: keeps the failing step's artifacts plus the last successful
    ///   step's "after" screenshot — the "state going into the failure."
    /// - `full`: copies every captured artifact with a stable step-indexed name.
    ///
    /// Safe to call whether or not the runner succeeded. Best-effort: copy
    /// failures are logged to stderr but never thrown.
    static func exportTraceArtifacts(
        reportDir: String,
        outputDir: String,
        snapshot: String,
        requestedFlowPaths: [String],
        stagedPathMap: [String: String]
    ) {
        let mode = snapshot.lowercased()
        guard mode == "trailing" || mode == "full" else { return }

        let fm = FileManager.default
        let flows: [RunnerArtifactCollector.AttributedFlow]
        do {
            flows = try RunnerArtifactCollector.attributedFlows(
                reportDir: reportDir,
                requestedFlowPaths: requestedFlowPaths,
                stagedPathMap: stagedPathMap
            )
        } catch {
            FileHandle.standardError.write(Data(
                "[grantiva] trace export skipped: \(error.localizedDescription)\n".utf8
            ))
            return
        }

        let traceDir = "\(outputDir)/trace"
        struct StepArtifact {
            let file: String
            let source: URL
            let index: Int
            let kind: String // "before", "after", or "" (hierarchy xml)
        }
        var assignedDestinations: Set<String> = []

        for flow in flows {
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: flow.assetsURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }

            var artifacts: [StepArtifact] = []
            for name in ((try? fm.contentsOfDirectory(atPath: flow.assetsURL.path)) ?? []).sorted() {
                guard name.hasPrefix("cmd-") else { continue }
                let lowercasedName = name.lowercased()
                guard lowercasedName.hasSuffix(".png") || lowercasedName.hasSuffix(".xml") else {
                    continue
                }
                let stripped = String(name.dropFirst("cmd-".count))
                let parts = stripped.split(separator: "-", maxSplits: 1).map(String.init)
                guard let indexStr = parts.first, let idx = Int(indexStr) else { continue }
                let kind: String
                if name.hasSuffix("-before.png") {
                    kind = "before"
                } else if name.hasSuffix("-after.png") {
                    kind = "after"
                } else if name.hasSuffix(".xml") {
                    kind = "xml"
                } else {
                    kind = "other"
                }
                do {
                    artifacts.append(StepArtifact(
                        file: name,
                        source: try RunnerArtifactCollector.artifactURL(named: name, in: flow),
                        index: idx,
                        kind: kind
                    ))
                } catch {
                    FileHandle.standardError.write(Data(
                        "[grantiva] trace export skipped \(name): \(error.localizedDescription)\n".utf8
                    ))
                }
            }

            let failingIndex = artifacts.map(\.index).max() ?? 0
            let keep = mode == "full" ? artifacts : artifacts.filter { artifact in
                artifact.index == failingIndex
                    || (artifact.index == failingIndex - 1 && artifact.kind == "after")
            }

            for artifact in keep {
                let destination = "\(traceDir)/\(flow.userName)-\(artifact.file)"
                let destinationKey = destination.precomposedStringWithCanonicalMapping.lowercased()
                guard assignedDestinations.insert(destinationKey).inserted else {
                    FileHandle.standardError.write(Data(
                        "[grantiva] trace export skipped duplicate destination \((destination as NSString).lastPathComponent)\n".utf8
                    ))
                    continue
                }
                do {
                    if !fm.fileExists(atPath: traceDir) {
                        try fm.createDirectory(atPath: traceDir, withIntermediateDirectories: true)
                    }
                    if fm.fileExists(atPath: destination) {
                        try fm.removeItem(atPath: destination)
                    }
                    try fm.copyItem(atPath: artifact.source.path, toPath: destination)
                } catch {
                    FileHandle.standardError.write(Data("[grantiva] trace export failed for \(artifact.file): \(error)\n".utf8))
                }
            }
        }
    }

    /// Injects or replaces the `appId` line in a Maestro flow YAML header.
    /// Flow files in subdirectories may omit appId or have it set to the wrong value;
    /// this ensures the runner always has the correct bundle ID for launchApp.
    static func injectAppId(_ content: String, bundleId: String) -> String {
        let lines = content.components(separatedBy: "\n")

        // Find the document separator, including an empty header (`---` on line 0).
        var separatorIdx: Int?
        for (i, line) in lines.enumerated() {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                separatorIdx = i
                break
            }
        }

        if let idx = separatorIdx {
            var headerLines = Array(lines[0..<idx])
            if let appIdIdx = headerLines.firstIndex(where: { line in
                line.trimmingCharacters(in: .whitespaces).hasPrefix("appId:")
            }) {
                let indentation = String(headerLines[appIdIdx].prefix { $0 == " " || $0 == "\t" })
                headerLines[appIdIdx] = "\(indentation)appId: \(bundleId)"
            } else {
                headerLines.insert("appId: \(bundleId)", at: 0)
            }
            let bodyLines = Array(lines[idx...])
            return (headerLines + bodyLines).joined(separator: "\n")
        } else {
            // No separator: prepend header and separator before the command list
            return "appId: \(bundleId)\n---\n\(content)"
        }
    }

    /// The runner names a flow after its file's basename and keys its summary
    /// table by that name, so `a/same.yaml` and `b/same.yaml` were reported as
    /// two rows called `same` sharing one flow's numbers. Flows whose basenames
    /// collide get the path the user passed (without extension) as their
    /// name; every other flow keeps the runner's default (nil).
    static func uniqueFlowNames(for flowPaths: [String]) -> [String?] {
        func key(_ name: String) -> String { name.precomposedStringWithCanonicalMapping.lowercased() }
        let baseNames = flowPaths.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
        let baseCounts = Dictionary(grouping: baseNames, by: key).mapValues(\.count)
        let stems = flowPaths.map { ($0 as NSString).deletingPathExtension }
        let stemCounts = Dictionary(grouping: stems, by: key).mapValues(\.count)
        return flowPaths.indices.map { index in
            guard baseCounts[key(baseNames[index]), default: 0] > 1 else { return nil }
            // `flows/login.yaml` beside `flows/login.yml`: keep the extension.
            return stemCounts[key(stems[index]), default: 0] > 1 ? flowPaths[index] : stems[index]
        }
    }

    /// Adds a `name:` to the flow's config header (which `injectAppId` has
    /// already guaranteed) unless the flow names itself.
    static func injectFlowName(_ content: String, name: String) -> String {
        var lines = content.components(separatedBy: "\n")
        guard let separator = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return content
        }
        let header = lines[0..<separator]
        if header.contains(where: { $0.hasPrefix("name:") }) {
            return content
        }
        lines.insert("name: \(FlowEnvironment.quoted(name))", at: separator)
        return lines.joined(separator: "\n")
    }

    /// How a screen step is named in capture results.
    public static func stepAction(for step: GrantivaConfig.Screen.Step) -> String {
        if let label = step.tap {
            return step.tapById ? "Tap on id \"\(label)\"" : "Tap on \"\(label)\""
        } else if let direction = step.swipe {
            return step.swipeFrom.map { "Swipe \(direction) from \"\($0)\"" } ?? "Swipe \(direction)"
        } else if let text = step.type {
            return "Type \"\(text)\""
        } else if let seconds = step.wait {
            return "Wait \(seconds)s"
        } else if let seconds = step.settle {
            return "Wait for animation to end (\(seconds)s max)"
        } else if let label = step.assertVisible {
            let target = step.assertVisibleById ? "id \"\(label)\"" : "\"\(label)\""
            if step.scrollUntilVisible { return "Scroll until visible \(target)" }
            if let timeout = step.waitTimeout { return "Wait until visible \(target) (\(timeout)ms max)" }
            return "Assert visible \(target)"
        } else if let label = step.assertNotVisible {
            let target = step.assertNotVisibleById ? "id \"\(label)\"" : "\"\(label)\""
            if let timeout = step.waitTimeout { return "Wait until not visible \(target) (\(timeout)ms max)" }
            return "Assert not visible \(target)"
        } else if let path = step.runFlow {
            return "Run flow \"\(path)\""
        }
        return "Unknown step"
    }
}
