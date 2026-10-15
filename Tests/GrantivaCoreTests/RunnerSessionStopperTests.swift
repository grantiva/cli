import Foundation
import XCTest
@testable import GrantivaCore

/// K14/K15/K87: stopping a keep-alive session, whoever holds it.
final class RunnerSessionStopperTests: XCTestCase {
    private let udid = "921A0945-7157-4533-BA1F-21E8132D3E40"
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-stopper-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testAnAttachedSessionIsReleasedThroughItsGrantivaProcess() async throws {
        let alive = Locked<Set<Int32>>([700, 701])
        let events = Locked<[String]>([])
        var stopper = makeStopper(alive: alive, events: events)
        stopper.parentPid = { $0 == 701 ? 700 : nil }
        stopper.interrupt = { pid in events.append("interrupt \(pid)"); alive.mutate { $0.subtract([700, 701]) } }
        let session = KeepAliveSession(sessionId: "s", port: 8100, pid: 701, udid: udid, path: "/x", ownerPid: 700, detached: false)

        let outcome = try await stopper.stop(session)
        XCTAssertEqual(outcome, .released(grantivaPid: 700, runnerPid: 701, udid: udid))
        XCTAssertEqual(events.value, ["interrupt 700", "files 701"])
    }

    func testAGrantivaThatDoesNotExitIsAnError() async throws {
        let alive = Locked<Set<Int32>>([700, 701])
        let events = Locked<[String]>([])
        var stopper = makeStopper(alive: alive, events: events)
        stopper.parentPid = { _ in 700 }
        stopper.waitTimeout = 0.2
        let session = KeepAliveSession(sessionId: "s", port: 8100, pid: 701, udid: udid, path: "/x", ownerPid: 700, detached: false)
        do {
            _ = try await stopper.stop(session)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("kill -INT 700"), error.localizedDescription)
        }
    }

    /// The owner pid is only trusted while it is still the runner's parent.
    func testAReusedOwnerPidIsNeverSignalled() async throws {
        let alive = Locked<Set<Int32>>([700, 701])
        let events = Locked<[String]>([])
        var stopper = makeStopper(alive: alive, events: events)
        stopper.parentPid = { _ in 1 }
        let session = KeepAliveSession(sessionId: "s", port: 8100, pid: 701, udid: udid, path: "/x", ownerPid: 700, detached: false)

        let outcome = try await stopper.stop(session)
        XCTAssertEqual(outcome, .terminated(runnerPid: 701, udid: udid, killed: false))
        XCTAssertEqual(events.value, ["terminate 701", "files 701", "lease \(udid)"])
    }

    func testAnOwnerThatIsNoLongerGrantivaIsNeverSignalled() async throws {
        let alive = Locked<Set<Int32>>([700, 701])
        let events = Locked<[String]>([])
        var stopper = makeStopper(alive: alive, events: events)
        stopper.parentPid = { _ in 700 }
        stopper.isGrantivaProcess = { _ in false }
        let session = KeepAliveSession(sessionId: "s", port: 8100, pid: 701, udid: udid, path: "/x", ownerPid: 700, detached: false)

        _ = try await stopper.stop(session)
        XCTAssertFalse(events.value.contains("interrupt 700"), "\(events.value)")
    }

    func testARunnerPidThatIsNoLongerARunnerIsNeverSignalled() async throws {
        let alive = Locked<Set<Int32>>([700, 701])
        let events = Locked<[String]>([])
        var stopper = makeStopper(alive: alive, events: events)
        stopper.parentPid = { _ in 700 }
        stopper.isRunnerProcess = { _ in false }
        let session = KeepAliveSession(sessionId: "s", port: 8100, pid: 701, udid: udid, path: "/x", ownerPid: 700, detached: false)

        let outcome = try await stopper.stop(session)
        XCTAssertEqual(outcome, .terminated(runnerPid: 701, udid: udid, killed: false))
        XCTAssertEqual(events.value, ["files 701", "lease \(udid)"], "neither pid is signalled")
    }

    func testADetachedSessionHasItsRunnerGroupTerminatedAndItsFilesRemoved() async throws {
        let alive = Locked<Set<Int32>>([701])
        let events = Locked<[String]>([])
        var stopper = makeStopper(alive: alive, events: events)
        stopper.terminateGroup = { pid in events.append("terminate \(pid)"); alive.mutate { $0.remove(pid) }; return .killed }
        let session = KeepAliveSession(sessionId: "s", port: 0, pid: 701, udid: "emulator-5554", path: "/x", ownerPid: 9, detached: true)

        let outcome = try await stopper.stop(session)
        XCTAssertEqual(outcome, .terminated(runnerPid: 701, udid: "emulator-5554", killed: true))
        XCTAssertEqual(events.value, ["terminate 701", "files 701", "orphans emulator-5554", "lease emulator-5554"])
    }

    func testADetachedAndroidSessionCleansOnlyItsRecordedForward() async throws {
        let alive = Locked<Set<Int32>>([701])
        let events = Locked<[String]>([])
        var stopper = makeStopper(alive: alive, events: events)
        stopper.terminateGroup = { pid in
            events.append("terminate \(pid)")
            alive.mutate { $0.remove(pid) }
            return .interrupted
        }
        let session = KeepAliveSession(
            sessionId: "s", port: 61211, pid: 701, udid: "emulator-5554",
            path: "/x", ownerPid: 9, detached: true
        )

        _ = try await stopper.stop(session)

        XCTAssertEqual(events.value, [
            "terminate 701", "files 701", "orphans emulator-5554", "forward emulator-5554 61211", "lease emulator-5554",
        ])
    }

    /// L04: a detached session's runner group is stopped while its helpers
    /// are watched; the device helper it left is reaped and reported.
    func testATerminatedRunnersDeviceHelperIsReapedAndReported() async throws {
        let alive = Locked<Set<Int32>>([701, 750])
        let events = Locked<[String]>([])
        let udid = udid
        let diagnose = "/usr/bin/simctl diagnose --no-archive --udid=\(udid)"
        let table = Locked("701 1 701 /x/grantiva-runner --device \(udid)\n740 701 701 /x/xcodebuild test-without-building -destination id=\(udid)")
        var stopper = makeStopper(alive: alive, events: events)
        stopper.terminateGroup = { pid in
            events.append("terminate \(pid)")
            table.mutate { $0 = "740 1 701 /x/xcodebuild test-without-building -destination id=\(udid)\n750 740 750 \(diagnose)" }
            usleep(200_000)
            table.mutate { $0 = "750 1 750 \(diagnose)" }
            alive.mutate { $0.remove(pid) }
            return .interrupted
        }
        stopper.helperReaper = RunnerHelperReaper(
            snapshot: { table.value },
            signal: { pid, _ in events.append("signal \(pid)"); alive.mutate { $0.remove(abs(pid)) } },
            isAlive: { alive.value.contains($0) },
            runnerBases: [], gracePeriod: 0.5, pollInterval: .milliseconds(10)
        )
        let session = KeepAliveSession(sessionId: "s", port: 8100, pid: 701, udid: udid, path: "/x", ownerPid: 9, detached: true)

        let outcome = try await stopper.stop(session)
        XCTAssertEqual(outcome, .terminated(runnerPid: 701, udid: udid, killed: false, reaped: [
            ReapedProcess(pid: 750, processGroup: 750, kind: .diagnose, command: diagnose, killed: true),
        ]))
        XCTAssertTrue(events.value.contains("signal 750"), "\(events.value)")
        XCTAssertFalse(alive.value.contains(750))
    }

    func testStopSessionsOnADeviceStopsOnlyThatDevicesSessions() async throws {
        try writeRunnerFile(pid: 701)
        try writeRunnerFile(pid: 801)
        let store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { [701, 801].contains($0) })
        store.recordOwner(udid: udid, runnerPid: 701, detached: true)
        store.recordOwner(udid: "11111111-2222-3333-4444-555555555555", runnerPid: 801, detached: true)
        let events = Locked<[String]>([])
        var stopper = makeStopper(alive: Locked([701, 801]), events: events)
        stopper.store = store

        let outcomes = await stopper.stopSessions(udid: udid, runnerStartSession: nil)
        XCTAssertEqual(outcomes.map(\.runnerPid), [701])
        XCTAssertTrue(events.value.contains("terminate 701"))
        XCTAssertFalse(events.value.contains("terminate 801"))
    }

    func testARunnerStartSessionFileForTheDeviceIsStoppedOnce() async throws {
        try writeRunnerFile(pid: 701)
        let store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { $0 == 701 })
        store.recordOwner(udid: udid, runnerPid: 701, detached: true)
        let events = Locked<[String]>([])
        var stopper = makeStopper(alive: Locked([701]), events: events)
        stopper.store = store
        let file = RunnerSessionInfo(pid: 701, wdaPort: 8100, bundleId: "b", udid: udid, startedAt: Date())

        let outcomes = await stopper.stopSessions(udid: udid, runnerStartSession: file)
        XCTAssertEqual(outcomes.map(\.runnerPid), [701])

        let other = RunnerSessionInfo(pid: 702, wdaPort: 8100, bundleId: "b", udid: udid, startedAt: Date())
        let none = KeepAliveSessionStore(directory: directory.appendingPathComponent("empty").path, isProcessAlive: { _ in true })
        stopper.store = none
        stopper.isProcessAlive = { $0 == 702 }
        let fromFile = await stopper.stopSessions(udid: udid, runnerStartSession: other)
        XCTAssertEqual(fromFile.map(\.runnerPid), [702])
        let elsewhere = await stopper.stopSessions(udid: "emulator-5554", runnerStartSession: other)
        XCTAssertTrue(elsewhere.isEmpty)
    }

    // MARK: - L54: a session whose runner has not published its file yet

    /// A `run --keep-alive` still in its flows: an owner sidecar with a live
    /// runner and holder, no `.grantiva` file. Its holder is interrupted, as
    /// for a published session; a sidecar for another device is left alone.
    func testAnUnpublishedKeepAliveRunOnTheDeviceIsInterruptedAndAnotherDevicesIsNot() async throws {
        let alive = Locked<Set<Int32>>([700, 701, 800, 801])
        let store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { alive.value.contains($0) })
        try overwriteOwner(KeepAliveOwner(udid: udid, runnerPid: 701, grantivaPid: 700, detached: false))
        try overwriteOwner(KeepAliveOwner(
            udid: "11111111-2222-3333-4444-555555555555", runnerPid: 801, grantivaPid: 800, detached: false
        ))
        let events = Locked<[String]>([])
        var stopper = makeStopper(alive: alive, events: events)
        stopper.store = store
        stopper.parentPid = { [701: 700, 801: 800][$0] }
        stopper.interrupt = { pid in events.append("interrupt \(pid)"); alive.mutate { $0.subtract([pid, pid + 1]) } }

        let outcomes = await stopper.stopSessions(udid: udid, runnerStartSession: nil)
        XCTAssertEqual(outcomes, [.released(grantivaPid: 700, runnerPid: 701, udid: udid)])
        XCTAssertEqual(events.value, ["interrupt 700", "files 701"])
    }

    /// A foreground `runner start` whose session flow has not armed the hold:
    /// found from its owner sidecar alone, and its runner's group is stopped
    /// (the holder reads the teardown's marker and exits 0) rather than the
    /// holder interrupted (which would exit 130).
    func testAnUnpublishedForegroundRunnerStartHasItsRunnerStoppedNotItsHolderInterrupted() async throws {
        let alive = Locked<Set<Int32>>([700, 701])
        let store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { alive.value.contains($0) })
        try overwriteOwner(KeepAliveOwner(
            udid: udid, runnerPid: 701, grantivaPid: 700, detached: false, command: KeepAliveOwner.runnerStartCommand
        ))
        let events = Locked<[String]>([])
        var stopper = makeStopper(alive: alive, events: events)
        stopper.store = store
        stopper.parentPid = { $0 == 701 ? 700 : nil }
        // The holder exits once its runner has gone.
        stopper.terminateGroup = { pid in
            events.append("terminate \(pid)"); alive.mutate { $0.subtract([701, 700]) }; return .interrupted
        }

        let outcomes = await stopper.stopSessions(udid: udid, runnerStartSession: nil)
        XCTAssertEqual(outcomes, [.released(grantivaPid: 700, runnerPid: 701, udid: udid)])
        XCTAssertEqual(events.value, ["terminate 701", "files 701"])
    }

    /// An orphan whose holder is dead is terminated only while its pid is
    /// still the runner the owner file recorded: a recycled pid (another
    /// start time) is never signalled, and the stale files still go.
    func testAnOrphanWhosePidWasRecycledIsNeverSignalled() async throws {
        let alive = Locked<Set<Int32>>([701])
        let store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { alive.value.contains($0) })
        try overwriteOwner(KeepAliveOwner(udid: udid, runnerPid: 701, grantivaPid: 700, detached: false, runnerStartTime: 1_000))
        let events = Locked<[String]>([])
        var stopper = makeStopper(alive: alive, events: events)
        stopper.store = store
        stopper.processStartTime = { _ in 2_000 }

        let recycled = await stopper.stopSessions(udid: udid, runnerStartSession: nil)
        XCTAssertEqual(recycled, [.terminated(runnerPid: 701, udid: udid, killed: false)])
        XCTAssertFalse(events.value.contains("terminate 701"), "\(events.value)")
        XCTAssertTrue(events.value.contains("files 701"), "\(events.value)")

        stopper.processStartTime = { _ in 1_000 }
        _ = await stopper.stopSessions(udid: udid, runnerStartSession: nil)
        XCTAssertTrue(events.value.contains("terminate 701"), "the recorded runner itself is stopped: \(events.value)")
    }

    /// An owner file written before `runnerStartTime` existed decodes with
    /// nil, and its orphaned runner is still terminated, matched by process
    /// name alone.
    func testALegacyOwnerFileWithoutAStartTimeIsStillTerminatedByName() async throws {
        let legacy = #"{"udid":"\#(udid)","runnerPid":701,"grantivaPid":700,"createdAt":"2026-10-07T10:00:00Z","detached":false}"#
        try Data(legacy.utf8).write(to: directory.appendingPathComponent("701.owner.json"))
        let owner = try XCTUnwrap(KeepAliveSessionStore.loadOwner(path: directory.appendingPathComponent("701.owner.json").path))
        XCTAssertNil(owner.runnerStartTime)

        let alive = Locked<Set<Int32>>([701])
        let events = Locked<[String]>([])
        var stopper = makeStopper(alive: alive, events: events)
        stopper.store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { alive.value.contains($0) })
        stopper.processStartTime = { _ in 2_000 }
        let outcomes = await stopper.stopSessions(udid: udid, runnerStartSession: nil)
        XCTAssertEqual(outcomes.map(\.runnerPid), [701])
        XCTAssertTrue(events.value.contains("terminate 701"), "\(events.value)")
    }

    /// `recordOwner` writes the runner's start time (additive key).
    func testTheOwnerFileRecordsTheRunnersStartTime() throws {
        let store = KeepAliveSessionStore(directory: directory.path)
        let owner = try XCTUnwrap(store.recordOwner(udid: udid, runnerPid: getpid()))
        XCTAssertEqual(owner.runnerStartTime, RunnerStopMarker.processStartTime(getpid()))
        let json = try String(contentsOf: directory.appendingPathComponent("\(getpid()).owner.json"), encoding: .utf8)
        XCTAssertTrue(json.contains("\"runnerStartTime\""), json)
    }

    private func overwriteOwner(_ owner: KeepAliveOwner) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(owner).write(to: directory.appendingPathComponent("\(owner.runnerPid).owner.json"))
    }

    private func writeRunnerFile(pid: Int32) throws {
        let json: [String: Any] = ["sessionId": "s\(pid)", "pid": pid, "port": 8100]
        try JSONSerialization.data(withJSONObject: json).write(to: directory.appendingPathComponent("\(pid)-1.grantiva"))
    }

    // MARK: - B4-L73.3: the project's .grantiva/session.json goes with the session

    private func projectWithSession(pid: Int32, udid: String) throws -> URL {
        let project = directory.appendingPathComponent("project-\(pid)")
        try FileManager.default.createDirectory(
            at: project.appendingPathComponent(".grantiva"), withIntermediateDirectories: true
        )
        try RunnerSessionInfo(pid: pid, wdaPort: 8403, bundleId: "a.b", udid: udid, startedAt: Date(), platform: .ios)
            .encoded().write(to: project.appendingPathComponent(RunnerSessionInfo.path))
        return project
    }

    func testStoppingADetachedSessionRemovesItsProjectSessionFile() async throws {
        let project = try projectWithSession(pid: 701, udid: udid)
        let alive = Locked<Set<Int32>>([701])
        let stopper = makeStopper(alive: alive, events: Locked<[String]>([]))
        let session = KeepAliveSession(
            sessionId: "s", port: 8403, pid: 701, udid: udid, path: "/x",
            projectDirectory: project.path, ownerPid: 9, detached: true
        )

        _ = try await stopper.stop(session)
        XCTAssertFalse(FileManager.default.fileExists(atPath: project.appendingPathComponent(RunnerSessionInfo.path).path))
    }

    func testStoppingAReleasedSessionRemovesItsProjectSessionFile() async throws {
        let project = try projectWithSession(pid: 701, udid: udid)
        let alive = Locked<Set<Int32>>([700, 701])
        var stopper = makeStopper(alive: alive, events: Locked<[String]>([]))
        stopper.parentPid = { $0 == 701 ? 700 : nil }
        stopper.interrupt = { _ in alive.mutate { $0.subtract([700, 701]) } }
        let session = KeepAliveSession(
            sessionId: "s", port: 8403, pid: 701, udid: udid, path: "/x",
            projectDirectory: project.path, ownerPid: 700, detached: false
        )

        _ = try await stopper.stop(session)
        XCTAssertFalse(FileManager.default.fileExists(atPath: project.appendingPathComponent(RunnerSessionInfo.path).path))
    }

    func testAProjectSessionFileOfAnotherRunnerIsKept() async throws {
        let project = try projectWithSession(pid: 999, udid: udid)
        let alive = Locked<Set<Int32>>([701])
        let stopper = makeStopper(alive: alive, events: Locked<[String]>([]))
        let session = KeepAliveSession(
            sessionId: "s", port: 8403, pid: 701, udid: udid, path: "/x",
            projectDirectory: project.path, ownerPid: 9, detached: true
        )

        _ = try await stopper.stop(session)
        XCTAssertTrue(FileManager.default.fileExists(atPath: project.appendingPathComponent(RunnerSessionInfo.path).path))
    }

    private func makeStopper(alive: Locked<Set<Int32>>, events: Locked<[String]>) -> RunnerSessionStopper {
        RunnerSessionStopper(
            store: KeepAliveSessionStore(directory: directory.path, isProcessAlive: { alive.value.contains($0) }),
            isProcessAlive: { alive.value.contains($0) },
            parentPid: { _ in nil },
            isRunnerProcess: { alive.value.contains($0) },
            isGrantivaProcess: { alive.value.contains($0) },
            interrupt: { events.append("interrupt \($0)") },
            terminateGroup: { pid in events.append("terminate \(pid)"); alive.mutate { $0.remove(pid) }; return .interrupted },
            removeSessionFiles: { events.append("files \($0)") },
            releaseLease: { events.append("lease \($0)") },
            cleanupOrphans: { serial in events.append("orphans \(serial)") },
            cleanupOwnedForward: { serial, port in events.append("forward \(serial) \(port)") },
            waitTimeout: 2,
            pollInterval: .milliseconds(10)
        )
    }
}

final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value
    init(_ value: Value) { storage = value }
    var value: Value { lock.withLock { storage } }
    func mutate(_ body: (inout Value) -> Void) { lock.withLock { body(&storage) } }
    func append<Element>(_ element: Element) where Value == [Element] { mutate { $0.append(element) } }
}
