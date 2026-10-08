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

    func testRunnerArgumentsKeepTheHistoricalIOSOrder() {
        let args = RunnerSession.runnerArguments(
            runnerBin: "/opt/runner",
            platform: IOSPlatform(),
            udid: "ABC-123",
            appFile: "/tmp/Demo.app",
            reportDir: "/tmp/report",
            snapshot: "full",
            failFast: true,
            keepAlive: true,
            flowPaths: ["/tmp/a.yaml", "/tmp/b.yaml"]
        )
        XCTAssertEqual(args, [
            "/opt/runner",
            "--platform", "ios",
            "--device", "ABC-123",
            "--no-ansi",
            "--no-app-install",
            "--app-file", "/tmp/Demo.app",
            "test",
            "--output", "/tmp/report",
            "--flatten",
            "--wait-for-idle-timeout", "0",
            "--artifacts", "always",
            "--fail-fast",
            "--keep-alive",
            "/tmp/a.yaml", "/tmp/b.yaml",
        ])

        let minimal = RunnerSession.runnerArguments(
            runnerBin: "/opt/runner",
            platform: IOSPlatform(),
            udid: "ABC-123",
            appFile: nil,
            reportDir: "/tmp/report",
            snapshot: "failure",
            keepAlive: false,
            flowPaths: ["/tmp/screens.yaml"]
        )
        XCTAssertEqual(minimal, [
            "/opt/runner",
            "--platform", "ios",
            "--device", "ABC-123",
            "--no-ansi",
            "--no-app-install",
            "test",
            "--output", "/tmp/report",
            "--flatten",
            "--wait-for-idle-timeout", "0",
            "--artifacts", "failure",
            "/tmp/screens.yaml",
        ])
    }
}
