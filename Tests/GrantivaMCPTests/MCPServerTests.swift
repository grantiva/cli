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

        XCTAssertThrowsError(try GrantivaMCPServer.loadActiveSession(projectDirectory: directory)) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("No active runner session"))
            XCTAssertTrue(message.contains("grantiva runner start"))
        }
    }

    private func makeProjectDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data().write(to: directory.appendingPathComponent("grantiva.yml"))
        return directory
    }
}
