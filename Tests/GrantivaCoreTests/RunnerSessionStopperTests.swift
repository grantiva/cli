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

    private func writeRunnerFile(pid: Int32) throws {
        let json: [String: Any] = ["sessionId": "s\(pid)", "pid": pid, "port": 8100]
        try JSONSerialization.data(withJSONObject: json).write(to: directory.appendingPathComponent("\(pid)-1.grantiva"))
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
            cleanupOrphans: { events.append("orphans \($0)") },
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
