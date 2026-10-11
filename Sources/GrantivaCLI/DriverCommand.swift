import ArgumentParser
import GrantivaCore
import Foundation

@available(macOS 15, *)
struct RunnerCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "runner",
        abstract: "Manage the embedded UI automation runner.",
        subcommands: [
            RunnerInstallCommand.self,
            RunnerVersionCommand.self,
            RunnerStartCommand.self,
            RunnerStopCommand.self,
            DumpHierarchyCommand.self,
        ]
    )
}

// MARK: - Install

@available(macOS 15, *)
struct RunnerInstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Extract or update the embedded runner binary.",
        discussion: """
        A no-op when the installed runner is already this version: it prints \
        "Runner already installed at <path>", and --json reports "extracted": false.
        """
    )

    @OptionGroup var options: GlobalOptions

    /// `runner install --json`. `extracted` is false when the installed stamp
    /// was already current and nothing was written.
    struct Result: Encodable, Equatable {
        var status = "installed"
        let path: String
        let version: String
        let extracted: Bool
    }

    func run() async throws {
        let json = options.json
        let alreadyInstalled = RunnerManager.isCurrentInstallPresent()
        let result = try await Self.install(manager: .live, note: { message in
            if !json { GrantivaLog.logger.info("\(message)") }
        })
        // An existing install is kept without reading the bundle; check it
        // here so a bundle from another release is reported before the next
        // fresh install trips over it.
        if alreadyInstalled, let warning = RunnerManager.bundleMismatchWarning() {
            GrantivaLog.logger.warning("\(warning)")
        }
        if options.json {
            Output.line(try JSONOutput.string(result))
        } else {
            Self.lines(result).forEach(Output.line)
        }
    }

    /// Installs, narrating "Extracting runner..." only when an extraction
    /// actually starts.
    static func install(manager: RunnerManager, note: @escaping @Sendable (String) -> Void) async throws -> Result {
        let extracted = try await manager.install { note("Extracting runner...") }
        return Result(path: manager.runnerPath(), version: RunnerManager.runnerVersion, extracted: extracted)
    }

    static func lines(_ result: Result) -> [String] {
        [
            result.extracted ? "Runner installed at \(result.path)" : "Runner already installed at \(result.path)",
            "Version: \(result.version)",
        ]
    }
}

// MARK: - Version

@available(macOS 15, *)
struct RunnerVersionCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Show the embedded runner version."
    )

    @OptionGroup var options: GlobalOptions

    func run() async throws {
        if options.json {
            Output.line(try JSONOutput.string(["version": RunnerManager.runnerVersion]))
        } else {
            Output.line("grantiva-runner \(RunnerManager.runnerVersion)")
        }
    }
}

// MARK: - Start

