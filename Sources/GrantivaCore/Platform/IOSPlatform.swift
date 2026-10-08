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
}
