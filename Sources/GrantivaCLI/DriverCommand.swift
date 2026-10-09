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
        abstract: "Extract or update the embedded runner binary."
    )

    @OptionGroup var options: GlobalOptions

    func run() async throws {
        options.note("Extracting runner...")

        let manager = RunnerManager.live
        try await manager.ensureAvailable()

        if options.json {
            Output.line(try JSONOutput.string([
                "status": "installed",
                "path": manager.runnerPath(),
                "version": RunnerManager.runnerVersion,
            ]))
        } else {
            Output.line("Runner installed at \(manager.runnerPath())")
            Output.line("Version: \(RunnerManager.runnerVersion)")
        }
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
        abstract: "Start the runner with WDA and keep it alive for interactive use."
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

    func run() async throws {
        // Check for existing session
        if let existing = try? RunnerSessionInfo.load(), existing.isAlive,
           let snapshot = try? await SimulatorReaper.processSnapshot(),
           existing.ownsRunnerProcess(in: snapshot) {
            if options.json {
                Output.line(try JSONOutput.string([
                    "status": "already_running",
                    "port": "\(existing.wdaPort)",
                    "pid": "\(existing.pid)",
                    "bundle_id": existing.bundleId,
                ]))
            } else {
                Output.line("Runner already running (pid \(existing.pid), WDA port \(existing.wdaPort))")
                Output.line("Use 'grantiva runner stop' to stop it first.")
            }
            return
        }

        let (platform, config) = try platformOptions.loadConfig()
        if platform == .ios {
            if emulator != nil { throw GrantivaError.invalidArgument("--emulator is an Android option, but this is an iOS project.") }
            if device != nil { throw GrantivaError.invalidArgument("--device is an Android option, but this is an iOS project.") }
            if headless { throw GrantivaError.invalidArgument("--headless is an Android option, but this is an iOS project.") }
        }
        if platform == .android, simulator != nil {
            throw GrantivaError.invalidArgument("--simulator is an iOS option, but this is an Android project.")
        }
        if device != nil, emulator != nil {
            throw GrantivaError.invalidArgument("--device and --emulator are mutually exclusive; pass one.")
        }
        if let device { _ = try DeviceID.validate(device, flag: "--device") }
        let resolvedAppID = try Self.appID(platform: platform, bundleId: bundleId, applicationId: applicationId, config: config)
        let targetName = Self.target(platform: platform, simulator: simulator, emulator: emulator, device: device, config: config)

        let platformDevice = try devicePlatform.make(platform, android: .init(headless: headless))
        let booted = try await platformDevice.bootDevice(named: targetName)
        // Held until the runner is up, then handed to the runner process: this
        // command returns immediately, but the session it started still owns
        // the device until `runner stop`.
        let simulatorLease = try SimulatorLease.acquire(udid: booted.udid)
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
        let environment = platformDevice.runnerEnvironment(runnerHome: runnerDir)
        let launch = Launch(
            runnerBin: runnerBin, runnerDir: runnerDir, runnerArgs: runnerArgs,
            environment: environment.isEmpty ? nil : environment,
            appID: resolvedAppID, device: booted, platform: platform, platformDevice: platformDevice
        )
        let runnerPid: Int32
        if detach {
            runnerPid = try await startDetached(launch)
        } else {
            runnerPid = try await startForeground(launch)
        }
        simulatorLease.handOff(to: runnerPid)
        handedOff = true
    }

    static func appID(platform: Platform, bundleId: String?, applicationId: String?, config: GrantivaConfig?) throws -> String {
        switch platform {
        case .ios:
            if applicationId != nil { throw GrantivaError.invalidArgument("--application-id is an Android option, but this is an iOS project.") }
            guard let id = bundleId ?? config?.bundleId else {
                throw GrantivaError.invalidArgument("No bundle ID. Pass --bundle-id or set bundle_id in grantiva.yml.")
            }
            return id
        case .android:
            if bundleId != nil { throw GrantivaError.invalidArgument("--bundle-id is an iOS option, but this is an Android project.") }
            guard let id = applicationId ?? config?.android?.applicationId else {
                throw GrantivaError.invalidArgument("No application ID. Pass --application-id or set application_id in grantiva-android.yml.")
            }
            return id
        }
    }

    static func target(platform: Platform, simulator: String?, emulator: String?, device: String?, config: GrantivaConfig?) -> String {
        switch platform {
        case .ios: return simulator ?? config?.simulator ?? "iPhone 16"
        case .android: return device ?? emulator ?? config?.android?.emulator ?? ""
        }
    }

    /// Global flags, `test`, the platform's test flags, then the flow. On iOS
    /// this is byte-for-byte the argv `runner start` has always used.
    ///
    /// Android also gets `--keep-alive` before the flow. The keep-alive flow's
    /// `waitForAnimationToEnd` holds the iOS runner for an hour, but on
    /// Android it returns as soon as the screen settles, so the runner would
    /// finish the flow and exit seconds after `runner start` reports success.
    /// The runner's `--keep-alive` holds the session until SIGINT, which is
    /// what `runner stop` sends.
    static func runnerArguments(platform: any DevicePlatform, deviceID: String, flowPath: String) -> [String] {
        let keepAlive = platform.platform == .android ? ["--keep-alive"] : []
        return platform.runnerGlobalArguments(deviceID: deviceID, appFile: nil) + ["test"] + platform.runnerTestArguments()
            + keepAlive + [flowPath]
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

        let port: UInt16?
        if launch.platform == .android {
            port = await Self.waitForUIAutomator2Port(launch)
        } else {
            // Poll the log file for WDA port
            port = try await waitForWDAPort(logFile: logPath, timeout: 60)
        }

        guard let port else {
            child.terminateGroup(gracePeriod: 1)
            throw GrantivaError.commandFailed(
                "Timed out waiting for \(launch.platform == .android ? "the UIAutomator2 session" : "WDA") to start. Log: \(logPath)", 1
            )
        }

        let session = RunnerSessionInfo(
            pid: runnerPid,
            wdaPort: port,
            bundleId: launch.appID,
            udid: launch.device.udid,
            startedAt: Date()
        )
        try Self.record(session: session)

        if options.json {
            Output.line(try JSONOutput.string([
                "status": "started",
                "port": "\(port)",
                "pid": "\(runnerPid)",
                "bundle_id": launch.appID,
                "udid": launch.device.udid,
                "log": logPath,
            ]))
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

    private func startForeground(_ launch: Launch) async throws -> Int32 {
        let stdoutPipe = Pipe()
        let child = try ChildProcess.spawn(
            executable: launch.runnerBin,
            arguments: launch.runnerArgs,
            workingDirectory: launch.runnerDir,
            environment: launch.environment,
            stdout: stdoutPipe.fileHandleForWriting.fileDescriptor,
            stderr: FileHandle.standardError.fileDescriptor
        )
        try? stdoutPipe.fileHandleForWriting.close()

        let output = Self.outputStream(from: stdoutPipe.fileHandleForReading)
        let port: UInt16
        if launch.platform == .android {
            // The port comes from the forward, not the output; keep draining
            // the pipe so the runner never blocks on a full one.
            Task { for await _ in output {} }
            guard let found = await Self.waitForUIAutomator2Port(launch) else {
                child.terminateGroup(gracePeriod: 1)
                RunnerSessionInfo.remove()
                throw GrantivaError.commandFailed("Timed out waiting for the UIAutomator2 session to start", 1)
            }
            port = found
        } else {
            guard let found = await Self.waitForForegroundWDAPort(
                chunks: output,
                timeout: {
                    try? await Task.sleep(for: .seconds(60))
                },
                probe: Self.probeKnownWDAPorts
            ) else {
                child.terminateGroup(gracePeriod: 1)
                RunnerSessionInfo.remove()
                throw GrantivaError.commandFailed("Timed out waiting for WDA to start", 1)
            }
            port = found
        }

        let session = RunnerSessionInfo(
            pid: child.pid,
            wdaPort: port,
            bundleId: launch.appID,
            udid: launch.device.udid,
            startedAt: Date()
        )
        try Self.record(session: session)

        if options.json {
            Output.line(try JSONOutput.string([
                "status": "started",
                "port": "\(port)",
                "pid": "\(child.pid)",
                "bundle_id": launch.appID,
                "udid": launch.device.udid,
            ]))
        } else {
            Output.line("Runner started")
            Output.line("  \(Self.portLabel(launch.platform)): \(port)")
            Output.line("  PID:      \(child.pid)")
            Output.line("  Session:  \(RunnerSessionInfo.path)")
            Output.line("")
            Output.line("Use 'grantiva runner dump-hierarchy' to inspect the view hierarchy.")
            Output.line("Use 'grantiva runner stop' to stop the session.")
        }
        return child.pid
    }

    // MARK: - Helpers

    /// Convert process output into a cancellable stream. `availableData` blocks
    /// when called directly, which can otherwise prevent the startup timeout
    /// from ever firing for a silent or wedged runner.
    static func outputStream(from handle: FileHandle) -> AsyncStream<Data> {
        AsyncStream { continuation in
            handle.readabilityHandler = { readableHandle in
                let data = readableHandle.availableData
                if data.isEmpty {
                    readableHandle.readabilityHandler = nil
                    continuation.finish()
                } else {
                    continuation.yield(data)
                }
            }
            continuation.onTermination = { _ in
                handle.readabilityHandler = nil
                try? handle.close()
            }
        }
    }

    static func waitForForegroundWDAPort(
        chunks: AsyncStream<Data>,
        timeout: @escaping @Sendable () async -> Void,
        probe: @escaping @Sendable () async -> UInt16?
    ) async -> UInt16? {
        await withTaskGroup(of: UInt16?.self) { group in
            group.addTask {
                var accumulated = Data()
                for await chunk in chunks {
                    accumulated.append(chunk)
                    let text = String(decoding: accumulated, as: UTF8.self)
                    if let port = extractWDAPort(from: text) {
                        return port
                    }
                    if text.contains("launchApp"), text.contains("✓"),
                       let port = await probe() {
                        return port
                    }
                }
                return nil
            }
            group.addTask {
                await timeout()
                return nil
            }

            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
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

    /// Poll a log file until a WDA port appears or the timeout elapses.
    private func waitForWDAPort(logFile: String, timeout: TimeInterval) async throws -> UInt16? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms
            guard let content = try? String(contentsOfFile: logFile, encoding: .utf8) else { continue }
            if let p = Self.extractWDAPort(from: content) { return p }
            if content.contains("launchApp") && content.contains("✓") {
                for candidate: UInt16 in [8430, 8100, 8200] {
                    let url = URL(string: "http://localhost:\(candidate)/status")!
                    if let (_, resp) = try? await URLSession.shared.data(from: url),
                       let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                        return candidate
                    }
                }
            }
        }
        return nil
    }

    /// Extract a WDA port number from a string of runner output.
    private static func extractWDAPort(from text: String) -> UInt16? {
        let patterns = ["port[: ]+([0-9]+)", "localhost:([0-9]+)", "WDA.*?([0-9]{4,5})"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text),
               let p = UInt16(text[range]), p > 1024 {
                return p
            }
        }
        return nil
    }

}

