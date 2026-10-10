import Foundation

public struct IOSPlatform: DevicePlatform {
    public let platform: Platform = .ios
    private let simulators: SimulatorManager
    private let xcodebuild: XcodeBuildRunner
    private let execute: @Sendable (String) async throws -> String

    public init(
        simulators: SimulatorManager = .live,
        xcodebuild: XcodeBuildRunner = XcodeBuildRunner(),
        execute: @escaping @Sendable (String) async throws -> String = { try await shell($0) }
    ) {
        self.simulators = simulators
        self.xcodebuild = xcodebuild
        self.execute = execute
    }

    public static func destination(for udid: String) -> String {
        "platform=iOS Simulator,id=\(udid)"
    }

    public func bootDevice(named nameOrID: String) async throws -> BootedDevice {
        let device = try await simulators.boot(nameOrUDID: nameOrID)
        return BootedDevice(udid: device.udid, name: device.name)
    }

    public func displayGeometry(deviceID: String) async throws -> DeviceGeometry {
        let geometry = try await simulators.displayGeometry(udid: deviceID)
        return DeviceGeometry(pixelWidth: geometry.pixels[0], pixelHeight: geometry.pixels[1], scale: geometry.scale)
    }

    public func build(_ request: PlatformBuildRequest) async throws -> BuildResult {
        guard let scheme = request.resolved.scheme else {
            throw GrantivaError.invalidArgument(
                "No scheme specified. Pass --scheme, set it in grantiva.yml, or use --app-file to provide a pre-built binary."
            )
        }
        return try await xcodebuild.build(
            scheme: scheme,
            workspace: request.resolved.workspace,
            project: request.resolved.project,
            destination: Self.destination(for: request.deviceID),
            buildSettings: request.extraBuildSettings
        )
    }

    public func install(appID: String, productPath: String, deviceID: String) async throws {
        try await xcodebuild.install(bundleId: appID, productPath: productPath, udid: deviceID)
    }

    public func launch(appID: String, deviceID: String) async throws {
        try await xcodebuild.launch(bundleId: appID, udid: deviceID)
    }

    public func terminate(appID: String, deviceID: String) async throws {
        try await xcodebuild.terminate(bundleId: appID, udid: deviceID)
    }

    public func uninstall(appID: String, deviceID: String) async throws {
        try await xcodebuild.uninstall(bundleId: appID, udid: deviceID)
    }

    public func prepareForCapture(deviceID: String) async {
        _ = try? await execute(
            "xcrun simctl status_bar \(deviceID) override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4"
        )
    }

    public func restoreAfterCapture(deviceID: String) async {
        _ = try? await execute("xcrun simctl status_bar \(deviceID) clear")
    }

    public func runnerGlobalArguments(deviceID: String, appFile: String?) -> [String] {
        var args = ["--platform", "ios", "--device", deviceID, "--no-ansi", "--no-app-install"]
        if let appFile {
            args += ["--app-file", appFile]
        }
        return args
    }

    public func runnerTestArguments() -> [String] {
        ["--wait-for-idle-timeout", "0"]
    }

    public func resolveBinary(_ path: String) async throws -> ResolvedBinary {
        let resolved = try AppBinaryResolver.resolve(path)
        return ResolvedBinary(appPath: resolved.appPath, tempDir: resolved.tempDir, appID: AppBinaryResolver.bundleId(from: resolved.appPath))
    }

    public func defaultDevice() async throws -> BootedDevice {
        let device = try await simulators.soleBootedDevice()
        return BootedDevice(udid: device.udid, name: device.name)
    }

    public func screenshot(deviceID: String, to path: String) async throws {
        _ = try await execute("xcrun simctl io \(shellQuoted(deviceID)) screenshot \(shellQuoted(path))")
    }

