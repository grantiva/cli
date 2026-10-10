import ArgumentParser
import Foundation
import GrantivaCore

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run Maestro flows against a simulator or emulator. No visual regression — reports step pass/fail and captures a screenshot on failure."
    )

    @OptionGroup var options: GlobalOptions
    @OptionGroup var buildOptions: BuildOptions
    @OptionGroup var platformOptions: PlatformOptions

    @OptionGroup var target: TargetOptions

    @Option(name: .long, help: "Run a single flow file instead of all configured flows")
    var flow: String?

    @Flag(name: .long, help: "Keep GrantivaAgent session alive after flows complete so `grantiva hierarchy` can inspect UI state without relaunching the app. Release with Ctrl-C.")
    var keepAlive: Bool = false

    @Flag(name: .long, help: "Stream app logs from the simulator or emulator into this terminal, prefixed with [log] (iOS and Android). On iOS the filter defaults to lines whose subsystem starts with the app's bundle ID or whose process is the app's executable; on Android, to lines from the app's uid.")
    var logs: Bool = false

    @Option(name: .long, help: "Custom NSPredicate for `simctl log stream --predicate` (iOS). Implies --logs.")
    var logsPredicate: String?

    @Option(name: .long, help: "logcat tag to keep when streaming logs (Android). Implies --logs.")
    var logsTag: String?

    @Option(name: .long, help: "Log level for --logs: default, info, debug. Defaults to `default` (warnings/errors/default).")
    var logsLevel: String?

    @Flag(name: .customLong("no-auto-accept-alerts"), help: "iOS: turn off WebDriverAgent's alert auto-accept, so alerts stay up until a flow step answers them. For apps whose own alerts (\"Discard changes?\") were being dismissed mid-flow. Permissions are still pre-granted on the simulator, but prompts simctl cannot grant (notifications, tracking, local network, Bluetooth) are no longer accepted for you.")
    var noAutoAcceptAlerts: Bool = false

    @Option(name: .long, help: "Snapshot policy: failure (default — one shot after failure), trailing (last-good step + failure step), full (every step).")
    var snapshot: SnapshotMode = .failure

    enum SnapshotMode: String, ExpressibleByArgument {
        case failure
        case trailing
        case full
    }

    @Flag(name: .long, help: "Keep running remaining flows after a failure. Default is fail-fast — stop the suite on the first broken flow, which matches CI semantics and avoids wasting cycles.")
    var continueOnFailure: Bool = false

    @Option(name: .long, help: "Write the runner's report.json + assets to this directory (workspace-relative). Survives grantiva's cleanup so CI can upload it. Default: ephemeral tmp dir.")
    var reportDir: String?

    @Option(name: .long, help: "Max seconds to wait for the runner subprocess before killing it with SIGTERM. Default: 600 (10 min). Minimum 30. Ignored under --keep-alive. Bump this for long multi-flow suites.")
    var timeout: Int = 600

    @Option(name: .long, help: "Write this file once the run reaches a terminal state, containing its status. Deleted at startup, and always written — a setup failure records `failed` rather than leaving a waiter hanging. Missing parent directories are created. Wait on it with `while [ ! -f <path> ]; do sleep 0.2; done` instead of polling report.json — useful with --keep-alive, where the session outlives the flows.")
    var readyFile: String?

    @Option(name: .long, parsing: .unconditionalSingleValue, help: "Environment variable for the app under test, as KEY=VALUE. Repeatable. Forwarded through the flow's launchApp (environment on iOS, string intent extras on Android).")
    var env: [String] = []

    /// Empty means "make one from the resolved platform"; tests inject a fake.
    var devicePlatform = InjectedDevicePlatform()
    var runnerManager: RunnerManager = .live

    func validate() throws {
        guard timeout >= 30 else {
            let message = "--timeout must be at least 30 seconds."
            // `--ready-file` is "always written", and validation runs before
            // `run()` arms it: release the waiter here or it spins forever.
            if let readyFile {
                try? ReadyFile.prepare(at: readyFile)
                try? ReadyFile.write(RunReadyState(status: "failed", flows: [], error: message), to: readyFile)
            }
            throw ValidationError(message)
        }
    }

    /// `--ready-file` is documented as `while [ ! -f "$f" ]; do sleep 0.2; done`,
    /// which only works if the file is absent until this run finishes and
    /// present once it has. Two things have to be true for that, and neither
    /// belongs inside the runner call:
    ///
    /// - a file left by a previous run is cleared before any project, build, or
    ///   simulator work, so the waiter cannot read a stale verdict; and
    /// - a terminal status is written on *every* exit path, including the setup
    ///   failures (missing project, bad scheme, build failure, no simulator)
    ///   that never reach the runner and used to leave the waiter hanging until
    ///   CI's global timeout.

    /// The value after `--predicate` in a log stream command, if any.
    static func predicateArgument(in arguments: [String]) -> String? {
        guard let flag = arguments.firstIndex(of: "--predicate"), flag + 1 < arguments.count else { return nil }
        return arguments[flag + 1]
    }

    /// The line printed once device log streaming starts.
    static func logStreamNarration(platform: Platform, predicate: String?, tag: String?) -> String {
        switch platform {
        case .ios:
            return "Streaming simulator logs" + (predicate.map { " (predicate: \($0))" } ?? "")
        case .android:
            return "Streaming emulator logs" + (tag.map { " (tag: \($0))" } ?? "")
        }
    }

    func run() async throws {
        if let readyFile {
            try ReadyFile.prepare(at: readyFile)
        }
        do {
            try await execute()
        } catch {
            // `execute` writes the real verdict when the runner produced one;
            // the file existing here means that already happened and must not
            // be overwritten with this coarser status. Startup deleted the
            // file, so absence means the run failed before any verdict — a
            // setup failure. `failed` and not a new value like `error` because
            // waiters test against the documented vocabulary
            // (passed | failed | interrupted); a fifth status would read as
            // "not failed" to every `[ "$s" = failed ]` in the wild.
            if let readyFile, !FileManager.default.fileExists(atPath: readyFile) {
                try? ReadyFile.write(
                    RunReadyState(status: "failed", flows: [], reportDir: reportDir),
                    to: readyFile
                )
            }
            if SignalRelay.shared.isTerminating {
                await Self.awaitSignalRelayExit()
            }
            throw error
        }
    }

    /// On Ctrl-C the runner dies first, so this thread unwinds with a runner
    /// error while SignalRelay is still running its cleanups (lease, capture
    /// settings, log stream). Exiting here with that error's code would cut
    /// them short and report exit 1 instead of 130; the relay exits for us.
    static func awaitSignalRelayExit() async -> Never {
        while true {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    private func execute() async throws {
        let (platform, config) = try platformOptions.loadConfig(includeMaestroDirectory: flow == nil)
        try target.checkFlags(
            for: platform, derivedDataPath: buildOptions.derivedDataPath,
            logsPredicate: logsPredicate, logsTag: logsTag
        )
        let device = try devicePlatform.make(platform, android: target.androidOptions)
        let launchEnvironment = try FlowEnvironment.parse(env)
        // With --report-dir the report directory is the run's artifact home, so
        // screenshots go there and nothing is written to ./.grantiva.
        let captureDir = reportDir.map { dir in
            (dir.hasPrefix("/") ? dir : FileManager.default.currentDirectoryPath + "/" + dir) + "/captures"
        } ?? DiffCommand.captureDirectory(for: platform)

        // Resolve app binary first (if --app-file provided)
        let resolvedBinary: ResolvedBinary? = if let appFile = buildOptions.appFile { try await device.resolveBinary(appFile) } else { nil }
        defer { resolvedBinary?.cleanup() }

        let appBundleId = resolvedBinary?.appID

        // Resolve project
        var resolved = try await target.resolve(
            platform: platform, config: config, skipBuild: buildOptions.shouldSkipBuild, appID: appBundleId
        )

        // --flow overrides configured flows and skips screens
        if let flow {
            resolved = ResolvedProject(
                scheme: resolved.scheme,
                project: resolved.project,
                workspace: resolved.workspace,
                bundleId: Self.flowBundleId(
                    flowPath: flow, resolved: resolved.bundleId,
                    explicit: target.bundleId ?? target.applicationId ?? config?.bundleId ?? config?.android?.applicationId
                        ?? appBundleId
                ),
                buildSettings: resolved.buildSettings,
                simulator: resolved.simulator,
                screens: [],
                flows: [flow],
                android: resolved.android
            )
        }

        guard !resolved.screens.isEmpty || !resolved.flows.isEmpty else {
            throw GrantivaError.invalidArgument("No screens or flows configured in grantiva.yml")
        }

        log("Resolved: scheme=\(resolved.scheme ?? "(none)") simulator=\(resolved.simulator) screens=\(resolved.screens.count) flows=\(resolved.flows.count)")

        // Prepare runner
        log("Preparing runner...")
        try await runnerManager.ensureAvailable()
        log("Runner ready")

        // Boot simulator
        let deviceNoun = platform == .ios ? "simulator" : "emulator"
        log("Booting \(deviceNoun): \(resolved.simulator)")
        let booted = try await device.bootDevice(named: resolved.simulator)
        log("\(deviceNoun.capitalized) booted: \(booted.name) (\(booted.udid))")
        let geometry = try await device.displayGeometry(deviceID: booted.udid)
        let expectedPixels = geometry.dimensions

        // Optional device log streaming, stopped by defer on success and
        // failure; on Ctrl-C the streamer's own SignalRelay cleanup stops it,
        // since the relay exits before this defer runs. Both platforms start it
        // after install, before any flow launches the app: logcat filters by
        // the app's uid, and the iOS default predicate names the installed
        // app's executable, both of which exist only once the app is
        // installed. The app ID may also come from the build.
        let wantsLogs = logs || logsPredicate != nil || logsTag != nil
        func startLogStream(appID: String) async -> LogStreamer? {
            // iOS names the predicate it streams with: the explicit one or the
            // default derived from the app.
            let streamer = LogStreamer()
            do {
                let stream = try await device.logStream(
                    deviceID: booted.udid, appID: appID,
                    filter: logsPredicate ?? logsTag, level: logsLevel
                )
                let predicate = platform == .ios ? Self.predicateArgument(in: stream.arguments) : nil
                try streamer.start(executable: stream.executable, arguments: stream.arguments)
                log(Self.logStreamNarration(platform: platform, predicate: predicate, tag: logsTag))
                return streamer
            } catch {
                GrantivaLog.logger.warning("failed to start log stream: \(error)")
                log("Log streaming unavailable: \(error)")
                return nil
            }
        }
        var logStreamer: LogStreamer?
        defer { logStreamer?.stop() }

        // Build / install / launch
        var productPath: String?
        var builtAppID: String?

        if buildOptions.shouldSkipInstall {
            log("Skipping build and install (--no-build)")
        } else if let resolvedBinary {
            log("Using pre-built binary: \(URL(fileURLWithPath: resolvedBinary.appPath).lastPathComponent)")
            productPath = resolvedBinary.appPath
        } else {
            // A missing scheme is rejected by the platform's build with the
            // same message the command used to throw here.
            if let buildScheme = resolved.scheme {
                log("Building \(buildScheme)...")
            }

            let buildResult = try await device.build(PlatformBuildRequest(
                config: config ?? GrantivaConfig(),
                resolved: resolved,
                deviceID: booted.udid,
                extraBuildSettings: target.extraBuildSettings(
                    platform: platform, derivedDataPath: buildOptions.derivedDataPath, resolved: resolved
                )
            ))
            log("Build finished: success=\(buildResult.success) duration=\(String(format: "%.1fs", buildResult.duration))")

            guard buildResult.success else {
                if options.json {
                    Output.line(try JSONOutput.string(buildResult))
                } else {
                    Output.line(TableFormatter().formatBuild(buildResult))
                }
                throw ExitCode.failure
            }
            productPath = buildResult.productPath
            builtAppID = buildResult.applicationId
        }

        guard let bid = resolved.bundleId ?? builtAppID else {
            throw GrantivaError.invalidArgument(TargetOptions.appIDMessage(for: platform))
        }

        if !buildOptions.shouldSkipInstall, let productPath {
            log("Installing \(bid)...")
            try await device.install(appID: bid, productPath: productPath, deviceID: booted.udid)
        }
        if wantsLogs {
            logStreamer = await startLogStream(appID: bid)
        }
        // Do not pre-launch: flows drive the app themselves via launchApp/clearState.
        // A grantiva-side launch creates a process WDA can't control, causing stopApp
        // and other lifecycle steps to fail.

        // Run flows — capture screenshots, but skip VRT comparison
        let totalFlows = (resolved.screens.isEmpty ? 0 : 1) + resolved.flows.count
        log("Running \(totalFlows) flow(s)...")

        var captures: [ScreenCapture] = []
        do {
            captures = try await Self.runSuite(
                hasScreens: !resolved.screens.isEmpty,
                hasFlows: !resolved.flows.isEmpty,
                keepAlive: keepAlive,
                readyFile: readyFile,
                options: sessionOptions,
                runScreens: { keepAlive, readyFile, session in
                    try await RunnerSession.run(
                        screens: resolved.screens,
                        bundleId: bid,
                        udid: booted.udid,
                        platform: device,
                        runner: runnerManager,
                        outputDir: captureDir,
                        appFile: productPath,
                        keepAlive: keepAlive,
                        snapshot: snapshot.rawValue,
                        environment: launchEnvironment,
                        readyFile: readyFile,
                        expectedPixels: expectedPixels,
                        failFast: session.failFast,
                        reportDir: session.reportDir,
                        timeoutSeconds: session.timeoutSeconds,
                        autoAcceptAlerts: !noAutoAcceptAlerts
                    )
                },
                runFlows: { keepAlive, readyFile, session in
                    log("Running \(resolved.flows.count) flow(s) in one GrantivaAgent session: \(resolved.flows.joined(separator: ", "))")
                    return try await RunnerSession.runFlowFiles(
                        at: resolved.flows,
                        bundleId: bid,
                        udid: booted.udid,
                        platform: device,
                        runner: runnerManager,
                        outputDir: captureDir,
                        appFile: productPath,
                        keepAlive: keepAlive,
                        snapshot: snapshot.rawValue,
                        failFast: session.failFast,
                        reportDir: session.reportDir,
                        timeoutSeconds: session.timeoutSeconds,
                        environment: launchEnvironment,
                        readyFile: readyFile,
                        expectedPixels: expectedPixels,
                        autoAcceptAlerts: !noAutoAcceptAlerts
                    )
                }
            )
        } catch {
            // Runner failed — take a failure screenshot so the developer can see the current state
            let failurePath = "\(captureDir)/failure-\(Int(Date().timeIntervalSince1970)).png"
            let fm = FileManager.default
            if !fm.fileExists(atPath: captureDir) {
                try? fm.createDirectory(atPath: captureDir, withIntermediateDirectories: true)
            }
            try? await device.screenshot(deviceID: booted.udid, to: failurePath)
            if fm.fileExists(atPath: failurePath) {
                log("Failure screenshot: \(failurePath)")
            }
            // The --ready-file waiter is released by `run`, which covers this
            // path and every setup failure that never reaches the runner.
            throw error
        }

        // Print results
        var allPassed = true
        if !options.json {
            for capture in captures {
                Output.line("\n  \(capture.screenName)")
                for step in capture.steps {
                    let icon = step.status == .passed ? "\u{2713}" : "\u{2717}"
                    Output.line("    \(icon) \(step.action)")
                    if let msg = step.message {
                        Output.line("      \(msg)")
                    }
                    if step.status != .passed {
                        allPassed = false
                    }
                }
            }
            Output.line("")
            let total = captures.count
            let passed = captures.filter { $0.steps.allSatisfy { $0.status == .passed } }.count
            Output.line("  Screens: \(total) total, \(passed) passed, \(total - passed) failed")
            Output.line("  Screenshots: \(captureDir)/")
            Output.line("")
        } else {
            struct RunResult: Codable, Sendable {
                let screens: [ScreenResult]
                let allPassed: Bool

                struct ScreenResult: Codable, Sendable {
                    let name: String
                    let passed: Bool
                    let steps: [StepResult]

                    struct StepResult: Codable, Sendable {
                        let action: String
                        let status: String
                        let message: String?
                    }
                }
            }

            let result = RunResult(
                screens: captures.map { capture in
                    let passed = capture.steps.allSatisfy { $0.status == .passed }
                    if !passed { allPassed = false }
                    return RunResult.ScreenResult(
                        name: capture.screenName,
                        passed: passed,
                        steps: capture.steps.map { step in
                            RunResult.ScreenResult.StepResult(
                                action: step.action,
                                status: step.status.rawValue,
                                message: step.message
                            )
                        }
                    )
                },
                allPassed: allPassed
            )
            Output.line(try JSONOutput.string(result))
        }

        if !allPassed {
            throw ExitCode.failure
        }
    }

    /// The runner flags every session of the suite honours.
    struct SessionOptions: Equatable {
        var reportDir: String?
        var timeoutSeconds: UInt64
        var failFast: Bool
    }

    var sessionOptions: SessionOptions {
        SessionOptions(reportDir: reportDir, timeoutSeconds: UInt64(timeout), failFast: !continueOnFailure)
    }

    /// `--flow` without `--bundle-id`/`--application-id` or a configured ID
    /// launches the app named by the flow's own `appId:` header, ahead of IDs
    /// guessed from project detection. A header that is a variable reference
    /// (`appId: ${APP_ID}`) names no app here and is ignored.
    static func flowBundleId(flowPath: String, resolved: String?, explicit: String?) -> String? {
        if explicit != nil { return resolved }
        let header = (try? String(contentsOfFile: flowPath, encoding: .utf8)).flatMap(MaestroFlowParser.appId(in:))
        guard let header, !header.contains("${") else { return resolved }
        return header
    }

    /// Only the final session owns suite readiness and the post-run hold.
    ///
    /// When screens and flows both run, the screens session reports into
    /// `<report-dir>/screens` so the flows session does not replace its
    /// report.json. A failed screens session stops the suite unless
    /// `--continue-on-failure`; then a runner failure becomes a failed row,
    /// the flows still run, and the ready file records `failed`.
    static func runSuite(
        hasScreens: Bool,
        hasFlows: Bool,
        keepAlive: Bool,
        readyFile: String?,
        options: SessionOptions,
        runScreens: (Bool, String?, SessionOptions) async throws -> [ScreenCapture],
        runFlows: (Bool, String?, SessionOptions) async throws -> [ScreenCapture]
    ) async throws -> [ScreenCapture] {
        var captures: [ScreenCapture] = []
        var screensFailed = false
        if hasScreens {
            var screenOptions = options
            if hasFlows {
                screenOptions.reportDir = options.reportDir.map { ($0 as NSString).appendingPathComponent("screens") }
            }
            do {
                captures += try await runScreens(keepAlive && !hasFlows, hasFlows ? nil : readyFile, screenOptions)
            } catch where hasFlows && !options.failFast && RunnerSession.isRunnerOutcomeFailure(error) {
                // Only the runner's own failure becomes a row; setup errors
                // and cancellation still stop the suite.
                let message = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                captures.append(ScreenCapture(screenName: "screens", path: "", sizeBytes: 0, steps: [
                    StepResult(action: "Capture screens", status: .failed, duration: 0, message: message),
                ]))
            }
            // Missing captures are returned as failed steps rather than thrown.
            // Do not let the later session publish success for a failed suite.
            if hasFlows, captures.contains(where: { $0.steps.contains(where: { $0.status != .passed }) }) {
                if options.failFast {
                    throw ExitCode.failure
                }
                screensFailed = true
            }
        }
        if hasFlows {
            captures += try await runFlows(keepAlive, readyFile, options)
            if screensFailed, let readyFile {
                let flowsState = try? ReadyFile.read(readyFile)
                try? ReadyFile.write(
                    RunReadyState(status: "failed", flows: flowsState?.flows ?? [], reportDir: flowsState?.reportDir),
                    to: readyFile
                )
            }
        }
        return captures
    }

    /// Progress narration for a human. Goes to stderr via the log; the run's
    /// results go to stdout via `Output`.
    private func log(_ message: String) {
        options.note(message)
    }
}
