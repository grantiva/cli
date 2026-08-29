import Foundation
import XCTest
@testable import GrantivaCore

/// `--ready-file` replaces a hand-rolled poll of `report.json`, which is
/// rewritten incrementally and therefore cannot be waited on by existence.
final class ReadyFileTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-ready-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    func testWritesTheTerminalStatusSoAWaiterCanTellPassFromFail() throws {
        let path = scratch.appendingPathComponent("ready.json").path
        try ReadyFile.write(
            RunReadyState(status: "failed", flows: [.init(name: "advertise", status: "failed")]),
            to: path
        )

        let state = try ReadyFile.read(path)
        XCTAssertEqual(state.status, "failed")
        XCTAssertFalse(state.passed)
        XCTAssertEqual(state.flows.first?.name, "advertise")
    }

    func testWriteLeavesNoPartialFileBehind() throws {
        let path = scratch.appendingPathComponent("ready.json").path
        try ReadyFile.write(RunReadyState(status: "passed", flows: []), to: path)
        try ReadyFile.write(RunReadyState(status: "failed", flows: []), to: path)

        // A rename-based write leaves exactly the target, no temp siblings for a
        // waiter to trip over.
        let entries = try FileManager.default.contentsOfDirectory(atPath: scratch.path)
        XCTAssertEqual(entries, ["ready.json"])
        XCTAssertEqual(try ReadyFile.read(path).status, "failed")
    }

    func testSignalWritesOnlyOnce() throws {
        let path = scratch.appendingPathComponent("ready.json").path
        let signal = ReadyFileSignal(path: path)

        XCTAssertTrue(signal.write(RunReadyState(status: "passed", flows: [])))
        XCTAssertFalse(signal.write(RunReadyState(status: "failed", flows: [])))
        XCTAssertEqual(try ReadyFile.read(path).status, "passed")
    }

    func testSignalWithoutAPathIsANoOp() {
        let signal = ReadyFileSignal(path: nil)
        XCTAssertFalse(signal.write(RunReadyState(status: "passed", flows: [])))
        XCTAssertFalse(signal.hasWritten)
    }

    // MARK: - report.json completion detection

    private func index(_ json: String) throws -> RunnerReportIndex {
        try JSONDecoder().decode(RunnerReportIndex.self, from: Data(json.utf8))
    }

    func testARunningReportIsNotComplete() throws {
        let report = try index("""
        {"updateSeq": 4, "status": "running", "flows": [
            {"name": "advertise", "status": "running"}
        ]}
        """)
        XCTAssertFalse(report.isComplete(expectedFlows: 1))
    }

    func testAPendingFlowIsNotComplete() throws {
        let report = try index("""
        {"status": "running", "flows": [
            {"name": "advertise", "status": "passed"},
            {"name": "scan", "status": "pending"}
        ]}
        """)
        XCTAssertFalse(report.isComplete(expectedFlows: 2))
    }

    func testFewerFlowsThanExpectedIsNotComplete() throws {
        // The runner registers flows as it reaches them; one finished flow does
        // not mean the suite is done.
        let report = try index("""
        {"status": "running", "flows": [{"name": "advertise", "status": "passed"}]}
        """)
        XCTAssertFalse(report.isComplete(expectedFlows: 2))
    }

    func testAllTerminalFlowsAreComplete() throws {
        let report = try index("""
        {"status": "running", "flows": [
            {"name": "advertise", "status": "passed"},
            {"name": "scan", "status": "failed"}
        ]}
        """)
        XCTAssertTrue(report.isComplete(expectedFlows: 2))
        XCTAssertEqual(report.readyState.status, "failed")
    }

    func testAFailedRunWithNoFlowEntriesIsStillComplete() throws {
        let report = try index("""
        {"status": "failed", "flows": []}
        """)
        XCTAssertTrue(report.isComplete(expectedFlows: 1))
        XCTAssertEqual(report.readyState.status, "failed")
    }

    func testPassingFlowsProducePassed() throws {
        let report = try index("""
        {"status": "passed", "flows": [{"name": "advertise", "status": "passed"}]}
        """)
        XCTAssertTrue(report.isComplete(expectedFlows: 1))
        XCTAssertTrue(report.readyState.passed)
    }

    func testLoadsFromAReportDirectory() throws {
        let reportDir = scratch.appendingPathComponent("report")
        try FileManager.default.createDirectory(at: reportDir, withIntermediateDirectories: true)
        try #"{"status":"passed","flows":[]}"#
            .write(to: reportDir.appendingPathComponent("report.json"), atomically: true, encoding: .utf8)

        let report = try XCTUnwrap(RunnerReportIndex.load(reportDir: reportDir.path))
        XCTAssertEqual(report.status, "passed")
        XCTAssertNil(RunnerReportIndex.load(reportDir: scratch.appendingPathComponent("missing").path))
    }
}
