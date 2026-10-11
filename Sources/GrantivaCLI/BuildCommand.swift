import ArgumentParser
import Foundation
import GrantivaCore

struct BuildCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build and optionally install the app to a simulator or emulator.",
        subcommands: [BuildOnlyCommand.self, InstallCommand.self],
        defaultSubcommand: BuildOnlyCommand.self
    )
}

// MARK: - build

struct BuildOnlyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build the app for a simulator (xcodebuild) or emulator (Gradle)."
    )

    @OptionGroup var options: GlobalOptions
    @OptionGroup var platformOptions: PlatformOptions

    @Option(name: .long, help: "Write Xcode build products and intermediates to this DerivedData directory.")
    var derivedDataPath: String?

    /// The target flags with the boot flags hidden from help (L29).
    @OptionGroup var target: BuildTargetOptions

    /// Empty means "make one from the resolved platform"; tests inject a fake.
    var devicePlatform = InjectedDevicePlatform()

    func run() async throws {
        let (platform, config) = try platformOptions.loadConfig()
        try target.checkFlags(for: platform, derivedDataPath: derivedDataPath)
        let device = try devicePlatform.make(platform, android: target.androidOptions)

        let resolved = try await target.resolve(
            platform: platform, config: config, skipBuild: false, appID: nil, acceptsAppFile: false
        )

        if platform == .ios, resolved.scheme == nil {
            throw GrantivaError.invalidArgument(ResolvedProject.noSchemeMessage(acceptsAppFile: false))
        }

        // iOS builds for a simulator destination. Android only compiles: the
        // config's `emulator:` is irrelevant and nothing is booted; an
        // explicit --device only lends its ABI to the choice of split APK.
        let deviceID: String
        let deviceName: String?
        switch platform {
        case .ios:
            let booted = try await device.bootDevice(for: resolved)
            deviceID = booted.udid
            deviceName = booted.name
        case .android:
            let attached = if let serial = target.device { try await device.attachedDevice(serial: serial) } else { nil as BootedDevice? }
            deviceID = attached?.udid ?? ""
            deviceName = attached?.name
        }

        let buildTarget = resolved.scheme ?? GradleBuildRunner.taskName(
            module: resolved.android?.module ?? "app", variant: resolved.android?.variant ?? "debug"
        )
        options.note("[grantiva] Building \(buildTarget)\(deviceName.map { " for \($0)" } ?? "")...")

        let result = try await device.build(PlatformBuildRequest(
            config: config ?? GrantivaConfig(),
            resolved: resolved,
            deviceID: deviceID,
            extraBuildSettings: target.extraBuildSettings(
                platform: platform, derivedDataPath: derivedDataPath, resolved: resolved
            )
        ))

        if options.json {
            Output.line(try JSONOutput.string(result))
        } else {
            Output.line(TableFormatter().formatBuild(result))
        }

        if !result.success {
            throw ExitCode.failure
        }
    }
}

// MARK: - install

