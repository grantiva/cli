import XCTest
@testable import GrantivaCore

final class RunnerSessionCleanupTests: XCTestCase {
    func testCleanupFinishesBeforeSuccessfulOperationReturns() async throws {
        let events = EventLog()

        let result = await RunnerSession.runWithStatusBarCleanup(
            udid: "TEST-UDID",
            clear: { udid in
                try? await Task.sleep(for: .milliseconds(10))
                await events.append("clear:\(udid)")
            },
            operation: {
                await events.append("operation")
                return 42
            }
        )

        XCTAssertEqual(result, 42)
        let values = await events.values
        XCTAssertEqual(values, ["operation", "clear:TEST-UDID"])
    }

}

private actor EventLog {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}