// MARK: - Stop

@available(macOS 15, *)
struct RunnerStopCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop the running runner session."
    )

    @OptionGroup var options: GlobalOptions

    func run() async throws {
        try await run(dependencies: .live)
    }

    func run(dependencies: RunnerStopDependencies) async throws {
        guard let session = try? dependencies.loadSession() else {
            if options.json {
                Output.line(try JSONOutput.string(["status": "not_running"]))
            } else {
                Output.line("No active session found.")
            }
            return
        }

        if dependencies.isAlive(session) {
            let snapshot = try await dependencies.processSnapshot()
            if session.ownsRunnerProcess(in: snapshot) {
                dependencies.terminateGroup(session.pid)
            }
        }

        // The runner's own teardown clears its forwards and the UIA2 server
        // when it exits cleanly; after a kill they may still be there.
        if DeviceID.isAndroidSerial(session.udid) {
            await dependencies.cleanupOrphans(session.udid)
        }

        dependencies.removeSession()
        // The session held the simulator lease by hand-off; free it now.
        dependencies.releaseLease(session.udid)

        if options.json {
            Output.line(try JSONOutput.string(["status": "stopped", "pid": "\(session.pid)"]))
        } else {
            Output.line("Runner stopped (pid \(session.pid))")
        }
    }
}