struct InstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Build and install the app on a simulator or emulator, then optionally launch it."
    )

    @OptionGroup var options: GlobalOptions
    @OptionGroup var buildOptions: BuildOptions
    @OptionGroup var platformOptions: PlatformOptions
    @OptionGroup var target: TargetOptions

    @Flag(name: .long, help: "Install the app without launching it.")
    var noLaunch: Bool = false

    /// Empty means "make one from the resolved platform"; tests inject a fake.
    var devicePlatform = InjectedDevicePlatform()

    func run() async throws {
        let (platform, config) = try platformOptions.loadConfig()
        try target.checkFlags(for: platform, derivedDataPath: buildOptions.derivedDataPath)
        let device = try devicePlatform.make(platform, android: target.androidOptions)

        let resolvedBinary: ResolvedBinary? = if let appFile = buildOptions.appFile { try await device.resolveBinary(appFile) } else { nil }
        defer { resolvedBinary?.cleanup() }

        let appBundleId = resolvedBinary?.appID

        let resolved = try await target.resolve(
            platform: platform, config: config, skipBuild: buildOptions.shouldSkipBuild, appID: appBundleId
        )

        let booted = try await device.bootDevice(for: resolved)

        var productPath: String?
        var builtAppID: String?

        if buildOptions.shouldSkipInstall {
            options.note("[grantiva] Skipping build and install (--no-build)")
        } else if let resolvedBinary {
            options.note("[grantiva] Using pre-built binary: \(URL(fileURLWithPath: resolvedBinary.appPath).lastPathComponent)")
            productPath = resolvedBinary.appPath
        } else {
            // A missing scheme is rejected by the platform's build with the
            // same message the command used to throw here.
            if let buildScheme = resolved.scheme {
                options.note("[grantiva] Building \(buildScheme) for \(booted.name)...")
            }

            let result = try await device.build(PlatformBuildRequest(
                config: config ?? GrantivaConfig(),
                resolved: resolved,
                deviceID: booted.udid,
                extraBuildSettings: target.extraBuildSettings(
                    platform: platform, derivedDataPath: buildOptions.derivedDataPath, resolved: resolved
                )
            ))

            if !options.json {
                Output.line(TableFormatter().formatBuild(result))
            }

            guard result.success else {
                if options.json {
                    Output.line(try JSONOutput.string(result))
                }
                throw ExitCode.failure
            }

            productPath = result.productPath
            builtAppID = result.applicationId
        }

        guard let bid = target.installedAppID(platform: platform, config: config, resolved: resolved, binaryID: builtAppID ?? appBundleId, purpose: .installing, warn: { GrantivaLog.logger.warning("\($0)") }) else {
            throw GrantivaError.invalidArgument(
                platform == .ios
                    ? "No bundle ID. Pass --bundle-id or set bundle_id in grantiva.yml."
                    : TargetOptions.appIDMessage(for: .android)
            )
        }

        if platform == .ios, let productPath,
           let mismatch = Self.bundleIDMismatch(
               flag: target.bundleId, configured: config?.bundleId, productPath: productPath
           ) {
            throw mismatch
        }

        if let productPath {
            let installID = TargetOptions.installAppID(platform: platform, testID: bid, binaryID: builtAppID ?? appBundleId)
            options.note("[grantiva] Installing \(installID)...")
            try await device.install(appID: installID, productPath: productPath, deviceID: booted.udid)
        }
        let installed = productPath != nil

        // Never launch an app this command did not install and the device
        // does not have: say so in one line instead.
        if !installed, !noLaunch, await device.isInstalled(appID: bid, deviceID: booted.udid) == false {
            throw GrantivaError.unavailable(Self.notInstalledMessage(appID: bid, deviceName: booted.name, serial: booted.udid))
        }

        let dataContainerPath = try await Self.dataContainerPath(platform: platform, bundleId: bid, deviceID: booted.udid)

        let status = try await completeInstall(installed: installed) {
            options.note("[grantiva] Launching \(bid)...")
            try await device.launch(appID: bid, deviceID: booted.udid)
        }

        if options.json, platform == .android {
            Output.line(try JSONOutput.string(AndroidInstallResult(
                status: status,
                applicationId: bid,
                device: .init(name: booted.name, serial: booted.udid),
                appPath: productPath
            )))
        } else if options.json {
            let result = InstallResult(
                status: status,
                scheme: resolved.scheme,
                bundleId: bid,
                simulator: .init(name: booted.name, udid: booted.udid),
                appPath: productPath,
                dataContainerPath: dataContainerPath
            )
            Output.line(try JSONOutput.string(result))
        } else {
            Output.line(Self.completionMessage(
                status: status,
                bundleId: bid,
                deviceName: booted.name,
                dataContainerPath: dataContainerPath,
                installSkipped: !installed
            ))
        }
    }

    /// An explicit iOS bundle ID (`--bundle-id`, else `bundle_id` in
    /// grantiva.yml) that is not the app being installed. simctl installs the
    /// product whatever the ID says, and the later container lookup under
    /// the wrong ID failed with a bare NSPOSIXErrorDomain error; this names
    /// both IDs before anything is installed.
    static func bundleIDMismatch(flag: String?, configured: String?, productPath: String) -> GrantivaError? {
        guard let explicit = flag ?? configured,
              let productID = AppBinaryResolver.bundleId(from: productPath),
              productID != explicit else { return nil }
        let source = flag != nil ? "--bundle-id \(explicit)" : "bundle_id \(explicit) in grantiva.yml"
        let plist = URL(fileURLWithPath: productPath).appendingPathComponent("Info.plist").path
        return GrantivaError.invalidArgument(
            "\(source) does not match the built app (\(productID), \(plist)). "
                + "Pass --bundle-id \(productID), or build the target whose bundle ID is \(explicit)."
        )
    }

    /// DevicePlatform has no data-container call yet; on iOS this is the same
    /// `simctl get_app_container ... data` lookup the command always did.
    /// Android has no host-readable data container, so there is none to report.
    static func dataContainerPath(platform: Platform, bundleId: String, deviceID: String) async throws -> String? {
        switch platform {
        case .ios:
            return try await XcodeBuildRunner().dataContainerPath(bundleId: bundleId, udid: deviceID)
        case .android:
            return nil
        }
    }

    /// `installed` is false when nothing was installed (`--no-build`); not
    /// launching then is `skipped`, not `installed`.
    func completeInstall(
        installed: Bool = true,
        launch: () async throws -> Void
    ) async throws -> InstallResult.Status {
        guard !noLaunch else { return installed ? .installed : .skipped }
        try await launch()
        return .launched
    }

    static func notInstalledMessage(appID: String, deviceName: String, serial: String) -> String {
        GrantivaError.notInstalledRoot(appID: appID, device: "\(deviceName) (\(serial))")
            + "; install it first (drop --no-build, or pass --app-file) or pass --no-launch."
    }

    static func completionMessage(
        status: InstallResult.Status,
        bundleId: String,
        deviceName: String,
        dataContainerPath: String?,
        installSkipped: Bool = false
    ) -> String {
        let action = switch (status, installSkipped) {
        case (.launched, false): "running on \(deviceName)"
        case (.launched, true): "running on \(deviceName) (install skipped)"
        case (.installed, _): "installed on \(deviceName) (not launched)"
        case (.skipped, _): "on \(deviceName) (install skipped, not launched)"
        }
        let done = "[grantiva] Done — \(bundleId) \(action)"
        guard let dataContainerPath else { return done }
        return "\(done)\nData container: \(dataContainerPath)"
    }
}

