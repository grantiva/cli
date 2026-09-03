import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class ConsoleOpenCommandTests: XCTestCase {
    func testMapsApiHostsToDashboardHosts() {
        XCTAssertEqual(ConsoleOpenCommand.dashboardURL(area: .flags, apiBaseURL: "https://api.grantiva.io"), "https://grantiva.io/dashboard/feature-flags")
        XCTAssertEqual(ConsoleOpenCommand.dashboardURL(area: .home, apiBaseURL: "https://dev-api.grantiva.io"), "https://dev.grantiva.io/dashboard")
        XCTAssertEqual(ConsoleOpenCommand.dashboardURL(area: .keys, apiBaseURL: "http://localhost:8080"), "http://localhost:8080/dashboard/settings/api-keys")
        XCTAssertEqual(ConsoleOpenCommand.dashboardURL(area: .audit, apiBaseURL: "garbage"), "https://grantiva.io/dashboard/audit-log")
    }

    func testHostMappingRequiresAnExactTrustedHostAndSanitizesCustomOrigins() {
        XCTAssertEqual(
            ConsoleOpenCommand.dashboardURL(area: .home, apiBaseURL: "https://api.grantiva.io.evil.example/api.grantiva.io"),
            "https://api.grantiva.io.evil.example/dashboard"
        )
        XCTAssertEqual(
            ConsoleOpenCommand.dashboardURL(area: .vrt, apiBaseURL: "https://user:secret@[::1]:8443/api?token=x#fragment"),
            "https://[::1]:8443/dashboard/vrt"
        )
        XCTAssertEqual(
            ConsoleOpenCommand.dashboardURL(area: .home, apiBaseURL: "file:///tmp/api"),
            "https://grantiva.io/dashboard"
        )
    }

    func testParsesAreaAndDefaultsToHome() throws {
        XCTAssertEqual(try ConsoleOpenCommand.parse([]).area, .home)
        XCTAssertEqual(try ConsoleOpenCommand.parse(["team"]).area, .team)
        XCTAssertThrowsError(try ConsoleOpenCommand.parse(["nowhere"]))
    }

    func testRunOpensResolvedURLAndSurfacesNonzeroExit() throws {
        let command = try ConsoleOpenCommand.parse(["flags"])
        var opened: String?
        try command.run(apiBaseURL: "https://dev-api.grantiva.io", openURL: {
            opened = $0
            return 0
        })
        XCTAssertEqual(opened, "https://dev.grantiva.io/dashboard/feature-flags")

        XCTAssertThrowsError(try command.run(apiBaseURL: "https://api.grantiva.io", openURL: { _ in 17 })) { error in
            guard case GrantivaError.commandFailed(let invocation, let status) = error else {
                return XCTFail("unexpected \(error)")
            }
            XCTAssertEqual(invocation, "open https://grantiva.io/dashboard/feature-flags")
            XCTAssertEqual(status, 17)
        }
    }

    func testJSONRunDoesNotLaunchBrowser() throws {
        let command = try ConsoleOpenCommand.parse(["vrt", "--json"])
        var called = false
        try command.run(apiBaseURL: "https://api.grantiva.io", openURL: { _ in
            called = true
            return 0
        })
        XCTAssertFalse(called)
    }
}
