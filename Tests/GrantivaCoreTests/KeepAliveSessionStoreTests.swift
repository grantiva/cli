import Foundation
import XCTest
@testable import GrantivaCore

/// Discovery of `grantiva run --keep-alive` sessions. The runner's session file
/// and grantiva's UDID sidecar are written by hand; process liveness is injected.
final class KeepAliveSessionStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-keepalive-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func store(live: Set<Int32>) -> KeepAliveSessionStore {
        KeepAliveSessionStore(directory: directory.path, isProcessAlive: { live.contains($0) })
    }

    /// Mirrors the runner's own file: `<pid>-<unix nanos>.grantiva`.
    @discardableResult
    private func writeRunnerSession(pid: Int32, nanos: Int64, port: Int, sessionId: String) throws -> String {
        let json: [String: Any] = [
            "version": 1, "sessionId": sessionId, "createdAt": "2026-10-07T10:00:00.123456789-07:00",
            "pid": pid, "port": port, "outputDir": "/tmp/out",
        ]
        let path = directory.appendingPathComponent("\(pid)-\(nanos).grantiva").path
        try JSONSerialization.data(withJSONObject: json).write(to: URL(fileURLWithPath: path))
        return path
    }

    func testNewestLiveSessionIsSelectedWhenNoUDIDIsGiven() throws {
        try writeRunnerSession(pid: 100, nanos: 1_791_340_000_000_000_000, port: 8100, sessionId: "older")
        try writeRunnerSession(pid: 200, nanos: 1_791_340_478_890_825_000, port: 8577, sessionId: "newer")

        let session = try store(live: [100, 200]).locate()
        XCTAssertEqual(session.sessionId, "newer")
        XCTAssertEqual(session.port, 8577)
        XCTAssertEqual(session.pid, 200)
        XCTAssertNil(session.udid)
    }

    func testUDIDSelectsTheSessionRecordedForThatSimulator() throws {
        let wanted = "921A0945-7157-4533-BA1F-21E8132D3E40"
        let other = "11111111-2222-3333-4444-555555555555"
        try writeRunnerSession(pid: 100, nanos: 1, port: 8100, sessionId: "wanted")
        try writeRunnerSession(pid: 200, nanos: 2, port: 8200, sessionId: "other-newer")
        let store = store(live: [100, 200])
        store.recordOwner(udid: wanted, runnerPid: 100)
        store.recordOwner(udid: other, runnerPid: 200)

        let session = try store.locate(udid: wanted)
        XCTAssertEqual(session.sessionId, "wanted")
        XCTAssertEqual(session.udid, wanted)

        XCTAssertThrowsError(try store.locate(udid: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("No keep-alive session for udid"), message)
            XCTAssertTrue(message.contains(wanted), message)
        }
    }

    func testSessionsWhoseRunnerHasExitedAreSkipped() throws {
        try writeRunnerSession(pid: 100, nanos: 1, port: 8100, sessionId: "live")
        try writeRunnerSession(pid: 999, nanos: 2, port: 8999, sessionId: "stale-but-newer")
        let store = store(live: [100])
        store.recordOwner(udid: "921A0945-7157-4533-BA1F-21E8132D3E40", runnerPid: 999)

        XCTAssertEqual(try store.locate().sessionId, "live")
        XCTAssertEqual(store.liveSessions().map(\.pid), [100])
        // The stale runner's UDID must not resolve to anything either.
        XCTAssertThrowsError(try store.locate(udid: "921A0945-7157-4533-BA1F-21E8132D3E40"))
    }

    func testNoLiveSessionsIsReportedWithTheStartHint() throws {
        let empty = store(live: [])
        XCTAssertThrowsError(try empty.locate()) { error in
            // K46: the shared no-session text, not an "Invalid argument".
            XCTAssertEqual(
                error.localizedDescription,
                "No active runner session. Start one with `grantiva runner start` or `grantiva run --keep-alive`."
            )
        }

        try writeRunnerSession(pid: 100, nanos: 1, port: 8100, sessionId: "dead")
        XCTAssertThrowsError(try store(live: []).locate()) { error in
            XCTAssertTrue(String(describing: error).contains("grantiva run --keep-alive"))
        }

        let missing = KeepAliveSessionStore(
            directory: directory.appendingPathComponent("does-not-exist").path, isProcessAlive: { _ in true }
        )
        XCTAssertThrowsError(try missing.locate())
    }

    func testCorruptAndForeignFilesAreIgnored() throws {
        try Data("not json".utf8).write(to: directory.appendingPathComponent("300-5.grantiva"))
        try Data("{}".utf8).write(to: directory.appendingPathComponent("301-6.grantiva"))
        try Data("ignored".utf8).write(to: directory.appendingPathComponent("notes.txt"))
        try writeRunnerSession(pid: 100, nanos: 1, port: 8100, sessionId: "valid")

        XCTAssertEqual(try store(live: [100, 300, 301]).locate().sessionId, "valid")
    }

    func testOwnerSidecarRoundTripsAndIsRemoved() throws {
        let store = store(live: [100])
        let udid = "921A0945-7157-4533-BA1F-21E8132D3E40"
        let owner = try XCTUnwrap(store.recordOwner(udid: udid, runnerPid: 100))
        XCTAssertEqual(owner.runnerPid, 100)
        XCTAssertEqual(owner.grantivaPid, getpid())

        let path = directory.appendingPathComponent("100.owner.json").path
        XCTAssertEqual(KeepAliveSessionStore.loadOwner(path: path)?.udid, udid)

        store.removeOwner(runnerPid: 100)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }

    /// C03: the sidecar records where the session was started and for which
    /// platform, and discovery surfaces both.
    func testOwnerRecordsTheProjectDirectoryAndPlatform() throws {
        let store = store(live: [100, 200])
        try writeRunnerSession(pid: 100, nanos: 1, port: 8100, sessionId: "ios")
        try writeRunnerSession(pid: 200, nanos: 2, port: 0, sessionId: "android")
        let project = directory.appendingPathComponent("project/../project")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        store.recordOwner(udid: "921A0945-7157-4533-BA1F-21E8132D3E40", runnerPid: 100, projectDirectory: project.path)
        store.recordOwner(udid: "emulator-5554", runnerPid: 200, projectDirectory: project.path)

        let canonical = KeepAliveOwner.canonicalDirectory(directory.appendingPathComponent("project").path)
        let sessions = Dictionary(uniqueKeysWithValues: store.liveSessions().map { ($0.sessionId, $0) })
        XCTAssertEqual(sessions["ios"]?.projectDirectory, canonical)
        XCTAssertEqual(sessions["ios"]?.platform, .ios)
        XCTAssertEqual(sessions["android"]?.projectDirectory, canonical)
        XCTAssertEqual(sessions["android"]?.platform, .android)
        XCTAssertFalse(canonical.contains(".."))
    }

    func testCanonicalDirectoryResolvesSymlinks() {
        XCTAssertEqual(KeepAliveOwner.canonicalDirectory("/tmp"), KeepAliveOwner.canonicalDirectory("/private/tmp"))
        // K104: resolved, not undone: realpath(3) spells /tmp as /private/tmp.
        XCTAssertEqual(KeepAliveOwner.canonicalDirectory("/tmp"), "/private/tmp")
        XCTAssertEqual(KeepAliveOwner.canonicalDirectory("/private/tmp"), "/private/tmp")
        // A directory that does not exist keeps its standardized spelling.
        XCTAssertEqual(KeepAliveOwner.canonicalDirectory("/no/such/dir/../x"), "/no/such/x")
    }

    /// K104: a sidecar written by 2.1.0 recorded the `/tmp` spelling; it still
    /// matches a project canonicalised to `/private/tmp`.
    func testOwnerRecordedWithTheTmpSpellingStillMatches() throws {
        try writeRunnerSession(pid: 100, nanos: 1, port: 8100, sessionId: "old")
        let legacy = #"{"createdAt":"2026-10-11T07:28:18Z","grantivaPid":1,"platform":"ios","projectDirectory":"/tmp","runnerPid":100,"udid":"921A0945-7157-4533-BA1F-21E8132D3E40"}"#
        try Data(legacy.utf8).write(to: directory.appendingPathComponent("100.owner.json"))
        let sessions = store(live: [100, 1]).liveSessions()
        XCTAssertEqual(sessions.first?.projectDirectory, "/private/tmp")
        XCTAssertEqual(sessions.first?.projectDirectory, KeepAliveOwner.canonicalDirectory("/tmp"))
    }

    func testRecordOwnerStoresThePrivateSpelling() throws {
        let owner = try XCTUnwrap(store(live: []).recordOwner(
            udid: "921A0945-7157-4533-BA1F-21E8132D3E40", runnerPid: 100, projectDirectory: "/tmp"
        ))
        XCTAssertEqual(owner.projectDirectory, "/private/tmp")
    }

    // MARK: - K79: a run --keep-alive owner that died

    func testARunOwnerWhoseGrantivaIsDeadIsExcluded() throws {
        try writeRunnerSession(pid: 100, nanos: 1, port: 8100, sessionId: "orphan")
        let store = store(live: [100])
        let owner = KeepAliveOwner(udid: "921A0945-7157-4533-BA1F-21E8132D3E40", runnerPid: 100, grantivaPid: 4163, detached: false)
        try write(owner)

        XCTAssertTrue(store.liveSessions().isEmpty)
        XCTAssertThrowsError(try store.locate())
        // Teardown and `runner stop` still see it, to clean it up.
        XCTAssertEqual(store.liveSessions(includingOrphans: true).map(\.pid), [100])
    }

    func testADetachedRunnerStartOwnerWithADeadStarterIsIncluded() throws {
        try writeRunnerSession(pid: 100, nanos: 1, port: 8100, sessionId: "detached")
        let store = store(live: [100])
        try write(KeepAliveOwner(udid: "921A0945-7157-4533-BA1F-21E8132D3E40", runnerPid: 100, grantivaPid: 4163, detached: true))

        let sessions = store.liveSessions()
        XCTAssertEqual(sessions.map(\.sessionId), ["detached"])
        XCTAssertEqual(sessions.first?.ownerPid, 4163)
        XCTAssertEqual(sessions.first?.detached, true)
    }

    func testAnAttachedOwnerWhoseGrantivaIsAliveIsIncluded() throws {
        try writeRunnerSession(pid: 100, nanos: 1, port: 8100, sessionId: "attached")
        try write(KeepAliveOwner(udid: "921A0945-7157-4533-BA1F-21E8132D3E40", runnerPid: 100, grantivaPid: 4163, detached: false))
        XCTAssertEqual(store(live: [100, 4163]).liveSessions().map(\.sessionId), ["attached"])
    }

    func testRecordOwnerKeepsWhetherTheSessionIsDetached() throws {
        let store = store(live: [])
        let owner = try XCTUnwrap(store.recordOwner(udid: "emulator-5554", runnerPid: 100, detached: true))
        XCTAssertEqual(owner.detached, true)
        let path = directory.appendingPathComponent("100.owner.json").path
        XCTAssertEqual(KeepAliveSessionStore.loadOwner(path: path)?.detached, true)
    }

    // MARK: - K87

    func testRemoveSessionFilesDeletesTheRunnerFileEvenWhileThePidLooksAlive() throws {
        let runnerFile = try writeRunnerSession(pid: 100, nanos: 1, port: 8100, sessionId: "stopped")
        try writeRunnerSession(pid: 1000, nanos: 2, port: 8200, sessionId: "other")
        let store = store(live: [100, 1000])
        store.recordOwner(udid: "921A0945-7157-4533-BA1F-21E8132D3E40", runnerPid: 100)

        let removed = store.removeSessionFiles(runnerPid: 100)
        XCTAssertEqual(Set(removed), [runnerFile, directory.appendingPathComponent("100.owner.json").path])
        XCTAssertFalse(FileManager.default.fileExists(atPath: runnerFile))
        XCTAssertEqual(store.liveSessions().map(\.pid), [1000])
    }

    private func write(_ owner: KeepAliveOwner) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(owner).write(to: directory.appendingPathComponent("\(owner.runnerPid).owner.json"))
    }

    func testASessionWithPortZeroIsListedBecauseAndroidRunnersPublishNoPort() throws {
        try writeRunnerSession(pid: 100, nanos: 1, port: 0, sessionId: "android")

        let sessions = store(live: [100]).liveSessions()
        XCTAssertEqual(sessions.map(\.sessionId), ["android"])
        XCTAssertEqual(sessions.first?.port, 0)
    }

    func testANegativePortIsStillRejected() throws {
        try writeRunnerSession(pid: 100, nanos: 1, port: -1, sessionId: "bad")

        XCTAssertTrue(store(live: [100]).liveSessions().isEmpty)
    }

    func testOrderFallsBackToModificationDateForUnexpectedNames() throws {
        let old = directory.appendingPathComponent("old.grantiva")
        let new = directory.appendingPathComponent("new.grantiva")
        let body: (String) throws -> Data = {
            try JSONSerialization.data(withJSONObject: ["sessionId": $0, "pid": 100, "port": 8100])
        }
        try body("old").write(to: old)
        try body("new").write(to: new)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -60)], ofItemAtPath: old.path)
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: new.path)

        XCTAssertEqual(try store(live: [100]).locate().sessionId, "new")
    }
}
