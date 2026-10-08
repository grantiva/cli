import Foundation
@testable import GrantivaCLI
import GrantivaCore

/// Records every call. Device-level results are canned so a command can be
/// driven to a chosen point without a simulator or emulator.
final class FakeDevicePlatform: DevicePlatform, @unchecked Sendable {
    let platform: Platform
    private let lock = NSLock()
    private var recorded: [String] = []
    var calls: [String] { lock.withLock { recorded } }
    private func record(_ call: String) { lock.withLock { recorded.append(call) } }

    var bootedName = "Fake"
    var bootedID = "emulator-5598"
    var buildResult = BuildResult(success: true, duration: 0, warnings: [], errors: [], productPath: "/fake/app.apk", applicationId: "com.fake.built")

    init(platform: Platform) { self.platform = platform }

    func bootDevice(named nameOrID: String) async throws -> BootedDevice {
        record("bootDevice(\(nameOrID))"); return BootedDevice(udid: bootedID, name: bootedName)
    }
    func displayGeometry(deviceID: String) async throws -> DeviceGeometry {
        record("displayGeometry(\(deviceID))"); return DeviceGeometry(pixelWidth: 1080, pixelHeight: 2400, scale: 2.625)
    }
    func build(_ request: PlatformBuildRequest) async throws -> BuildResult {
        record("build(module=\(request.resolved.android?.module ?? "-"),variant=\(request.resolved.android?.variant ?? "-"),args=\(request.extraBuildSettings))"); return buildResult
    }
    func install(appID: String, productPath: String, deviceID: String) async throws { record("install(\(appID),\(productPath))") }
    func launch(appID: String, deviceID: String) async throws { record("launch(\(appID))") }
    func terminate(appID: String, deviceID: String) async throws { record("terminate(\(appID))") }
    func uninstall(appID: String, deviceID: String) async throws { record("uninstall(\(appID))") }
    func prepareForCapture(deviceID: String) async { record("prepare") }
    func restoreAfterCapture(deviceID: String) async { record("restore") }
    func runnerGlobalArguments(deviceID: String, appFile: String?) -> [String] { ["--platform", platform.rawValue, "--device", deviceID] }
    func runnerTestArguments() -> [String] { [] }
    func resolveBinary(_ path: String) async throws -> ResolvedBinary {
        record("resolveBinary(\(path))"); return ResolvedBinary(appPath: path, tempDir: nil, appID: "com.fake.binary")
    }
    func defaultDevice() async throws -> BootedDevice { record("defaultDevice"); return BootedDevice(udid: bootedID, name: bootedName) }
    func screenshot(deviceID: String, to path: String) async throws { record("screenshot") }
    func logStream(deviceID: String, appID: String?, filter: String?, level: String?) async throws -> LogStreamCommand {
        record("logStream(\(appID ?? "-"),\(filter ?? "-"))"); return LogStreamCommand(executable: "/bin/echo", arguments: ["fake log"])
    }
    func runnerEnvironment(runnerHome: String) -> [String: String] { [:] }
    func cleanupOrphans(deviceID: String) async { record("cleanupOrphans") }
}