@available(macOS 15, *)
struct RunnerStartCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start the runner with WDA (UIAutomator2 on Android) and keep it alive for interactive use.",
        discussion: """
        Without --detach the command stays in the foreground, streams the runner's \
        output to stderr and holds the session until Ctrl-C (or `grantiva runner \
        stop` from another shell); it then stops the runner, removes the session \
        files and releases the device. Interrupted, it exits 130. With --detach it \
        returns once the driver is up and the runner keeps the session until \
        `grantiva runner stop`.

        --json prints one document: {"status": "started" | "already_running", \
        "pid": <number>, "port": <number>, "platform": "ios" | "android", plus \
        "bundleId" and "udid" on iOS or "applicationId" and "serial" on Android, \
        and "log" with --detach}. "bundle_id" (and "udid" on Android) are kept \
        for compatibility and are deprecated.
        """
    )

    @OptionGroup var options: GlobalOptions

    @OptionGroup var platformOptions: PlatformOptions

    @Option(name: .long, help: "App bundle identifier (iOS; reads from grantiva.yml if omitted)")
    var bundleId: String?

    @Option(name: .long, help: "Simulator name or UDID (iOS; reads from grantiva.yml if omitted)")
    var simulator: String?

    @Option(name: .long, help: "Application ID (Android; reads from grantiva-android.yml if omitted)")
    var applicationId: String?

    @Option(name: .long, help: "AVD name to use, booting it if needed (Android)")
    var emulator: String?

    @Option(name: .long, help: "adb serial of an attached emulator or device (Android)")
    var device: String?

    @Flag(name: .long, help: "Boot an emulator without a window (Android)")
    var headless = false

    @Flag(name: .long, help: "Detach the runner process from this terminal. Prints the log file path on start.")
    var detach: Bool = false

    /// Empty means "make one from the resolved platform"; tests inject a fake.
    var devicePlatform = InjectedDevicePlatform()

    func validate() throws {
        try requireExclusive(("--device", device != nil), ("--emulator", emulator != nil))
    }

    func run() async throws {
        options.applyRunnerNarration()
        // Check for existing session
        if let existing = try? RunnerSessionInfo.load(), existing.isAlive,
           let snapshot = try? await SimulatorReaper.processSnapshot(),
           existing.ownsRunnerProcess(in: snapshot) {
            if options.json {
                Output.line(try JSONOutput.string(RunnerLifecycleDocument(
                    status: "already_running", pid: existing.pid, port: existing.wdaPort,
                    appID: existing.bundleId, deviceID: existing.udid,
                    platform: existing.platform ?? (DeviceID.isAndroidSerial(existing.udid) ? .android : .ios), log: nil
                )))
            } else {
                let label = Self.portLabel(DeviceID.isAndroidSerial(existing.udid) ? .android : .ios)
                Output.line("Runner already running (pid \(existing.pid), \(label) \(existing.wdaPort))")
                Output.line("Use 'grantiva runner stop' to stop it first.")
            }
            return
        }

        let (platform, config) = try platformOptions.loadConfig()
        if platform == .ios {
            if emulator != nil { throw TargetOptions.otherPlatformFlagError("--emulator", platform: .ios) }
            if device != nil { throw TargetOptions.otherPlatformFlagError("--device", platform: .ios) }
            if headless { throw TargetOptions.otherPlatformFlagError("--headless", platform: .ios) }
        }
        if platform == .android, simulator != nil {
            throw TargetOptions.otherPlatformFlagError("--simulator", platform: .android)
        }
        if let device { _ = try DeviceID.validate(device, flag: "--device") }
        let resolvedAppID = try Self.appID(platform: platform, bundleId: bundleId, applicationId: applicationId, config: config)
        let targetName = Self.target(platform: platform, simulator: simulator, emulator: emulator, device: device, config: config)

        let platformDevice = try devicePlatform.make(platform, android: .init(headless: headless))
        // The default name (nothing named a simulator) boots only a simulator Grantiva created (L08).
        let booted = platform == .ios && simulator == nil && config?.simulator == nil
            ? try await platformDevice.bootDefaultDevice(named: targetName, override: "--simulator")
            : try await platformDevice.bootDevice(named: targetName)
        // Held until the runner is up, then handed to the runner process: this
        // command returns immediately, but the session it started still owns
        // the device until `runner stop`.
        let simulatorLease = try SimulatorLease.acquire(udid: booted.udid, platform: platform)
        var handedOff = false
        defer { if !handedOff { simulatorLease.release() } }

        let deviceNoun = platform == .ios ? "Simulator" : "Device"
        options.note("Starting runner...")
        options.note("  \(platform == .ios ? "Bundle ID" : "Application ID"): \(resolvedAppID)")
        options.note("  \(deviceNoun): \(booted.name) (\(booted.udid))")

        let runner = RunnerManager.live
        try await runner.ensureAvailable()
        let runnerBin = runner.runnerPath()
        let runnerDir = runner.runnerDir()

        let flowYaml = """
        appId: \(resolvedAppID)
        ---
        - launchApp
        - waitForAnimationToEnd:
            timeout: 3600000
        """
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-session")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let flowPath = tempDir.appendingPathComponent("session-flow.yaml").path
        try flowYaml.write(toFile: flowPath, atomically: true, encoding: .utf8)

        let runnerArgs = Self.runnerArguments(platform: platformDevice, deviceID: booted.udid, flowPath: flowPath)
        let environment = platformDevice.runnerEnvironment(runnerHome: runnerDir, deviceID: booted.udid)
        let launch = Launch(
            runnerBin: runnerBin, runnerDir: runnerDir, runnerArgs: runnerArgs,
            environment: environment.isEmpty ? nil : environment,
            appID: resolvedAppID, device: booted, platform: platform, platformDevice: platformDevice
        )
        if detach {
            let runnerPid = try await startDetached(launch)
            simulatorLease.handOff(to: runnerPid)
            handedOff = true
        } else {
            // Held by this process until the runner ends; the `defer` above
            // (or the interrupt cleanup) releases it.
            try await startForeground(launch, lease: simulatorLease)
        }
    }

    static func appID(platform: Platform, bundleId: String?, applicationId: String?, config: GrantivaConfig?) throws -> String {
        switch platform {
        case .ios:
            if applicationId != nil { throw TargetOptions.otherPlatformFlagError("--application-id", platform: .ios) }
            guard let id = bundleId ?? config?.bundleId else {
                throw GrantivaError.invalidArgument("No bundle ID. Pass --bundle-id or set bundle_id in grantiva.yml.")
            }
            return id
        case .android:
            if bundleId != nil { throw TargetOptions.otherPlatformFlagError("--bundle-id", platform: .android) }
            guard let id = applicationId ?? config?.android?.applicationId else {
                throw GrantivaError.invalidArgument("No application ID. Pass --application-id or set application_id in grantiva-android.yml.")
            }
            return id
        }
    }

    static func target(platform: Platform, simulator: String?, emulator: String?, device: String?, config: GrantivaConfig?) -> String {
        switch platform {
        case .ios: return simulator ?? config?.simulator ?? DefaultSimulator.name
        case .android: return device ?? emulator ?? config?.android?.emulator ?? ""
        }
    }

    /// Global flags, `test`, the platform's test flags, `--keep-alive`, then
    /// the flow.
    ///
    /// The session flow's `waitForAnimationToEnd` was meant to hold the runner
    /// for an hour, but runner 1.1.18 returns from it as soon as the screen
    /// settles on either platform, so without `--keep-alive` the runner
    /// finishes the flow and exits seconds after `runner start` reports
    /// success. `--keep-alive` holds the session until SIGINT, which is what
    /// `runner stop` sends.
    static func runnerArguments(platform: any DevicePlatform, deviceID: String, flowPath: String) -> [String] {
        platform.runnerGlobalArguments(deviceID: deviceID, appFile: nil) + ["test"] + platform.runnerTestArguments()
            + ["--keep-alive", flowPath]
    }

    /// Polls `attach` until the runner has opened its UIAutomator2 session.
    /// The successful attachment is returned un-detached: its forward is the
    /// port `session.json` records and `dump-hierarchy` and the MCP server use.
    static func waitForUIAutomator2(
        attach: @Sendable () async throws -> DriverAttachment,
        timeout: TimeInterval,
        sleep: @Sendable () async -> Void = { try? await Task.sleep(for: .seconds(1)) }
    ) async -> DriverAttachment? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let attachment = try? await attach() { return attachment }
            await sleep()
        } while Date() < deadline
        return nil
    }

    struct Launch {
        let runnerBin: String
        let runnerDir: String
        let runnerArgs: [String]
        let environment: [String: String]?
        let appID: String
        let device: BootedDevice
        let platform: Platform
        let platformDevice: any DevicePlatform
    }

    /// The local end of the forward to the runner's UIAutomator2 session. The
    /// forward is left in place: it is the port the session records.
    private static func waitForUIAutomator2Port(_ launch: Launch) async -> UInt16? {
        let device = launch.platformDevice
        let serial = launch.device.udid
        let attachment = await Self.waitForUIAutomator2(
            attach: { try await device.attachDriver(deviceID: serial, port: nil) }, timeout: 90
        )
        return attachment.map { UInt16(clamping: $0.port) }
    }

    private static func portLabel(_ platform: Platform) -> String {
        platform == .android ? "UIAutomator2 port" : "WDA port"
    }

    /// The runner runs with `--keep-alive`, so it publishes a session file in
    /// /tmp/grantiva-sessions that carries no device (and, on Android, port
    /// 0). The owner sidecar maps its pid to the UDID or serial, which is what
    /// lets `grantiva hierarchy` and the MCP server find the device, exactly
    /// as `grantiva run --keep-alive` does.
    private static func recordKeepAliveOwner(_ launch: Launch, runnerPid: Int32, detached: Bool) {
        KeepAliveSessionStore().recordOwner(
            udid: launch.device.udid, runnerPid: runnerPid, platform: launch.platform, detached: detached, appID: launch.appID
        )
    }

    private static func removeKeepAliveOwner(_ launch: Launch, runnerPid: Int32) {
        KeepAliveSessionStore().removeOwner(runnerPid: runnerPid)
    }

    // MARK: - Detached start

    private func startDetached(_ launch: Launch) async throws -> Int32 {
        let logPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-runner-\(Int(Date().timeIntervalSince1970)).log")
            .path
        FileManager.default.createFile(atPath: logPath, contents: nil)
        guard let log = FileHandle(forWritingAtPath: logPath) else {
            throw GrantivaError.commandFailed("Could not open runner log: \(logPath)", 1)
        }
        let child: ChildProcess
        do {
            child = try ChildProcess.spawn(
                executable: "/usr/bin/nohup",
                arguments: [launch.runnerBin] + launch.runnerArgs,
                workingDirectory: launch.runnerDir,
                environment: launch.environment,
                stdout: log.fileDescriptor,
                stderr: log.fileDescriptor
            )
            try log.close()
        } catch {
            try? log.close()
            throw error
        }
        let runnerPid = child.pid
        Self.recordKeepAliveOwner(launch, runnerPid: runnerPid, detached: true)

        let port: UInt16
        if launch.platform == .android {
            guard let found = await Self.waitForUIAutomator2Port(launch) else {
                child.terminateGroup(gracePeriod: 1)
                Self.removeKeepAliveOwner(launch, runnerPid: runnerPid)
                throw GrantivaError.commandFailed("Timed out waiting for the UIAutomator2 session to start. Log: \(logPath)", 1)
            }
            port = found
        } else {
            // Poll the log file for WDA's port or a failed build.
            let startup = try await waitForWDAPort(logFile: logPath, timeout: 60)
            guard case .port(let found)? = startup else {
                child.terminateGroup(gracePeriod: 1)
                throw Self.wdaStartupError(startup, logPath: logPath)
            }
            port = found
        }

        let session = RunnerSessionInfo(
            pid: runnerPid,
            wdaPort: port,
            bundleId: launch.appID,
            udid: launch.device.udid,
            startedAt: Date(),
            platform: launch.platform
        )
        try Self.record(session: session)

        if options.json {
            Output.line(try JSONOutput.string(RunnerLifecycleDocument(
                status: "started", pid: runnerPid, port: port, appID: launch.appID,
                deviceID: launch.device.udid, platform: launch.platform, log: logPath
            )))
        } else {
            Output.line("Runner started (detached)")
            Output.line("  \(Self.portLabel(launch.platform)): \(port)")
            Output.line("  PID:      \(runnerPid)")
            Output.line("  Log:      \(logPath)")
            Output.line("  Session:  \(RunnerSessionInfo.path)")
            Output.line("")
            Output.line("Tail the log with: tail -f \(logPath)")
            Output.line("Use 'grantiva runner stop' to stop the session.")
        }
        return runnerPid
    }

    // MARK: - Foreground start

    /// Starts the runner attached to this process and holds the session until
    /// the runner ends: Ctrl-C (SignalRelay reaps the runner's group, runs the
    /// cleanup and exits 130), `runner stop` from another shell, or the runner
    /// exiting on its own. The runner's output streams to stderr meanwhile.
    private func startForeground(_ launch: Launch, lease: SimulatorLease) async throws {
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let child = try ChildProcess.spawn(
            executable: launch.runnerBin,
            arguments: launch.runnerArgs,
            workingDirectory: launch.runnerDir,
            environment: launch.environment,
            stdout: stdoutPipe.fileHandleForWriting.fileDescriptor,
            stderr: stderrPipe.fileHandleForWriting.fileDescriptor
        )
        try? stdoutPipe.fileHandleForWriting.close()
        try? stderrPipe.fileHandleForWriting.close()
        // `kill -9` of this process must not leave the runner holding the device.
        let lifeline = child.bindLifetimeToParent(sessionDirectory: KeepAliveSessionStore.defaultDirectory)
        Self.recordKeepAliveOwner(launch, runnerPid: child.pid, detached: false)
        lease.recordRunner(pid: child.pid, keepAlive: true)

        let runnerPid = child.pid
        let cleanup = Once {
            if let session = try? RunnerSessionInfo.load(), session.pid == runnerPid { RunnerSessionInfo.remove() }
            KeepAliveSessionStore().removeSessionFiles(runnerPid: runnerPid)
            lease.release()
        }
        SignalRelay.shared.track(group: child.processGroup)
        let startupInterrupt = SignalRelay.shared.onTermination { cleanup.run() }
        defer {
            SignalRelay.shared.untrack(group: child.processGroup)
            SignalRelay.shared.removeCleanup(startupInterrupt)
        }
        // Each exit path that gets here has stopped or waited for the
        // runner; this is the only place the lifeline closes.
        defer { if let lifeline { Darwin.close(lifeline) } }

        // Through the narration choke point: --json and --quiet silence it.
        let output = RunnerOutputForwarder()
        output.attachOutput(stdoutPipe.fileHandleForReading)
        output.attachErrors(stderrPipe.fileHandleForReading)
        let port: UInt16
        if launch.platform == .android {
            // The port comes from the forward, not the output.
            output.endStartup()
            guard let found = await Self.waitForUIAutomator2Port(launch) else {
                child.terminateGroup(gracePeriod: 1)
                cleanup.run()
                throw GrantivaError.commandFailed("Timed out waiting for the UIAutomator2 session to start", 1)
            }
            port = found
        } else {
            let startup = await Self.waitForForegroundWDAPort(
                chunks: output.chunks,
                timeout: Self.foregroundWDATimeout,
                probe: Self.probeKnownWDAPorts
            )
            output.endStartup()
            guard case .port(let found)? = startup else {
                child.terminateGroup(gracePeriod: 1)
                cleanup.run()
                throw Self.wdaStartupError(startup, logPath: nil)
            }
            port = found
        }

        let session = RunnerSessionInfo(
            pid: child.pid,
            wdaPort: port,
            bundleId: launch.appID,
            udid: launch.device.udid,
            startedAt: Date(),
            platform: launch.platform
        )
        do {
            try Self.record(session: session)
        } catch {
            cleanup.run()
            throw error
        }

        if options.json {
            Output.line(try JSONOutput.string(RunnerLifecycleDocument(
                status: "started", pid: child.pid, port: port, appID: launch.appID,
                deviceID: launch.device.udid, platform: launch.platform, log: nil
            )))
        } else {
            Output.line("Runner started")
            Output.line("  \(Self.portLabel(launch.platform)): \(port)")
            Output.line("  PID:      \(child.pid)")
            Output.line("  Session:  \(RunnerSessionInfo.path)")
            Output.line("")
            Output.line("Use 'grantiva runner dump-hierarchy' to inspect the view hierarchy.")
            Output.line("Press Ctrl-C (or run 'grantiva runner stop') to stop the session.")
        }

        let status = await Self.holdForeground(
            waitForExit: {
                await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async { continuation.resume(returning: child.wait()) }
                }
            },
            onInterrupt: { SignalRelay.shared.onTermination($0) },
            removeInterruptHandler: { SignalRelay.shared.removeCleanup($0) },
            cleanup: { cleanup.run() }
        )
        if SignalRelay.shared.isTerminating {
            // Ctrl-C: the relay is reaping and exits 130 once its cleanups
            // finish; do not race it to a 0. Capped like `run`'s wait.
            try? await Task.sleep(for: .seconds(30))
            throw ExitCode(130)
        }
        guard Self.isOrderlyRunnerExit(status) else {
            throw GrantivaError.commandFailed("The runner exited with status \(status); the session has ended.", 1)
        }
        options.note("Runner stopped (pid \(child.pid)); the session has ended.")
    }

    /// Holds until `waitForExit` returns, running `cleanup` exactly once:
    /// on an interrupt (through the handler registered with `onInterrupt`)
    /// or when the runner exits, whichever comes first.
    static func holdForeground(
        waitForExit: @escaping @Sendable () async -> Int32,
        onInterrupt: (@escaping @Sendable () -> Void) -> UInt64,
        removeInterruptHandler: (UInt64) -> Void,
        cleanup: @escaping @Sendable () -> Void
    ) async -> Int32 {
        let once = Once(cleanup)
        let token = onInterrupt { once.run() }
        let status = await waitForExit()
        once.run()
        removeInterruptHandler(token)
        return status
    }

    /// A runner that exited 0, or was stopped by a signal (`runner stop`,
    /// teardown), ended the session in order.
    static func isOrderlyRunnerExit(_ status: Int32) -> Bool {
        [0, SIGINT, SIGTERM, SIGKILL, 128 + SIGINT, 128 + SIGTERM].contains(status)
    }

    // MARK: - Helpers

    /// What the runner's output says about WebDriverAgent so far.
    enum WDAStartup: Equatable {
        case port(UInt16)
        case buildFailed
    }

    /// How long `runner start` waits for WDA once the runner reports that it
    /// is building it from source (no cached build for this iOS runtime). A
    /// cached build comes up within the ordinary 60 s.
    static let wdaBuildTimeout: TimeInterval = 600

    static func isBuildingWDA(_ text: String) -> Bool {
        text.contains("Building WDA") || text.contains("Building GrantivaAgent")
    }

    /// The production `timeout` for `waitForForegroundWDAPort`: 60 s, or
    /// `wdaBuildTimeout` once the runner has started a WDA build.
    static func foregroundWDATimeout(isBuilding: @escaping @Sendable () -> Bool) async {
        try? await Task.sleep(for: .seconds(60))
        if isBuilding() {
            try? await Task.sleep(for: .seconds(wdaBuildTimeout - 60))
        }
    }

    static func waitForForegroundWDAPort(
        chunks: AsyncStream<Data>,
        timeout: @escaping @Sendable (_ isBuilding: @escaping @Sendable () -> Bool) async -> Void,
        probe: @escaping @Sendable () async -> UInt16?
    ) async -> WDAStartup? {
        let building = BuildFlag()
        return await withTaskGroup(of: WDAStartup?.self) { group in
            group.addTask {
                var accumulated = Data()
                for await chunk in chunks {
                    accumulated.append(chunk)
                    let text = String(decoding: accumulated, as: UTF8.self)
                    if let startup = parseWDAStartup(text) {
                        return startup
                    }
                    if isBuildingWDA(text) { building.set() }
                    if text.contains("launchApp"), text.contains("✓"),
                       let port = await probe() {
                        return .port(port)
                    }
                }
                return nil
            }
            group.addTask {
                await timeout { building.isSet }
                return nil
            }

            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    private final class BuildFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false
        var isSet: Bool { lock.withLock { value } }
        func set() { lock.withLock { value = true } }
    }

    private static func probeKnownWDAPorts() async -> UInt16? {
        for candidate: UInt16 in [8430, 8100, 8200] {
            let url = URL(string: "http://localhost:\(candidate)/status")!
            if let (_, response) = try? await URLSession.shared.data(from: url),
               let http = response as? HTTPURLResponse, http.statusCode == 200 {
                return candidate
            }
        }
        return nil
    }

    static func record(
        session: RunnerSessionInfo,
        write: (RunnerSessionInfo) throws -> Void = { try $0.write() },
        terminate: (Int32) -> Void = { ChildProcess.terminateGroup($0, gracePeriod: 1) }
    ) throws {
        do {
            try write(session)
        } catch {
            terminate(session.pid)
            throw error
        }
    }

    /// Poll a log file until the runner reports WDA's port or a failed WDA
    /// build, or the timeout elapses.
    private func waitForWDAPort(logFile: String, timeout: TimeInterval) async throws -> WDAStartup? {
        let started = Date()
        var deadline = started.addingTimeInterval(timeout)
        var extendedForBuild = false
        while Date() < deadline {
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms
            guard let content = try? String(contentsOfFile: logFile, encoding: .utf8) else { continue }
            if let startup = Self.parseWDAStartup(content) { return startup }
            if !extendedForBuild, Self.isBuildingWDA(content) {
                extendedForBuild = true
                deadline = started.addingTimeInterval(Self.wdaBuildTimeout)
            }
            if content.contains("launchApp") && content.contains("✓"),
               let port = await Self.probeKnownWDAPorts() {
                return .port(port)
            }
        }
        return nil
    }

    /// The error `runner start` throws when WDA never came up.
    static func wdaStartupError(_ startup: WDAStartup?, logPath: String?) -> GrantivaError {
        let log = logPath.map { " Log: \($0)" } ?? ""
        if startup == .buildFailed {
            return .commandFailed("WebDriverAgent failed to build. Check that Xcode is installed and the simulator runtime is available.\(log)", 1)
        }
        return .commandFailed("Timed out waiting for WDA to start.\(log)", 1)
    }

    /// Reads the runner's output for WDA's state. A port wins over an earlier
    /// build failure because the runner retries the build. Only the runner's
    /// own announcements count: the WDA build log it echoes contains
    /// "WebDriverAgent" and plenty of digits, which is how an earlier loose
    /// pattern once reported a clang response-file hash as the port.
    static func parseWDAStartup(_ text: String) -> WDAStartup? {
        let portPatterns = [
            "WDA started successfully on port ([0-9]+)",
            "localhost:([0-9]+)",
            "\\bport[: ]+([0-9]+)",
        ]
        for pattern in portPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text),
               let port = UInt16(text[range]), port > 1024 {
                return .port(port)
            }
        }
        let failureMarkers = [
            "WDA build failed", "GrantivaAgent setup failed", "xcodebuild failed",
            "** TEST BUILD FAILED **", "** BUILD FAILED **",
        ]
        if failureMarkers.contains(where: text.contains) {
            return .buildFailed
        }
        return nil
    }

}

