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
}
