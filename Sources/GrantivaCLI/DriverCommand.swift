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
        files and releases the device. Interrupted, it exits 130; ended by \
        `grantiva runner stop` or by a simulator or emulator teardown, it exits 0. \
        With --detach it returns once the driver is up and the runner keeps the \
        session until `grantiva runner stop`. .grantiva/session.json is written \
        as soon as the runner is spawned, with "state": "starting", and marked \
        "ready" once the driver answers.

        --json prints one document: {"status": "started" | "already_running", \
        "pid": <number>, "port": <number> (null for a session still starting), \
        "platform": "ios" | "android", plus \
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
                    status: "already_running", pid: existing.pid, port: existing.isReady ? existing.wdaPort : nil,
                    appID: existing.bundleId, deviceID: existing.udid,
                    platform: existing.platform ?? (DeviceID.isAndroidSerial(existing.udid) ? .android : .ios), log: nil
                )))
            } else {
                let label = Self.portLabel(DeviceID.isAndroidSerial(existing.udid) ? .android : .ios)
                let state = existing.isReady ? "\(label) \(existing.wdaPort)" : "starting"
                Output.line("Runner already running (pid \(existing.pid), \(state))")
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
        var launch = Launch(
            runnerBin: runnerBin, runnerDir: runnerDir, runnerArgs: runnerArgs,
            environment: environment.isEmpty ? nil : environment,
            appID: resolvedAppID, device: booted, platform: platform, platformDevice: platformDevice
        )
        // A UIAutomator2 session already on the device belongs to no runner
        // this command starts (a `kill -9`'d keep-alive run leaves one): its
        // id is recorded so the readiness wait never accepts it (L38-b).
        launch.staleSessionID = await Self.currentDriverSession(platformDevice, deviceID: booted.udid)
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

    /// How a wait for the runner's UIAutomator2 session ended: attached, the
    /// runner exited first (`exitStatus`), or neither before the timeout.
    struct UIAutomator2Wait {
        var attachment: DriverAttachment?
        var exitStatus: Int32?
    }

    /// Polls `attach` until the runner has opened its UIAutomator2 session.
    /// The successful attachment is returned un-detached: its forward is the
    /// port `session.json` records and `dump-hierarchy` and the MCP server use.
    /// `runnerExit` (the spawned runner's status once it has exited) ends the
    /// wait at the next poll: a runner that gave up is not waited on (L48).
    /// `staleSessionID`, the session the device held before the runner was
    /// spawned, is never accepted: it belongs to a server the new runner is
    /// about to restart (L38-b).
    static func waitForUIAutomator2(
        attach: @Sendable () async throws -> DriverAttachment,
        timeout: TimeInterval,
        staleSessionID: String? = nil,
        runnerExit: @Sendable () -> Int32? = { nil },
        sleep: @Sendable () async -> Void = { try? await Task.sleep(for: .seconds(1)) }
    ) async -> UIAutomator2Wait {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let status = runnerExit() { return UIAutomator2Wait(exitStatus: status) }
            if let attachment = try? await attach() {
                if let stale = staleSessionID, attachment.sessionID == stale {
                    await attachment.detach()
                } else {
                    return UIAutomator2Wait(attachment: attachment)
                }
            }
            await sleep()
        } while Date() < deadline
        return UIAutomator2Wait(exitStatus: runnerExit())
    }

    /// The runner's own reason, from its output: its last `Error:` line.
    static func lastErrorLine(in text: String) -> String? {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { $0.hasPrefix("Error:") }
    }

    /// The error `runner start` ends with when the runner exits before its
    /// UIAutomator2 session is up, carrying the runner's reason (L48), or
    /// how it ended when it gave none (`status 1`, `killed by SIGKILL`).
    static func startupExitError(serial: String, status: Int32, signal: Int32? = nil, lastError: String?, logPath: String?) -> GrantivaError {
        let log = logPath.map { " Log: \($0)" } ?? ""
        var reason = lastError ?? ""
        for prefix in ["Error:", "failed to create driver:", "start UIAutomator2:"] {
            reason = reason.trimmingCharacters(in: .whitespaces)
            if reason.hasPrefix(prefix) { reason = String(reason.dropFirst(prefix.count)) }
        }
        reason = reason.trimmingCharacters(in: .whitespaces)
        while reason.hasSuffix(".") { reason.removeLast() }
        guard !reason.isEmpty else {
            let ended = signal.map { "was killed by \(SubprocessLog.signalName($0))" } ?? "exited (status \(status))"
            return .commandFailed("The runner \(ended) before UIAutomator2 was up on \(serial).\(log)", 1)
        }
        let remedy = reason.contains("not ready after")
            ? " Raise the limit with \(AndroidPlatform.driverStartTimeoutVariable)=<seconds>."
            : ""
        return .commandFailed("The runner could not start UIAutomator2 on \(serial): \(reason).\(remedy)\(log)", 1)
    }

    /// How long `runner start` waits for the UIAutomator2 session:
    /// max(90, 2n + 30) seconds, where n is the `--driver-start-timeout`
    /// passed from `GRANTIVA_DRIVER_START_TIMEOUT`.
    static func uiAutomator2WaitTimeout(environment: [String: String] = ProcessInfo.processInfo.environment) -> TimeInterval {
        let limit = TimeInterval(AndroidPlatform.driverStartTimeout(environment: environment) ?? 0)
        return max(90, 2 * limit + 30)
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
        /// The UIAutomator2 session on the device before this runner started.
        var staleSessionID: String? = nil
    }

    /// The local end of the forward to the runner's UIAutomator2 session. The
    /// forward is left in place: it is the port the session records.
    private static func waitForUIAutomator2Port(_ launch: Launch, child: ChildProcess) async -> (port: UInt16?, exitStatus: Int32?) {
        let device = launch.platformDevice
        let serial = launch.device.udid
        let wait = await Self.waitForUIAutomator2(
            attach: { try await device.attachDriver(deviceID: serial, port: nil) },
            timeout: uiAutomator2WaitTimeout(),
            staleSessionID: launch.staleSessionID,
            runnerExit: { child.poll() }
        )
        return (wait.attachment.map { UInt16(clamping: $0.port) }, wait.exitStatus)
    }

    /// The UIAutomator2 session already on the device before the runner is
    /// spawned, if any; nothing is stopped or cleared (L38-b). The probe's
    /// forward is removed again.
    static func currentDriverSession(_ platform: any DevicePlatform, deviceID: String) async -> String? {
        guard platform.platform == .android,
              let attachment = try? await platform.attachDriver(deviceID: deviceID, port: nil) else { return nil }
        await attachment.detach()
        return attachment.sessionID
    }

    /// Hands the runner's group to the interrupt relay, naming the device
    /// the notice says is released (L37).
    static func trackRunner(group: pid_t, platform: Platform) {
        SignalRelay.shared.track(group: group, deviceNoun: SignalRelay.deviceNoun(for: platform))
    }

    /// `.grantiva/session.json` the moment the runner is spawned: `starting`
    /// until the driver answers, so readers say so instead of "no session" (L38-a).
    private static func recordStarting(_ launch: Launch, runnerPid: Int32) throws {
        try record(session: .starting(
            pid: runnerPid, bundleId: launch.appID, udid: launch.device.udid, startedAt: Date(), platform: launch.platform
        ))
    }

    /// Removes `.grantiva/session.json` when it still names `runnerPid`.
    private static func removeSessionFile(of runnerPid: Int32) {
        if let session = try? RunnerSessionInfo.load(), session.pid == runnerPid { RunnerSessionInfo.remove() }
    }

    /// `runner stop` removes `.grantiva/session.json` before it signals the
    /// runner, so a session file that is gone (or names another runner) means
    /// the stop was asked for (L36).
    static func stopWasRequested(runnerPid: Int32, session: RunnerSessionInfo?) -> Bool {
        session?.pid != runnerPid
    }

    /// The stop request read when the foreground runner exits.
    final class StopBox: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: StopRequest?
        var value: StopRequest? {
            get { lock.withLock { stored } }
            set { lock.withLock { stored = newValue } }
        }
    }

    /// Who asked for a runner's stop.
    enum StopRequest: Equatable {
        /// `runner stop` (the session file is gone).
        case runnerStop
        /// A teardown, from any directory (a `RunnerStopMarker` for this runner).
        case teardown
    }

    /// Whether the runner's stop was asked for: a teardown's marker for this
    /// very process (`marked`), or `runner stop`'s removed session file.
    static func stopRequest(runnerPid: Int32, session: RunnerSessionInfo?, marked: Bool) -> StopRequest? {
        if marked { return .teardown }
        return stopWasRequested(runnerPid: runnerPid, session: session) ? .runnerStop : nil
    }

    /// The live check: the session file in this directory and the stop
    /// marker for this runner, which must carry the start time the runner
    /// had when this command spawned it (a stale marker never counts).
    static func liveStopRequest(runnerPid: Int32, runnerStartTime: Int64?, marker: RunnerStopMarker = RunnerStopMarker()) -> StopRequest? {
        stopRequest(
            runnerPid: runnerPid, session: try? RunnerSessionInfo.load(),
            marked: marker.isMarked(runnerPid: runnerPid, runnerStartTime: runnerStartTime)
        )
    }

    /// The foreground command's last line, or its failure: a runner that
    /// exited 0, or after `runner stop` or a teardown asked it to, ended the
    /// session in order; any other status is the runner's failure.
    static func foregroundEnding(status: Int32, pid: Int32, stop: StopRequest?) throws -> String {
        switch stop {
        case .teardown:
            return "Runner stopped by teardown (pid \(pid)); the session has ended."
        case .runnerStop:
            return "Runner stopped (pid \(pid)); the session has ended."
        case nil:
            guard isOrderlyRunnerExit(status) else {
                throw GrantivaError.commandFailed("The runner exited with status \(status); the session has ended.", 1)
            }
            return "Runner stopped (pid \(pid)); the session has ended."
        }
    }

    static func foregroundEnding(status: Int32, pid: Int32, stopRequested: Bool) throws -> String {
        try foregroundEnding(status: status, pid: pid, stop: stopRequested ? .runnerStop : nil)
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
            udid: launch.device.udid, runnerPid: runnerPid, platform: launch.platform, detached: detached, appID: launch.appID,
            command: KeepAliveOwner.runnerStartCommand
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
        let runnerStartTime = RunnerStopMarker.processStartTime(runnerPid)
        Self.recordKeepAliveOwner(launch, runnerPid: runnerPid, detached: true)
        try Self.recordStarting(launch, runnerPid: runnerPid)
        func abandon() {
            child.terminateGroup(gracePeriod: 1)
            Self.removeKeepAliveOwner(launch, runnerPid: runnerPid)
            Self.removeSessionFile(of: runnerPid)
        }

        let port: UInt16
        if launch.platform == .android {
            let wait = await Self.waitForUIAutomator2Port(launch, child: child)
            if let status = wait.exitStatus {
                abandon()
                let text = (try? String(contentsOfFile: logPath, encoding: .utf8)) ?? ""
                throw Self.startupExitError(
                    serial: launch.device.udid, status: status, signal: child.terminatingSignal,
                    lastError: Self.lastErrorLine(in: text), logPath: logPath
                )
            }
            guard let found = wait.port else {
                abandon()
                throw GrantivaError.commandFailed("Timed out waiting for the UIAutomator2 session to start. Log: \(logPath)", 1)
            }
            port = found
        } else {
            // Poll the log file for WDA's port or a failed build.
            let startup = try await waitForWDAPort(logFile: logPath, timeout: 60)
            guard case .port(let found)? = startup else {
                abandon()
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
        // A `runner stop` (or a teardown) that came during the start removed
        // the starting file; the runner is on its way out, so do not bring it back.
        if Self.liveStopRequest(runnerPid: runnerPid, runnerStartTime: runnerStartTime) == nil {
            try Self.record(session: session)
        }

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
        // What a teardown's stop marker must name to count for this runner.
        let runnerStartTime = RunnerStopMarker.processStartTime(child.pid)
        // `kill -9` of this process must not leave the runner holding the device.
        let lifeline = child.bindLifetimeToParent(sessionDirectory: KeepAliveSessionStore.defaultDirectory)
        Self.recordKeepAliveOwner(launch, runnerPid: child.pid, detached: false)
        lease.recordRunner(pid: child.pid, keepAlive: true)

        let runnerPid = child.pid
        @Sendable func requestedStop() -> StopRequest? {
            Self.liveStopRequest(runnerPid: runnerPid, runnerStartTime: runnerStartTime)
        }
        let cleanup = Once {
            Self.removeSessionFile(of: runnerPid)
            KeepAliveSessionStore().removeSessionFiles(runnerPid: runnerPid)
            RunnerStopMarker().remove(runnerPid: runnerPid)
            lease.release()
        }
        Self.trackRunner(group: child.processGroup, platform: launch.platform)
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
        do {
            try Self.recordStarting(launch, runnerPid: runnerPid)
        } catch {
            cleanup.run()
            throw error
        }
        let port: UInt16
        if launch.platform == .android {
            // The port comes from the forward, not the output.
            output.endStartup()
            let wait = await Self.waitForUIAutomator2Port(launch, child: child)
            if let status = wait.exitStatus {
                // `runner stop` removed the session file, or a teardown
                // marked the runner, before stopping it.
                let requested = requestedStop()
                cleanup.run()
                if let requested {
                    let ending = try Self.foregroundEnding(status: status, pid: runnerPid, stop: requested)
                    options.note(ending)
                    return
                }
                throw Self.startupExitError(
                    serial: launch.device.udid, status: status, signal: child.terminatingSignal,
                    lastError: Self.lastErrorLine(in: output.recentText), logPath: nil
                )
            }
            guard let found = wait.port else {
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
                // `runner stop` removed the session file, or a teardown
                // marked the runner, before stopping it.
                let requested = requestedStop()
                child.terminateGroup(gracePeriod: 1)
                cleanup.run()
                if let requested {
                    let ending = try Self.foregroundEnding(status: child.wait(), pid: runnerPid, stop: requested)
                    options.note(ending)
                    return
                }
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
        // A `runner stop` (or a teardown) that came during the start removed
        // the starting file; the runner is on its way out, so do not bring it back.
        if requestedStop() == nil {
            do {
                try Self.record(session: session)
            } catch {
                cleanup.run()
                throw error
            }
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

        let stopRequested = StopBox()
        let status = await Self.holdForeground(
            waitForExit: {
                let status = await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async { continuation.resume(returning: child.wait()) }
                }
                // Read before the cleanup removes the session file and marker.
                stopRequested.value = requestedStop()
                return status
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
        let ending = try Self.foregroundEnding(status: status, pid: child.pid, stop: stopRequested.value)
        options.note(ending)
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

    /// Without a stop request, only a runner that exited 0 ended the session
    /// in order. `runner stop` and teardown remove `.grantiva/session.json`
    /// before they signal, so their stops are told apart by that, not by the
    /// status; a runner killed by a signal nobody asked for is a failure (L36).
    static func isOrderlyRunnerExit(_ status: Int32) -> Bool {
        status == 0
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

    /// The port and app the stopped session recorded, so a stop document
    /// carries `runner start --json`'s keys (L13); nil when not recorded.
    struct SessionDetails: Equatable {
        var port: UInt16?
        var appID: String?

        init(port: UInt16? = nil, appID: String? = nil) {
            self.port = port.flatMap { $0 > 0 ? $0 : nil }
            self.appID = appID.flatMap { $0.isEmpty ? nil : $0 }
        }

        init(_ session: RunnerSessionInfo) {
            self.init(port: session.isReady ? session.wdaPort : nil, appID: session.bundleId)
        }

        init(_ session: KeepAliveSession) {
            self.init(port: UInt16(exactly: session.port), appID: session.appId)
        }
    }

    enum Result: Equatable {
        case notRunning
        /// The `runner start` session's runner was stopped; `killed` when it
        /// took SIGKILL. `reaped`: device helpers it left running, ended here.
        case stopped(pid: Int32, udid: String, killed: Bool, reaped: [ReapedProcess] = [], details: SessionDetails = .init())
        /// The `runner start` session's runner had already exited; its
        /// session was cleaned up.
        case exited(pid: Int32, udid: String, reaped: [ReapedProcess] = [], details: SessionDetails = .init())
        /// Every keep-alive session started from this directory, with each
        /// one's details by runner pid.
        case keepAlive([RunnerSessionStopper.Outcome], details: [Int32: SessionDetails] = [:])
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
            var details: [Int32: SessionDetails] = [:]
            for session in sessions {
                outcomes.append(try await dependencies.stopKeepAlive(session))
                details[session.pid] = SessionDetails(session)
            }
            return .keepAlive(outcomes, details: details)
        }

        let details = SessionDetails(session)
        var outcome: Result?
        var sessionRemoved = false
        if dependencies.isAlive(session) {
            let snapshot = try await dependencies.processSnapshot()
            if session.ownsRunnerProcess(in: snapshot) {
                // Before the signal: a foreground `runner start` holding this
                // session reads a missing file as "the stop was asked for"
                // and ends in order whatever status the runner exits with (L36).
                dependencies.removeSession()
                sessionRemoved = true
                // Watch what the runner started while its group stops: on iOS
                // an interrupted xcodebuild starts `simctl diagnose` in a group
                // of its own, which outlives the group (L04).
                let (termination, reaped) = await dependencies.helperReaper.stopping(
                    runnerPid: session.pid, udid: session.udid
                ) { dependencies.terminateGroup(session.pid) }
                outcome = .stopped(pid: session.pid, udid: session.udid, killed: termination == .killed, reaped: reaped, details: details)
            }
        }
        if outcome == nil {
            let reaped = await dependencies.helperReaper.sweep(exitedRunnerPid: session.pid, udid: session.udid)
            outcome = .exited(pid: session.pid, udid: session.udid, reaped: reaped, details: details)
        }

        // A runner that took SIGKILL never removes its own session file.
        dependencies.removeRunnerSessionFiles(session.pid)
        // The runner's own teardown clears its forwards and the UIA2 server
        // when it exits cleanly; after a kill they may still be there.
        if DeviceID.isAndroidSerial(session.udid) {
            await dependencies.cleanupOrphans(session.udid)
        }

        if !sessionRemoved { dependencies.removeSession() }
        dependencies.removeKeepAliveOwner(session.pid)
        // The session held the simulator lease by hand-off; free it now.
        dependencies.releaseLease(session.udid)
        return outcome ?? .exited(pid: session.pid, udid: session.udid, details: details)
    }

    static func render(_ result: Result) -> String {
        switch result {
        case .notRunning:
            return "No active session found."
        case .stopped(let pid, let udid, let killed, let reaped, _):
            let line = killed
                ? "Runner stopped (pid \(pid); it ignored SIGINT and SIGTERM and was killed)"
                : "Runner stopped (pid \(pid))"
            return ([line] + reapedLines(reaped, udid: udid)).joined(separator: "\n")
        case .exited(let pid, let udid, let reaped, _):
            return (["No running runner (pid \(pid) had exited); cleaned up its session."] + reapedLines(reaped, udid: udid))
                .joined(separator: "\n")
        case .keepAlive(let outcomes, _):
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

    /// Every `stopped` document (single, `alreadyExited`, each `sessions[]`
    /// entry) carries `runner start --json`'s keys, `port` and the app ID
    /// `null` when the session did not record them, plus the stop-only
    /// `runnerPid`, `killed` (false unless SIGKILL was needed) and `reaped`
    /// (L13).
    static func document(_ result: Result) -> RunnerLifecycleDocument {
        func platform(_ udid: String) -> Platform { DeviceID.isAndroidSerial(udid) ? .android : .ios }
        func stopped(pid: Int32, runnerPid: Int32, udid: String, killed: Bool, reaped: [ReapedProcess], details: SessionDetails?) -> RunnerLifecycleDocument {
            var document = RunnerLifecycleDocument(
                status: "stopped", pid: pid, port: details?.port, appID: details?.appID, deviceID: udid, platform: platform(udid)
            )
            document.runnerPid = runnerPid
            document.killed = killed
            document.reaped = reaped
            document.nullWhenUnrecorded = true
            return document
        }
        switch result {
        case .notRunning:
            return RunnerLifecycleDocument(status: "not_running")
        case .stopped(let pid, let udid, let killed, let reaped, let details):
            return stopped(pid: pid, runnerPid: pid, udid: udid, killed: killed, reaped: reaped, details: details)
        case .exited(let pid, let udid, let reaped, let details):
            var document = stopped(pid: pid, runnerPid: pid, udid: udid, killed: false, reaped: reaped, details: details)
            document.alreadyExited = true
            return document
        case .keepAlive(let outcomes, let details):
            let documents = outcomes.map { outcome -> RunnerLifecycleDocument in
                switch outcome {
                case .released(let grantivaPid, let runnerPid, let udid, let reaped):
                    return stopped(pid: grantivaPid, runnerPid: runnerPid, udid: udid, killed: false, reaped: reaped, details: details[runnerPid])
                case .terminated(let runnerPid, let udid, let killed, let reaped):
                    return stopped(pid: runnerPid, runnerPid: runnerPid, udid: udid, killed: killed, reaped: reaped, details: details[runnerPid])
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
        if let runnerSession {
            guard runnerSession.isReady else {
                throw RunnerSessionInfo.startingError(
                    platform: runnerSession.platform ?? (DeviceID.isAndroidSerial(runnerSession.udid) ? .android : .ios)
                )
            }
            return Target(udid: runnerSession.udid, port: runnerSession.wdaPort)
        }
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
