import XCTest
@testable import GrantivaCore

final class RunnerSessionInfoTests: XCTestCase {
    private let session = RunnerSessionInfo(
        pid: 4242,
        wdaPort: 8100,
        bundleId: "com.example.app",
        udid: "TEST-UDID",
        startedAt: Date()
    )

    func testRecognizesTheRecordedGrantivaRunner() {
        XCTAssertTrue(session.ownsRunnerProcess(
            in: " 4242 4242 /Users/me/.grantiva/runner/grantiva-runner --device TEST-UDID"
        ))
    }

    func testRejectsAReusedPIDBelongingToAnUnrelatedProcess() {
        XCTAssertFalse(session.ownsRunnerProcess(in: " 4242 4242 /bin/sleep 30"))
        XCTAssertFalse(session.ownsRunnerProcess(in: " 4242 4242 /usr/bin/grantiva runner version"))
    }
}
