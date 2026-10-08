import Foundation

public struct DeviceGeometry: Sendable, Equatable {
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let scale: Double

    public init(pixelWidth: Int, pixelHeight: Int, scale: Double) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.scale = scale
    }

    public var dimensions: SimulatorProvisionResult.Dimensions {
        .init(width: pixelWidth, height: pixelHeight)
    }
}

public struct BootedDevice: Sendable, Equatable {
    public let udid: String
    public let name: String

    public init(udid: String, name: String) {
        self.udid = udid
        self.name = name
    }
}

public struct PlatformBuildRequest: Sendable {
    public let config: GrantivaConfig
    public let resolved: ResolvedProject
    public let deviceID: String
    public let extraBuildSettings: [String]

    public init(config: GrantivaConfig, resolved: ResolvedProject, deviceID: String, extraBuildSettings: [String]) {
        self.config = config
        self.resolved = resolved
        self.deviceID = deviceID
        self.extraBuildSettings = extraBuildSettings
    }
}

/// Everything a command needs from a device that differs between iOS and
/// Android. Commands hold one of these and never call simctl, xcodebuild,
/// adb, or gradle themselves.
public protocol DevicePlatform: Sendable {
    var platform: Platform { get }

    func bootDevice(named nameOrID: String) async throws -> BootedDevice
    func displayGeometry(deviceID: String) async throws -> DeviceGeometry

    func build(_ request: PlatformBuildRequest) async throws -> BuildResult
    func install(appID: String, productPath: String, deviceID: String) async throws
    func launch(appID: String, deviceID: String) async throws
    func terminate(appID: String, deviceID: String) async throws
    func uninstall(appID: String, deviceID: String) async throws

    /// Put the device in a deterministic state for screenshots. Never throws:
    /// a failure here degrades a capture, it does not abort a run.
    func prepareForCapture(deviceID: String) async
    func restoreAfterCapture(deviceID: String) async

    /// Arguments that go before the runner's `test` subcommand.
    func runnerGlobalArguments(deviceID: String, appFile: String?) -> [String]
    /// Platform-specific arguments that go after `test`.
    func runnerTestArguments() -> [String]
}

public enum DevicePlatformFactory {
    public static func make(_ platform: Platform) -> any DevicePlatform {
        switch platform {
        case .ios:
            return IOSPlatform()
        case .android:
            // Plan 2 replaces this with AndroidPlatform().
            fatalError("Android support is not available in this build")
        }
    }
}
