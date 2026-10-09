import Foundation

public struct AndroidPlatform: DevicePlatform {
    public struct Options: Sendable, Equatable {
        public var allowDeviceSettings: Bool
        public var headless: Bool

        public init(allowDeviceSettings: Bool = false, headless: Bool = false) {
            self.allowDeviceSettings = allowDeviceSettings
            self.headless = headless
        }
    }

    public let platform: Platform = .android
    private let sdk: AndroidSDK
    public let adb: ADB
    private let gradle: GradleBuildRunner
    public let emulators: EmulatorManager
    private let captureSettings: AndroidCaptureSettings
    private let execute: @Sendable (String) async throws -> String
    private let options: Options
    private let environment: [String: String]

    public init(
        sdk: AndroidSDK,
        adb: ADB,
        gradle: GradleBuildRunner,
        emulators: EmulatorManager,
        captureSettings: AndroidCaptureSettings,
        execute: @escaping @Sendable (String) async throws -> String = { try await GrantivaCore.shell($0) },
        options: Options = Options(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.sdk = sdk
        self.adb = adb
        self.gradle = gradle
        self.emulators = emulators
        self.captureSettings = captureSettings
        self.execute = execute
        self.options = options
        self.environment = environment
    }

    /// The real thing: throws when no SDK is installed.
    public static func live(options: Options = Options()) throws -> AndroidPlatform {
        let sdk = try AndroidSDK.require()
        let adb = ADB(path: sdk.adb)
        return AndroidPlatform(
            sdk: sdk, adb: adb, gradle: GradleBuildRunner(),
            emulators: EmulatorManager(sdk: sdk, adb: adb, headless: options.headless),
            captureSettings: AndroidCaptureSettings(adb: adb),
            options: options
        )
    }

    static func isPhysical(_ serial: String) -> Bool { !serial.hasPrefix("emulator-") }

    // MARK: Devices

    /// An attached serial is used as is; otherwise the name must be an AVD,
    /// which `selectDevice` uses or boots. Anything else is an error that
    /// names both lists, since a serial and an AVD name look alike.
    public func bootDevice(named nameOrID: String) async throws -> BootedDevice {
        let devices = try await adb.devices()
        if let match = devices.first(where: { $0.serial == nameOrID }) {
            guard match.isUsable else {
                throw GrantivaError.invalidArgument(
                    "\(nameOrID) is \(match.state). Reconnect it, accept the USB debugging prompt, or pick another device."
                )
            }
            let name = match.isEmulator ? ((try? await adb.avdName(serial: match.serial)) ?? match.serial) : match.serial
            return BootedDevice(udid: match.serial, name: name)
        }
        if nameOrID.isEmpty {
            return try await emulators.selectDevice(configured: nil)
        }
        let avds = try await emulators.listAVDs()
        guard avds.contains(nameOrID) else {
            throw GrantivaError.invalidArgument(
                "No attached device has the serial \"\(nameOrID)\" (see `adb devices`) and no AVD has that name "
                    + "(see `emulator -list-avds`). AVDs: \(avds.isEmpty ? "(none)" : avds.joined(separator: ", "))."
            )
        }
        return try await emulators.selectDevice(configured: nameOrID)
    }

    public func defaultDevice() async throws -> BootedDevice {
        try await emulators.selectDevice(configured: nil)
    }

    public func displayGeometry(deviceID: String) async throws -> DeviceGeometry {
        let size = try await adb.displaySize(serial: deviceID)
        let density = try await adb.density(serial: deviceID)
        return DeviceGeometry(pixelWidth: size.width, pixelHeight: size.height, scale: Double(density) / 160)
    }

    // MARK: Build and install

    public func build(_ request: PlatformBuildRequest) async throws -> BuildResult {
        let android = request.resolved.android ?? AndroidProject()
        let abi = try await adb.getprop(serial: request.deviceID, "ro.product.cpu.abi")
        let javaHome = await AndroidSDK.javaHome(environment: environment, execute: execute)
        return try await gradle.build(
            projectRoot: FileManager.default.currentDirectoryPath,
            module: android.module, variant: android.variant,
            extraArgs: request.extraBuildSettings, javaHome: javaHome, deviceABI: abi
        )
    }

    public func install(appID: String, productPath: String, deviceID: String) async throws {
        try await adb.install(serial: deviceID, apk: productPath, applicationId: appID)
    }

    public func launch(appID: String, deviceID: String) async throws {
        try await adb.launch(serial: deviceID, applicationId: appID)
    }

    public func terminate(appID: String, deviceID: String) async throws {
        try await adb.forceStop(serial: deviceID, applicationId: appID)
    }

    public func uninstall(appID: String, deviceID: String) async throws {
        try await adb.uninstall(serial: deviceID, applicationId: appID)
    }

    public func resolveBinary(_ path: String) async throws -> ResolvedBinary {
        let absolute = (path as NSString).standardizingPath
        guard absolute.lowercased().hasSuffix(".apk") else {
            throw GrantivaError.invalidBinary("Expected an .apk file for Android, got: \"\(URL(fileURLWithPath: absolute).lastPathComponent)\"")
        }
        guard FileManager.default.fileExists(atPath: absolute) else {
            throw GrantivaError.appNotFound(absolute)
        }
        let javaHome = await AndroidSDK.javaHome(environment: environment, execute: execute)
        let prefix = javaHome.map { "JAVA_HOME=\(shellQuoted($0)) " } ?? ""
        let id = try? await execute("\(prefix)\(shellQuoted(sdk.apkanalyzer)) manifest application-id \(shellQuoted(absolute))")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return ResolvedBinary(appPath: absolute, tempDir: nil, appID: (id?.isEmpty ?? true) ? nil : id)
    }

    // MARK: Capture state

    private func settingsAllowed(_ serial: String) -> Bool {
        if Self.isPhysical(serial), !options.allowDeviceSettings {
            GrantivaLog.logger.info(
                "skipping demo mode and animation settings on physical device \(serial); pass --allow-device-settings to apply them"
            )
            return false
        }
        return true
    }

    public func prepareForCapture(deviceID: String) async {
        guard settingsAllowed(deviceID) else { return }
        _ = await captureSettings.restoreIfCrashed(serial: deviceID)
        do {
            try await captureSettings.prepare(serial: deviceID)
        } catch {
            GrantivaLog.logger.warning("could not apply capture settings on \(deviceID): \(error)")
        }
    }

    public func restoreAfterCapture(deviceID: String) async {
        guard Self.isPhysical(deviceID) == false || options.allowDeviceSettings else { return }
        await captureSettings.restore(serial: deviceID)
    }

    public func screenshot(deviceID: String, to path: String) async throws {
        try await adb.screenshot(serial: deviceID, to: path)
    }

    // MARK: Logs

    public func logStream(deviceID: String, appID: String?, filter: String?, level: String?) async throws -> LogStreamCommand {
        _ = try? await execute(adb.line(deviceID, "logcat -c"))
        guard let appID else {
            throw GrantivaError.invalidArgument("--logs on Android needs the application ID to filter logcat; pass --application-id.")
        }
        guard let uid = try await adb.packageUID(serial: deviceID, applicationId: appID) else {
            throw GrantivaError.invalidArgument("\(appID) is not installed on \(deviceID), so its logs cannot be streamed.")
        }
        var args = ["-s", deviceID, "logcat", "--uid=\(uid)", "-v", "time"]
        if let filter, !filter.isEmpty {
            if let level, let priority = level.first {
                args += ["-s", "\(filter):\(priority.uppercased())"]
            } else {
                args += ["-s", filter]
            }
        } else if let level, let priority = level.first {
            args += ["-s", "*:\(priority.uppercased())"]
        }
        return LogStreamCommand(executable: adb.path, arguments: args)
    }

    // MARK: Runner

    public func runnerGlobalArguments(deviceID: String, appFile: String?) -> [String] {
        var args = ["--platform", "android", "--device", deviceID, "--no-ansi", "--no-app-install"]
        if let appFile { args += ["--app-file", appFile] }
        return args
    }

    public func runnerTestArguments() -> [String] { [] }

    public func runnerEnvironment(runnerHome: String) -> [String: String] {
        let path = environment["PATH"].map { ":" + $0 } ?? ""
        return [
            "MAESTRO_RUNNER_HOME": runnerHome,
            "ANDROID_HOME": sdk.root,
            "PATH": "\(sdk.root)/platform-tools:\(sdk.root)/emulator\(path)",
        ]
    }

    public func cleanupOrphans(deviceID: String) async {
        for package in ADB.uiAutomator2Packages {
            _ = try? await adb.forceStop(serial: deviceID, applicationId: package)
        }
        _ = try? await adb.removeForwards(serial: deviceID)
    }

    // MARK: Driver and recording

    public static let maximumRecordingSeconds = 180
    static let remoteRecordingPath = "/sdcard/grantiva-record.mp4"

    public func attachDriver(deviceID: String, port: UInt16?) async throws -> DriverAttachment {
        try await attachDriver(deviceID: deviceID, port: port, transport: .live)
    }

    /// `transport` is the seam for tests; the protocol entry point uses the live one.
    public func attachDriver(deviceID: String, port: UInt16?, transport: UIAutomator2Transport) async throws -> DriverAttachment {
        let endpoint: UIAutomator2Endpoint
        let forwarded: Bool
        if let port, port > 0,
           let recorded = try? await UIAutomator2.endpoint(localPort: Int(port), serial: deviceID, transport: transport) {
            endpoint = recorded
            forwarded = false
        } else {
            // No recorded port, or its forward is gone (an adb restart drops
            // every forward): make a fresh one.
            endpoint = try await UIAutomator2.attach(adb: adb, serial: deviceID, transport: transport)
            forwarded = true
        }
        let geometry: DeviceGeometry
        do {
            geometry = try await displayGeometry(deviceID: deviceID)
        } catch {
            if forwarded { _ = try? await adb.removeForward(serial: deviceID, localPort: endpoint.localPort) }
            throw error
        }
        let adb = self.adb
        return DriverAttachment(
            client: .uiAutomator2(endpoint: endpoint, scale: geometry.scale, transport: transport),
            port: endpoint.localPort,
            detach: { if forwarded { _ = try? await adb.removeForward(serial: deviceID, localPort: endpoint.localPort) } }
        )
    }

    /// `screenrecord` caps every file at 180 s; longer requests are refused
    /// up front rather than silently truncated.
    public func recordVideo(deviceID: String, to path: String, seconds: Double) async throws {
        guard seconds.isFinite, seconds <= Double(Self.maximumRecordingSeconds) else {
            throw GrantivaError.invalidArgument(
                "Android recordings are capped at \(Self.maximumRecordingSeconds) seconds per file (screenrecord --time-limit); --duration \(seconds) is too long."
            )
        }
        let whole = Int(seconds.rounded(.up))
        try await adb.screenrecord(serial: deviceID, remotePath: Self.remoteRecordingPath, seconds: max(whole, 1))
        try await adb.pull(serial: deviceID, remotePath: Self.remoteRecordingPath, to: path)
        _ = try? await adb.removeFile(serial: deviceID, remotePath: Self.remoteRecordingPath)
    }
}
