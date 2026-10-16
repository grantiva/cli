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


    /// N-01: a holder that has exited but whose parent has not reaped it yet
    /// (a harness that waits on it only after `runner stop` returns) is a
    /// zombie. `kill(pid, 0)` still succeeds on it, so `runner stop` waited
    /// its full 30 s and failed although the holder had exited 0.
    func testAnExitedButUnreapedProcessIsNotAlive() throws {
        var pid: pid_t = 0
        let argv: [UnsafeMutablePointer<CChar>?] = [strdup("/usr/bin/true"), nil]
        defer { argv.forEach { free($0) } }
        XCTAssertEqual(posix_spawn(&pid, "/usr/bin/true", nil, nil, argv, nil), 0)
        var reaped = false
        defer { if !reaped { var status: Int32 = 0; waitpid(pid, &status, 0) } }
        // Wait for it to exit without reaping it.
        var info = siginfo_t()
        XCTAssertEqual(waitid(P_PID, id_t(pid), &info, WEXITED | WNOWAIT), 0)
        XCTAssertEqual(kill(pid, 0), 0, "a zombie still answers kill(pid, 0)")
        XCTAssertFalse(KeepAliveSessionStore.processIsAlive(pid))
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        reaped = true
        XCTAssertFalse(KeepAliveSessionStore.processIsAlive(pid))
        XCTAssertTrue(KeepAliveSessionStore.processIsAlive(getpid()))
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

    /// C14 (B2-K88): with this project's own runner still starting, a lookup
    /// without --udid answered from another project's published iOS session.
    /// This project's session, starting or not, comes first; another
    /// project's is used only when this one has none.
    func testThisProjectsSessionIsPreferredEvenWhileItIsStarting() throws {
        let other = directory.appendingPathComponent("other-project").path
        try writeRunnerSession(pid: 400, nanos: 1, port: 8240, sessionId: "theirs")
        try write(KeepAliveOwner(udid: "A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF", runnerPid: 400, projectDirectory: other, platform: .ios))
        try write(KeepAliveOwner(udid: "emulator-5562", runnerPid: 401, projectDirectory: directory.path, platform: .android))
        let store = store(live: [400, 401, getpid()])

        let mine = try store.locateIncludingStarting(udid: nil, projectDirectory: directory.path)
        XCTAssertEqual(mine.pid, 401)
        XCTAssertFalse(mine.isPublished)
        XCTAssertThrowsError(try store.locate(udid: nil, projectDirectory: directory.path)) { error in
            XCTAssertTrue("\(error)".contains("starting"), "\(error)")
        }
        // A project with no session of its own still falls back to the newest.
        let elsewhere = directory.appendingPathComponent("third-project").path
        XCTAssertEqual(try store.locateIncludingStarting(udid: nil, projectDirectory: elsewhere).pid, 400)
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

    /// K56: the owner sidecar records the app ID the session launched, and
    /// the live session carries it; an older sidecar without it reads nil.
    func testOwnerSidecarRoundTripsTheAppID() throws {
        try writeRunnerSession(pid: 300, nanos: 1, port: 8235, sessionId: "s300")
        try writeRunnerSession(pid: 301, nanos: 2, port: 8236, sessionId: "s301")
        let store = store(live: [300, 301])
        store.recordOwner(udid: "A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF", runnerPid: 300, projectDirectory: directory.path, platform: .ios, appID: "com.kylebrowning.Landmarks")
        store.recordOwner(udid: "C2C8E2D3-F7E6-4FBF-A2FE-7A25B9363961", runnerPid: 301, projectDirectory: directory.path, platform: .ios)

        let owner = try XCTUnwrap(KeepAliveSessionStore.loadOwner(path: store.ownerPath(runnerPid: 300)))
        XCTAssertEqual(owner.appId, "com.kylebrowning.Landmarks")
        let sessions = store.liveSessions()
        XCTAssertEqual(sessions.first { $0.pid == 300 }?.appId, "com.kylebrowning.Landmarks")
        XCTAssertNil(sessions.first { $0.pid == 301 }?.appId)

        // A sidecar from an earlier Grantiva has no appId key at all.
        let legacy = #"{"udid":"C2C8E2D3-F7E6-4FBF-A2FE-7A25B9363961","runnerPid":301,"grantivaPid":1,"createdAt":"2026-10-07T10:00:00Z"}"#
        try Data(legacy.utf8).write(to: URL(fileURLWithPath: store.ownerPath(runnerPid: 301)))
        XCTAssertNil(try XCTUnwrap(KeepAliveSessionStore.loadOwner(path: store.ownerPath(runnerPid: 301))).appId)
    }

    // MARK: - L12: a dead runner's file with no sidecar left

    func testRemoveSessionsDropsADeadRunnersFileThatHasNoSidecar() throws {
        let dead = try writeRunnerSession(pid: 12109, nanos: 1_791_747_326_192_132_000, port: 8987, sessionId: "dead")
        let live = try writeRunnerSession(pid: 300, nanos: 1_791_747_326_192_132_001, port: 8988, sessionId: "live")
        let removed = store(live: [300]).removeSessions(udid: "7E846901-F93F-4220-A153-7043061033D7")
        XCTAssertEqual(removed, [dead])
        XCTAssertTrue(FileManager.default.fileExists(atPath: live))
    }

    func testRemoveSessionsKeepsADeadRunnersFileWhoseSidecarNamesAnotherDevice() throws {
        let other = try writeRunnerSession(pid: 999, nanos: 1, port: 8101, sessionId: "other")
        try write(KeepAliveOwner(udid: "OTHER-UDID", runnerPid: 999))
        let removed = store(live: []).removeSessions(udid: "7E846901-F93F-4220-A153-7043061033D7")
        XCTAssertEqual(removed, [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: other))
    }

    // MARK: - L38-a: a session whose runner is up but has not published yet

    func testAStartingSessionIsALiveOwnerWithoutARunnerFile() throws {
        try write(KeepAliveOwner(
            udid: "emulator-5554", runnerPid: 400, projectDirectory: "/private/tmp/p", platform: .android, detached: true
        ))
        try write(KeepAliveOwner(
            udid: "emulator-5556", runnerPid: 401, projectDirectory: "/private/tmp/p", platform: .android, detached: true
        ))
        try writeRunnerSession(pid: 401, nanos: 1, port: 0, sessionId: "ready")
        try write(KeepAliveOwner(udid: "emulator-5558", runnerPid: 402, projectDirectory: "/private/tmp/p", platform: .android, detached: true))

        let starting = store(live: [400, 401]).startingSessions()
        XCTAssertEqual(starting.map(\.runnerPid), [400], "ready (401) and dead (402) runners are not starting")
    }

    func testAnAttachedStartingSessionWhoseGrantivaIsGoneIsNotStarting() throws {
        try write(KeepAliveOwner(
            udid: "emulator-5554", runnerPid: 400, grantivaPid: 77, projectDirectory: "/private/tmp/p", platform: .android, detached: false
        ))
        XCTAssertEqual(store(live: [400]).startingSessions(), [])
        XCTAssertEqual(store(live: [400, 77]).startingSessions().map(\.runnerPid), [400])
    }

    // MARK: - L52/L54/L55: one lookup for published and starting sessions

    func testTheSharedLookupReturnsOwnerOnlySessionsAfterPublishedOnes() throws {
        try writeRunnerSession(pid: 500, nanos: 1, port: 8100, sessionId: "published")
        try write(KeepAliveOwner(udid: "emulator-5554", runnerPid: 500, grantivaPid: 50, projectDirectory: "/private/tmp/p",
                                 platform: .android, detached: false))
        try write(KeepAliveOwner(udid: "emulator-5556", runnerPid: 501, grantivaPid: 51, projectDirectory: "/private/tmp/p",
                                 platform: .android, detached: false, appId: "com.example", command: KeepAliveOwner.runnerStartCommand))

        let sessions = store(live: [500, 50, 501, 51]).sessions()
        XCTAssertEqual(sessions.map(\.pid), [500, 501])
        XCTAssertEqual(sessions.map(\.isPublished), [true, false])
        let starting = sessions[1]
        XCTAssertEqual(starting.udid, "emulator-5556")
        XCTAssertEqual(starting.ownerPid, 51)
        XCTAssertEqual(starting.port, 0)
        XCTAssertEqual(starting.projectDirectory, "/private/tmp/p")
        XCTAssertEqual(starting.appId, "com.example")
        XCTAssertTrue(starting.isForegroundRunnerStart)
        XCTAssertFalse(sessions[0].isForegroundRunnerStart)
    }

    /// An owner whose holder is dead is an orphan: skipped by default,
    /// included for `runner stop` and teardown. A dead runner is never a
    /// session.
    func testTheSharedLookupSkipsDeadHoldersUnlessOrphansAreIncluded() throws {
        try write(KeepAliveOwner(udid: "emulator-5554", runnerPid: 600, grantivaPid: 60, detached: false))
        try write(KeepAliveOwner(udid: "emulator-5556", runnerPid: 601, grantivaPid: 61, detached: false))
        let store = store(live: [600, 61])
        XCTAssertEqual(store.sessions().map(\.pid), [])
        XCTAssertEqual(store.sessions(includingOrphans: true).map(\.pid), [600])
    }

    /// L52: `hierarchy` names a run still in its flows as starting.
    func testLocatingASessionThatHasNotPublishedSaysItIsStarting() throws {
        let udid = "921A0945-7157-4533-BA1F-21E8132D3E40"
        try write(KeepAliveOwner(udid: udid, runnerPid: 700, grantivaPid: 70, platform: .ios, detached: false))
        let store = store(live: [700, 70])
        XCTAssertThrowsError(try store.locate(udid: udid)) { error in
            XCTAssertEqual(error.localizedDescription, RunnerSessionInfo.startingError(platform: .ios).localizedDescription)
        }
        XCTAssertThrowsError(try store.locate()) { error in
            XCTAssertTrue(error.localizedDescription.contains("is starting"), error.localizedDescription)
        }
        XCTAssertEqual(try store.locateIncludingStarting(udid: udid).isPublished, false)
    }
}
