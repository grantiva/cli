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
}
