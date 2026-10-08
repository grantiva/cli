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

    func testMakeReturnsIOS() throws {
        XCTAssertEqual(try DevicePlatformFactory.make(.ios).platform, .ios)
    }

    func testScreenshotUsesSimctlIO() async throws {
        let executor = ScriptedExecutor([.success("")])
        try await IOSPlatform(execute: executor.execute).screenshot(deviceID: "ABC", to: "/tmp/a b.png")
        XCTAssertEqual(executor.commands, ["xcrun simctl io 'ABC' screenshot '/tmp/a b.png'"])
    }

    func testLogStreamBuildsTheSimctlSpawnCommand() async throws {
        let command = try await IOSPlatform().logStream(deviceID: "ABC", appID: "com.example", filter: nil, level: "debug")
        XCTAssertEqual(command.executable, "/usr/bin/xcrun")
        XCTAssertEqual(command.arguments, [
            "simctl", "spawn", "ABC", "log", "stream", "--style", "compact",
            "--predicate", defaultLogPredicate(forBundleID: "com.example"), "--level", "debug",
        ])
        let explicit = try await IOSPlatform().logStream(deviceID: "ABC", appID: nil, filter: "subsystem == \"x\"", level: nil)
        XCTAssertEqual(explicit.arguments.suffix(2), ["--predicate", "subsystem == \"x\""])
        let none = try await IOSPlatform().logStream(deviceID: "ABC", appID: nil, filter: nil, level: nil)
        XCTAssertFalse(none.arguments.contains("--predicate"))
    }

    func testRunnerEnvironmentIsEmptyOnIOS() {
        XCTAssertEqual(IOSPlatform().runnerEnvironment(runnerHome: "/r"), [:])
    }

    func testResolveBinaryRejectsAnAPK() async {
        do {
            _ = try await IOSPlatform().resolveBinary("/tmp/app.apk")
            XCTFail("expected rejection")
        } catch {
            XCTAssertTrue("\(error)".contains(".app or .ipa"), "\(error)")
        }
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
