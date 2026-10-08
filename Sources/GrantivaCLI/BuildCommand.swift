import ArgumentParser
import Foundation
import GrantivaCore

struct BuildCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build and optionally install the app to a simulator.",
        subcommands: [BuildOnlyCommand.self, InstallCommand.self],
        defaultSubcommand: BuildOnlyCommand.self
    )
}

// MARK: - build

struct BuildOnlyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build the app for a simulator using xcodebuild."
    )

    @OptionGroup var options: GlobalOptions
    @OptionGroup var platformOptions: PlatformOptions

    @Option(name: .long, help: "Write Xcode build products and intermediates to this DerivedData directory.")
    var derivedDataPath: String?

    @Option(name: .long, help: "Scheme to build")
    var scheme: String?

    @Option(name: .long, help: "Simulator name")
    var simulator: String?

    /// Empty means "make one from the resolved platform"; tests inject a fake.
    var devicePlatform = InjectedDevicePlatform()

    func run() async throws {
        let (platform, config) = try platformOptions.loadConfig()
        let device = devicePlatform.make(platform)

        let resolved = try await ResolvedProject.resolve(
            schemeFlag: scheme,
            simulatorFlag: simulator,
            config: config,
            skipBuild: false
        )

        guard let buildScheme = resolved.scheme else {
            throw GrantivaError.invalidArgument(
                "No scheme specified. Pass --scheme or set it in grantiva.yml."
            )
        }

        let booted = try await device.bootDevice(named: resolved.simulator)

        options.note("[grantiva] Building \(buildScheme) for \(booted.name)...")

        let result = try await device.build(PlatformBuildRequest(
            config: config ?? GrantivaConfig(),
            resolved: resolved,
            deviceID: booted.udid,
            extraBuildSettings: BuildOptions.xcodeBuildSettings(
                derivedDataPath: derivedDataPath,
                merging: resolved.buildSettings
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
        abstract: "Build and install the app on a simulator, then optionally launch it."
    )

    @OptionGroup var options: GlobalOptions
    @OptionGroup var buildOptions: BuildOptions
    @OptionGroup var platformOptions: PlatformOptions

    @Option(name: .long, help: "Scheme to build")
    var scheme: String?

    @Option(name: .long, help: "Simulator name")
    var simulator: String?

    @Option(name: .long, help: "Bundle identifier")
    var bundleId: String?

    @Flag(name: .long, help: "Install the app without launching it.")
    var noLaunch: Bool = false

    /// Empty means "make one from the resolved platform"; tests inject a fake.
    var devicePlatform = InjectedDevicePlatform()

    func run() async throws {
        let (platform, config) = try platformOptions.loadConfig()
        let device = devicePlatform.make(platform)

        let resolvedBinary = try buildOptions.resolveAppBinary()
        defer { resolvedBinary?.cleanup() }

        let appBundleId = resolvedBinary.flatMap { AppBinaryResolver.bundleId(from: $0.appPath) }

        let resolved = try await ResolvedProject.resolve(
            schemeFlag: scheme,
            simulatorFlag: simulator,
            bundleIdFlag: bundleId,
            config: config,
            skipBuild: buildOptions.shouldSkipBuild,
            appBundleId: appBundleId
        )

        let booted = try await device.bootDevice(named: resolved.simulator)

        var productPath: String?

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
                extraBuildSettings: buildOptions.xcodeBuildSettings(merging: resolved.buildSettings)
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
        }

        guard let bid = resolved.bundleId else {
            throw GrantivaError.invalidArgument(
                "No bundle ID. Pass --bundle-id or set bundle_id in grantiva.yml."
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
    static func dataContainerPath(platform: Platform, bundleId: String, deviceID: String) async throws -> String {
        switch platform {
        case .ios:
            return try await XcodeBuildRunner().dataContainerPath(bundleId: bundleId, udid: deviceID)
        case .android:
            throw GrantivaError.invalidArgument("Reading the app data container is not supported on Android yet.")
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
        dataContainerPath: String
    ) -> String {
        let action = status == .installed ? "installed on \(deviceName) (not launched)" : "running on \(deviceName)"
        return "[grantiva] Done — \(bundleId) \(action)\nData container: \(dataContainerPath)"
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
