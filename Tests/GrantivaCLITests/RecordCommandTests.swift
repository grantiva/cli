import Foundation
import XCTest
@testable import GrantivaCLI

final class RecordCommandTests: XCTestCase {
    func testStopInterruptsAndWaitsForCaptureProcess() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tail")
        process.arguments = ["-f", "/dev/null"]
        try process.run()

        RecorderLifecycle.stop(process)

        XCTAssertFalse(process.isRunning)
        XCTAssertNotEqual(process.terminationReason, .exit)
    }
}
