import ArgumentParser
import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class AndroidCommandTests: XCTestCase {
    private var dir: URL!
    private var previousDirectory: String!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("android-cmd-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try """
        module: app
        emulator: Pixel_8_API_35
        flows:
          - smoke.yaml
        """.write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        try "appId: com.placeholder\n---\n- launchApp\n".write(to: dir.appendingPathComponent("smoke.yaml"), atomically: true, encoding: .utf8)
        previousDirectory = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(dir.path)
        unsetenv("GRANTIVA_PLATFORM")
    }

    override func tearDownWithError() throws {
        FileManager.default.changeCurrentDirectoryPath(previousDirectory)
        try? FileManager.default.removeItem(at: dir)
    }

    private let stubRunner = RunnerManager(ensureAvailable: {}, runnerPath: { "/usr/bin/false" }, runnerDir: { NSTemporaryDirectory() })

    func testRunOnAndroidRejectsAnIOSFlagBeforeTouchingADevice() async throws {
        var command = try RunCommand.parse(["--no-build", "--scheme", "Demo"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.runnerManager = stubRunner
        do {
            try await command.run()
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("--scheme"), "\(error)")
            XCTAssertTrue(fake.calls.isEmpty, "\(fake.calls)")
        }
    }

    func testRunOnAndroidWithoutAnApplicationIDFailsAfterBootWithTheAndroidMessage() async throws {
        var command = try RunCommand.parse(["--no-build"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.runnerManager = stubRunner
        do {
            try await command.run()
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("--application-id"), "\(error)")
            XCTAssertEqual(fake.calls.first, "bootDevice(Pixel_8_API_35)", "\(fake.calls)")
        }
    }

    /// Review Focus 2: `--logs` on Android streams through the platform, never simctl.
    func testRunOnAndroidWithLogsStreamsThroughThePlatform() async throws {
        var command = try RunCommand.parse(["--no-build", "--application-id", "com.fake", "--logs", "--logs-tag", "Fake", "--timeout", "30"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.runnerManager = stubRunner
        // The stub runner is /usr/bin/false, so the run fails at the runner;
        // everything before it is what this test pins.
        _ = try? await command.run()
        XCTAssertTrue(fake.calls.contains("logStream(com.fake,Fake)"), "\(fake.calls)")
        XCTAssertTrue(fake.calls.contains("screenshot"), "the failure screenshot goes through the platform: \(fake.calls)")
        XCTAssertTrue(fake.calls.contains("cleanupOrphans"), "\(fake.calls)")
    }

    func testRunWithFlowOnAndroidKeepsTheGradleTarget() async throws {
        var command = try RunCommand.parse(["--flow", "smoke.yaml", "--module", "mobile", "--variant", "freeDebug", "--timeout", "30"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.runnerManager = stubRunner
        _ = try? await command.run()
        XCTAssertTrue(fake.calls.contains("build(module=mobile,variant=freeDebug,args=[])"), "\(fake.calls)")
    }

    func testBuildInstallOnAndroidUsesTheBuiltApplicationID() async throws {
        var command = try InstallCommand.parse(["--no-launch", "--module", "mobile", "--variant", "freeDebug"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        do {
            try await command.run()
        } catch {
            // The data-container step is unsupported on Android and throws after install.
            XCTAssertTrue("\(error)".contains("data container"), "\(error)")
        }
        XCTAssertTrue(fake.calls.contains("build(module=mobile,variant=freeDebug,args=[])"), "\(fake.calls)")
        XCTAssertTrue(fake.calls.contains("install(com.fake.built,/fake/app.apk)"), "\(fake.calls)")
    }

    func testAppFileAPKGoesThroughThePlatformResolver() async throws {
        let apk = dir.appendingPathComponent("prebuilt.apk").path
        try Data().write(to: URL(fileURLWithPath: apk))
        var command = try InstallCommand.parse(["--no-launch", "--app-file", apk])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        _ = try? await command.run()
        XCTAssertTrue(fake.calls.contains("resolveBinary(\(apk))"), "\(fake.calls)")
        XCTAssertTrue(fake.calls.contains("install(com.fake.binary,\(apk))"), "\(fake.calls)")
    }
}
