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

    @OptionGroup var target: TargetOptions

    /// Empty means "make one from the resolved platform"; tests inject a fake.
    var devicePlatform = InjectedDevicePlatform()

    func run() async throws {
        let (platform, config) = try platformOptions.loadConfig()
        try target.checkFlags(for: platform, derivedDataPath: derivedDataPath)
        let device = try devicePlatform.make(platform, android: target.androidOptions)

        let resolved = try await target.resolve(platform: platform, config: config, skipBuild: false, appID: nil)

        if platform == .ios, resolved.scheme == nil {
            throw GrantivaError.invalidArgument(
                "No scheme specified. Pass --scheme or set it in grantiva.yml."
            )
        }

        let booted = try await device.bootDevice(named: resolved.simulator)

        let buildTarget = resolved.scheme ?? GradleBuildRunner.taskName(
            module: resolved.android?.module ?? "app", variant: resolved.android?.variant ?? "debug"
        )
        options.note("[grantiva] Building \(buildTarget) for \(booted.name)...")

        let result = try await device.build(PlatformBuildRequest(
            config: config ?? GrantivaConfig(),
            resolved: resolved,
            deviceID: booted.udid,
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

        let booted = try await device.bootDevice(named: resolved.simulator)

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

        guard let bid = target.installedAppID(platform: platform, config: config, resolved: resolved, binaryID: builtAppID ?? appBundleId, warn: { GrantivaLog.logger.warning("\($0)") }) else {
            throw GrantivaError.invalidArgument(
                platform == .ios
                    ? "No bundle ID. Pass --bundle-id or set bundle_id in grantiva.yml."
                    : TargetOptions.appIDMessage(for: .android)
            )
        }

        if let productPath {
            options.note("[grantiva] Installing \(bid)...")
            try await device.install(appID: bid, productPath: productPath, deviceID: booted.udid)
        }

        let dataContainerPath = try await Self.dataContainerPath(platform: platform, bundleId: bid, deviceID: booted.udid)

        let status = try await completeInstall {
            options.note("[grantiva] Launching \(bid)...")
            try await device.launch(appID: bid, deviceID: booted.udid)
        }

        if options.json {
            let result = InstallResult(
                status: status,
                scheme: resolved.scheme,
                bundleId: bid,
                simulator: .init(name: booted.name, udid: booted.udid),
                appPath: productPath,
                dataContainerPath: dataContainerPath
            )
            Output.line(try JSONOutput.string(result))
        } else if noLaunch {
            Output.line(Self.completionMessage(
                status: .installed,
                bundleId: bid,
                deviceName: booted.name,
                dataContainerPath: dataContainerPath
            ))
        } else {
            Output.line(Self.completionMessage(
                status: .launched,
                bundleId: bid,
                deviceName: booted.name,
                dataContainerPath: dataContainerPath
            ))
        }
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

    func completeInstall(
        launch: () async throws -> Void
    ) async throws -> InstallResult.Status {
        guard !noLaunch else { return .installed }
        try await launch()
        return .launched
    }

    static func completionMessage(
        status: InstallResult.Status,
        bundleId: String,
        deviceName: String,
        dataContainerPath: String?
    ) -> String {
        let action = status == .installed ? "installed on \(deviceName) (not launched)" : "running on \(deviceName)"
        let done = "[grantiva] Done — \(bundleId) \(action)"
        guard let dataContainerPath else { return done }
        return "\(done)\nData container: \(dataContainerPath)"
    }
}

struct InstallResult: Codable, Equatable {
    enum Status: String, Codable {
        case installed
        case launched
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
}