// MARK: - Stop

@available(macOS 15, *)
struct RunnerStopCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop the running runner session.",
        discussion: """
        Stops the session `grantiva runner start` recorded in .grantiva/session.json: \
        the runner gets SIGINT, then SIGTERM and SIGKILL if it does not exit, and \
        its session files and device lease are removed. Helpers the runner \
        started for the device that outlive it (on iOS, the `simctl diagnose` \
        WebDriverAgent's xcodebuild starts when it is interrupted) are stopped \
        too and listed (`reaped` in --json); on Android the runner's port \
        forwards and UIAutomator2 server are cleared. Without one, it releases a \
        `grantiva run --keep-alive` session started from this directory (every \
        one, if there are several) the way Ctrl-C would, by sending that grantiva \
        process SIGINT, and waits for it to exit. A run whose flows had already \
        finished keeps the ready file it wrote (`passed` or `failed`): the ready \
        file is written once, and the `stopped` result here is the record of the \
        release. Sessions started from other directories are left alone. With no \
        session at all it prints "No active session found." and exits 0.
        """
    )

    @OptionGroup var options: GlobalOptions

    enum Result: Equatable {
        case notRunning
        /// The `runner start` session's runner was stopped; `killed` when it
        /// took SIGKILL. `reaped`: device helpers it left running, ended here.
        case stopped(pid: Int32, udid: String, killed: Bool, reaped: [ReapedProcess] = [])
        /// The `runner start` session's runner had already exited; its
        /// session was cleaned up.
        case exited(pid: Int32, udid: String, reaped: [ReapedProcess] = [])
        /// Every keep-alive session started from this directory.
        case keepAlive([RunnerSessionStopper.Outcome])
    }

    func run() async throws {
        let result = try await perform(dependencies: .live)
        if options.json {
            Output.line(try JSONOutput.string(Self.document(result)))
        } else if result == .notRunning {
            // Narration, not a result: stderr, so stdout stays empty.
            options.note(Self.render(result))
        } else {
            Output.line(Self.render(result))
        }
    }

    func perform(dependencies: RunnerStopDependencies) async throws -> Result {
        guard let session = try? dependencies.loadSession() else {
            let here = KeepAliveOwner.canonicalDirectory(dependencies.currentDirectory())
            let sessions = dependencies.keepAliveSessions()
                .filter { $0.projectDirectory.map(KeepAliveOwner.canonicalDirectory) == here }
            guard !sessions.isEmpty else { return .notRunning }
            var outcomes: [RunnerSessionStopper.Outcome] = []
            for session in sessions {
                outcomes.append(try await dependencies.stopKeepAlive(session))
            }
            return .keepAlive(outcomes)
        }

        var outcome: Result?
        if dependencies.isAlive(session) {
            let snapshot = try await dependencies.processSnapshot()
            if session.ownsRunnerProcess(in: snapshot) {
                // Watch what the runner started while its group stops: on iOS
                // an interrupted xcodebuild starts `simctl diagnose` in a group
                // of its own, which outlives the group (L04).
                let (termination, reaped) = await dependencies.helperReaper.stopping(
                    runnerPid: session.pid, udid: session.udid
                ) { dependencies.terminateGroup(session.pid) }
                outcome = .stopped(pid: session.pid, udid: session.udid, killed: termination == .killed, reaped: reaped)
            }
        }
        if outcome == nil {
            let reaped = await dependencies.helperReaper.sweep(exitedRunnerPid: session.pid, udid: session.udid)
            outcome = .exited(pid: session.pid, udid: session.udid, reaped: reaped)
        }

        // A runner that took SIGKILL never removes its own session file.
        dependencies.removeRunnerSessionFiles(session.pid)
        // The runner's own teardown clears its forwards and the UIA2 server
        // when it exits cleanly; after a kill they may still be there.
        if DeviceID.isAndroidSerial(session.udid) {
            await dependencies.cleanupOrphans(session.udid)
        }

        dependencies.removeSession()
        dependencies.removeKeepAliveOwner(session.pid)
        // The session held the simulator lease by hand-off; free it now.
        dependencies.releaseLease(session.udid)
        return outcome ?? .exited(pid: session.pid, udid: session.udid)
    }

    static func render(_ result: Result) -> String {
        switch result {
        case .notRunning:
            return "No active session found."
        case .stopped(let pid, let udid, let killed, let reaped):
            let line = killed
                ? "Runner stopped (pid \(pid); it ignored SIGINT and SIGTERM and was killed)"
                : "Runner stopped (pid \(pid))"
            return ([line] + reapedLines(reaped, udid: udid)).joined(separator: "\n")
        case .exited(let pid, let udid, let reaped):
            return (["No running runner (pid \(pid) had exited); cleaned up its session."] + reapedLines(reaped, udid: udid))
                .joined(separator: "\n")
        case .keepAlive(let outcomes):
            return outcomes.flatMap { outcome in
                switch outcome {
                case .released(let grantivaPid, _, let udid, let reaped):
                    return ["Stopped keep-alive session (pid \(grantivaPid), \(udid))"] + reapedLines(reaped, udid: udid)
                case .terminated(let runnerPid, let udid, _, let reaped):
                    return ["Stopped keep-alive session (pid \(runnerPid), \(udid))"] + reapedLines(reaped, udid: udid)
                }
            }.joined(separator: "\n")
        }
    }

    /// One line per device helper a stop ended (L04).
    static func reapedLines(_ reaped: [ReapedProcess], udid: String) -> [String] {
        reaped.map { "Also stopped \($0.kind.rawValue) pid \($0.pid), which the runner left running for \(udid)." }
    }

    static func document(_ result: Result) -> RunnerLifecycleDocument {
        func platform(_ udid: String) -> Platform { DeviceID.isAndroidSerial(udid) ? .android : .ios }
        switch result {
        case .notRunning:
            return RunnerLifecycleDocument(status: "not_running")
        case .stopped(let pid, let udid, let killed, let reaped):
            var document = RunnerLifecycleDocument(status: "stopped", pid: pid, deviceID: udid, platform: platform(udid))
            document.runnerPid = pid
            document.killed = killed
            document.reaped = reaped
            return document
        case .exited(let pid, let udid, let reaped):
            var document = RunnerLifecycleDocument(status: "stopped", pid: pid, deviceID: udid, platform: platform(udid))
            document.runnerPid = pid
            document.alreadyExited = true
            document.reaped = reaped
            return document
        case .keepAlive(let outcomes):
            let documents = outcomes.map { outcome -> RunnerLifecycleDocument in
                switch outcome {
                case .released(let grantivaPid, let runnerPid, let udid, let reaped):
                    var document = RunnerLifecycleDocument(status: "stopped", pid: grantivaPid, deviceID: udid, platform: platform(udid))
                    document.runnerPid = runnerPid
                    document.reaped = reaped
                    return document
                case .terminated(let runnerPid, let udid, let killed, let reaped):
                    var document = RunnerLifecycleDocument(status: "stopped", pid: runnerPid, deviceID: udid, platform: platform(udid))
                    document.runnerPid = runnerPid
                    document.killed = killed
                    document.reaped = reaped
                    return document
                }
            }
            guard var first = documents.first else { return RunnerLifecycleDocument(status: "not_running") }
            if documents.count > 1 { first.sessions = documents }
            return first
        }
    }
}

