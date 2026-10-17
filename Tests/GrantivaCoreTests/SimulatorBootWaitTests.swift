import Darwin
import Foundation
import XCTest
@testable import GrantivaCore

/// IOS-015: `simulator ensure` hung forever on `simctl bootstatus -b` while
/// `simctl list` showed the device Booted, and the hung ensure left no record
/// for `teardown --session-id`.
final class SimulatorBootWaitTests: XCTestCase {
    /// A bootstatus child that exits only when told to (or never).
    final class FakeBootStatus: BootStatusChild, @unchecked Sendable {
        private let lock = NSLock()
        private var status: Int32?
        private var terminations = 0
        let pid: pid_t = 4242

        init(exitStatus: Int32? = nil) { status = exitStatus }

        var terminated: Bool { lock.withLock { terminations > 0 } }
        func poll() -> Int32? { lock.withLock { status } }
        func output() -> String { "" }
        func terminate() {
            lock.withLock {
                terminations += 1
                if status == nil { status = SIGTERM }
            }
        }
    }

    private func makeManager(
        _ simctl: FakeSimctl,
        bootWait: SimulatorBootWait,
        startBootStatus: @escaping @Sendable (String) throws -> BootStatusChild
    ) -> (SimulatorManager, SimulatorCapacity) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-bootwait-tests-\(UUID().uuidString)").path
        addTeardownBlock { try? FileManager.default.removeItem(atPath: directory) }
        let capacity = SimulatorCapacity(directory: directory, maximum: 4, waitTimeout: 0, pollInterval: 0.01)
        let manager = SimulatorManager(
            execute: simctl.execute, capacity: capacity, provenance: SimulatorProvenance(directory: directory),
            runnerHome: "\(directory)/runner", startBootStatus: startBootStatus, bootWait: bootWait
        )
        return (manager, capacity)
    }

    private func preexisting(state: String = "Shutdown") -> FakeSimctl {
        FakeSimctl(devices: [
            .init(name: "cov-a", udid: "PRE-1", state: state, runtime: "iOS-26-0", type: FakeSimctl.iPhone17),
        ])
    }

    // MARK: - The bound

    func testEnsureCompletesWhenBootstatusNeverReturnsButListShowsBooted() async throws {
        let simctl = preexisting()
        let child = FakeBootStatus()
        let (manager, capacity) = makeManager(
            simctl, bootWait: SimulatorBootWait(timeout: 30, bootStatusGrace: 0, pollInterval: 0.01, environment: [:]),
            startBootStatus: { _ in child }
        )

        let result = try await manager.ensure(name: "cov-a", boot: true)

        XCTAssertEqual(result.state, "Booted")
        XCTAssertTrue(child.terminated, "the stuck bootstatus is ended by its pid")
        let record = try XCTUnwrap(capacity.records(udid: "PRE-1").first)
        XCTAssertEqual(record.state, .active)
        XCTAssertEqual(record.bootedByGrantiva, true)
    }

    func testListIsNotConsultedBeforeTheGraceAndTheDeadlineTakesItsAnswer() async throws {
        let child = FakeBootStatus()
        let asked = Seen()
        let wait = SimulatorBootWait(timeout: 0.3, bootStatusGrace: 10, pollInterval: 0.01, environment: [:])
        let started = Date()
        let outcome = try await wait.wait(udid: "U", start: { child }, isBooted: {
            asked.calls += 1
            return true
        })
        // The grace runs past the deadline: the list is asked once, at the
        // deadline, and its Booted ends the wait there.
        XCTAssertEqual(outcome, .listedBooted)
        XCTAssertEqual(asked.calls, 1)
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), 0.3)
        XCTAssertTrue(child.terminated)
    }

    func testBootstatusThatFinishesIsTheNormalPath() async throws {
        let wait = SimulatorBootWait(timeout: 5, bootStatusGrace: 0, pollInterval: 0.01, environment: [:])
        let child = FakeBootStatus(exitStatus: 0)
        let outcome = try await wait.wait(udid: "U", start: { child }, isBooted: { true })
        XCTAssertEqual(outcome, .bootStatusFinished)
        XCTAssertFalse(child.terminated)
    }

    func testTheOverallDeadlineFailsWithAClearError() async throws {
        let child = FakeBootStatus()
        let wait = SimulatorBootWait(timeout: 0.05, bootStatusGrace: 0, pollInterval: 0.01, environment: [:])
        do {
            _ = try await wait.wait(udid: "DEV-9", start: { child }, isBooted: { false })
            XCTFail("expected a timeout")
        } catch GrantivaError.commandFailed(let message, _) {
            XCTAssertTrue(message.contains("Timed out after 0s waiting for simulator DEV-9 to boot"), message)
            XCTAssertTrue(message.contains(SimulatorBootWait.timeoutVariable), message)
        }
        XCTAssertTrue(child.terminated)
    }

    func testEnsurePastTheDeadlineFailsAndKeepsTheRecordOfTheDeviceItBooted() async throws {
        let simctl = preexisting()
        simctl.bootState = "Booting"
        let child = FakeBootStatus()
        let (manager, capacity) = makeManager(
            simctl, bootWait: SimulatorBootWait(timeout: 0.05, bootStatusGrace: 0, pollInterval: 0.01, environment: [:]),
            startBootStatus: { _ in child }
        )

        do {
            _ = try await manager.ensure(name: "cov-a", boot: true)
            XCTFail("expected a timeout")
        } catch GrantivaError.commandFailed(let message, _) {
            XCTAssertTrue(message.contains("Timed out"), message)
        }
        XCTAssertTrue(child.terminated)
        // The boot was issued: the record stays for teardown.
        XCTAssertEqual(try capacity.records(udid: "PRE-1").first?.bootedByGrantiva, true)
    }

    func testCancellingTheWaitEndsTheChild() async throws {
        let child = FakeBootStatus()
        let wait = SimulatorBootWait(timeout: 60, bootStatusGrace: 60, pollInterval: 0.01, environment: [:])
        let task = Task { try await wait.wait(udid: "U", start: { child }, isBooted: { false }) }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()
        _ = try? await task.value
        XCTAssertTrue(child.terminated)
    }

    func testDeadlineAndGraceComeFromTheEnvironment() {
        let wait = SimulatorBootWait(environment: [
            SimulatorBootWait.timeoutVariable: "42", SimulatorBootWait.graceVariable: "7",
        ])
        XCTAssertEqual(wait.timeout, 42)
        XCTAssertEqual(wait.bootStatusGrace, 7)
        let defaults = SimulatorBootWait(environment: [:])
        XCTAssertEqual(defaults.timeout, 300)
        XCTAssertEqual(defaults.bootStatusGrace, 60)
    }

    // MARK: - Ownership recorded before the wait

    func testTheRecordNamesTheBootBeforeTheWaitStarts() async throws {
        let simctl = preexisting()
        let seen = Seen()
        let capacityBox = CapacityBox()
        let (manager, capacity) = makeManager(
            simctl, bootWait: SimulatorBootWait(timeout: 5, bootStatusGrace: 0, pollInterval: 0.01, environment: [:]),
            startBootStatus: { udid in
                seen.record = try capacityBox.capacity?.records(udid: udid).first
                return FakeBootStatus(exitStatus: 0)
            }
        )
        capacityBox.capacity = capacity

        _ = try await manager.ensure(name: "cov-a", boot: true)

        let record = try XCTUnwrap(seen.record, "a record exists when bootstatus starts")
        XCTAssertEqual(record.state, .pending)
        XCTAssertEqual(record.bootedByGrantiva, true)
    }

    func testAFailedBootCommandGivesTheReservationBack() async throws {
        let simctl = preexisting()
        let (manager, capacity) = makeManager(
            simctl, bootWait: SimulatorBootWait(timeout: 5, bootStatusGrace: 0, pollInterval: 0.01, environment: [:]),
            startBootStatus: { _ in FakeBootStatus(exitStatus: 0) }
        )
        let failing = SimulatorManager(
            execute: { command in
                if command.hasPrefix("xcrun simctl boot ") { throw GrantivaError.commandFailed("boot failed", 1) }
                return try await simctl.execute(command)
            },
            capacity: capacity, provenance: SimulatorProvenance(directory: capacity.directory),
            runnerHome: "\(capacity.directory)/runner"
        )
        _ = manager
        do {
            _ = try await failing.ensure(name: "cov-a", boot: true)
            XCTFail("expected the boot failure")
        } catch {}
        XCTAssertTrue(try capacity.records(udid: "PRE-1").isEmpty)
    }

    // MARK: - A dead owner's record of a boot it issued

    private func pending(sessionId: String, bootedByGrantiva: Bool?, ephemeral: Bool) -> ManagedSimulatorSession {
        ManagedSimulatorSession(
            udid: "PRE-1", name: "cov-a", sessionId: sessionId, ownerPID: 99_999,
            acquiredAt: Date(), state: .pending, bootedByGrantiva: bootedByGrantiva, ephemeral: ephemeral
        )
    }

    private func device(_ state: String) -> SimulatorDevice {
        let json = """
        {"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-0":[{"name":"cov-a","udid":"PRE-1","state":"\(state)","isAvailable":true}]}}
        """
        return try! JSONDecoder().decode(SimctlDeviceList.self, from: Data(json.utf8)).allDevices[0]
    }

    func testPruneKeepsADeadSessionsPendingRecordOfADeviceItBooted() {
        for state in ["Booted", "Booting"] {
            var records = [pending(sessionId: "cov-tmp", bootedByGrantiva: true, ephemeral: false)]
            SimulatorCapacity.prune(&records, devices: [device(state)], isProcessAlive: { _ in false })
            XCTAssertEqual(records.count, 1, state)
        }
        // An ensure without a session is durable too.
        var sessionless = [pending(sessionId: SimulatorCapacity.sessionlessOwner(udid: "PRE-1"), bootedByGrantiva: true, ephemeral: false)]
        SimulatorCapacity.prune(&sessionless, devices: [device("Booted")], isProcessAlive: { _ in false })
        XCTAssertEqual(sessionless.count, 1)
    }

    func testPruneDropsADeadPendingRecordOtherwise() {
        let cases: [(ManagedSimulatorSession, String)] = [
            (pending(sessionId: "cov-tmp", bootedByGrantiva: nil, ephemeral: false), "Booted"),
            (pending(sessionId: "cov-tmp", bootedByGrantiva: true, ephemeral: false), "Shutdown"),
            (pending(sessionId: SimulatorCapacity.sessionlessOwner(udid: "PRE-1"), bootedByGrantiva: true, ephemeral: true), "Booted"),
        ]
        for (record, state) in cases {
            var records = [record]
            SimulatorCapacity.prune(&records, devices: [device(state)], isProcessAlive: { _ in false })
            XCTAssertTrue(records.isEmpty, "\(record) on \(state)")
        }
    }

    func testTeardownShutsDownADeviceWhoseEnsureDiedMidBootAndAnEnsureTakesItOver() async throws {
        let deadPID: Int32 = 99_999
        try XCTSkipIf(kill(deadPID, 0) == 0 || errno == EPERM, "pid \(deadPID) is alive")
        let simctl = preexisting(state: "Booted")
        let (manager, capacity) = makeManager(
            simctl, bootWait: SimulatorBootWait(timeout: 5, bootStatusGrace: 0, pollInterval: 0.01, environment: [:]),
            startBootStatus: { _ in FakeBootStatus(exitStatus: 0) }
        )
        // The dead ensure ran in the same session as this one, so the record
        // belongs to whatever GRANTIVA_SESSION_ID the tests run under.
        let owner = capacity.sessionId ?? SimulatorCapacity.sessionlessOwner(udid: "PRE-1")
        let record = ManagedSimulatorSession(
            udid: "PRE-1", name: "cov-a", sessionId: owner, ownerPID: deadPID,
            acquiredAt: Date(), state: .pending, bootedByGrantiva: true, ephemeral: false
        )
        try FileManager.default.createDirectory(atPath: capacity.directory, withIntermediateDirectories: true)
        try JSONEncoder().encode([record]).write(to: URL(fileURLWithPath: "\(capacity.directory)/sessions.json"))

        // A later ensure of the device takes the record over rather than
        // waiting on a twin that is gone.
        _ = try await manager.boot(nameOrUDID: "PRE-1")
        let taken = try XCTUnwrap(capacity.records(udid: "PRE-1").first)
        XCTAssertEqual(taken.state, .active)
        XCTAssertEqual(taken.bootedByGrantiva, true)

        let outcomes = try await manager.teardown(sessionId: owner)
        XCTAssertEqual(outcomes.map(\.session?.udid), ["PRE-1"])
        XCTAssertTrue(simctl.commands.contains("xcrun simctl shutdown 'PRE-1'"))
        XCTAssertEqual(simctl.device("PRE-1")?.state, "Shutdown")
    }

    // MARK: - The live child

    func testTheLiveChildIsEndedByItsRecordedPid() throws {
        let child = try LiveBootStatusChild.start(executable: "/bin/sleep", arguments: ["30"])
        XCTAssertNil(child.poll())
        XCTAssertTrue(ShellChildren.shared.running.contains(child.pid))
        child.terminate()
        XCTAssertNotNil(child.poll())
        XCTAssertFalse(ShellChildren.shared.running.contains(child.pid))
    }

    func testTheLiveChildReportsItsExitAndOutput() async throws {
        let child = try LiveBootStatusChild.start(executable: "/bin/sh", arguments: ["-c", "echo nope >&2; exit 3"])
        let wait = SimulatorBootWait(timeout: 10, bootStatusGrace: 10, pollInterval: 0.01, environment: [:])
        do {
            _ = try await wait.wait(udid: "U", start: { child }, isBooted: { false })
            XCTFail("expected the exit status")
        } catch GrantivaError.commandFailed(let message, let code) {
            XCTAssertEqual(code, 3)
            XCTAssertEqual(message, "nope")
        }
    }
}

private final class Seen: @unchecked Sendable {
    var record: ManagedSimulatorSession?
    var calls = 0
}

private final class CapacityBox: @unchecked Sendable {
    var capacity: SimulatorCapacity?
}
