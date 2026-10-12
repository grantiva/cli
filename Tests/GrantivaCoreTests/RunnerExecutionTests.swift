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
        sessionFileGrace: TimeInterval = 10,
        readyReportDir: String? = nil
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
        request.readyReportDir = readyReportDir
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
            cp -p \(sessionsDir)/$$-1791340478890825000.grantiva \(scratch.path)/published.grantiva
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
        let readyMTime = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: readyPath)[.modificationDate] as? Date
        )
        // A copy taken as the runner published (the stand-in, unlike the
        // runner, does not remove its own file on exit; grantiva does, L12).
        let sessionMTime = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: scratch.appendingPathComponent("published.grantiva").path)[.modificationDate] as? Date
        )
        XCTAssertGreaterThanOrEqual(readyMTime, sessionMTime)

        // Once the runner is gone its session files are removed and nothing resolves.
        let remaining = try FileManager.default.contentsOfDirectory(atPath: sessionsDir)
        XCTAssertEqual(remaining, [], "\(remaining)")
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

    /// A06: Ctrl-C during a running flow. The relay used to reap the runner
    /// first, so the session saw a non-zero exit and published `failed` with
    /// the flow still `running`, and the `interrupted` cleanup was dropped.
    func testASimulatedSIGINTDuringARunningFlowPublishesInterrupted() async throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        defer { lease.release() }
        defer { SignalRelay.shared.resetTerminationForTesting() }

        let reportDir = scratch.appendingPathComponent("report")
        try FileManager.default.createDirectory(at: reportDir, withIntermediateDirectories: true)
        let report = reportDir.appendingPathComponent("report.json").path
        let readyPath = scratch.appendingPathComponent("ready.json").path
        let signal = ReadyFileSignal(path: readyPath)

        let interrupter = Task.detached {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            SignalRelay.shared.simulateTerminationForTesting()
        }
        let outcome = await RunnerExecution.run(request(
            script: """
            printf '{"status":"running","flows":[{"name":"qa-longwait","status":"running"}]}' > \(report)
            sleep 30
            """,
            lease: lease,
            reportDir: reportDir.path,
            readyFile: signal,
            timeoutSeconds: 60
        ))
        _ = try? await interrupter.value

        XCTAssertTrue(outcome.interrupted)
        XCTAssertFalse(outcome.timedOut)
        let state = try ReadyFile.read(readyPath)
        XCTAssertEqual(state.status, "interrupted")
        XCTAssertEqual(state.flows, [RunReadyState.Flow(name: "qa-longwait", status: "interrupted")])
        XCTAssertNil(state.reportDir, "an ephemeral report dir is deleted on exit and must not be advertised")
    }

    func testTheWatcherAdvertisesOnlyThePreservedReportDir() async throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        defer { lease.release() }

        for preserved in [false, true] {
            let reportDir = scratch.appendingPathComponent("report-\(preserved)")
            try FileManager.default.createDirectory(at: reportDir, withIntermediateDirectories: true)
            let report = reportDir.appendingPathComponent("report.json").path
            let readyPath = scratch.appendingPathComponent("ready-\(preserved).json").path
            let signal = ReadyFileSignal(path: readyPath)
            _ = await RunnerExecution.run(request(
                script: """
                printf '{"status":"passed","flows":[{"name":"a","status":"passed"}]}' > \(report)
                sleep 1
                """,
                lease: lease,
                reportDir: reportDir.path,
                readyFile: signal,
                readyReportDir: preserved ? reportDir.path : nil
            ))
            XCTAssertEqual(try ReadyFile.read(readyPath).reportDir, preserved ? reportDir.path : nil)
        }
    }

    // MARK: - L11/L12: a keep-alive runner that dies on its own

    /// The stand-in publishes its session file, leaves a descendant that
    /// ignores SIGTERM and holds the output pipe (as WebDriverAgent's
    /// xcodebuild can), then dies of SIGHUP. grantiva must notice within a
    /// few seconds, name the signal, and remove both session files.
    func testAKeepAliveRunnerKilledBySIGHUPIsNoticedAndItsFilesRemoved() async throws {
        let udid = "921A0945-7157-4533-BA1F-21E8132D3E40"
        let lease = try SimulatorLease.acquire(udid: udid, directory: leaseDirectory)
        defer { lease.release() }
        let store = sessionStore()
        let pidFile = scratch.appendingPathComponent("runner.pid").path
        let started = Date()
        let outcome = await RunnerExecution.run(request(
            script: """
            mkdir -p \(store.directory)
            echo $$ > \(pidFile)
            printf '{"version":1,"sessionId":"abc","createdAt":"x","pid":%d,"port":8577,"outputDir":"/o"}' $$ > \(store.directory)/$$-1791340478890825000.grantiva
            (trap '' TERM INT; exec sleep 8) &
            sleep 0.3
            kill -HUP $$
            sleep 30
            """,
            lease: lease,
            keepAlive: true,
            sessions: store
        ))
        let elapsed = Date().timeIntervalSince(started)
        if let pid = try? String(contentsOfFile: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           let runnerPid = Int32(pid) {
            kill(-runnerPid, SIGKILL)
        }
        XCTAssertLessThan(elapsed, 5, "grantiva kept waiting on a dead runner")
        XCTAssertEqual(outcome.terminatingSignal, SIGHUP)
        XCTAssertEqual(RunnerExecution.exitDescription(outcome), "killed by SIGHUP")
        let remaining = (try? FileManager.default.contentsOfDirectory(atPath: store.directory)) ?? []
        XCTAssertEqual(remaining, [], "the dead runner's session file and sidecar must go")
    }

    func testAnOrdinaryExitIsDescribedByItsStatus() {
        let outcome = RunnerExecution.Outcome(terminationStatus: 3, stderr: "", timedOut: false)
        XCTAssertEqual(RunnerExecution.exitDescription(outcome), "exit 3")
    }

    // MARK: - L56: a release after the hold ends with the earned status

    /// A stand-in for a keep-alive runner whose flows are over: it writes the
    /// report (`flowStatus`), publishes its session file and holds; SIGINT
    /// releases the hold and it exits `releaseStatus`, as the runner does.
    private func holdingRunner(report: String, sessions: String, flowStatus: String, releaseStatus: Int?) -> String {
        """
        \(releaseStatus.map { "trap 'exit \($0)' INT" } ?? "trap '' INT")
        printf '{"status":"\(flowStatus)","flows":[{"name":"f","status":"\(flowStatus)"}]}' > \(report)
        mkdir -p \(sessions)
        printf '{"version":1,"sessionId":"abc","createdAt":"x","pid":%d,"port":8577,"outputDir":"/o"}' $$ > \(sessions)/$$-1791340478890825000.grantiva
        while :; do sleep 0.1; done
        """
    }

    /// Sends one signal through the relay once the hold is armed (the ready
    /// file is written after arming); returns whether the relay would exit.
    private func signalOnceArmed(readyPath: String, release: @escaping @Sendable (pid_t) -> Void = SignalRelay.releaseGroup) -> Task<Bool, Never> {
        Task.detached {
            // The hold is armed before the ready file is written.
            for _ in 0..<400 where !FileManager.default.fileExists(atPath: readyPath) {
                try? await Task.sleep(nanoseconds: 25_000_000)
            }
            return SignalRelay.shared.simulateSignalForTesting(SIGINT, release: release)
        }
    }

    func testAReleaseAfterTheHoldEndsWithTheRunnersFailedStatusNotAnInterrupt() async throws {
        defer { SignalRelay.shared.resetTerminationForTesting() }
        let lease = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        defer { lease.release() }
        let store = sessionStore()
        let reportDir = scratch.appendingPathComponent("report")
        try FileManager.default.createDirectory(at: reportDir, withIntermediateDirectories: true)
        let readyPath = scratch.appendingPathComponent("ready.json").path

        let signal = signalOnceArmed(readyPath: readyPath)
        let outcome = await RunnerExecution.run(request(
            script: holdingRunner(report: reportDir.appendingPathComponent("report.json").path, sessions: store.directory,
                                  flowStatus: "failed", releaseStatus: 1),
            lease: lease, reportDir: reportDir.path, readyFile: ReadyFileSignal(path: readyPath),
            keepAlive: true, sessions: store
        ))
        let wouldExit = await signal.value
        XCTAssertFalse(wouldExit, "a release must not exit 130")
        XCTAssertFalse(outcome.interrupted)
        XCTAssertEqual(outcome.terminationStatus, 1)
        XCTAssertTrue(SignalRelay.shared.isReleasingHold)
        XCTAssertFalse(SignalRelay.shared.isTerminating)
        XCTAssertEqual(try ReadyFile.read(readyPath).status, "failed", "the ready file is written once")
    }

    func testAReleaseAfterTheHoldOfAPassedRunEndsWithStatusZero() async throws {
        defer { SignalRelay.shared.resetTerminationForTesting() }
        let lease = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        defer { lease.release() }
        let store = sessionStore()
        let reportDir = scratch.appendingPathComponent("report")
        try FileManager.default.createDirectory(at: reportDir, withIntermediateDirectories: true)
        let readyPath = scratch.appendingPathComponent("ready.json").path

        let signal = signalOnceArmed(readyPath: readyPath)
        let outcome = await RunnerExecution.run(request(
            script: holdingRunner(report: reportDir.appendingPathComponent("report.json").path, sessions: store.directory,
                                  flowStatus: "passed", releaseStatus: 0),
            lease: lease, reportDir: reportDir.path, readyFile: ReadyFileSignal(path: readyPath),
            keepAlive: true, sessions: store
        ))
        let wouldExit = await signal.value
        XCTAssertFalse(wouldExit)
        XCTAssertFalse(outcome.interrupted)
        XCTAssertEqual(outcome.terminationStatus, 0)
    }

    /// A released runner that exits 130, or is killed by the release's
    /// escalation, ended as an interrupt: `interrupted`, ready file as
    /// written.
    func testAReleasedRunnerThatExits130OrDiesByASignalIsInterrupted() async throws {
        let cases: [(String, Int?)] = [("exit-130", 130), ("killed", nil)]
        for (name, releaseStatus) in cases {
            defer { SignalRelay.shared.resetTerminationForTesting() }
            let lease = try SimulatorLease.acquire(udid: "SIM-\(name)", directory: leaseDirectory)
            defer { lease.release() }
            let store = KeepAliveSessionStore(directory: scratch.appendingPathComponent("sessions-\(name)").path)
            let reportDir = scratch.appendingPathComponent("report-\(name)")
            try FileManager.default.createDirectory(at: reportDir, withIntermediateDirectories: true)
            let readyPath = scratch.appendingPathComponent("ready-\(name).json").path
            // The runner that ignores SIGINT stands in for one the
            // escalation has to kill.
            let killGroup: @Sendable (pid_t) -> Void = { pgid in _ = kill(-pgid, SIGKILL) }
            let release = releaseStatus == nil ? killGroup : SignalRelay.releaseGroup
            let signal = signalOnceArmed(readyPath: readyPath, release: release)
            let outcome = await RunnerExecution.run(request(
                script: holdingRunner(report: reportDir.appendingPathComponent("report.json").path, sessions: store.directory,
                                      flowStatus: "passed", releaseStatus: releaseStatus),
                lease: lease, reportDir: reportDir.path, readyFile: ReadyFileSignal(path: readyPath),
                keepAlive: true, sessions: store
            ))
            let wouldExit = await signal.value
            XCTAssertFalse(wouldExit, name)
            XCTAssertTrue(outcome.interrupted, name)
            XCTAssertEqual(try ReadyFile.read(readyPath).status, "passed", "\(name): the ready file is written once")
        }
    }

    /// Before the hold is armed (flows still running) a signal interrupts,
    /// as today: the outcome is `interrupted` and the relay would exit 130.
    func testASignalDuringTheFlowsIsStillAnInterrupt() async throws {
        defer { SignalRelay.shared.resetTerminationForTesting() }
        let lease = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        defer { lease.release() }
        let store = sessionStore()
        let started = scratch.appendingPathComponent("started").path
        let signal = Task.detached {
            for _ in 0..<200 where !FileManager.default.fileExists(atPath: started) {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            return SignalRelay.shared.simulateSignalForTesting(SIGINT)
        }
        let outcome = await RunnerExecution.run(request(
            script: "touch \(started); while :; do sleep 0.1; done",
            lease: lease, keepAlive: true, sessions: store
        ))
        let wouldExit = await signal.value
        XCTAssertTrue(wouldExit)
        XCTAssertTrue(outcome.interrupted)
    }

    /// A second signal while a release is under way interrupts (exit 130).
    func testASecondSignalDuringAReleaseInterrupts() {
        defer { SignalRelay.shared.resetTerminationForTesting() }
        SignalRelay.shared.track(group: 424_242, deviceNoun: "simulator")
        defer { SignalRelay.shared.untrack(group: 424_242) }
        SignalRelay.shared.armHold(group: 424_242)
        let released = Locked<[pid_t]>([])
        XCTAssertFalse(SignalRelay.shared.simulateSignalForTesting(SIGINT, release: { released.append($0) }))
        XCTAssertEqual(released.value, [424_242])
        SignalRelay.shared.untrack(group: 424_242)
        XCTAssertTrue(SignalRelay.shared.simulateSignalForTesting(SIGINT, release: { released.append($0) }))
        XCTAssertEqual(released.value, [424_242])
    }
}
