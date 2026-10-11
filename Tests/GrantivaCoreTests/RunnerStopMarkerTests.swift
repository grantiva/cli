import Darwin
import Foundation
import XCTest
@testable import GrantivaCore

/// L36: a teardown's stop request, readable from any directory and any
/// runner home, and never left behind.
final class RunnerStopMarkerTests: XCTestCase {
    private var directory: String!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-stops-\(UUID().uuidString)").path
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: directory)
    }

    private func sleeper() throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]
        try process.run()
        return process
    }

    private func markers() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []).filter { $0.hasSuffix(".stop.json") }
    }

    func testTheMarkerLivesBesideTheOwnerFilesWhateverTheRunnerHome() {
        XCTAssertEqual(RunnerStopMarker().directory, KeepAliveSessionStore.defaultDirectory)
        XCTAssertEqual(RunnerStopMarker().path(42), "/tmp/grantiva-sessions/42.stop.json")
    }

    func testAMarkedLiveRunnerIsSeenByItsOwner() throws {
        let runner = try sleeper()
        defer { runner.terminate() }
        let marker = RunnerStopMarker(directory: directory)
        let started = RunnerStopMarker.processStartTime(runner.processIdentifier)
        XCTAssertNotNil(started)
        XCTAssertFalse(marker.isMarked(runnerPid: runner.processIdentifier, runnerStartTime: started))
        XCTAssertTrue(try marker.mark(runnerPid: runner.processIdentifier, ownerPid: getpid()))
        XCTAssertTrue(marker.isMarked(runnerPid: runner.processIdentifier, runnerStartTime: started))
        marker.remove(runnerPid: runner.processIdentifier)
        XCTAssertFalse(marker.isMarked(runnerPid: runner.processIdentifier, runnerStartTime: started))
    }

    /// A marker left for an earlier process with the same pid never counts,
    /// and the next sweep removes it.
    func testAStaleMarkerIsIgnoredAndSwept() throws {
        let marker = RunnerStopMarker(directory: directory, startTime: { _ in 1_791_700_000 }, isProcessAlive: { _ in true })
        XCTAssertTrue(try marker.mark(runnerPid: 4242, ownerPid: 77))
        XCTAssertTrue(marker.isMarked(runnerPid: 4242, runnerStartTime: 1_791_700_000))
        XCTAssertFalse(marker.isMarked(runnerPid: 4242, runnerStartTime: 1_791_799_999), "same pid, another process")
        let reused = RunnerStopMarker(directory: directory, startTime: { _ in 1_791_799_999 }, isProcessAlive: { _ in true })
        XCTAssertEqual(reused.sweep().count, 1)
        XCTAssertEqual(markers(), [])
    }

    func testADeadPidIsNeverMarked() throws {
        let marker = RunnerStopMarker(directory: directory, startTime: { _ in nil })
        XCTAssertFalse(try marker.mark(runnerPid: 4242, ownerPid: getpid()))
        XCTAssertEqual(markers(), [])
    }

    /// The holder reads its marker after its runner died: the marker stays
    /// while the holder lives, and goes once the holder is gone too.
    func testAMarkerStaysForALiveHolderAndGoesWithIt() throws {
        let alive = LockedSet([77])
        let marker = RunnerStopMarker(directory: directory, startTime: { $0 == 4242 ? 1_791_700_000 : nil }, isProcessAlive: { alive.contains($0) })
        XCTAssertTrue(try marker.mark(runnerPid: 4242, ownerPid: 77))
        let afterRunnerDied = RunnerStopMarker(directory: directory, startTime: { _ in nil }, isProcessAlive: { alive.contains($0) })
        XCTAssertEqual(afterRunnerDied.sweep(), [])
        XCTAssertFalse(afterRunnerDied.removeUnlessHeld(runnerPid: 4242))
        alive.remove(77)
        XCTAssertEqual(afterRunnerDied.sweep().count, 1)
        XCTAssertEqual(markers(), [])
    }

    /// A `runner start` killed with SIGKILL (and its runner with it) never
    /// removes its marker; the next sweep does.
    func testASIGKILLedStartsMarkerIsGoneAfterTheNextSweep() throws {
        let holder = try sleeper()
        let runner = try sleeper()
        let marker = RunnerStopMarker(directory: directory)
        XCTAssertTrue(try marker.mark(runnerPid: runner.processIdentifier, ownerPid: holder.processIdentifier))
        for process in [holder, runner] {
            kill(process.processIdentifier, SIGKILL)
            var status: Int32 = 0
            _ = waitpid(process.processIdentifier, &status, 0)
        }
        XCTAssertEqual(markers().count, 1)
        marker.sweep()
        XCTAssertEqual(markers(), [])
    }

    func testAMarkerThatCannotBeWrittenThrows() throws {
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-stops-file-\(UUID().uuidString)").path
        FileManager.default.createFile(atPath: blocker, contents: Data())
        defer { try? FileManager.default.removeItem(atPath: blocker) }
        let marker = RunnerStopMarker(directory: "\(blocker)/sessions", startTime: { _ in 1 })
        XCTAssertThrowsError(try marker.mark(runnerPid: 4242, ownerPid: getpid()))
    }

    /// The session-file sweeps take a marker with its owner file once its
    /// holder is gone, and leave it for a holder that is alive.
    func testOwnerFileSweepsTakeTheMarkerOnlyOnceItsHolderIsGone() throws {
        let alive = LockedSet([77])
        let store = KeepAliveSessionStore(directory: directory, isProcessAlive: { alive.contains($0) })
        let marker = RunnerStopMarker(directory: directory, startTime: { $0 == 4242 ? 1 : nil }, isProcessAlive: { alive.contains($0) })
        XCTAssertTrue(try marker.mark(runnerPid: 4242, ownerPid: 77))
        store.removeSessionFiles(runnerPid: 4242)
        XCTAssertEqual(markers(), ["4242.stop.json"], "the holder still reads it")
        alive.remove(77)
        XCTAssertEqual(store.removeSessionFiles(runnerPid: 4242), ["\(directory!)/4242.stop.json"])
        XCTAssertEqual(markers(), [])
    }
}

private final class LockedSet: @unchecked Sendable {
    private let lock = NSLock()
    private var values: Set<Int32>
    init(_ values: Set<Int32>) { self.values = values }
    func contains(_ value: Int32) -> Bool { lock.withLock { values.contains(value) } }
    func remove(_ value: Int32) { _ = lock.withLock { values.remove(value) } }
}
