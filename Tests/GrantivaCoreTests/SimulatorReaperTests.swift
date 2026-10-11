import Foundation
import XCTest
@testable import GrantivaCore

/// The matching rules `teardown --udid <UDID> --force` uses to find what is
/// holding a simulator. These replace the reporter's hand-written trap:
///
///     pkill -f "grantiva-runner .*--device $udid"
///     pkill -f "test-without-building .*-destination id=$udid"
///     pkill -f "simctl diagnose .*--udid=$udid"
final class SimulatorReaperTests: XCTestCase {
    private let udid = "A1B2C3D4-1111-2222-3333-444455556666"

    private var sample: String {
        """
          501   501 /Users/kyle/.grantiva/runner/grantiva-runner --platform ios --device \(udid) --no-ansi test --output /tmp/r flow.yaml
          502   501 /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test-without-building -destination id=\(udid) -xctestrun /tmp/wda.xctestrun
          503   501 /usr/bin/xcrun simctl diagnose --udid=\(udid) --no-archive
          504   504 /opt/homebrew/bin/grantiva run --flow flows/advertise.yaml --simulator \(udid) --keep-alive
          505   505 /bin/sh -c sleep 60
          506   506 /Users/kyle/.grantiva/runner/grantiva-runner --platform ios --device DEAD-BEEF --no-ansi test
          507   507 /opt/homebrew/bin/grantiva simulator teardown --udid \(udid) --force
        """
    }

    func testFindsRunnerWebDriverAgentAndDiagnose() {
        let found = SimulatorReaper.processes(owning: udid, psOutput: sample)
        let byPID = Dictionary(uniqueKeysWithValues: found.map { ($0.pid, $0.kind) })

        XCTAssertEqual(byPID[501], .runner)
        XCTAssertEqual(byPID[502], .webDriverAgent)
        XCTAssertEqual(byPID[503], .diagnose)
    }

    func testFindsTheLiveGrantivaRunHoldingTheLease() {
        // The usual culprit: a backgrounded `grantiva run --keep-alive` whose
        // SIGINT was ignored, still holding the lease with an empty session
        // ledger.
        let found = SimulatorReaper.processes(owning: udid, psOutput: sample)
        XCTAssertEqual(found.first { $0.pid == 504 }?.kind, .grantiva)
    }

    func testIgnoresProcessesForOtherSimulatorsAndUnrelatedWork() {
        let found = SimulatorReaper.processes(owning: udid, psOutput: sample)
        let pids = found.map(\.pid)
        XCTAssertFalse(pids.contains(505), "unrelated process matched")
        XCTAssertFalse(pids.contains(506), "another simulator's runner matched")
    }

    func testNeverMatchesTheTeardownCommandDoingTheReaping() {
        let found = SimulatorReaper.processes(owning: udid, psOutput: sample)
        XCTAssertFalse(found.map(\.pid).contains(507))
    }

    func testExcludesTheCallersOwnProcess() {
        let found = SimulatorReaper.processes(owning: udid, psOutput: sample, excludingPID: 501)
        XCTAssertFalse(found.map(\.pid).contains(501))
    }

    func testMatchingIsCaseInsensitiveOnTheUDID() {
        let found = SimulatorReaper.processes(owning: udid.lowercased(), psOutput: sample)
        XCTAssertFalse(found.isEmpty)
    }

    func testReportsProcessGroupsSoTheWholeTreeCanBeSignalled() {
        let found = SimulatorReaper.processes(owning: udid, psOutput: sample)
        XCTAssertEqual(found.first { $0.pid == 502 }?.processGroup, 501)
    }

    func testStaleLeasePIDReusedByUnrelatedProcessIsNotTargeted() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-reaper-tests-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let unrelated = Process()
        unrelated.executableURL = URL(fileURLWithPath: "/bin/sleep")
        unrelated.arguments = ["30"]
        try unrelated.run()
        defer {
            if unrelated.isRunning { unrelated.terminate() }
            unrelated.waitUntilExit()
        }

        let lease = try SimulatorLease.acquire(udid: udid, directory: directory)
        lease.handOff(to: unrelated.processIdentifier)
        let snapshot = "  \(unrelated.processIdentifier)  \(unrelated.processIdentifier) /bin/sleep 30"

