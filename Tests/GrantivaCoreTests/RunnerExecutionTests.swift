import Foundation
import XCTest
@testable import GrantivaCore

/// Exercises the spawn/relay/readiness path with a stand-in for
/// grantiva-runner. The real runner (and the WebDriverAgent and simctl
/// processes it starts) cannot run in a unit test, but everything the CLI side
/// owns can.
final class RunnerExecutionTests: XCTestCase {
    private var scratch: URL!
    private var leaseDirectory: String!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-execution-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        leaseDirectory = scratch.appendingPathComponent("locks").path
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private func request(
        script: String,
        lease: SimulatorLease,
        pathMap: [String: String] = [:],
        reportDir: String? = nil,
        readyFile: ReadyFileSignal = ReadyFileSignal(path: nil),
        timeoutSeconds: UInt64 = 30,
        expectedFlows: Int = 1
    ) -> RunnerExecution.Request {
        RunnerExecution.Request(
            executable: "/bin/sh",
            arguments: ["-c", script],
            workingDirectory: scratch.path,
            lease: lease,
            keepAlive: false,
            timeoutSeconds: timeoutSeconds,
            pathMap: pathMap,
            reportDir: reportDir ?? scratch.path,
            expectedFlows: expectedFlows,
            readyFile: readyFile
        )
    }

    func testReportsExitStatusAndCapturesStderr() async throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        defer { lease.release() }

        let outcome = await RunnerExecution.run(request(
            script: "echo boom >&2; exit 3", lease: lease
        ))
        XCTAssertEqual(outcome.terminationStatus, 3)
        XCTAssertTrue(outcome.stderr.contains("boom"), outcome.stderr)
        XCTAssertFalse(outcome.timedOut)
    }

    func testRecordsTheRunnerPIDOnTheLease() async throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        defer { lease.release() }

        _ = await RunnerExecution.run(request(script: "exit 0", lease: lease))
        let claim = try XCTUnwrap(SimulatorLease.claim(udid: "SIM-1", directory: leaseDirectory))
        XCTAssertNotNil(claim.runnerPID)
    }

    func testATimeoutIsReportedAndTheGroupIsKilled() async throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        defer { lease.release() }

        let outcome = await RunnerExecution.run(request(
            script: "trap '' INT; sleep 30", lease: lease, timeoutSeconds: 1
        ))
        XCTAssertTrue(outcome.timedOut)
        XCTAssertNotEqual(outcome.terminationStatus, 0)
    }

    func testTheReadyFileIsWrittenWhenTheReportGoesTerminal() async throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        defer { lease.release() }

        let reportDir = scratch.appendingPathComponent("report")
        try FileManager.default.createDirectory(at: reportDir, withIntermediateDirectories: true)
        let readyPath = scratch.appendingPathComponent("ready.json").path
        let signal = ReadyFileSignal(path: readyPath)

        // The stand-in writes a finished report and then keeps running, the way
        // a --keep-alive session holds the app after its flows complete.
        let report = reportDir.appendingPathComponent("report.json").path
        let outcome = await RunnerExecution.run(request(
            script: """
            printf '{"status":"passed","flows":[{"name":"advertise","status":"passed"}]}' > \(report)
            sleep 2
            """,
            lease: lease,
            reportDir: reportDir.path,
            readyFile: signal,
            timeoutSeconds: 30
        ))

        XCTAssertEqual(outcome.terminationStatus, 0)
        XCTAssertTrue(signal.hasWritten)
        let state = try ReadyFile.read(readyPath)
        XCTAssertEqual(state.status, "passed")
        XCTAssertEqual(state.flows.first?.name, "advertise")
    }
}
