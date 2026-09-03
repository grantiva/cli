import XCTest
@testable import GrantivaCore

final class RunnerSessionAppIdTests: XCTestCase {
    func testReplacesIndentedAppIdWithoutAddingDuplicateKey() {
        let input = """
          appId: com.example.old
        name: Login
        ---
        - launchApp
        """

        let result = RunnerSession.injectAppId(input, bundleId: "com.example.new")

        XCTAssertEqual(result, """
          appId: com.example.new
        name: Login
        ---
        - launchApp
        """)
        XCTAssertEqual(result.components(separatedBy: "appId:").count - 1, 1)
    }

    func testInsertsAppIdBeforeSeparatorAtStartOfFlow() {
        let input = """
        ---
        - launchApp
        """

        XCTAssertEqual(
            RunnerSession.injectAppId(input, bundleId: "com.example.app"),
            """
            appId: com.example.app
            ---
            - launchApp
            """
        )
    }

    func testAddsHeaderToCommandOnlyFlow() {
        let input = """
        - launchApp
        - tapOn: Continue
        """

        XCTAssertEqual(
            RunnerSession.injectAppId(input, bundleId: "com.example.app"),
            """
            appId: com.example.app
            ---
            - launchApp
            - tapOn: Continue
            """
        )
    }
}