        let result = try await SimulatorReaper.forceTeardown(
            udid: udid,
            capacity: SimulatorCapacity(directory: directory),
            leaseDirectory: directory,
            snapshot: { snapshot },
            gracePeriod: 0
        )

        XCTAssertTrue(result.processes.isEmpty)
        XCTAssertTrue(unrelated.isRunning)
        XCTAssertTrue(result.leaseReleased)
    }

    func testForceTeardownBreaksTheLeaseWhenNothingIsRunning() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-reaper-tests-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let lease = try SimulatorLease.acquire(udid: udid, directory: directory)
        defer { lease.release() }

        let result = try await SimulatorReaper.forceTeardown(
            udid: udid,
            capacity: SimulatorCapacity(directory: directory),
            leaseDirectory: directory,
            snapshot: { "" }
        )
        XCTAssertTrue(result.leaseReleased)
        XCTAssertEqual(result.udid, udid)

        // The whole point: the simulator can be claimed again afterwards.
        let claim = try SimulatorLease.acquire(udid: udid, directory: directory)
        claim.release()

        XCTAssertTrue(result.reclaimed, "breaking a held lease is real work")
    }

    // A `--force` teardown that found nothing is a success — the device was
    // already free — but it is not the same event as one that killed a stranded
    // runner, and the exit code is 0 either way. The JSON has to say which.
    func testAForceTeardownThatFoundNothingSaysSoInJSON() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-reaper-tests-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let result = try await SimulatorReaper.forceTeardown(
            udid: udid,
            capacity: SimulatorCapacity(directory: directory),
            leaseDirectory: directory,
            snapshot: { "" }
        )
        XCTAssertTrue(result.processes.isEmpty)
        XCTAssertFalse(result.leaseReleased)
        XCTAssertFalse(result.reclaimed)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any]
        )
        XCTAssertEqual(object["reclaimed"] as? Bool, false)
    }

    // MARK: - I09: keep live records, remove the killed runner's files

    private func temporaryDirectory() -> String {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-reaper-tests-\(UUID().uuidString)").path
        addTeardownBlock { try? FileManager.default.removeItem(atPath: directory) }
        return directory
    }

    private func writeRecords(_ records: [ManagedSimulatorSession], to directory: String) throws {
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(records).write(to: URL(fileURLWithPath: "\(directory)/sessions.json"))
    }

    private func record(_ udid: String, session: String, state: ManagedSimulatorSession.State = .active) -> ManagedSimulatorSession {
        ManagedSimulatorSession(udid: udid, name: "Sim \(udid.prefix(4))", sessionId: session, ownerPID: 4242, acquiredAt: Date(), state: state)
    }

    private func booted(_ udids: String...) -> [SimulatorDevice] {
        udids.map { SimulatorDevice(name: "Sim", udid: $0, state: "Booted", runtime: "iOS-26-0", isAvailable: true) }
    }

    private func forceTeardown(directory: String, sessionDirectory: String? = nil) async throws -> ForceTeardownResult {
        try await SimulatorReaper.forceTeardown(
            udid: udid,
            capacity: SimulatorCapacity(directory: directory),
            leaseDirectory: directory,
            runnerBase: "\(directory)/runner",
            sessions: KeepAliveSessionStore(directory: sessionDirectory ?? "\(directory)/sessions", isProcessAlive: { _ in false }),
            snapshot: { "" },
            gracePeriod: 0,
            isProcessAlive: { _ in false }
        )
    }

    // A named session outlives the CLI process that booted its device, so a
    // forced reclaim never drops its record while the device is booted.
    func testForceTeardownRemovesTheDeviceHomeUnderEveryRunnerVersion() async throws {
        let directory = temporaryDirectory()
        let fm = FileManager.default
        let homes = ["v1", "v2"].map { "\(directory)/runner/versions/\($0)/devices/\(udid)" }
        let other = "\(directory)/runner/versions/v1/devices/OTHER-1"
        for path in homes + [other] { try fm.createDirectory(atPath: path, withIntermediateDirectories: true) }

        let result = try await forceTeardown(directory: directory)

        XCTAssertEqual(Set(result.deviceHomesRemoved), Set(homes))
        XCTAssertEqual(result.deviceHomeFailures, [])
        for path in homes { XCTAssertFalse(fm.fileExists(atPath: path)) }
        XCTAssertTrue(fm.fileExists(atPath: other))
    }

    func testForceTeardownKeepsANamedSessionRecordWhateverItsOwnerPID() async throws {
        let directory = temporaryDirectory()
        try writeRecords([record(udid, session: "qa-ios")], to: directory)

        let result = try await forceTeardown(directory: directory)

        XCTAssertEqual(result.capacityRecordsCleared, 0)
        XCTAssertEqual(result.capacityRecordsKept.map(\.sessionId), ["qa-ios"])
        XCTAssertTrue(result.capacityRecordsKept[0].reason.contains("teardown --session-id qa-ios"), result.capacityRecordsKept[0].reason)
        let remaining = try SimulatorCapacity(directory: directory).sessions(devices: booted(udid))
        XCTAssertEqual(remaining.map(\.udid), [udid])

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
        XCTAssertNotNil(object["capacityRecordsKept"])
    }

    func testForceTeardownClearsAPendingRecordAndADeadSessionlessOne() async throws {
        let directory = temporaryDirectory()
        try writeRecords([record(udid, session: "qa-ios", state: .pending)], to: directory)
        var result = try await forceTeardown(directory: directory)
        XCTAssertEqual(result.capacityRecordsCleared, 1)
        XCTAssertEqual(result.capacityRecordsKept, [])

        try writeRecords([record(udid, session: "simulator:\(udid)")], to: directory)
        result = try await forceTeardown(directory: directory)
        XCTAssertEqual(result.capacityRecordsCleared, 1)
        XCTAssertEqual(result.capacityRecordsKept, [])
    }

    func testForceTeardownKeepsASessionlessRecordWhoseOwnerIsAlive() async throws {
        let directory = temporaryDirectory()
        try writeRecords([record(udid, session: "simulator:\(udid)")], to: directory)
        let result = try await SimulatorReaper.forceTeardown(
            udid: udid,
            capacity: SimulatorCapacity(directory: directory),
            leaseDirectory: directory,
            sessions: KeepAliveSessionStore(directory: "\(directory)/sessions", isProcessAlive: { _ in false }),
            snapshot: { "" },
            gracePeriod: 0,
            isProcessAlive: { _ in true }
        )
        XCTAssertEqual(result.capacityRecordsCleared, 0)
        XCTAssertTrue(result.capacityRecordsKept.first?.reason.contains("still running") == true)
    }

    func testForceTeardownRemovesTheKilledRunnersSessionFiles() async throws {
        let directory = temporaryDirectory()
        let sessionDirectory = "\(directory)/grantiva-sessions"
        let store = KeepAliveSessionStore(directory: sessionDirectory, isProcessAlive: { _ in false })
        store.recordOwner(udid: udid, runnerPid: 31830)
        store.recordOwner(udid: "OTHER-UDID", runnerPid: 999)
        let runnerFile = "\(sessionDirectory)/31830-1791583257475743000.grantiva"
        let otherRunnerFile = "\(sessionDirectory)/999-1791583257475743000.grantiva"
        try Data(#"{"sessionId":"s","port":8100,"pid":31830}"#.utf8).write(to: URL(fileURLWithPath: runnerFile))
        try Data(#"{"sessionId":"t","port":8101,"pid":999}"#.utf8).write(to: URL(fileURLWithPath: otherRunnerFile))

        let result = try await forceTeardown(directory: directory, sessionDirectory: sessionDirectory)

        let left = try FileManager.default.contentsOfDirectory(atPath: sessionDirectory).sorted()
        XCTAssertEqual(left, ["999-1791583257475743000.grantiva", "999.owner.json"])
        XCTAssertEqual(result.sessionFilesRemoved.count, 2)
    }

    /// L12: the keep-alive runner died on its own and grantiva removed its
    /// sidecar on the way out; the runner's own file is all that is left.
    func testForceTeardownRemovesADeadRunnersFileWithNoSidecar() async throws {
        let directory = temporaryDirectory()
        let sessionDirectory = "\(directory)/grantiva-sessions"
        try FileManager.default.createDirectory(atPath: sessionDirectory, withIntermediateDirectories: true)
        let runnerFile = "\(sessionDirectory)/12109-1791747326192132000.grantiva"
        try Data(#"{"sessionId":"12109-1791747326192132000","port":8987,"pid":12109}"#.utf8).write(to: URL(fileURLWithPath: runnerFile))

        let result = try await forceTeardown(directory: directory, sessionDirectory: sessionDirectory)

        XCTAssertFalse(FileManager.default.fileExists(atPath: runnerFile))
        XCTAssertEqual(result.sessionFilesRemoved, [runnerFile])
    }

    func testForceTeardownReapsADiagnoseThatAppearsAfterTheFirstKill() async throws {
        let directory = temporaryDirectory()
        func sleeper() throws -> Process {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sleep")
            process.arguments = ["30"]
            try process.run()
            return process
        }
        let runner = try sleeper()
        let late = try sleeper()
        defer {
            for process in [runner, late] {
                if process.isRunning { process.terminate() }
                process.waitUntilExit()
            }
        }
        let runnerLine = "  \(runner.processIdentifier)  \(runner.processIdentifier) /x/grantiva-runner --platform ios --device \(udid) test"
        let fresh = try sleeper()
        defer {
            if fresh.isRunning { fresh.terminate() }
            fresh.waitUntilExit()
        }
        let pid = late.processIdentifier
        let freshPID = fresh.processIdentifier
        let snapshots = SnapshotSequence([
            runnerLine,
            runnerLine
                + "\n  \(pid)  \(pid) /usr/bin/xcrun simctl diagnose --udid=\(udid) --no-archive"
                + "\n  \(freshPID)  \(freshPID) /opt/homebrew/bin/grantiva run --simulator \(udid)",
        ])

        let result = try await SimulatorReaper.forceTeardown(
            udid: udid,
            capacity: SimulatorCapacity(directory: directory),
            leaseDirectory: directory,
            sessions: KeepAliveSessionStore(directory: "\(directory)/sessions"),
            snapshot: { snapshots.next() },
            gracePeriod: 1
        )

        late.waitUntilExit()
        XCTAssertFalse(late.isRunning)
        XCTAssertEqual(result.processes.first { $0.pid == pid }?.kind, .diagnose)
        XCTAssertTrue(fresh.isRunning, "a grantiva run started after the first snapshot was killed")
        XCTAssertFalse(result.processes.contains { $0.pid == freshPID })
    }
}

extension SimulatorReaperTests {
    // MARK: - K68: only a held lease is a reclaim

    func testForceTeardownWithNoProcessesAndOnlyAStaleLockFileIsNotAReclaim() async throws {
        let directory = temporaryDirectory()
        // What a run that ended normally used to leave: the file, no claim.
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: SimulatorLease.leasePath(udid: udid, directory: directory), contents: Data())

        let result = try await forceTeardown(directory: directory)

        XCTAssertEqual(result.processes, [])
        XCTAssertFalse(result.leaseReleased)
        XCTAssertFalse(result.reclaimed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: SimulatorLease.leasePath(udid: udid, directory: directory)))
    }

    func testForceTeardownOfAKilledKeepAliveRunStillReportsTheLeaseReleased() async throws {
        let directory = temporaryDirectory()
        // `kill -9` of the grantiva process: its claim is left behind naming a
        // runner that is still alive until the reaper kills it.
        let runner = Process()
        runner.executableURL = URL(fileURLWithPath: "/bin/sleep")
        runner.arguments = ["30"]
        try runner.run()
        defer { if runner.isRunning { runner.terminate() }; runner.waitUntilExit() }
        let dead = Process()
        dead.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try dead.run()
        dead.waitUntilExit()
        try writeClaim(SimulatorLeaseClaim(
            pid: dead.processIdentifier, udid: udid, startedAt: Date(),
            runnerPID: runner.processIdentifier, keepAlive: true
        ), directory: directory)
        let line = "  \(runner.processIdentifier)  \(runner.processIdentifier) /x/grantiva-runner --platform ios --device \(udid) test"

        let result = try await SimulatorReaper.forceTeardown(
            udid: udid,
            capacity: SimulatorCapacity(directory: directory),
            leaseDirectory: directory,
            runnerBase: "\(directory)/runner",
            sessions: KeepAliveSessionStore(directory: "\(directory)/sessions", isProcessAlive: { _ in false }),
            snapshot: { line },
            gracePeriod: 1
        )

        XCTAssertEqual(result.processes.map(\.pid), [runner.processIdentifier])
        XCTAssertTrue(result.leaseReleased)
        XCTAssertTrue(result.reclaimed)
    }

    // MARK: - K106: the killed run's temp directories

    private func writeClaim(_ claim: SimulatorLeaseClaim, directory: String) throws {
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try JSONEncoder.leaseEncoder.encode(claim)
            .write(to: URL(fileURLWithPath: SimulatorLease.leasePath(udid: udid, directory: directory)))
    }

    private func makeTempDirectories(under root: String) throws -> [String] {
        let paths = ["grantiva-\(UUID().uuidString)", "grantiva-report-\(UUID().uuidString)"].map { "\(root)/\($0)" }
        for path in paths {
            try FileManager.default.createDirectory(atPath: "\(path)/0", withIntermediateDirectories: true)
        }
        return paths
    }

    func testForceTeardownRemovesTheKilledRunsTempDirectories() async throws {
        let directory = temporaryDirectory()
        let temps = try makeTempDirectories(under: "\(directory)/tmp")
        var claim = SimulatorLeaseClaim(pid: 999_999, udid: udid, startedAt: Date(), runnerPID: 999_998, keepAlive: true)
        claim.temporaryDirectories = temps
        try writeClaim(claim, directory: directory)

        let result = try await forceTeardown(directory: directory)

        XCTAssertEqual(result.temporaryDirectoriesRemoved, temps)
        for path in temps { XCTAssertFalse(FileManager.default.fileExists(atPath: path), path) }
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
        XCTAssertEqual(object["temporaryDirectoriesRemoved"] as? [String], temps)
    }

    func testForceTeardownKeepsTempDirectoriesOfALiveOwner() async throws {
        let directory = temporaryDirectory()
        let temps = try makeTempDirectories(under: "\(directory)/tmp")
        // The owner is this test process: alive, and never reaped.
        var claim = SimulatorLeaseClaim(pid: getpid(), udid: udid, startedAt: Date())
        claim.temporaryDirectories = temps
        try writeClaim(claim, directory: directory)

        let result = try await forceTeardown(directory: directory)

        XCTAssertEqual(result.temporaryDirectoriesRemoved, [])
        for path in temps { XCTAssertTrue(FileManager.default.fileExists(atPath: path), path) }
    }

    func testForceTeardownNeverRemovesADirectoryThatIsNotAGrantivaTempDirectory() async throws {
        let directory = temporaryDirectory()
        let reportDir = "\(directory)/ci-reports"
        try FileManager.default.createDirectory(atPath: reportDir, withIntermediateDirectories: true)
        var claim = SimulatorLeaseClaim(pid: 999_999, udid: udid, startedAt: Date())
        claim.temporaryDirectories = [reportDir]
        try writeClaim(claim, directory: directory)

        let result = try await forceTeardown(directory: directory)

        XCTAssertEqual(result.temporaryDirectoriesRemoved, [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: reportDir))
    }
}

