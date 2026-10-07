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
        expectedFlows: Int = 1,
        keepAlive: Bool = false,
        sessions: KeepAliveSessionStore? = nil,
        sessionFileGrace: TimeInterval = 10
    ) -> RunnerExecution.Request {
        var request = RunnerExecution.Request(
            executable: "/bin/sh",
            arguments: ["-c", script],
            workingDirectory: scratch.path,
            lease: lease,
            keepAlive: keepAlive,
            timeoutSeconds: timeoutSeconds,
            pathMap: pathMap,
            reportDir: reportDir ?? scratch.path,
            expectedFlows: expectedFlows,
            readyFile: readyFile
        )
        if let sessions { request.sessions = sessions }
        request.sessionFileGrace = sessionFileGrace
        return request
    }

    /// A scratch directory standing in for /tmp/grantiva-sessions, with the
    /// real pid liveness check.
    private func sessionStore() -> KeepAliveSessionStore {
        KeepAliveSessionStore(directory: scratch.appendingPathComponent("sessions").path)
    }

    func testKeepAliveRecordsTheUDIDSidecarBeforeTheReadyFileAndRemovesItOnExit() async throws {
        let udid = "921A0945-7157-4533-BA1F-21E8132D3E40"
        let lease = try SimulatorLease.acquire(udid: udid, directory: leaseDirectory)
        defer { lease.release() }
        let store = sessionStore()
        let sessionsDir = store.directory

        let reportDir = scratch.appendingPathComponent("report")
        try FileManager.default.createDirectory(at: reportDir, withIntermediateDirectories: true)
        let readyPath = scratch.appendingPathComponent("ready.json").path
        let signal = ReadyFileSignal(path: readyPath)
        let report = reportDir.appendingPathComponent("report.json").path
        let listing = scratch.appendingPathComponent("at-flow-end.txt").path

        // The stand-in behaves like grantiva-runner --keep-alive: it finishes
        // its flows, then (a beat later) publishes its session file and holds.
        // It snapshots the sessions dir when the flows finish so the test can
        // prove the UDID sidecar was already there.
        let outcome = await RunnerExecution.run(request(
            script: """
            printf '{"status":"passed","flows":[{"name":"advertise","status":"passed"}]}' > \(report)
            ls \(sessionsDir) > \(listing) 2>/dev/null
            sleep 0.5
            printf '{"version":1,"sessionId":"abc","createdAt":"x","pid":%d,"port":8577,"outputDir":"/o"}' $$ > \(sessionsDir)/$$-1791340478890825000.grantiva
            sleep 1.5
            """,
            lease: lease,
            reportDir: reportDir.path,
            readyFile: signal,
            keepAlive: true,
            sessions: store
        ))
        XCTAssertEqual(outcome.terminationStatus, 0)

        // The sidecar existed when the flows finished — before any ready file.
        let atFlowEnd = try String(contentsOfFile: listing, encoding: .utf8)
        XCTAssertTrue(atFlowEnd.contains(".owner.json"), atFlowEnd)

        // The ready file waited for the runner's session file, so a waiter
        // that then runs `grantiva hierarchy --udid` finds a resolvable session.
        XCTAssertTrue(signal.hasWritten)
        let sessionFile = try XCTUnwrap(
            try FileManager.default.contentsOfDirectory(atPath: sessionsDir).first { $0.hasSuffix(".grantiva") }
        )
        let readyMTime = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: readyPath)[.modificationDate] as? Date
        )
        let sessionMTime = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: "\(sessionsDir)/\(sessionFile)")[.modificationDate] as? Date
        )
        XCTAssertGreaterThanOrEqual(readyMTime, sessionMTime)

        // Once the runner is gone the sidecar is removed and nothing resolves.
        let remaining = try FileManager.default.contentsOfDirectory(atPath: sessionsDir)
        XCTAssertFalse(remaining.contains { $0.hasSuffix(".owner.json") }, "\(remaining)")
        XCTAssertThrowsError(try store.locate(udid: udid))
    }

    func testKeepAliveReadyFileIsNotHeldForeverWhenNoSessionFileAppears() async throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        defer { lease.release() }

        let reportDir = scratch.appendingPathComponent("report")
        try FileManager.default.createDirectory(at: reportDir, withIntermediateDirectories: true)
        let readyPath = scratch.appendingPathComponent("ready.json").path
        let signal = ReadyFileSignal(path: readyPath)
        let report = reportDir.appendingPathComponent("report.json").path

        let outcome = await RunnerExecution.run(request(
            script: """
            printf '{"status":"passed","flows":[{"name":"advertise","status":"passed"}]}' > \(report)
            sleep 2
            """,
            lease: lease,
            reportDir: reportDir.path,
            readyFile: signal,
            keepAlive: true,
            sessions: sessionStore(),
            sessionFileGrace: 0.3
        ))
        XCTAssertEqual(outcome.terminationStatus, 0)
        XCTAssertTrue(signal.hasWritten)
        XCTAssertEqual(try ReadyFile.read(readyPath).status, "passed")
    }

    func testNonKeepAliveRunsWriteNoSidecar() async throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        defer { lease.release() }
        let store = sessionStore()
        _ = await RunnerExecution.run(request(script: "exit 0", lease: lease, sessions: store))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.directory))
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

    func testPreparedReportDirectoryCannotPublishAStaleReadyVerdict() async throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        defer { lease.release() }

        let reportDir = scratch.appendingPathComponent("reused-report")
        try FileManager.default.createDirectory(at: reportDir, withIntermediateDirectories: true)
        let report = reportDir.appendingPathComponent("report.json")
        try Data(#"{"status":"passed","flows":[{"name":"old","status":"passed"}]}"#.utf8)
            .write(to: report)
        try RunnerReportWorkspace.prepare(at: reportDir.path)

        let readyPath = scratch.appendingPathComponent("reused-ready.json").path
        let signal = ReadyFileSignal(path: readyPath)
        let outcome = await RunnerExecution.run(request(
            script: """
            sleep 1
            printf '{"status":"failed","flows":[{"name":"current","status":"failed"}]}' > \(report.path)
            sleep 1
            """,
            lease: lease,
            reportDir: reportDir.path,
            readyFile: signal,
            timeoutSeconds: 30
        ))

        XCTAssertEqual(outcome.terminationStatus, 0)
        let state = try ReadyFile.read(readyPath)
        XCTAssertEqual(state.status, "failed")
        XCTAssertEqual(state.flows.first?.name, "current")
    }
}
