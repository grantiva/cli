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
        try await command.run()
        XCTAssertTrue(fake.calls.contains("build(module=mobile,variant=freeDebug,args=[])"), "\(fake.calls)")
        XCTAssertTrue(fake.calls.contains("install(com.fake.built,/fake/app.apk)"), "\(fake.calls)")
        XCTAssertFalse(fake.calls.contains("launch(com.fake.built)"), "\(fake.calls)")
    }

    /// A10: `build install --json` on Android runs the Android branch and
    /// emits applicationId and device{name, serial}, not bundleId/simulator.
    func testBuildInstallJSONOnAndroidUsesAndroidKeys() async throws {
        var command = try InstallCommand.parse(["--no-launch", "--json"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        let stdout = try await captureStandardOutput { try await command.run() }
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(stdout.utf8)) as? [String: Any], stdout)
        XCTAssertEqual(Set(json.keys), ["status", "applicationId", "device", "appPath"], stdout)
        XCTAssertEqual(json["status"] as? String, "installed")
        XCTAssertEqual(json["applicationId"] as? String, "com.fake.built")
        XCTAssertEqual(json["appPath"] as? String, "/fake/app.apk")
        let device = try XCTUnwrap(json["device"] as? [String: Any])
        XCTAssertEqual(device["name"] as? String, "Fake")
        XCTAssertEqual(device["serial"] as? String, "emulator-5598")
    }

    /// Points fd 1 at a temporary file while `body` runs.
    private func captureStandardOutput(_ body: () async throws -> Void) async throws -> String {
        let file = dir.appendingPathComponent("stdout-\(UUID().uuidString).txt")
        FileManager.default.createFile(atPath: file.path, contents: nil)
        let handle = try FileHandle(forWritingTo: file)
        let saved = dup(STDOUT_FILENO)
        dup2(handle.fileDescriptor, STDOUT_FILENO)
        do {
            try await body()
        } catch {
            dup2(saved, STDOUT_FILENO); close(saved); try? handle.close()
            throw error
        }
        dup2(saved, STDOUT_FILENO); close(saved); try handle.close()
        return try String(contentsOf: file, encoding: .utf8)
    }

    func testBuildInstallOnAndroidLaunchesTheBuiltApplicationID() async throws {
        var command = try InstallCommand.parse(["--module", "mobile"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        try await command.run()
        XCTAssertTrue(fake.calls.contains("install(com.fake.built,/fake/app.apk)"), "\(fake.calls)")
        XCTAssertTrue(fake.calls.contains("launch(com.fake.built)"), "\(fake.calls)")
    }

    /// The app's uid only exists once it is installed, so on Android the log
    /// stream starts after install, with the application ID from the build.
    func testRunOnAndroidStartsTheLogStreamAfterInstallWithTheBuiltApplicationID() async throws {
        var command = try RunCommand.parse(["--logs", "--timeout", "30"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.runnerManager = stubRunner
        _ = try? await command.run()
        let calls = fake.calls
        let install = try XCTUnwrap(calls.firstIndex(of: "install(com.fake.built,/fake/app.apk)"), "\(calls)")
        let stream = try XCTUnwrap(calls.firstIndex(of: "logStream(com.fake.built,-)"), "\(calls)")
        XCTAssertGreaterThan(stream, install, "\(calls)")
    }

    private func configureApplicationID(_ id: String) throws {
        try """
        module: app
        emulator: Pixel_8_API_35
        application_id: \(id)
        flows:
          - smoke.yaml
        """.write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
    }

    /// A03: a built variant (`--variant paidDebug`) is installed and tested
    /// under the output metadata's applicationId, not `application_id`.
    func testRunOnAndroidTestsTheBuiltVariantsApplicationIDOverConfig() async throws {
        try configureApplicationID("com.fake.configured")
        var command = try RunCommand.parse(["--variant", "paidDebug", "--timeout", "30"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.runnerManager = stubRunner
        _ = try? await command.run()
        XCTAssertTrue(fake.calls.contains("install(com.fake.built,/fake/app.apk)"), "\(fake.calls)")
        XCTAssertFalse(fake.calls.contains { $0.contains("com.fake.configured") }, "\(fake.calls)")
    }

    /// A03: `--app-file` installs and tests the APK's own package.
    func testRunOnAndroidTestsTheAppFilesApplicationIDOverConfig() async throws {
        try configureApplicationID("com.fake.configured")
        let apk = dir.appendingPathComponent("app-paid-debug.apk").path
        try Data().write(to: URL(fileURLWithPath: apk))
        var command = try RunCommand.parse(["--app-file", apk, "--timeout", "30"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.runnerManager = stubRunner
        _ = try? await command.run()
        XCTAssertTrue(fake.calls.contains("install(com.fake.binary,\(apk))"), "\(fake.calls)")
        XCTAssertFalse(fake.calls.contains { $0.contains("com.fake.configured") }, "\(fake.calls)")
    }

    func testBuildInstallOnAndroidUsesTheBuiltApplicationIDOverConfig() async throws {
        try configureApplicationID("com.fake.configured")
        var command = try InstallCommand.parse(["--variant", "paidDebug"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        try await command.run()
        XCTAssertTrue(fake.calls.contains("install(com.fake.built,/fake/app.apk)"), "\(fake.calls)")
        XCTAssertTrue(fake.calls.contains("launch(com.fake.built)"), "\(fake.calls)")
    }

    /// Review round 1: `--application-id` picks the test target, but the APK
    /// is installed under its own ID (the INCOMPATIBLE retry uninstalls that).
    func testBuildInstallWithAnApplicationIDOverrideInstallsUnderTheAppsOwnID() async throws {
        var command = try InstallCommand.parse(["--variant", "paidDebug", "--application-id", "com.fake.flag"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        try await command.run()
        XCTAssertTrue(fake.calls.contains("install(com.fake.built,/fake/app.apk)"), "\(fake.calls)")
        XCTAssertTrue(fake.calls.contains("launch(com.fake.flag)"), "\(fake.calls)")
    }

    func testRunWithAnApplicationIDOverrideInstallsUnderTheAppsOwnID() async throws {
        var command = try RunCommand.parse(["--application-id", "com.fake.flag", "--timeout", "30"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.runnerManager = stubRunner
        _ = try? await command.run()
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

    func testCIRunOnAndroidFailsWithTheLocalOnlyMessageBeforeAnyDeviceWork() async throws {
        try """
        module: app
        screens:
          - name: Home
            path: launch
        """.write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        var command = try CICommand.CIRunCommand.parse(["--no-build", "--application-id", "com.fake"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        do {
            try await command.run()
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains(DiffCommand.androidLocalOnlyMessage), "\(error)")
            XCTAssertTrue(fake.calls.isEmpty, "\(fake.calls)")
        }
    }

    func testRunOnAndroidCapturesUnderTheAndroidDirectory() async throws {
        var command = try RunCommand.parse(["--no-build", "--application-id", "com.fake", "--timeout", "30"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.runnerManager = stubRunner
        _ = try? await command.run()
        let failureShots = (try? FileManager.default.contentsOfDirectory(atPath: ".grantiva/captures/android")) ?? []
        XCTAssertFalse(failureShots.isEmpty, "the failure capture directory is the Android one")
        let firstShot = try XCTUnwrap(failureShots.first)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ".grantiva/captures/\(firstShot)"), "nothing lands in the iOS directory")
    }
}
