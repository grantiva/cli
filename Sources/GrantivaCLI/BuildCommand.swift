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
    @OptionGroup var buildOptions: BuildOptions

    @Option(name: .long, help: "Scheme to build")
    var scheme: String?

    @Option(name: .long, help: "Simulator name")
    var simulator: String?

    func run() async throws {
        let config = try? GrantivaConfig.load()

        let resolved = try await ResolvedProject.resolve(
            schemeFlag: scheme,
            simulatorFlag: simulator,
            config: config,
            skipBuild: buildOptions.shouldSkipBuild
        )

        guard let buildScheme = resolved.scheme else {
            throw GrantivaError.invalidArgument(
                "No scheme specified. Pass --scheme or set it in grantiva.yml."
            )
        }

        let device = try await SimulatorManager.live.boot(nameOrUDID: resolved.simulator)
        let destination = "platform=iOS Simulator,id=\(device.udid)"

        if !options.json {
            print("[grantiva] Building \(buildScheme) for \(device.name)...")
        }

        let result = try await XcodeBuildRunner().build(
            scheme: buildScheme,
            workspace: resolved.workspace,
            project: resolved.project,
            destination: destination,
            buildSettings: resolved.buildSettings
        )

        if options.json {
            print(try JSONOutput.string(result))
        } else {
            print(TableFormatter().formatBuild(result))
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

    @Option(name: .long, help: "Scheme to build")
    var scheme: String?

    @Option(name: .long, help: "Simulator name")
    var simulator: String?

    @Option(name: .long, help: "Bundle identifier")
    var bundleId: String?

    @Flag(name: .long, help: "Install the app without launching it.")
    var noLaunch: Bool = false

    func run() async throws {
        let config = try? GrantivaConfig.load()

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

        let device = try await SimulatorManager.live.boot(nameOrUDID: resolved.simulator)
        let destination = "platform=iOS Simulator,id=\(device.udid)"

        var productPath: String?

        if buildOptions.shouldSkipInstall {
            if !options.json {
                print("[grantiva] Skipping build and install (--no-build)")
            }
        } else if let resolvedBinary {
            if !options.json {
                print("[grantiva] Using pre-built binary: \(URL(fileURLWithPath: resolvedBinary.appPath).lastPathComponent)")
            }
            productPath = resolvedBinary.appPath
        } else {
            guard let buildScheme = resolved.scheme else {
                throw GrantivaError.invalidArgument(
                    "No scheme specified. Pass --scheme, set it in grantiva.yml, or use --app-file to provide a pre-built binary."
                )
            }

            if !options.json {
                print("[grantiva] Building \(buildScheme) for \(device.name)...")
            }

            let result = try await XcodeBuildRunner().build(
                scheme: buildScheme,
                workspace: resolved.workspace,
                project: resolved.project,
                destination: destination,
                buildSettings: resolved.buildSettings
            )

            if !options.json {
                print(TableFormatter().formatBuild(result))
            }

            guard result.success else {
                if options.json {
                    print(try JSONOutput.string(result))
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

        let runner = XcodeBuildRunner()

        if let productPath {
            if !options.json {
                print("[grantiva] Installing \(bid)...")
            }
            try await runner.install(bundleId: bid, productPath: productPath, udid: device.udid)
        }

        let dataContainerPath = options.json
            ? try await runner.dataContainerPath(bundleId: bid, udid: device.udid)
            : nil

        let status = try await completeInstall {
            if !options.json {
                print("[grantiva] Launching \(bid)...")
            }
            try await runner.launch(bundleId: bid, udid: device.udid)
        }

        if options.json {
            let result = InstallResult(
                status: status,
                scheme: resolved.scheme,
                bundleId: bid,
                simulator: .init(name: device.name, udid: device.udid),
                appPath: productPath,
                dataContainerPath: dataContainerPath
            )
            print(try JSONOutput.string(result))
        } else if noLaunch {
            print("[grantiva] Done — \(bid) installed on \(device.name) (not launched)")
        } else {
            print("[grantiva] Done — \(bid) running on \(device.name)")
        }
    }

    func completeInstall(
        launch: () async throws -> Void
    ) async throws -> InstallResult.Status {
        guard !noLaunch else { return .installed }
        try await launch()
        return .launched
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
