import Foundation
import XCTest
@testable import GrantivaCore

/// Tests never write into the user's runner home. The suites that drive
/// `RunnerSession` and the WDA device homes take simulator leases; each one
/// must take them under its own temp directory, or every `swift test` adds a
/// lock file per test UDID to `<runner home>/locks` (K107-b).
final class TestHygieneTests: XCTestCase {
    /// The lease directory the product would use in this environment:
    /// `GRANTIVA_RUNNER_HOME/locks`, else `~/.grantiva/runner/locks`.
    private var realLockDirectory: String { SimulatorLease.directory() }

    private func entries() -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: realLockDirectory)) ?? [])
    }

    func testSuiteDoesNotWriteIntoTheRunnerHome() {
        let before = entries()

        for suite in [
            RunnerSessionReportTests.defaultTestSuite,
            RunnerSessionCleanupTests.defaultTestSuite,
            WDADeviceHomeTests.defaultTestSuite,
        ] {
            suite.run()
        }

        let added = entries().subtracting(before)
        XCTAssertEqual(
            added.sorted(), [],
            "tests created lease files in the real runner home \(realLockDirectory)"
        )
    }
}