    public func logStream(deviceID: String, appID: String?, filter: String?, level: String?) async throws -> LogStreamCommand {
        var args = ["simctl", "spawn", deviceID, "log", "stream", "--style", "compact"]
        var predicate = filter
        if predicate == nil, let appID {
            let executable = await installedExecutable(appID: appID, deviceID: deviceID)
            predicate = defaultLogPredicate(forBundleID: appID, executable: executable)
        }
        if let predicate, !predicate.isEmpty {
            args += ["--predicate", predicate]
        }
        if let level, !level.isEmpty {
            args += ["--level", level]
        }
        return LogStreamCommand(executable: "/usr/bin/xcrun", arguments: args)
    }

    /// The installed app's `CFBundleExecutable`, or nil when the app is not
    /// installed on the simulator or its Info.plist cannot be read.
    func installedExecutable(appID: String, deviceID: String) async -> String? {
        guard let container = try? await execute(
            "xcrun simctl get_app_container \(shellQuoted(deviceID)) \(shellQuoted(appID)) app"
        ).trimmingCharacters(in: .whitespacesAndNewlines), !container.isEmpty else { return nil }
        let executable = try? await execute(
            "/usr/bin/plutil -extract CFBundleExecutable raw -o - \(shellQuoted(container + "/Info.plist"))"
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return executable?.isEmpty == false ? executable : nil
    }

    /// Points xcodebuild at grantiva's xcconfig so the runner's WebDriverAgent
    /// build survives Xcode 27 (see `WDABuildConfig`), and gives the runner a
    /// per-simulator home so concurrent runs on different simulators each
    /// launch WDA from their own xctestrun, port, and DerivedData (see
    /// `WDADeviceHome`). Each piece falls back to the stock behavior when its
    /// files cannot be written.
    public func runnerEnvironment(runnerHome: String, deviceID: String) -> [String: String] {
        var environment: [String: String] = [:]
        if let xcconfig = WDABuildConfig.install(in: runnerHome) {
            environment["XCODE_XCCONFIG_FILE"] = xcconfig
        }
        if let deviceHome = WDADeviceHome.prepare(runnerHome: runnerHome, deviceID: deviceID) {
            environment["MAESTRO_RUNNER_HOME"] = deviceHome
        }
        return environment
    }

    /// Promotes a WebDriverAgent build the runner produced in this
    /// simulator's home into the shared cache (see `WDADeviceHome.promote`).
    /// A build is complete once its xctestrun exists, so this runs whatever
    /// the flows' verdict was: a failing first flow must not throw away a
    /// fresh multi-minute WDA build.
    public func runnerFinished(runnerHome: String, deviceID: String) {
        WDADeviceHome.promote(runnerHome: runnerHome, deviceID: deviceID)
    }

    public func cleanupOrphans(deviceID: String) async {}

    public func attachDriver(deviceID: String, port: UInt16?) async throws -> DriverAttachment {
        guard let port, port > 0 else {
            throw GrantivaError.invalidArgument("A WebDriverAgent port is required to attach to an iOS session.")
        }
        return DriverAttachment(client: .wda(port: port), port: Int(port), detach: {})
    }

    /// `simctl io recordVideo`, stopped with SIGINT so simctl finalizes the file.
    public func recordVideo(deviceID: String, to path: String, seconds: Double) async throws {
        let outputURL = URL(fileURLWithPath: path)
        let recorder = Process()
        recorder.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        recorder.arguments = ["simctl", "io", deviceID, "recordVideo", "--codec=h264", path]
        let stderrURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-record-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: stderrURL) }
        let stderr = try FileHandle(forWritingTo: stderrURL)
        recorder.standardError = stderr
        do {
            try recorder.run()
            try await RecorderLifecycle.withCleanup(for: recorder) {
                try await RecorderLifecycle.waitForStart(of: outputURL)
                try await Task.sleep(for: .seconds(seconds))
            }
            try stderr.close()
        } catch {
            try? stderr.close()
            throw error
        }
        guard FileManager.default.fileExists(atPath: path) else {
            let message = (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
            throw GrantivaError.commandFailed("Grantiva recording produced no video: \(message)", recorder.terminationStatus)
        }
    }
}
