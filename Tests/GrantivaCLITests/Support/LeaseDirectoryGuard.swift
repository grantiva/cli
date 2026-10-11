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

    /// The hook this test installs for its own duration. The suite-wide
    /// hook is belt and braces: when several test bundles share a process
    /// (as `swift test` does on CI) only one bundle's install wins, so no
    /// assertion counts on it.
    private var previousHook: ((String) throws -> Void)?
    private let probe = ProbeHook()

    override func setUp() {
        super.setUp()
        previousHook = SimulatorLease.defaultDirectoryUseForTesting
        let probe = probe
        SimulatorLease.defaultDirectoryUseForTesting = { udid in
            probe.trip()
            throw GrantivaError.commandFailed("default lease directory refused for \(udid)", 1)
        }
    }

    override func tearDown() {
        SimulatorLease.defaultDirectoryUseForTesting = previousHook
        super.tearDown()
    }

    func testANilDirectoryAcquireTripsTheHookOnceAndCreatesNothing() {
        let locks = SimulatorLease.directory()
        let existed = FileManager.default.fileExists(atPath: locks)

        XCTAssertThrowsError(try SimulatorLease.acquire(udid: "LEASE-GUARD-PROBE"))

        XCTAssertEqual(probe.count, 1)
        if !existed {
            XCTAssertFalse(FileManager.default.fileExists(atPath: locks), "the refused acquire created \(locks)")
        }
        XCTAssertNil(SimulatorLease.claim(udid: "LEASE-GUARD-PROBE"), "no lease file for the probe")
    }

    func testAnExplicitDirectoryNeverTripsTheHook() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-guard-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let lease = try SimulatorLease.acquire(udid: "LEASE-GUARD-PROBE", directory: directory)
        lease.release()
        XCTAssertEqual(probe.count, 0)
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
    nonisolated(unsafe) private(set) static var lockDirectoryExistedAtStart = true

    static func install() {
        lock.withLock {
            guard !installed else { return }
            installed = true
            lockDirectoryExistedAtStart = FileManager.default.fileExists(atPath: SimulatorLease.directory())
            SimulatorLease.defaultDirectoryUseForTesting = { udid in
                let message = "A test took the simulator lease for \(udid) in the default directory "
                    + "\(SimulatorLease.directory()); give it a temp lease directory."
                XCTFail(message)
                throw GrantivaError.commandFailed(message, 1)
            }
        }
    }
}

final class ProbeHook: @unchecked Sendable {
    private let lock = NSLock()
    private var trips = 0
    var count: Int { lock.withLock { trips } }
    func trip() { lock.withLock { trips += 1 } }
}
