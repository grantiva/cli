import Foundation
import GrantivaCore
@testable import GrantivaMCP
import XCTest

@available(macOS 15, *)
final class MCPServerTests: XCTestCase {
    func testProjectDirectoryRequiresGrantivaConfig() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertThrowsError(try GrantivaMCPServer.resolveProjectDirectory(directory)) { error in
            XCTAssertTrue(String(describing: error).contains("No grantiva.yml"))
        }
    }

    func testSessionIsLoadedRelativeToExplicitProjectDirectory() throws {
        let directory = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = RunnerSessionInfo(
            pid: getpid(),
            wdaPort: 8201,
            bundleId: "com.example.app",
            udid: "921A0945-7157-4533-BA1F-21E8132D3E40",
            startedAt: Date()
        )
        let sessionURL = directory.appendingPathComponent(RunnerSessionInfo.path)
        try FileManager.default.createDirectory(
            at: sessionURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(session).write(to: sessionURL)

        let loaded = try GrantivaMCPServer.loadActiveSession(projectDirectory: directory)

        XCTAssertEqual(loaded.wdaPort, 8201)
        XCTAssertEqual(loaded.bundleId, "com.example.app")
    }

    func testSessionRejectsMalformedUDIDBeforeToolsConsumeIt() throws {
        let directory = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = RunnerSessionInfo(
            pid: getpid(),
            wdaPort: 8201,
            bundleId: "com.example.app",
            udid: "$(touch /tmp/grantiva-mcp-injected)",
            startedAt: Date()
        )
        let sessionURL = directory.appendingPathComponent(RunnerSessionInfo.path)
        try FileManager.default.createDirectory(
            at: sessionURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(session).write(to: sessionURL)

        XCTAssertThrowsError(try GrantivaMCPServer.loadActiveSession(projectDirectory: directory)) { error in
            XCTAssertTrue(String(describing: error).contains("session UDID"))
        }
    }

    func testMissingSessionFailsLoudly() throws {
        let directory = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertThrowsError(
            try GrantivaMCPServer.loadActiveSession(projectDirectory: directory, keepAliveSessions: emptyKeepAliveStore())
        ) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("No active runner session"))
            XCTAssertTrue(message.contains("grantiva runner start"))
            XCTAssertTrue(message.contains("grantiva run --keep-alive"))
        }
    }

    func testFallsBackToALiveKeepAliveSessionUsingTheSharedDiscovery() throws {
        let directory = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sessions = directory.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let store = KeepAliveSessionStore(directory: sessions.path, isProcessAlive: { $0 == 4242 })
        let runnerFile: [String: Any] = ["version": 1, "sessionId": "abc", "pid": 4242, "port": 8577, "outputDir": "/o"]
        try JSONSerialization.data(withJSONObject: runnerFile)
            .write(to: sessions.appendingPathComponent("4242-1791340478890825000.grantiva"))
        let udid = "921A0945-7157-4533-BA1F-21E8132D3E40"
        store.recordOwner(udid: udid, runnerPid: 4242)

        let loaded = try GrantivaMCPServer.loadActiveSession(projectDirectory: directory, keepAliveSessions: store)
        XCTAssertEqual(loaded.pid, 4242)
        XCTAssertEqual(loaded.wdaPort, 8577)
        XCTAssertEqual(loaded.udid, udid)
    }

    private func emptyKeepAliveStore() -> KeepAliveSessionStore {
        KeepAliveSessionStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path,
            isProcessAlive: { _ in false }
        )
    }

    private func makeProjectDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data().write(to: directory.appendingPathComponent("grantiva.yml"))
        return directory
    }

    /// Review Focus 5.
    func testProjectDirectoryAcceptsAnAndroidOnlyProject() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "platform: android\nmodule: app\n".write(to: directory.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        XCTAssertEqual(try GrantivaMCPServer.resolveProjectDirectory(directory).standardizedFileURL, directory.standardizedFileURL)
    }

    /// Review Focus 5.
    func testLoadActiveSessionAcceptsAnADBSerial() throws {
        let directory = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = RunnerSessionInfo(pid: getpid(), wdaPort: 61211, bundleId: "dev.grantiva.example", udid: "emulator-5554", startedAt: Date())
        let sessionURL = directory.appendingPathComponent(RunnerSessionInfo.path)
        try FileManager.default.createDirectory(at: sessionURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(session).write(to: sessionURL)
        let loaded = try GrantivaMCPServer.loadActiveSession(projectDirectory: directory)
        XCTAssertEqual(loaded.udid, "emulator-5554")
        XCTAssertEqual(loaded.wdaPort, 61211)
    }

    func testDriverPortIsNilForAKeepAliveSessionWithPortZero() {
        XCTAssertNil(GrantivaMCPServer.driverPort(for: RunnerSessionInfo(pid: 1, wdaPort: 0, bundleId: "", udid: "emulator-5554", startedAt: Date())))
        XCTAssertEqual(GrantivaMCPServer.driverPort(for: RunnerSessionInfo(pid: 1, wdaPort: 8100, bundleId: "", udid: "", startedAt: Date())), 8100)
    }

    /// A directory with both config files is ambiguous on its own; the
    /// server's `--platform` flag settles it.
    func testExplicitPlatformWinsOverADualConfigDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "scheme: Example\n".write(to: directory.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
        try "platform: android\nmodule: app\n".write(to: directory.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        let resolver = PlatformResolver(directory: directory)
        XCTAssertThrowsError(try resolver.resolveOrDefault(flag: nil))
        XCTAssertEqual(try resolver.resolveOrDefault(flag: .android), .android)
    }
}
