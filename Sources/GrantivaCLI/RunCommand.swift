import ArgumentParser
import Foundation
import GrantivaCore

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run Maestro flows against a simulator. No visual regression — reports step pass/fail and captures a screenshot on failure."
    )

    @OptionGroup var options: GlobalOptions
    @OptionGroup var buildOptions: BuildOptions

    @Option(name: .long, help: "Scheme to build")
    var scheme: String?

    @Option(name: .long, help: "Simulator name")
    var simulator: String?

    @Option(name: .long, help: "Bundle identifier")
    var bundleId: String?

    @Option(name: .long, help: "Run a single flow file instead of all configured flows")
    var flow: String?

    @Flag(name: .long, help: "Keep GrantivaAgent session alive after flows complete so `grantiva hierarchy` can inspect UI state without relaunching the app. Release with Ctrl-C.")
    var keepAlive: Bool = false

    @Flag(name: .long, help: "Stream simulator app logs into this terminal, prefixed with [log]. Filter defaults to lines whose subsystem or process matches the app's bundle ID.")
    var logs: Bool = false

    @Option(name: .long, help: "Custom NSPredicate for `simctl log stream --predicate`. Implies --logs.")
    var logsPredicate: String?

    @Option(name: .long, help: "Log level for --logs: default, info, debug. Defaults to `default` (warnings/errors/default).")
    var logsLevel: String?

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

    @Option(name: .long, help: "Max seconds to wait for the runner subprocess before killing it with SIGTERM. Default: 600 (10 min). Bump this for long multi-flow suites.")
    var timeout: Int = 600

    @Option(name: .long, help: "Write this file once the run reaches a terminal state, containing its status. Deleted at startup, and always written — a setup failure records `failed` rather than leaving a waiter hanging. Wait on it with `while [ ! -f <path> ]; do sleep 0.2; done` instead of polling report.json — useful with --keep-alive, where the session outlives the flows.")
    var readyFile: String?

    @Option(name: .long, parsing: .unconditionalSingleValue, help: "Environment variable for the app under test, as KEY=VALUE. Repeatable. Forwarded through the flow's launchApp environment.")
    var env: [String] = []

    var simulatorManager: SimulatorManager = .live
    var runnerManager: RunnerManager = .live

    func validate() throws {
        guard timeout >= 30 else {
            throw ValidationError("--timeout must be at least 30 seconds.")
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
            throw error
        }
    }

    private func execute() async throws {
        let config = try? GrantivaConfig.load()
        let launchEnvironment = try FlowEnvironment.parse(env)
        // With --report-dir the report directory is the run's artifact home, so
        // screenshots go there and nothing is written to ./.grantiva.
        let captureDir = reportDir.map { dir in
            (dir.hasPrefix("/") ? dir : FileManager.default.currentDirectoryPath + "/" + dir) + "/captures"
        } ?? ".grantiva/captures"

        // Resolve app binary first (if --app-file provided)
        let resolvedBinary = try buildOptions.resolveAppBinary()
        defer { resolvedBinary?.cleanup() }

        let appBundleId = resolvedBinary.flatMap { AppBinaryResolver.bundleId(from: $0.appPath) }

        // Resolve project
        var resolved = try await ResolvedProject.resolve(
            schemeFlag: scheme, simulatorFlag: simulator, bundleIdFlag: bundleId, config: config,
            skipBuild: buildOptions.shouldSkipBuild,
            appBundleId: appBundleId
        )

        // --flow overrides configured flows and skips screens
        if let flow {
            resolved = ResolvedProject(
                scheme: resolved.scheme,
                project: resolved.project,
                workspace: resolved.workspace,
                bundleId: resolved.bundleId,
                buildSettings: resolved.buildSettings,
                simulator: resolved.simulator,
                screens: [],
                flows: [flow]
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
        log("Booting simulator: \(resolved.simulator)")
        let device = try await simulatorManager.boot(nameOrUDID: resolved.simulator)
        log("Simulator booted: \(device.name) (\(device.udid))")
        let destination = "platform=iOS Simulator,id=\(device.udid)"

        // Optional simulator log streaming. Started after boot so `simctl spawn`
        // has a running sim to attach to; stopped by defer so it shuts down on
        // any exit path (success, failure, Ctrl-C).
        let logStreamer: LogStreamer?
        if logs || logsPredicate != nil {
            let predicate: String?
            if let explicit = logsPredicate {
                predicate = explicit
            } else if let bundle = resolved.bundleId ?? appBundleId {
                predicate = defaultLogPredicate(forBundleID: bundle)
            } else {
                log("--logs requested but no bundle ID resolved; streaming without a predicate (very chatty).")
                predicate = nil
            }
            let streamer = LogStreamer()
            do {
                try streamer.start(udid: device.udid, predicate: predicate, level: logsLevel)
                log("Streaming simulator logs\(predicate.map { " (predicate: \($0))" } ?? "")")
                logStreamer = streamer
            } catch {
                GrantivaLog.logger.warning("failed to start log stream: \(error)")
                logStreamer = nil
            }
        } else {
            logStreamer = nil
        }
        defer { logStreamer?.stop() }

        // Build / install / launch
        var productPath: String?

        if buildOptions.shouldSkipInstall {
            log("Skipping build and install (--no-build)")
        } else if let resolvedBinary {
            log("Using pre-built binary: \(URL(fileURLWithPath: resolvedBinary.appPath).lastPathComponent)")
            productPath = resolvedBinary.appPath
        } else {
            guard let buildScheme = resolved.scheme else {
                throw GrantivaError.invalidArgument(
                    "No scheme specified. Pass --scheme, set it in grantiva.yml, or use --app-file to provide a pre-built binary."
                )
            }

            log("Building \(buildScheme)...")

            let buildResult = try await XcodeBuildRunner().build(
                scheme: buildScheme,
                workspace: resolved.workspace,
                project: resolved.project,
                destination: destination,
                buildSettings: buildOptions.xcodeBuildSettings(merging: resolved.buildSettings)
            )
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
        }

        guard let bid = resolved.bundleId else {
            throw GrantivaError.invalidArgument("Bundle ID is required to run flows")
        }

        if !buildOptions.shouldSkipInstall, let productPath {
            log("Installing \(bid)...")
            try await XcodeBuildRunner().install(
                bundleId: bid, productPath: productPath, udid: device.udid
            )
        }
        // Do not pre-launch: flows drive the app themselves via launchApp/clearState.
        // A grantiva-side launch creates a process WDA can't control, causing stopApp
        // and other lifecycle steps to fail.

        // Run flows — capture screenshots, but skip VRT comparison
        let totalFlows = (resolved.screens.isEmpty ? 0 : 1) + resolved.flows.count
        log("Running \(totalFlows) flow(s)...")

        var captures: [ScreenCapture] = []
        do {
            if !resolved.screens.isEmpty {
                let screenCaptures = try await RunnerSession.run(
                    screens: resolved.screens,
                    bundleId: bid,
                    udid: device.udid,
                    runner: runnerManager,
                    outputDir: captureDir,
                    appFile: productPath,
                    keepAlive: keepAlive,
                    snapshot: snapshot.rawValue,
                    environment: launchEnvironment,
                    readyFile: readyFile
                )
                captures.append(contentsOf: screenCaptures)
            }

            if !resolved.flows.isEmpty {
                log("Running \(resolved.flows.count) flow(s) in one GrantivaAgent session: \(resolved.flows.joined(separator: ", "))")
                let flowCaptures = try await RunnerSession.runFlowFiles(
                    at: resolved.flows,
                    bundleId: bid,
                    udid: device.udid,
                    runner: runnerManager,
                    outputDir: captureDir,
                    appFile: productPath,
                    keepAlive: keepAlive,
                    snapshot: snapshot.rawValue,
                    failFast: !continueOnFailure,
                    reportDir: reportDir,
                    timeoutSeconds: UInt64(timeout),
                    environment: launchEnvironment,
                    readyFile: readyFile
                )
                captures.append(contentsOf: flowCaptures)
            }
        } catch {
            // Runner failed — take a failure screenshot so the developer can see the current state
            let failurePath = "\(captureDir)/failure-\(Int(Date().timeIntervalSince1970)).png"
            let fm = FileManager.default
            if !fm.fileExists(atPath: captureDir) {
                try? fm.createDirectory(atPath: captureDir, withIntermediateDirectories: true)
            }
            _ = try? await shell("xcrun simctl io \(device.udid) screenshot \(failurePath)")
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

    /// Progress narration for a human. Goes to stderr via the log; the run's
    /// results go to stdout via `Output`.
    private func log(_ message: String) {
        options.note(message)
    }
}