struct RunnerStopDependencies: Sendable {
    var loadSession: @Sendable () throws -> RunnerSessionInfo
    var isAlive: @Sendable (RunnerSessionInfo) -> Bool
    var processSnapshot: @Sendable () async throws -> String
    var terminateGroup: @Sendable (Int32) -> Void
    var removeSession: @Sendable () -> Void
    var releaseLease: @Sendable (String) -> Void
    var cleanupOrphans: @Sendable (String) async -> Void

    static let live = RunnerStopDependencies(
        loadSession: { try RunnerSessionInfo.load() },
        isAlive: { $0.isAlive },
        processSnapshot: { try await SimulatorReaper.processSnapshot() },
        terminateGroup: { ChildProcess.terminateGroup($0, gracePeriod: 1) },
        removeSession: { RunnerSessionInfo.remove() },
        releaseLease: { SimulatorLease.forceRelease(udid: $0) },
        cleanupOrphans: { serial in
            guard let platform = try? AndroidPlatform.live() else { return }
            await platform.cleanupOrphans(deviceID: serial)
        }
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

    @Option(name: .shortAndLong, help: "WDA port (auto-detected from active session if omitted)")
    var port: UInt16?

    @Option(name: .shortAndLong, help: "Output format: tree, json, or xml (default: tree)")
    var format: String = "tree"

    @Option(name: .long, help: "Simulator UDID or adb serial when falling back to a `grantiva run --keep-alive` session")
    var udid: String?

    var devicePlatform = InjectedDevicePlatform()

    func validate() throws {
        if let udid { _ = try DeviceID.validate(udid) }
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
        throw GrantivaError.invalidArgument(
            "No active runner session. Start one with 'grantiva runner start' or `grantiva run --keep-alive`, or pass --port."
        )
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

        switch format.lowercased() {
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
            throw GrantivaError.invalidArgument("Invalid format '\(format)'. Use: tree, json, or xml")
        }
    }

    private func render(client: DriverClient) async throws {
        switch format.lowercased() {
        case "xml":
            Output.line(try await client.hierarchyXML())
        case "json":
            let data = try JSONSerialization.data(withJSONObject: try await client.hierarchy(), options: [.prettyPrinted, .sortedKeys])
            Output.line(String(data: data, encoding: .utf8) ?? "{}")
        case "tree":
            printTree(element: try await client.hierarchy(), indent: 0)
        default:
            throw GrantivaError.invalidArgument("Invalid format '\(format)'. Use: tree, json, or xml")
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
