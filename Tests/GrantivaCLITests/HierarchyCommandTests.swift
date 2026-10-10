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

    func testExplicitSerialLoadsItsSession() throws {
        let directory = try temporaryDirectory()
        let store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { _ in true })
        try writeRunnerSession(pid: 100, nanos: 1, sessionId: "android", in: directory)
        store.recordOwner(udid: "emulator-5554", runnerPid: 100)
        let command = try HierarchyCommand.parse(["--udid", "emulator-5554"])
        XCTAssertEqual(try command.locateSession(store: store).sessionId, "android")
    }

    func testAndroidSessionReadsTheHierarchyThroughThePlatformAndDetaches() async throws {
        let directory = try temporaryDirectory()
        let store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { _ in true })
        try writeRunnerSession(pid: 100, nanos: 1, sessionId: "android", in: directory)
        store.recordOwner(udid: "emulator-5554", runnerPid: 100)
        var command = try HierarchyCommand.parse(["--format", "json"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        try await command.run(store: store)
        XCTAssertEqual(fake.calls, ["attachDriver(emulator-5554,-)", "detach"])
    }

    func testAndroidSessionDetachesWhenTheReadFails() async throws {
        let directory = try temporaryDirectory()
        let store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { _ in true })
        try writeRunnerSession(pid: 100, nanos: 1, sessionId: "android", in: directory)
        store.recordOwner(udid: "emulator-5554", runnerPid: 100)
        var command = try HierarchyCommand.parse(["--format", "json"])
        let fake = FakeDevicePlatform(platform: .android)
        fake.hierarchyXML = "<hierarchy><broken>"
        command.devicePlatform = InjectedDevicePlatform(fake)
        await XCTAssertThrowsErrorAsync(try await command.run(store: store))
        XCTAssertEqual(fake.calls, ["attachDriver(emulator-5554,-)", "detach"])
    }

    /// `runner start` on Android used to leave exactly this behind: the
    /// runner's port-0 session file and no owner sidecar. It must not fall
    /// into the iOS path and request http://127.0.0.1:0/source.
    func testAnOwnerlessPortZeroSessionIsRejectedWithAClearMessage() async throws {
        let directory = try temporaryDirectory()
        let store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { _ in true })
        try writeRunnerSession(pid: 100, nanos: 1, sessionId: "ownerless", in: directory, port: 0)
        let command = try HierarchyCommand.parse([])
        do {
            try await command.run(store: store)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("records no device"), "\(error)")
        }
    }

    // MARK: - Agent errors (I15)

    func testATimeoutIsOneActionableLine() {
        let error = HierarchyCommand.agentError(URLError(.timedOut), port: 8129, timeout: 0.01)
        XCTAssertEqual(
            error.localizedDescription,
            "GrantivaAgent on port 8129 did not answer within 0.01s (--timeout). Is the run still alive?"
        )
        XCTAssertEqual(
            HierarchyCommand.agentError(URLError(.timedOut), port: 8129, timeout: 60).localizedDescription,
            "GrantivaAgent on port 8129 did not answer within 60s (--timeout). Is the run still alive?"
        )
    }

    func testARefusedConnectionNamesThePortAndTheKeepAliveRun() {
        let message = HierarchyCommand.agentError(URLError(.cannotConnectToHost), port: 8129, timeout: 60).localizedDescription
        XCTAssertEqual(
            message,
            "Cannot reach GrantivaAgent on port 8129. Is the grantiva run --keep-alive session still alive?"
        )
        XCTAssertFalse(message.contains("NSURLErrorDomain"))
    }

    func testOtherErrorsPassThrough() {
        let error = HierarchyCommand.agentError(GrantivaError.invalidImage, port: 1, timeout: 1)
        XCTAssertEqual(error.localizedDescription, GrantivaError.invalidImage.localizedDescription)
    }

    func testAnIOSSessionWhoseAgentIsGoneFailsWithTheMappedMessage() async throws {
        let directory = try temporaryDirectory()
        let store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { _ in true })
        // Port 9 (discard) on loopback has no listener: connection refused.
        try writeRunnerSession(pid: 100, nanos: 1, sessionId: "ios", in: directory, port: 9)
        let command = try HierarchyCommand.parse(["--timeout", "5"])
        do {
            try await command.run(store: store)
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                "Cannot reach GrantivaAgent on port 9. Is the grantiva run --keep-alive session still alive?"
            )
        }
    }

    private func writeRunnerSession(pid: Int, nanos: Int, sessionId: String, in directory: URL, port: Int? = nil) throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "version": 1, "sessionId": sessionId, "createdAt": "2026-10-07T10:00:00Z",
            "pid": pid, "port": port ?? 8100 + pid, "outputDir": "/tmp/out",
        ])
        try data.write(to: directory.appendingPathComponent("\(pid)-\(nanos).grantiva"))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-hierarchy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    // `--json` was advertised (GlobalOptions) but never read, so it printed XML.
    func testJSONFlagSelectsJSONOutput() throws {
        XCTAssertEqual(try HierarchyCommand.parse(["--json"]).outputFormat, .json)
        XCTAssertEqual(try HierarchyCommand.parse(["--json", "--format", "json"]).outputFormat, .json)
        XCTAssertEqual(try HierarchyCommand.parse([]).outputFormat, .xml)
        XCTAssertEqual(try HierarchyCommand.parse(["--format", "json"]).outputFormat, .json)
    }

    func testJSONFlagWithXMLFormatIsAUsageError() {
        XCTAssertThrowsError(try HierarchyCommand.parse(["--json", "--format", "xml"])) { error in
            XCTAssertEqual(HierarchyCommand.exitCode(for: error), .validationFailure)
        }
    }
}

func XCTAssertThrowsErrorAsync(_ expression: @autoclosure () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
    do {
        try await expression()
        XCTFail("expected an error", file: file, line: line)
    } catch {}
}
