import Foundation
import XCTest
@testable import GrantivaCore

final class RunnerSessionCleanupTests: XCTestCase {
    func testCleanupFinishesBeforeSuccessfulOperationReturns() async throws {
        let events = EventLog()

        let result = await RunnerSession.runWithStatusBarCleanup(
            udid: "TEST-UDID",
            clear: { udid in
                try? await Task.sleep(for: .milliseconds(10))
                await events.append("clear:\(udid)")
            },
            operation: {
                await events.append("operation")
                return 42
            }
        )

        XCTAssertEqual(result, 42)
        let values = await events.values
        XCTAssertEqual(values, ["operation", "clear:TEST-UDID"])
    }

    func testTerminationCleanupRestoresCaptureStateAndCleansOrphans() {
        let calls = LockedCalls()
        let fake = RecordingPlatform(calls: calls, restoreDelay: 0)

        RunnerSession.terminationCleanup(platform: fake, deviceID: "emulator-5554")()

        XCTAssertEqual(calls.values, ["restore(emulator-5554)", "cleanupOrphans(emulator-5554)"])
    }

    func testTerminationCleanupGivesUpAfterTheTimeout() {
        let fake = RecordingPlatform(calls: LockedCalls(), restoreDelay: 2)

        let start = Date()
        RunnerSession.terminationCleanup(platform: fake, deviceID: "emulator-5554", timeout: 0.05)()
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.5)
    }
}

private final class LockedCalls: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    func append(_ value: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(value)
    }

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

/// Records the capture-restore calls a termination cleanup makes; every other
/// member is unused by these tests.
private struct RecordingPlatform: DevicePlatform {
    let calls: LockedCalls
    let restoreDelay: TimeInterval
    let platform: Platform = .android

    func bootDevice(named: String) async throws -> BootedDevice { fatalError() }
    func displayGeometry(deviceID: String) async throws -> DeviceGeometry { fatalError() }
    func build(_ request: PlatformBuildRequest) async throws -> BuildResult { fatalError() }
    func install(appID: String, productPath: String, deviceID: String) async throws {}
    func launch(appID: String, deviceID: String) async throws {}
    func terminate(appID: String, deviceID: String) async throws {}
    func uninstall(appID: String, deviceID: String) async throws {}
    func prepareForCapture(deviceID: String) async {}
    func restoreAfterCapture(deviceID: String) async {
        if restoreDelay > 0 { try? await Task.sleep(for: .seconds(restoreDelay)) }
        calls.append("restore(\(deviceID))")
    }
    func runnerGlobalArguments(deviceID: String, appFile: String?) -> [String] { [] }
    func runnerTestArguments() -> [String] { [] }
    func resolveBinary(_ path: String) async throws -> ResolvedBinary { fatalError() }
    func defaultDevice() async throws -> BootedDevice { fatalError() }
    func screenshot(deviceID: String, to path: String) async throws {}
    func logStream(deviceID: String, appID: String?, filter: String?, level: String?) async throws -> LogStreamCommand { fatalError() }
    func runnerEnvironment(runnerHome: String) -> [String: String] { [:] }
    func cleanupOrphans(deviceID: String) async {
        calls.append("cleanupOrphans(\(deviceID))")
    }
    func attachDriver(deviceID: String, port: UInt16?) async throws -> DriverAttachment { fatalError() }
    func recordVideo(deviceID: String, to path: String, seconds: Double) async throws {}
}

private actor EventLog {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}
