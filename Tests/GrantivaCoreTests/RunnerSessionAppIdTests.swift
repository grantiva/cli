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

    func testRunnerEnvironmentComesFromThePlatform() {
        struct EnvPlatform: DevicePlatform {
            let platform: Platform = .android
            func bootDevice(named: String) async throws -> BootedDevice { fatalError() }
            func displayGeometry(deviceID: String) async throws -> DeviceGeometry { fatalError() }
            func build(_ request: PlatformBuildRequest) async throws -> BuildResult { fatalError() }
            func install(appID: String, productPath: String, deviceID: String) async throws {}
            func launch(appID: String, deviceID: String) async throws {}
            func terminate(appID: String, deviceID: String) async throws {}
            func uninstall(appID: String, deviceID: String) async throws {}
            func prepareForCapture(deviceID: String) async {}
            func restoreAfterCapture(deviceID: String) async {}
            func runnerGlobalArguments(deviceID: String, appFile: String?) -> [String] { [] }
            func runnerTestArguments() -> [String] { [] }
            func resolveBinary(_ path: String) async throws -> ResolvedBinary { fatalError() }
            func defaultDevice() async throws -> BootedDevice { fatalError() }
            func screenshot(deviceID: String, to path: String) async throws {}
            func logStream(deviceID: String, appID: String?, filter: String?, level: LogStreamLevel?) async throws -> LogStreamCommand { fatalError() }
            func runnerEnvironment(runnerHome: String, deviceID: String) -> [String: String] { ["MAESTRO_RUNNER_HOME": runnerHome] }
            func cleanupOrphans(deviceID: String) async {}
            func attachDriver(deviceID: String, port: UInt16?) async throws -> DriverAttachment { fatalError() }
            func recordVideo(deviceID: String, to path: String, seconds: Double) async throws {}
        }
        XCTAssertEqual(
            RunnerSession.runnerEnvironment(platform: EnvPlatform(), runnerDir: "/home/.grantiva/runner", deviceID: "SIM-1"),
            ["MAESTRO_RUNNER_HOME": "/home/.grantiva/runner"]
        )
    }
}
