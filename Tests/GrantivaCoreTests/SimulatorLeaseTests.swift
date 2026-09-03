import Foundation
import XCTest
@testable import GrantivaCore

final class SimulatorLeaseTests: XCTestCase {
    private var leaseDirectory: String!

    override func setUpWithError() throws {
        leaseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-lease-tests-\(UUID().uuidString)")
            .path
    }

    override func tearDownWithError() throws {
        if let leaseDirectory {
            try? FileManager.default.removeItem(atPath: leaseDirectory)
        }
    }

    func testRejectsConcurrentOwnershipOfSameSimulator() throws {
        let first = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        defer { first.release() }

        XCTAssertThrowsError(
            try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        ) { error in
            XCTAssertTrue(String(describing: error).contains("already owned"))
        }
    }

    func testAllowsConcurrentOwnershipOfDifferentSimulators() throws {
        let first = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        defer { first.release() }
        let second = try SimulatorLease.acquire(udid: "SIM-2", directory: leaseDirectory)
        defer { second.release() }

        XCTAssertNotEqual(first.path, second.path)
    }

    func testReleasedLeaseCanBeReacquired() throws {
        let first = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        first.release()

        let second = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        second.release()
    }

    // MARK: - Ownership record

    func testLeaseDescriptorIsCloseOnExec() throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        defer { lease.release() }

        // Without FD_CLOEXEC the descriptor would survive into every spawned
        // child, and the flock with it — a lease outliving the process that
        // took it is exactly the state that makes the next run unrunnable.
        XCTAssertTrue(lease.descriptorIsCloseOnExec)
    }

    func testClaimNamesTheOwningProcessAndRunner() throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        defer { lease.release() }

        let claim = try XCTUnwrap(SimulatorLease.claim(udid: "SIM-1", directory: leaseDirectory))
        XCTAssertEqual(claim.pid, getpid())
        XCTAssertEqual(claim.udid, "SIM-1")
        XCTAssertNil(claim.runnerPID)

        lease.recordRunner(pid: 4242, keepAlive: true)
        let updated = try XCTUnwrap(SimulatorLease.claim(udid: "SIM-1", directory: leaseDirectory))
        XCTAssertEqual(updated.runnerPID, 4242)
        XCTAssertTrue(updated.keepAlive)
    }

    func testReleaseClearsTheClaim() throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        XCTAssertNotNil(SimulatorLease.claim(udid: "SIM-1", directory: leaseDirectory))
        lease.release()
        XCTAssertNil(SimulatorLease.claim(udid: "SIM-1", directory: leaseDirectory))
    }

    func testForceReleaseReclaimsAHeldLease() throws {
        let stuck = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        XCTAssertThrowsError(try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory))

        // What `teardown --udid <UDID> --force` does after reaping the holders.
        XCTAssertTrue(SimulatorLease.forceRelease(udid: "SIM-1", directory: leaseDirectory))

        let reclaimed = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        reclaimed.release()
        stuck.release()
    }

    func testOwnershipErrorNamesTheHolderAndTheWayOut() throws {
        let first = try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        first.recordRunner(pid: 99, keepAlive: true)
        defer { first.release() }

        XCTAssertThrowsError(
            try SimulatorLease.acquire(udid: "SIM-1", directory: leaseDirectory)
        ) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("already owned"), message)
            XCTAssertTrue(message.contains("pid \(getpid())"), message)
            XCTAssertTrue(message.contains("grantiva-runner pid 99"), message)
            XCTAssertTrue(message.contains("teardown --udid SIM-1 --force"), message)
        }
    }
}

extension SimulatorLeaseTests {
    func testHandedOffLeaseStaysHeldWhileTheRunnerLives() throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-HANDOFF", directory: leaseDirectory)
        // Stand in for the runner with a process that is certainly alive and
        // is not us: our parent.
        lease.handOff(to: getppid())

        XCTAssertThrowsError(
            try SimulatorLease.acquire(udid: "SIM-HANDOFF", directory: leaseDirectory)
        ) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("already owned"), message)
            XCTAssertTrue(message.contains("pid \(getppid())"), message)
        }
    }

    func testHandedOffLeaseIsReclaimableOnceTheRunnerIsGone() throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-STALE", directory: leaseDirectory)
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try child.run()
        child.waitUntilExit()
        lease.handOff(to: child.processIdentifier)

        let reclaimed = try SimulatorLease.acquire(udid: "SIM-STALE", directory: leaseDirectory)
        reclaimed.release()
    }

    func testForceReleaseClearsAHandedOffLease() throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-FORCE", directory: leaseDirectory)
        lease.handOff(to: getppid())
        XCTAssertTrue(SimulatorLease.forceRelease(udid: "SIM-FORCE", directory: leaseDirectory))

        let reclaimed = try SimulatorLease.acquire(udid: "SIM-FORCE", directory: leaseDirectory)
        reclaimed.release()
    }
}
