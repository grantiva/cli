import Foundation
import XCTest
@testable import GrantivaCore

final class IOSPlatformTests: XCTestCase {
    func testRunnerGlobalArgumentsMatchTheHistoricalShape() {
        let platform = IOSPlatform()
        XCTAssertEqual(
            platform.runnerGlobalArguments(deviceID: "ABC-123", appFile: "/tmp/Demo.app"),
            ["--platform", "ios", "--device", "ABC-123", "--no-ansi", "--no-app-install", "--app-file", "/tmp/Demo.app"]
        )
        XCTAssertEqual(
            platform.runnerGlobalArguments(deviceID: "ABC-123", appFile: nil),
            ["--platform", "ios", "--device", "ABC-123", "--no-ansi", "--no-app-install"]
        )
    }

    func testRunnerTestArgumentsDisableIdleWaitOnIOS() {
        XCTAssertEqual(IOSPlatform().runnerTestArguments(), ["--wait-for-idle-timeout", "0"])
    }

    func testPrepareAndRestoreDriveSimctlStatusBar() async {
        let executor = ScriptedExecutor([.success(""), .success("")])
        let platform = IOSPlatform(execute: executor.execute)
        await platform.prepareForCapture(deviceID: "ABC")
        await platform.restoreAfterCapture(deviceID: "ABC")
        XCTAssertEqual(executor.commands.count, 2)
        XCTAssertTrue(executor.commands[0].hasPrefix("xcrun simctl status_bar ABC override --time 9:41"))
        XCTAssertEqual(executor.commands[1], "xcrun simctl status_bar ABC clear")
    }

    func testBuildUsesTheSimulatorDestination() async throws {
        let executor = ScriptedExecutor([
            .success(""),
            .success("BUILT_PRODUCTS_DIR = /tmp/P\nFULL_PRODUCT_NAME = Demo.app\n"),
        ])
        let platform = IOSPlatform(xcodebuild: XcodeBuildRunner(execute: executor.execute))
        let request = PlatformBuildRequest(
            config: GrantivaConfig(scheme: "Demo", project: "Demo.xcodeproj"),
            resolved: ResolvedProject(scheme: "Demo", project: "Demo.xcodeproj"),
            deviceID: "ABC",
            extraBuildSettings: []
        )
        let result = try await platform.build(request)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.destination, "platform=iOS Simulator,id=ABC")
        XCTAssertEqual(result.productPath, "/tmp/P/Demo.app")
        XCTAssertTrue(executor.commands[0].contains("'platform=iOS Simulator,id=ABC'"))
    }

    func testMakeReturnsIOS() {
        XCTAssertEqual(DevicePlatformFactory.make(.ios).platform, .ios)
    }
}

private final class ScriptedExecutor: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<String, Error>]
    private var recorded: [String] = []
    init(_ results: [Result<String, Error>]) { self.results = results }
    func execute(_ command: String) async throws -> String {
        try lock.withLock {
            recorded.append(command)
            return try results.removeFirst().get()
        }
    }
    var commands: [String] { lock.withLock { recorded } }
}