struct RunnerStopDependencies: Sendable {
    var loadSession: @Sendable () throws -> RunnerSessionInfo
    var isAlive: @Sendable (RunnerSessionInfo) -> Bool
    var processSnapshot: @Sendable () async throws -> String
    var terminateGroup: @Sendable (Int32) -> ChildProcess.GroupTermination
    var removeSession: @Sendable () -> Void
    var releaseLease: @Sendable (String) -> Void
    var cleanupOrphans: @Sendable (String) async -> Void
    /// `runner start` records a keep-alive owner sidecar for the runner pid
    /// on both platforms; stop removes it with the session.
    var removeKeepAliveOwner: @Sendable (Int32) -> Void
    /// The runner's own `<pid>-<ts>.grantiva` (and sidecar), removed by pid.
    var removeRunnerSessionFiles: @Sendable (Int32) -> Void
    /// Live keep-alive sessions, orphans included.
    var keepAliveSessions: @Sendable () -> [KeepAliveSession]
    var stopKeepAlive: @Sendable (KeepAliveSession) async throws -> RunnerSessionStopper.Outcome
    var currentDirectory: @Sendable () -> String
    /// Ends the device helpers the stopped runner left (L04). Inert unless set.
    var helperReaper: RunnerHelperReaper = .inert

    static let live = RunnerStopDependencies(
        loadSession: { try RunnerSessionInfo.load() },
        isAlive: { $0.isAlive },
        processSnapshot: { try await SimulatorReaper.processSnapshot() },
        // Five seconds to release WebDriverAgent before SIGTERM, as on Ctrl-C.
        terminateGroup: { ChildProcess.terminateGroup($0, gracePeriod: 5) },
        removeSession: { RunnerSessionInfo.remove() },
        releaseLease: { SimulatorLease.forceRelease(udid: $0) },
        cleanupOrphans: { serial in
            guard let platform = try? AndroidPlatform.live() else { return }
            await platform.cleanupOrphans(deviceID: serial)
        },
        removeKeepAliveOwner: { KeepAliveSessionStore().removeOwner(runnerPid: $0) },
        removeRunnerSessionFiles: { KeepAliveSessionStore().removeSessionFiles(runnerPid: $0) },
        keepAliveSessions: { KeepAliveSessionStore().liveSessions(includingOrphans: true) },
        stopKeepAlive: { try await RunnerSessionStopper.live().stop($0) },
        currentDirectory: { FileManager.default.currentDirectoryPath },
        helperReaper: .live()
    )
}

