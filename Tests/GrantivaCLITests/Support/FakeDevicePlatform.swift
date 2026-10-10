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

    /// What `isInstalled` reports; nil means "cannot tell".
    var installed: Bool?

    init(platform: Platform) { self.platform = platform }

    func isInstalled(appID: String, deviceID: String) async -> Bool? {
        record("isInstalled(\(appID))"); return installed
    }

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
    func screenshot(deviceID: String, to path: String) async throws {
        record("screenshot")
        FileManager.default.createFile(atPath: path, contents: Data())
    }
    func logStream(deviceID: String, appID: String?, filter: String?, level: LogStreamLevel?) async throws -> LogStreamCommand {
        record("logStream(\(appID ?? "-"),\(filter ?? "-"))"); return LogStreamCommand(executable: "/bin/echo", arguments: ["fake log"])
    }
    func runnerEnvironment(runnerHome: String, deviceID: String) -> [String: String] { [:] }
    func cleanupOrphans(deviceID: String) async { record("cleanupOrphans") }
    var hierarchyXML = "<hierarchy><android.view.View class=\"android.view.View\" text=\"Fake\" bounds=\"[0,0][10,10]\"/></hierarchy>"
    func attachDriver(deviceID: String, port: UInt16?) async throws -> DriverAttachment {
        record("attachDriver(\(deviceID),\(port.map(String.init) ?? "-"))")
        let xml = hierarchyXML
        let client = DriverClient(
            status: { WDAStatus(sessionId: "fake", ready: true) },
            hierarchy: { try UIAutomator2HierarchyXMLParser(xml: xml, scale: 1).parse() },
            hierarchyXML: { xml },
            tapByLabel: { _ in }, tapByCoordinate: { _, _ in }, typeText: { _ in }, swipe: { _ in },
            screenshot: { Data([0x89, 0x50, 0x4E, 0x47]) }
        )
        return DriverAttachment(client: client, port: Int(port ?? 7000), detach: { self.record("detach") })
    }
    var recordingData = Data()
    func recordVideo(deviceID: String, to path: String, seconds: Double) async throws {
        record("recordVideo(\(deviceID),\(seconds))")
        FileManager.default.createFile(atPath: path, contents: recordingData)
    }
}