/// Hands out a different `ps` snapshot on each call.
private final class SnapshotSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var outputs: [String]

    init(_ outputs: [String]) { self.outputs = outputs }

    func next() -> String {
        lock.withLock { outputs.count > 1 ? outputs.removeFirst() : (outputs.first ?? "") }
    }
}

/// L04: the exact command line of the `simctl diagnose` the repro captured.
final class SimulatorReaperDiagnoseLineTests: XCTestCase {
    func testMatchesTheDiagnoseCommandLineCapturedByTheRepro() {
        let udid = "AD257930-C4D0-4C0F-9DAA-DAA6C335AF8F"
        let line = " 4806  4806 /Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/Resources/bin/simctl diagnose -l -b --timeout=600 --log-option=--last --log-option=2m --output=/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/fix3-cli/runner-home/versions/1.1.28-grantiva.10+android-drivers-2/devices/\(udid)/cache/wda-builds/sim-ios26.0-iphone-wda16.12.8-r1/devices/\(udid)/run-4685-1791728323714722000/attempt-1.xcresult/Staging/1_Test/Diagnostics/simctl_diagnostics --no-archive --udid=\(udid)"
        let found = SimulatorReaper.processes(owning: udid, psOutput: line)
        XCTAssertEqual(found.map(\.pid), [4806])
        XCTAssertEqual(found.first?.kind, .diagnose)
        XCTAssertEqual(found.first?.processGroup, 4806)
    }
}
