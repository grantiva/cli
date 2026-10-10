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

public struct LogStreamCommand: Sendable, Equatable {
    public let executable: String
    public let arguments: [String]

    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }
}

/// A driver client bound to a live session, plus how to let go of whatever
/// the platform set up to reach it (a port forward on Android, nothing on iOS).
public struct DriverAttachment: Sendable {
    public let client: DriverClient
    /// The local port the client talks to.
    public let port: Int
    public let detach: @Sendable () async -> Void

    public init(client: DriverClient, port: Int, detach: @escaping @Sendable () async -> Void) {
        self.client = client
        self.port = port
        self.detach = detach
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

    /// Validates a pre-built binary for this platform and reads its app ID.
    func resolveBinary(_ path: String) async throws -> ResolvedBinary
    /// The device a `--no-build` capture targets when none is named by flag,
    /// config, or runner session. On iOS this is the only booted simulator;
    /// several booted is an error, never "the first one".
    func defaultDevice() async throws -> BootedDevice
    /// A full-screen PNG of the device, written to `path`.
    func screenshot(deviceID: String, to path: String) async throws
    /// The process that streams the app's logs. `filter` is the platform's
    /// own syntax (an NSPredicate on iOS, a logcat tag on Android).
    func logStream(deviceID: String, appID: String?, filter: String?, level: String?) async throws -> LogStreamCommand
    /// Extra environment for the runner process that drives `deviceID`.
    func runnerEnvironment(runnerHome: String, deviceID: String) -> [String: String]
    /// Called once the runner process that drove `deviceID` has exited.
    func runnerFinished(runnerHome: String, deviceID: String)
    /// Kills driver processes a crashed runner may have left on the device.
    func cleanupOrphans(deviceID: String) async
    /// A driver client for the session held on `deviceID`. `port` is the
    /// local port a previous attach (or `runner start`) recorded; nil or 0
    /// means "find it", which on Android forwards a new one.
    func attachDriver(deviceID: String, port: UInt16?) async throws -> DriverAttachment
    /// Records the screen for `seconds` and leaves a video file at `path`.
    func recordVideo(deviceID: String, to path: String, seconds: Double) async throws
    /// Whether `appID` is installed on the device; nil when the platform
    /// cannot tell. `run --no-build` checks this before starting the runner.
    func isInstalled(appID: String, deviceID: String) async -> Bool?
}

extension DevicePlatform {
    public func isInstalled(appID: String, deviceID: String) async -> Bool? { nil }
}

public enum DevicePlatformFactory {
    public static func make(_ platform: Platform, android: AndroidPlatform.Options = AndroidPlatform.Options()) throws -> any DevicePlatform {
        switch platform {
        case .ios:
            return IOSPlatform()
        case .android:
            return try AndroidPlatform.live(options: android)
        }
    }
}

public extension DevicePlatform {
    func runnerFinished(runnerHome: String, deviceID: String) {}
}
