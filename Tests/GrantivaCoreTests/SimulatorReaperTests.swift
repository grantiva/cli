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
            sessions: KeepAliveSessionStore(directory: sessionDirectory ?? "\(directory)/sessions", isProcessAlive: { _ in false }),
            snapshot: { "" },
            gracePeriod: 0,
            isProcessAlive: { _ in false }
        )
    }

    func testForceTeardownKeepsTheRecordOfASessionStillActiveOnAnotherDevice() async throws {
        let directory = temporaryDirectory()
        let other = "B0B0B0B0-1111-2222-3333-444455556666"
        try writeRecords([record(udid, session: "qa-ios"), record(other, session: "qa-ios")], to: directory)

        let result = try await forceTeardown(directory: directory)

        XCTAssertEqual(result.capacityRecordsCleared, 0)
        XCTAssertEqual(result.capacityRecordsKept.map(\.sessionId), ["qa-ios"])
        XCTAssertTrue(result.capacityRecordsKept[0].reason.contains(other), result.capacityRecordsKept[0].reason)
        let remaining = try SimulatorCapacity(directory: directory).sessions(devices: booted(udid, other))
        XCTAssertEqual(remaining.filter { $0.sessionId == "qa-ios" }.map(\.udid).sorted(), [udid, other].sorted())

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
        XCTAssertNotNil(object["capacityRecordsKept"])
    }

    func testForceTeardownClearsADeadSingleDeviceRecordAndAPendingOne() async throws {
        let directory = temporaryDirectory()
        try writeRecords([record(udid, session: "solo")], to: directory)
        var result = try await forceTeardown(directory: directory)
        XCTAssertEqual(result.capacityRecordsCleared, 1)
        XCTAssertEqual(result.capacityRecordsKept, [])

        let other = "B0B0B0B0-1111-2222-3333-444455556666"
        try writeRecords([record(udid, session: "qa-ios", state: .pending), record(other, session: "qa-ios")], to: directory)
        result = try await forceTeardown(directory: directory)
        XCTAssertEqual(result.capacityRecordsCleared, 1)
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
        let pid = late.processIdentifier
        let snapshots = SnapshotSequence([
            runnerLine,
            runnerLine + "\n  \(pid)  \(pid) /usr/bin/xcrun simctl diagnose --udid=\(udid) --no-archive",
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
