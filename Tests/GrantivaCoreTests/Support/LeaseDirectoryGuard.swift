import Foundation
import XCTest
@testable import GrantivaCore

/// Tests never take a simulator lease in the user's runner home (K107-b).
///
/// `install()` makes any `SimulatorLease.acquire` without an explicit
/// directory fail the running test and throw before it touches
/// `<runner home>/locks`. XCTest asks every test class for its
/// `defaultTestSuite` while it builds the run, before any test executes, so
/// overriding it here installs the guard for the whole bundle.
final class LeaseDirectoryGuardTests: XCTestCase {
    override class var defaultTestSuite: XCTestSuite {
        LeaseDirectoryGuard.install()
        return super.defaultTestSuite
    }

    func testTheGuardIsInstalledAndRefusesTheDefaultDirectory() throws {
        XCTAssertNotNil(SimulatorLease.defaultDirectoryUseForTesting)
        let tripped = LeaseDirectoryGuard.trips
        try XCTExpectFailure("the guard fails a test that uses the default lease directory") {
            XCTAssertThrowsError(try SimulatorLease.acquire(udid: "LEASE-GUARD-PROBE"))
        }
        XCTAssertEqual(LeaseDirectoryGuard.trips, tripped + 1)
    }

    func testTheDefaultLockDirectoryWasNotCreatedByTests() {
        guard !LeaseDirectoryGuard.lockDirectoryExistedAtStart else { return }
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: SimulatorLease.directory()),
            "a test created \(SimulatorLease.directory())"
        )
    }
}

enum LeaseDirectoryGuard {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var installed = false
    nonisolated(unsafe) private static var tripCount = 0
    nonisolated(unsafe) private(set) static var lockDirectoryExistedAtStart = true

    static var trips: Int { lock.withLock { tripCount } }

    static func install() {
        lock.withLock {
            guard !installed else { return }
            installed = true
            lockDirectoryExistedAtStart = FileManager.default.fileExists(atPath: SimulatorLease.directory())
            SimulatorLease.defaultDirectoryUseForTesting = { udid in
                lock.withLock { tripCount += 1 }
                let message = "A test took the simulator lease for \(udid) in the default directory "
                    + "\(SimulatorLease.directory()); give it a temp lease directory."
                XCTFail(message)
                throw GrantivaError.commandFailed(message, 1)
            }
        }
    }
}