struct InstallResult: Codable, Equatable {
    /// `installed`: installed, not launched. `launched`: running (installed
    /// by this command, or already there with `--no-build`). `skipped`:
    /// `--no-build --no-launch`, nothing done to the app.
    enum Status: String, Codable {
        case installed
        case launched
        case skipped
    }

    struct Simulator: Codable, Equatable {
        let name: String
        let udid: String
    }

    let status: Status
    let scheme: String?
    let bundleId: String
    let simulator: Simulator
    let appPath: String?
    let dataContainerPath: String?

    enum CodingKeys: String, CodingKey { case status, scheme, bundleId, simulator, appPath, dataContainerPath }

    /// Every documented key in every document: `null` where there is no
    /// value (`appPath` when nothing was installed, L39).
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(status, forKey: .status)
        try c.encode(scheme, forKey: .scheme)
        try c.encode(bundleId, forKey: .bundleId)
        try c.encode(simulator, forKey: .simulator)
        try c.encode(appPath, forKey: .appPath)
        try c.encode(dataContainerPath, forKey: .dataContainerPath)
    }
}

/// `build install --json` on Android: application ID and adb serial instead
/// of iOS's `bundleId` and `simulator {name, udid}`. Android has no scheme
/// and no host-readable data container.
struct AndroidInstallResult: Codable, Equatable {
    struct Device: Codable, Equatable {
        let name: String
        let serial: String
    }

    let status: InstallResult.Status
    let applicationId: String
    let device: Device
    let appPath: String?

    enum CodingKeys: String, CodingKey { case status, applicationId, device, appPath }

    /// `appPath` is `null` when nothing was installed (L39).
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(status, forKey: .status)
        try c.encode(applicationId, forKey: .applicationId)
        try c.encode(device, forKey: .device)
        try c.encode(appPath, forKey: .appPath)
    }
}
