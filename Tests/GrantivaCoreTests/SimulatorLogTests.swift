import XCTest
@testable import GrantivaCore

final class SimulatorLogTests: XCTestCase {
    func testCommandQuotesEveryArgumentIncludingAdversarialFilterValues() {
        let command = simulatorLogCommand([
            "xcrun",
            "simctl",
            "--predicate",
            "subsystem == \"user'value; touch /tmp/injected\"",
            "$(touch /tmp/also-injected)",
        ])

        XCTAssertEqual(
            command,
            "'xcrun' 'simctl' '--predicate' 'subsystem == \"user'\\''value; touch /tmp/injected\"' '$(touch /tmp/also-injected)'"
        )
    }
}
