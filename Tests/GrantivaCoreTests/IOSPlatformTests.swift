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
        let executor = ScriptedExecutor([
            .success("/sims/ABC/Containers/Bundle/Application/X/Example.app\n"),
            .success("Example\n"),
        ])
        let platform = IOSPlatform(execute: executor.execute)
        let command = try await platform.logStream(deviceID: "ABC", appID: "com.example", filter: nil, level: .debug)
        XCTAssertEqual(command.executable, "/usr/bin/xcrun")
        XCTAssertEqual(command.arguments, [
            "simctl", "spawn", "ABC", "log", "stream", "--style", "compact",
            "--predicate", defaultLogPredicate(forBundleID: "com.example", executable: "Example"), "--level", "debug",
        ])
        XCTAssertEqual(executor.commands, [
            "xcrun simctl get_app_container 'ABC' 'com.example' app",
            "/usr/bin/plutil -extract CFBundleExecutable raw -o - '/sims/ABC/Containers/Bundle/Application/X/Example.app/Info.plist'",
        ])
        let explicit = try await platform.logStream(deviceID: "ABC", appID: nil, filter: "subsystem == \"x\"", level: nil)
        XCTAssertEqual(explicit.arguments.suffix(2), ["--predicate", "subsystem == \"x\""])
        let none = try await platform.logStream(deviceID: "ABC", appID: nil, filter: nil, level: nil)
        XCTAssertFalse(none.arguments.contains("--predicate"))
    }

    func testLogStreamFallsBackToTheBundlePredicateWhenTheAppIsNotInstalled() async throws {
        let executor = ScriptedExecutor([.failure(GrantivaError.commandFailed("No such app", 2))])
        let command = try await IOSPlatform(execute: executor.execute)
            .logStream(deviceID: "ABC", appID: "com.example", filter: nil, level: nil)
        XCTAssertEqual(command.arguments.suffix(2), ["--predicate", defaultLogPredicate(forBundleID: "com.example")])
    }

    func testRunnerEnvironmentPointsXcodebuildAtGrantivasXcconfig() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-ios-platform-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: home) }

        let env = IOSPlatform().runnerEnvironment(runnerHome: home, deviceID: "SIM-1")
        let xcconfig = "\(home)/\(WDABuildConfig.fileName)"
        XCTAssertEqual(env["XCODE_XCCONFIG_FILE"], xcconfig)
        let contents = try String(contentsOfFile: xcconfig, encoding: .utf8)
        XCTAssertTrue(contents.contains("WARNING_CFLAGS = $(inherited) -Wno-poison-system-directories"), contents)
    }

    func testRunnerEnvironmentFallsBackWhenTheXcconfigCannotBeWritten() {
        XCTAssertEqual(IOSPlatform().runnerEnvironment(runnerHome: "/nonexistent-grantiva-\(UUID().uuidString)", deviceID: "SIM-1"), [:])
    }

    func testWDABuildConfigRewritesAStaleFileAndLeavesACurrentOne() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-wda-config-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: home) }
        let path = "\(home)/\(WDABuildConfig.fileName)"

        try "WARNING_CFLAGS = -Wold".write(toFile: path, atomically: true, encoding: .utf8)
        XCTAssertEqual(WDABuildConfig.install(in: home), path)
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), WDABuildConfig.contents)

        let before = try FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
        XCTAssertEqual(WDABuildConfig.install(in: home), path)
        let after = try FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
        XCTAssertEqual(before, after, "a current file is left untouched")
    }

    func testResolveBinaryRejectsAnAPK() async {
        do {
            _ = try await IOSPlatform().resolveBinary("/tmp/app.apk")
            XCTFail("expected rejection")
        } catch {
            XCTAssertTrue("\(error)".contains(".app or .ipa"), "\(error)")
        }
    }

    func testAttachDriverNeedsAPortAndReturnsWDA() async throws {
        let platform = IOSPlatform(execute: ScriptedExecutor([]).execute)
        let attachment = try await platform.attachDriver(deviceID: "921A0945-7157-4533-BA1F-21E8132D3E40", port: 8100)
        XCTAssertEqual(attachment.port, 8100)
        await attachment.detach()
        do {
            _ = try await platform.attachDriver(deviceID: "921A0945-7157-4533-BA1F-21E8132D3E40", port: nil)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("WebDriverAgent port"), "\(error)")
        }
    }

    // simctl prints "Recording completed. Writing to disk." and "Wrote video
    // to: ..." on its own stdout; inherited, that landed ahead of `record`'s
    // result and broke `record --json | jq`.
    func testRecordVideoProcessDoesNotInheritStdout() throws {
        let log = FileHandle.nullDevice
        let recorder = IOSPlatform.makeRecorder(deviceID: "ABC-123", path: "/tmp/x.mov", log: log)
        XCTAssertEqual(recorder.arguments, ["simctl", "io", "ABC-123", "recordVideo", "--codec=h264", "/tmp/x.mov"])
        XCTAssertTrue((recorder.standardOutput as? FileHandle) === log, "stdout must go to the log, not be inherited")
        XCTAssertTrue((recorder.standardError as? FileHandle) === log)
    }

    func testIsInstalledProbesTheAppContainer() async {
        let installed = IOSPlatform(execute: { command in
            XCTAssertEqual(command, "xcrun simctl get_app_container 'ABC-123' 'com.example.app'")
            return "/path/to/App.app\n"
        })
        let isInstalled = await installed.isInstalled(appID: "com.example.app", deviceID: "ABC-123")
        XCTAssertEqual(isInstalled, true)
        let missing = IOSPlatform(execute: { _ in throw GrantivaError.commandFailed("No such file or directory", 2) })
        let isMissing = await missing.isInstalled(appID: "com.example.app", deviceID: "ABC-123")
        XCTAssertEqual(isMissing, false)
        let shutDown = IOSPlatform(execute: { _ in
            throw GrantivaError.commandFailed("Unable to lookup in current state: Shutdown", 149)
        })
        let isUnknown = await shutDown.isInstalled(appID: "com.example.app", deviceID: "ABC-123")
        XCTAssertNil(isUnknown, "an unrelated simctl failure must not read as not installed")
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
