import Darwin
import Foundation
import XCTest
@testable import GrantivaCore

/// L36: a teardown's stop request, readable from any directory.
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

    func testAMarkedLiveRunnerIsSeenByItsOwner() throws {
        let runner = try sleeper()
        defer { runner.terminate() }
        let marker = RunnerStopMarker(directory: directory)
        let started = RunnerStopMarker.processStartTime(runner.processIdentifier)
        XCTAssertNotNil(started)
        XCTAssertFalse(marker.isMarked(runnerPid: runner.processIdentifier, runnerStartTime: started))
        XCTAssertTrue(marker.mark(runnerPid: runner.processIdentifier))
        XCTAssertTrue(marker.isMarked(runnerPid: runner.processIdentifier, runnerStartTime: started))
        marker.remove(runnerPid: runner.processIdentifier)
        XCTAssertFalse(marker.isMarked(runnerPid: runner.processIdentifier, runnerStartTime: started))
    }

    /// A marker left for an earlier process with the same pid never counts.
    func testAStaleMarkerIsIgnored() throws {
        let marker = RunnerStopMarker(directory: directory, startTime: { _ in 1_791_700_000 })
        XCTAssertTrue(marker.mark(runnerPid: 4242))
        XCTAssertTrue(marker.isMarked(runnerPid: 4242, runnerStartTime: 1_791_700_000))
        XCTAssertFalse(marker.isMarked(runnerPid: 4242, runnerStartTime: 1_791_799_999), "same pid, another process")
        XCTAssertFalse(marker.isMarked(runnerPid: 4242, runnerStartTime: nil))
    }

    func testADeadPidIsNeverMarked() {
        let marker = RunnerStopMarker(directory: directory, startTime: { _ in nil })
        XCTAssertFalse(marker.mark(runnerPid: 4242))
        XCTAssertFalse(FileManager.default.fileExists(atPath: "\(directory!)/4242"))
    }
}
