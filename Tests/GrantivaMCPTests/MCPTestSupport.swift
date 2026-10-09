import Foundation
import GrantivaCore
import MCP
import XCTest

@testable import GrantivaMCP

/// Thread-safe recorder for calls made against the fake `DriverClient`.
final class WDARecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    func record(_ entry: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(entry)
    }

    var calls: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

enum MCPTestSupport {
    /// An empty-but-valid hierarchy payload.
    static let emptyHierarchyJSON = #"{"type":"XCUIElementTypeApplication","children":[]}"#

    /// Builds a `DriverClient` whose every call is recorded and whose responses are fixtures.
    /// Nothing here touches the network, a simulator, or the filesystem.
    static func fakeDriver(
        recorder: WDARecorder,
        hierarchyJSON: String = emptyHierarchyJSON,
        screenshotBytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
    ) -> DriverClient {
        DriverClient(
            status: { WDAStatus(sessionId: "test-session", ready: true) },
            hierarchy: {
                recorder.record("hierarchy")
                let object = try JSONSerialization.jsonObject(with: Data(hierarchyJSON.utf8))
                return object as? [String: Any] ?? [:]
            },
            hierarchyXML: {
                recorder.record("hierarchyXML")
                return "<AppiumAUT/>"
            },
            tapByLabel: { label in recorder.record("tapByLabel(\(label))") },
            tapByCoordinate: { x, y in recorder.record("tapByCoordinate(\(x),\(y))") },
            typeText: { text in recorder.record("typeText(\(text))") },
            swipe: { direction in recorder.record("swipe(\(direction))") },
            screenshot: {
                recorder.record("screenshot")
                return Data(screenshotBytes)
            }
        )
    }

    /// A session with no UDID, which forces the screenshot tool down the driver path
    /// instead of asking the device platform.
    static func sessionWithoutUDID() -> RunnerSessionInfo {
        RunnerSessionInfo(pid: 0, wdaPort: 8100, bundleId: "", udid: "", startedAt: Date())
    }

    static func registry(
        driver: DriverClient,
        config: GrantivaConfig? = nil,
        session: RunnerSessionInfo? = nil,
        platform: Platform = .ios,
        device: any DevicePlatform = MCPFakeDevicePlatform(platform: .ios)
    ) -> ToolRegistry {
        ToolRegistry(
            driver: driver,
            platform: platform,
            device: device,
            config: config,
            session: session ?? sessionWithoutUDID(),
            simulatorManager: SimulatorManager.live,
            buildRunner: XcodeBuildRunner(),
            emulators: nil
        )
    }

    /// A `Server` that was never connected to a transport. Notification sends against it
    /// fail fast (and the registry swallows that), so it is safe to use in tests.
    static func disconnectedServer() -> Server {
        Server(name: "grantiva-test", version: "0.0.0")
    }
}

// MARK: - Assertions

extension XCTestCase {
    /// Extracts the concatenated text of a tool result, failing if there is none.
    func textContent(
        of result: CallTool.Result,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let texts: [String] = result.content.compactMap {
            if case .text(let text, _, _) = $0 { return text }
            return nil
        }
        if texts.isEmpty {
            XCTFail("Expected text content, got \(result.content)", file: file, line: line)
            throw XCTSkip("no text content")
        }
        return texts.joined(separator: "\n")
    }

    func imageContent(
        of result: CallTool.Result,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> (data: String, mimeType: String) {
        for item in result.content {
            if case .image(let data, let mimeType, _, _) = item { return (data, mimeType) }
        }
        XCTFail("Expected image content, got \(result.content)", file: file, line: line)
        throw XCTSkip("no image content")
    }
}

/// Records every call. Mirrors the CLI test target's FakeDevicePlatform; the
/// two test targets cannot share a file.
final class MCPFakeDevicePlatform: DevicePlatform, @unchecked Sendable {
    let platform: Platform
    private let lock = NSLock()
    private var recorded: [String] = []
    var calls: [String] { lock.withLock { recorded } }
    private func record(_ call: String) { lock.withLock { recorded.append(call) } }

    var bootedID = "emulator-5598"
    var bootedName = "Fake"
    var buildResult = BuildResult(success: true, duration: 0, warnings: [], errors: [], productPath: "/fake/app.apk", applicationId: "com.fake.built")
    var screenshotBytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47]

    init(platform: Platform) { self.platform = platform }

    func bootDevice(named nameOrID: String) async throws -> BootedDevice { record("bootDevice(\(nameOrID))"); return BootedDevice(udid: bootedID, name: bootedName) }
    func displayGeometry(deviceID: String) async throws -> DeviceGeometry { record("displayGeometry"); return DeviceGeometry(pixelWidth: 1080, pixelHeight: 2400, scale: 2.625) }
    func build(_ request: PlatformBuildRequest) async throws -> BuildResult {
        record("build(scheme=\(request.resolved.scheme ?? "-"),module=\(request.resolved.android?.module ?? "-"),variant=\(request.resolved.android?.variant ?? "-"))"); return buildResult
    }
    func install(appID: String, productPath: String, deviceID: String) async throws { record("install(\(appID),\(productPath))") }
    func launch(appID: String, deviceID: String) async throws { record("launch(\(appID))") }
    func terminate(appID: String, deviceID: String) async throws { record("terminate(\(appID))") }
    func uninstall(appID: String, deviceID: String) async throws { record("uninstall(\(appID))") }
    func prepareForCapture(deviceID: String) async { record("prepare") }
    func restoreAfterCapture(deviceID: String) async { record("restore") }
    func runnerGlobalArguments(deviceID: String, appFile: String?) -> [String] { ["--platform", platform.rawValue, "--device", deviceID] }
    func runnerTestArguments() -> [String] { [] }
    func resolveBinary(_ path: String) async throws -> ResolvedBinary { record("resolveBinary(\(path))"); return ResolvedBinary(appPath: path, tempDir: nil, appID: "com.fake.binary") }
    func defaultDevice() async throws -> BootedDevice { record("defaultDevice"); return BootedDevice(udid: bootedID, name: bootedName) }
    func screenshot(deviceID: String, to path: String) async throws {
        record("screenshot(\(deviceID))")
        try Data(screenshotBytes).write(to: URL(fileURLWithPath: path))
    }
    func logStream(deviceID: String, appID: String?, filter: String?, level: String?) async throws -> LogStreamCommand { LogStreamCommand(executable: "/bin/echo", arguments: []) }
    func runnerEnvironment(runnerHome: String) -> [String: String] { [:] }
    func cleanupOrphans(deviceID: String) async { record("cleanupOrphans") }
    func attachDriver(deviceID: String, port: UInt16?) async throws -> DriverAttachment {
        record("attachDriver(\(deviceID),\(port.map(String.init) ?? "-"))")
        return DriverAttachment(client: .failing, port: Int(port ?? 7000), detach: {})
    }
    func recordVideo(deviceID: String, to path: String, seconds: Double) async throws { record("recordVideo") }
}
