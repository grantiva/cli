import Foundation
import GrantivaCore
import XCTest
@testable import GrantivaCLI

/// `grantiva hierarchy` session selection. Discovery itself is covered by
/// KeepAliveSessionStoreTests; these prove the command routes its flags into it.
final class HierarchyCommandTests: XCTestCase {
    func testRejectsInvalidTimeoutBeforeLookingForSessions() {
        XCTAssertThrowsError(try HierarchyCommand.parse(["--timeout", "0"]))
    }

    func testRejectsUDIDPathTraversal() {
        XCTAssertThrowsError(try HierarchyCommand.parse(["--udid", "../auth"]))
    }

    func testExplicitUDIDLoadsOnlyItsSession() throws {
        let directory = try temporaryDirectory()
        let store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { _ in true })
        let udid = "921A0945-7157-4533-BA1F-21E8132D3E40"
        try writeRunnerSession(pid: 100, nanos: 1, sessionId: "wanted", in: directory)
        try writeRunnerSession(pid: 200, nanos: 2, sessionId: "other", in: directory)
        store.recordOwner(udid: udid, runnerPid: 100)
        store.recordOwner(udid: "11111111-2222-3333-4444-555555555555", runnerPid: 200)

        let command = try HierarchyCommand.parse(["--udid", udid])
        XCTAssertEqual(try command.locateSession(store: store).sessionId, "wanted")
    }

    func testWithoutUDIDTheNewestLiveSessionIsUsed() throws {
        let directory = try temporaryDirectory()
        try writeRunnerSession(pid: 100, nanos: 1, sessionId: "older", in: directory)
        try writeRunnerSession(pid: 200, nanos: 2, sessionId: "newest-but-dead", in: directory)
        let store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { $0 == 100 })
        XCTAssertEqual(try HierarchyCommand.parse([]).locateSession(store: store).sessionId, "older")
    }

    func testMissingSessionsAreReportedWithTheStartHint() throws {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        let store = KeepAliveSessionStore(directory: missing, isProcessAlive: { _ in true })
        XCTAssertThrowsError(try HierarchyCommand.parse([]).locateSession(store: store)) { error in
            XCTAssertTrue(String(describing: error).contains("grantiva run --keep-alive"))
        }
    }

    private func writeRunnerSession(pid: Int, nanos: Int, sessionId: String, in directory: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "version": 1, "sessionId": sessionId, "createdAt": "2026-10-07T10:00:00Z",
            "pid": pid, "port": 8100 + pid, "outputDir": "/tmp/out",
        ])
        try data.write(to: directory.appendingPathComponent("\(pid)-\(nanos).grantiva"))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-hierarchy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