// MARK: - Dump Hierarchy

@available(macOS 15, *)
struct DumpHierarchyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dump-hierarchy",
        abstract: "Dump the view hierarchy from a running app for agent inspection."
    )

    @OptionGroup var options: GlobalOptions

    @Option(name: .shortAndLong, help: "Driver port: WDA on iOS, the forwarded UIAutomator2 port on Android (auto-detected from the active session if omitted)")
    var port: UInt16?

    @Option(name: .shortAndLong, help: "Output format: tree, json, or xml (default: tree; any case). --json is the same as --format json.")
    var format: Format?

    /// Checked while parsing, so `--format bogus` is a usage error before any
    /// session lookup. Case-insensitive, as it always was.
    enum Format: String, CaseIterable, ExpressibleByArgument {
        case tree, json, xml

        init?(argument: String) {
            self.init(rawValue: argument.lowercased())
        }
    }

    /// `--json` selects JSON, as it does on every command that offers it.
    var outputFormat: String {
        options.json ? "json" : (format ?? .tree).rawValue
    }

    @Option(name: .long, help: "Simulator UDID or adb serial when falling back to a `grantiva run --keep-alive` session")
    var udid: String?

    var devicePlatform = InjectedDevicePlatform()

    func validate() throws {
        if let udid { _ = try usageCheck { try DeviceID.validate(udid) } }
        if options.json, let format, format != .json {
            throw ValidationError("--json and --format \(format.rawValue) conflict; pass one.")
        }
    }

    struct Target: Equatable {
        let udid: String
        let port: UInt16?
    }

    /// Flag port, then a `runner start` session, then a keep-alive session.
    /// A keep-alive port of 0 (Android) becomes nil: the platform forwards one.
    static func resolveTarget(port: UInt16?, runnerSession: RunnerSessionInfo?, keepAlive: KeepAliveSession?) throws -> Target {
        if let port { return Target(udid: "", port: port) }
        if let runnerSession { return Target(udid: runnerSession.udid, port: runnerSession.wdaPort) }
        if let keepAlive {
            return Target(udid: keepAlive.udid ?? "", port: keepAlive.port > 0 ? UInt16(exactly: keepAlive.port) : nil)
        }
        throw GrantivaError.noRunnerSession(orPassPort: true)
    }

    func run() async throws {
        let runnerSession: RunnerSessionInfo? = {
            guard let session = try? RunnerSessionInfo.load(), session.isAlive else { return nil }
            return session
        }()
        let keepAlive = try? KeepAliveSessionStore().locate(udid: udid)
        let target = try Self.resolveTarget(port: port, runnerSession: runnerSession, keepAlive: keepAlive)
        try await dump(target: target)
    }

    func dump(target: Target) async throws {
        if DeviceID.isAndroidSerial(target.udid) {
            let device = try devicePlatform.make(.android)
            let attachment = try await device.attachDriver(deviceID: target.udid, port: target.port)
            do {
                try await render(client: attachment.client)
            } catch {
                await attachment.detach()
                throw error
            }
            await attachment.detach()
            return
        }
        guard let wdaPort = target.port else {
            throw GrantivaError.invalidArgument("No WebDriverAgent port for this session. Pass --port.")
        }

        // WDA uses the WebDriver protocol. The source endpoint returns the page hierarchy.
        // First, get the active session ID
        let statusUrl = URL(string: "http://localhost:\(wdaPort)/status")!
        let (statusData, statusResponse) = try await URLSession.shared.data(from: statusUrl)

        guard let statusHttp = statusResponse as? HTTPURLResponse, statusHttp.statusCode == 200 else {
            throw GrantivaError.commandFailed(
                "Cannot connect to WDA on port \(wdaPort). Is the runner started?", 1
            )
        }

        // Parse session ID from status
        var sessionId: String?
        if let statusJson = try? JSONSerialization.jsonObject(with: statusData) as? [String: Any],
           let sid = statusJson["sessionId"] as? String {
            sessionId = sid
        }

        // Fetch the page source (XML format from WDA)
        let sourceUrlString: String
        if let sid = sessionId {
            sourceUrlString = "http://localhost:\(wdaPort)/session/\(sid)/source"
        } else {
            sourceUrlString = "http://localhost:\(wdaPort)/source"
        }

        let sourceUrl = URL(string: sourceUrlString)!
        let (sourceData, sourceResponse) = try await URLSession.shared.data(from: sourceUrl)

        guard let sourceHttp = sourceResponse as? HTTPURLResponse, sourceHttp.statusCode == 200 else {
            let msg = String(data: sourceData, encoding: .utf8) ?? "Unknown error"
            throw GrantivaError.commandFailed("Failed to get hierarchy: \(msg)", 1)
        }

        // WDA returns JSON with a "value" key containing the XML source
        let xmlSource: String
        if let json = try? JSONSerialization.jsonObject(with: sourceData) as? [String: Any],
           let value = json["value"] as? String {
            xmlSource = value
        } else if let raw = String(data: sourceData, encoding: .utf8) {
            xmlSource = raw
        } else {
            throw GrantivaError.commandFailed("Empty hierarchy response", 1)
        }

        switch outputFormat {
        case "xml":
            Output.line(xmlSource)

        case "json":
            // Parse XML to JSON
            let parser = WDAHierarchyXMLParser(xml: xmlSource)
            let tree = try parser.parse()
            let jsonData = try JSONSerialization.data(withJSONObject: tree, options: [.prettyPrinted, .sortedKeys])
            Output.line(String(data: jsonData, encoding: .utf8) ?? "{}")

        case "tree":
            // Parse XML and pretty-print as tree
            let parser = WDAHierarchyXMLParser(xml: xmlSource)
            let tree = try parser.parse()
            printTree(element: tree, indent: 0)

        default:
            throw GrantivaError.invalidArgument("Invalid format '\(outputFormat)'. Use: tree, json, or xml")
        }
    }

    private func render(client: DriverClient) async throws {
        switch outputFormat {
        case "xml":
            Output.line(try await client.hierarchyXML())
        case "json":
            let data = try JSONSerialization.data(withJSONObject: try await client.hierarchy(), options: [.prettyPrinted, .sortedKeys])
            Output.line(String(data: data, encoding: .utf8) ?? "{}")
        case "tree":
            printTree(element: try await client.hierarchy(), indent: 0)
        default:
            throw GrantivaError.invalidArgument("Invalid format '\(outputFormat)'. Use: tree, json, or xml")
        }
    }

    private func printTree(element: [String: Any], indent: Int) {
        let prefix = String(repeating: "  ", count: indent)
        let type = element["type"] as? String ?? "Unknown"
        let label = element["label"] as? String
        let identifier = element["identifier"] as? String
        let name = element["name"] as? String
        let value = element["value"] as? String
        let enabled = element["enabled"] as? Bool ?? true

        var desc = "\(prefix)[\(type)]"
        if let label = label, !label.isEmpty {
            desc += " label=\"\(label)\""
        }
        if let name = name, !name.isEmpty, name != label {
            desc += " name=\"\(name)\""
        }
        if let identifier = identifier, !identifier.isEmpty {
            desc += " id=\"\(identifier)\""
        }
        if let value = value, !value.isEmpty {
            desc += " value=\"\(value)\""
        }
        if !enabled {
            desc += " (disabled)"
        }

        Output.line(desc)

        if let children = element["children"] as? [[String: Any]] {
            for child in children {
                printTree(element: child, indent: indent + 1)
            }
        }
    }
}
