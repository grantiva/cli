import XCTest
@testable import GrantivaCLI

final class ConsoleOpenCommandTests: XCTestCase {
    func testMapsApiHostsToDashboardHosts() {
        XCTAssertEqual(ConsoleOpenCommand.dashboardURL(area: .flags, apiBaseURL: "https://api.grantiva.io"), "https://grantiva.io/dashboard/feature-flags")
        XCTAssertEqual(ConsoleOpenCommand.dashboardURL(area: .home, apiBaseURL: "https://dev-api.grantiva.io"), "https://dev.grantiva.io/dashboard")
        XCTAssertEqual(ConsoleOpenCommand.dashboardURL(area: .keys, apiBaseURL: "http://localhost:8080"), "http://localhost:8080/dashboard/settings/api-keys")
        XCTAssertEqual(ConsoleOpenCommand.dashboardURL(area: .audit, apiBaseURL: "garbage"), "https://grantiva.io/dashboard/audit-log")
    }

    func testParsesAreaAndDefaultsToHome() throws {
        XCTAssertEqual(try ConsoleOpenCommand.parse([]).area, .home)
        XCTAssertEqual(try ConsoleOpenCommand.parse(["team"]).area, .team)
        XCTAssertThrowsError(try ConsoleOpenCommand.parse(["nowhere"]))
    }
}
