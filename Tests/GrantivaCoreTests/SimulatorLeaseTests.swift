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

    /// A10: on Android the refusal names the emulator and `grantiva emulator`.
    func testAndroidOwnershipErrorNamesTheEmulatorCommands() throws {
        let first = try SimulatorLease.acquire(udid: "emulator-5554", platform: .android, directory: leaseDirectory)
        defer { first.release() }

        XCTAssertThrowsError(
            try SimulatorLease.acquire(udid: "emulator-5554", platform: .android, directory: leaseDirectory)
        ) { error in
            let message = error.localizedDescription
            XCTAssertTrue(message.hasPrefix("Emulator emulator-5554 is already owned"), message)
            XCTAssertTrue(message.contains("`grantiva emulator teardown --serial emulator-5554 --force`"), message)
            XCTAssertTrue(message.contains("`grantiva emulator ensure --name <unique-name>`"), message)
            XCTAssertFalse(message.contains("simulator"), message)
            XCTAssertFalse(message.contains("exited with code"), message)
            XCTAssertTrue(SimulatorLease.isOwnershipRefusal(error))
        }
        XCTAssertFalse(SimulatorLease.isOwnershipRefusal(GrantivaError.commandFailed("Runner failed (exit 1)", 1)))
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
            XCTAssertTrue(message.contains("`grantiva runner start` session"), message)
            XCTAssertTrue(message.contains("pid \(getppid())"), message)
            XCTAssertTrue(SimulatorLease.isOwnershipRefusal(error))
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

// MARK: - K68, K86-a, K106, K107-a

extension SimulatorLeaseTests {
    /// Runs `/usr/bin/lockf -k <path> sleep 30`, which holds a BSD `flock` on
    /// the lease file from another process, and waits until it does.
    private func holdLockInChild(udid: String) throws -> Process {
        try FileManager.default.createDirectory(atPath: leaseDirectory, withIntermediateDirectories: true)
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/lockf")
        child.arguments = ["-k", SimulatorLease.leasePath(udid: udid, directory: leaseDirectory), "/bin/sleep", "30"]
        try child.run()
        addTeardownBlock {
            if child.isRunning { child.terminate() }
            child.waitUntilExit()
        }
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if SimulatorLease.isHeld(udid: udid, directory: leaseDirectory) { return child }
            usleep(20_000)
        }
        XCTFail("lockf never took the lock")
        return child
    }

    // K68: a lock file left by a run that ended is not a held lease.
    func testForceReleaseOfAnUnheldLockFileWithAnEmptyClaimReturnsFalse() throws {
        try FileManager.default.createDirectory(atPath: leaseDirectory, withIntermediateDirectories: true)
        let path = SimulatorLease.leasePath(udid: "SIM-FREE", directory: leaseDirectory)
        FileManager.default.createFile(atPath: path, contents: Data())

        XCTAssertFalse(SimulatorLease.forceRelease(udid: "SIM-FREE", directory: leaseDirectory))
        XCTAssertFalse(FileManager.default.fileExists(atPath: path), "the stale file is still removed")
    }

    func testForceReleaseOfAStaleClaimReturnsFalse() throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-DEAD", directory: leaseDirectory)
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try child.run()
        child.waitUntilExit()
        lease.handOff(to: child.processIdentifier)

        XCTAssertFalse(SimulatorLease.forceRelease(udid: "SIM-DEAD", directory: leaseDirectory))
    }

    func testForceReleaseOfAFlockHeldByAnotherProcessReturnsTrue() throws {
        let child = try holdLockInChild(udid: "SIM-HELD")

        XCTAssertTrue(SimulatorLease.forceRelease(udid: "SIM-HELD", directory: leaseDirectory))
        let next = try SimulatorLease.acquire(udid: "SIM-HELD", directory: leaseDirectory)
        next.release()
        child.terminate()
    }

    func testForceReleaseOfALiveHandOffReturnsTrueAndTheNextAcquireSucceeds() throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-LIVE", directory: leaseDirectory)
        lease.handOff(to: getppid())

        XCTAssertTrue(SimulatorLease.forceRelease(udid: "SIM-LIVE", directory: leaseDirectory))
        let next = try SimulatorLease.acquire(udid: "SIM-LIVE", directory: leaseDirectory)
        next.release()
    }

    // K86-a: a `runner start` session is not a `run --keep-alive`.
    func testOwnershipMessageForAHandedOffClaimNamesRunnerStop() {
        let claim = SimulatorLeaseClaim(
            pid: 52144, udid: "SIM-1", startedAt: Date().addingTimeInterval(-58),
            runnerPID: 52144, keepAlive: true, handedOff: true, projectDirectory: "/tmp/project"
        )
        let message = SimulatorLease.ownershipMessage(udid: "SIM-1", holder: claim)
        XCTAssertTrue(message.hasPrefix("Simulator SIM-1 is held by a `grantiva runner start` session"), message)
        XCTAssertTrue(message.contains("grantiva-runner pid 52144"), message)
        XCTAssertTrue(message.contains("`grantiva runner stop`"), message)
        XCTAssertTrue(message.contains("/tmp/project"), message)
        XCTAssertFalse(message.contains("--keep-alive"), message)
        XCTAssertFalse(message.contains("--force"), message)
        XCTAssertTrue(SimulatorLease.isOwnershipRefusal(GrantivaError.commandFailed(message, 1)))

        let android = SimulatorLease.ownershipMessage(udid: "emulator-5554", holder: claim, platform: .android)
        XCTAssertTrue(android.hasPrefix("Emulator emulator-5554 is held by a `grantiva runner start` session"), android)
        XCTAssertTrue(android.contains("`grantiva runner stop`"), android)
        XCTAssertTrue(android.contains("`grantiva emulator ensure --name <unique-name>`"), android)
    }

    func testOwnershipMessageForAKeepAliveRunIsUnchanged() {
        let claim = SimulatorLeaseClaim(pid: 100, udid: "SIM-1", startedAt: Date(), runnerPID: 101, keepAlive: true)
        let message = SimulatorLease.ownershipMessage(udid: "SIM-1", holder: claim)
        XCTAssertTrue(message.hasPrefix("Simulator SIM-1 is already owned by another Grantiva run (pid 100"), message)
        XCTAssertTrue(message.contains("grantiva-runner pid 101, --keep-alive)"), message)
        XCTAssertTrue(message.contains("`grantiva simulator teardown --udid SIM-1 --force`"), message)
    }

    func testHandOffRecordsTheSessionKindAndProjectDirectory() throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-KIND", directory: leaseDirectory)
        lease.handOff(to: getppid())
        let claim = try XCTUnwrap(SimulatorLease.claim(udid: "SIM-KIND", directory: leaseDirectory))
        XCTAssertEqual(claim.handedOff, true)
        XCTAssertEqual(claim.projectDirectory, FileManager.default.currentDirectoryPath)
        _ = SimulatorLease.forceRelease(udid: "SIM-KIND", directory: leaseDirectory)
    }

    // K106: the claim names the run's temp directories.
    func testClaimRoundTripsTheTemporaryDirectories() throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-TMP", directory: leaseDirectory)
        defer { lease.release() }
        lease.recordTemporaryDirectory("/tmp/grantiva-A")
        lease.recordTemporaryDirectory("/tmp/grantiva-report-B")

        let claim = try XCTUnwrap(SimulatorLease.claim(udid: "SIM-TMP", directory: leaseDirectory))
        XCTAssertEqual(claim.temporaryDirectories, ["/tmp/grantiva-A", "/tmp/grantiva-report-B"])
        let decoded = try JSONDecoder.leaseDecoder.decode(
            SimulatorLeaseClaim.self, from: JSONEncoder.leaseEncoder.encode(claim)
        )
        XCTAssertEqual(decoded, claim)
        // A claim written before the field existed still reads.
        let legacy = #"{"keepAlive":false,"pid":1,"startedAt":"2026-10-10T00:00:00Z","udid":"SIM-TMP"}"#
        XCTAssertNil(try JSONDecoder.leaseDecoder.decode(SimulatorLeaseClaim.self, from: Data(legacy.utf8)).temporaryDirectories)
    }

    // K107-a: a released lease leaves no file behind.
    func testReleaseRemovesTheLockFile() throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-GONE", directory: leaseDirectory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: lease.path))
        lease.release()
        XCTAssertFalse(FileManager.default.fileExists(atPath: lease.path))
    }

    func testAHandOffKeepsTheLockFile() throws {
        let lease = try SimulatorLease.acquire(udid: "SIM-KEEP", directory: leaseDirectory)
        lease.handOff(to: getppid())
        XCTAssertTrue(FileManager.default.fileExists(atPath: lease.path))
        _ = SimulatorLease.forceRelease(udid: "SIM-KEEP", directory: leaseDirectory)
    }

    /// Between `open` and `flock` the previous holder released and unlinked
    /// the file: the lock just taken is on an inode nobody else can see.
    func testAcquireRetriesWhenTheLockFileWasUnlinkedWhileWaiting() throws {
        let unlinked = UnlinkOnce()
        SimulatorLease.afterOpenForTesting = { path in unlinked.run(path) }
        defer { SimulatorLease.afterOpenForTesting = nil }

        let lease = try SimulatorLease.acquire(udid: "SIM-RACE", directory: leaseDirectory)
        defer { lease.release() }

        XCTAssertTrue(unlinked.didRun)
        XCTAssertTrue(FileManager.default.fileExists(atPath: lease.path), "the lease must lock the file at its path")
        XCTAssertEqual(SimulatorLease.claim(udid: "SIM-RACE", directory: leaseDirectory)?.pid, getpid())
        XCTAssertThrowsError(try SimulatorLease.acquire(udid: "SIM-RACE", directory: leaseDirectory))
    }

    func testConcurrentAcquiresWhileTheHolderReleasesGiveOneOwner() throws {
        for _ in 0..<200 {
            let holder = try SimulatorLease.acquire(udid: "SIM-CONC", directory: leaseDirectory)
            let winners = Winners()
            let group = DispatchGroup()
            for index in 0..<3 {
                group.enter()
                DispatchQueue.global().async { [leaseDirectory] in
                    defer { group.leave() }
                    if index == 0 {
                        holder.release()
                    } else if let lease = try? SimulatorLease.acquire(udid: "SIM-CONC", directory: leaseDirectory) {
                        winners.add(lease)
                    }
                }
            }
            group.wait()
            XCTAssertLessThanOrEqual(winners.count, 1, "two leases owned one simulator")
            winners.releaseAll()
        }
    }
}

private final class UnlinkOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var ran = false
    var didRun: Bool { lock.withLock { ran } }

    func run(_ path: String) {
        let first = lock.withLock { () -> Bool in
            defer { ran = true }
            return !ran
        }
        if first { unlink(path) }
    }
}

private final class Winners: @unchecked Sendable {
    private let lock = NSLock()
    private var leases: [SimulatorLease] = []
    var count: Int { lock.withLock { leases.count } }
    func add(_ lease: SimulatorLease) { lock.withLock { leases.append(lease) } }
    func releaseAll() { lock.withLock { leases.forEach { $0.release() }; leases = [] } }
}
