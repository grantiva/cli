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
        let reclaimed = try SimulatorLease.acquire(udid: udid, directory: directory)
        reclaimed.release()
    }
}
