import Foundation
import XCTest
@testable import GrantivaCore

final class AndroidPlatformTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("android-platform-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private func platform(_ shell: ScriptedShell, options: AndroidPlatform.Options = .init()) -> AndroidPlatform {
        let sdk = AndroidSDK(root: "/sdk")
        let adb = ADB(path: sdk.adb, execute: shell.execute)
        return AndroidPlatform(
            sdk: sdk, adb: adb,
            gradle: GradleBuildRunner(execute: shell.execute),
            emulators: EmulatorManager(sdk: sdk, adb: adb, execute: shell.execute, spawn: { _, _ in 1 },
                                       provenance: AndroidProvenance(directory: scratch.path), bootTimeout: 1, pollInterval: 0.01),
            captureSettings: AndroidCaptureSettings(adb: adb, stateDirectory: scratch.path),
            execute: shell.execute,
            options: options,
            environment: ["PATH": "/usr/bin", "JAVA_HOME": "/nonexistent"]
        )
    }

    func testRunnerArgumentsForAndroid() {
        let p = platform(ScriptedShell())
        XCTAssertEqual(
            p.runnerGlobalArguments(deviceID: "emulator-5554", appFile: "/b/app.apk"),
            ["--platform", "android", "--device", "emulator-5554", "--no-ansi", "--no-app-install", "--app-file", "/b/app.apk"]
        )
        XCTAssertEqual(p.runnerTestArguments(), [])
        let env = p.runnerEnvironment(runnerHome: "/home/.grantiva/runner")
        XCTAssertEqual(env["MAESTRO_RUNNER_HOME"], "/home/.grantiva/runner")
        XCTAssertEqual(env["ANDROID_HOME"], "/sdk")
        XCTAssertEqual(env["PATH"], "/sdk/platform-tools:/sdk/emulator:/usr/bin")
    }

    func testBootDeviceWithARunningSerialUsesItDirectly() async throws {
        let shell = ScriptedShell([
            .success("List of devices attached\nemulator-5556 device"),
            .success("Pixel_8_API_35\nOK"),
        ])
        let booted = try await platform(shell).bootDevice(named: "emulator-5556")
        XCTAssertEqual(booted, BootedDevice(udid: "emulator-5556", name: "Pixel_8_API_35"))
    }

    func testBootDeviceWithAnOfflineSerialFailsNamingTheState() async {
        let shell = ScriptedShell([.success("List of devices attached\nemulator-5556 offline")])
        do {
            _ = try await platform(shell).bootDevice(named: "emulator-5556")
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("emulator-5556 is offline"), "\(error)")
        }
    }

    func testBootDeviceWithAnUnknownSerialFails() async {
        let shell = ScriptedShell([.success("List of devices attached")])
        do {
            _ = try await platform(shell).bootDevice(named: "R58M1234ABC")
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("R58M1234ABC"), "\(error)")
            XCTAssertTrue("\(error)".contains("adb devices"), "\(error)")
        }
    }

    func testDisplayGeometryDerivesScaleFromDensity() async throws {
        let shell = ScriptedShell([.success("Physical size: 1080x2400"), .success("Physical density: 420")])
        let geometry = try await platform(shell).displayGeometry(deviceID: "emulator-5554")
        XCTAssertEqual(geometry, DeviceGeometry(pixelWidth: 1080, pixelHeight: 2400, scale: 2.625))
    }

    func testPrepareIsSkippedOnPhysicalDevicesUnlessAllowed() async {
        let shell = ScriptedShell()
        await platform(shell).prepareForCapture(deviceID: "R58M1234ABC")
        await platform(shell).restoreAfterCapture(deviceID: "R58M1234ABC")
        XCTAssertTrue(shell.commands.isEmpty)

        let allowed = ScriptedShell()
        allowed.fallback = "1"
        await platform(allowed, options: .init(allowDeviceSettings: true)).prepareForCapture(deviceID: "R58M1234ABC")
        XCTAssertFalse(allowed.commands.isEmpty)
    }

    func testPrepareRestoresACrashedRunFirst() async throws {
        let state = AndroidCaptureSettings.statePath(serial: "emulator-5554", directory: scratch.path)
        try JSONEncoder().encode(["global/window_animation_scale": "1.0"] as [String: String?]).write(to: URL(fileURLWithPath: state))
        let shell = ScriptedShell()
        shell.fallback = "1"
        await platform(shell).prepareForCapture(deviceID: "emulator-5554")
        XCTAssertTrue(shell.commands[0].contains("command exit"), "the crash restore runs before anything else: \(shell.commands[0])")
        XCTAssertTrue(shell.commands.contains { $0.contains("settings put global window_animation_scale 1.0") })
    }

    func testResolveBinaryRequiresAnExistingAPKAndReadsItsID() async throws {
        let apk = scratch.appendingPathComponent("app.apk").path
        try Data().write(to: URL(fileURLWithPath: apk))
        let shell = ScriptedShell([.success("com.example.app\n")])
        let resolved = try await platform(shell).resolveBinary(apk)
        XCTAssertEqual(resolved.appPath, apk)
        XCTAssertEqual(resolved.appID, "com.example.app")
        XCTAssertEqual(shell.commands, ["'/sdk/cmdline-tools/latest/bin/apkanalyzer' manifest application-id \(shellQuoted(apk))"])

        do {
            _ = try await platform(ScriptedShell()).resolveBinary(scratch.appendingPathComponent("Demo.app").path)
            XCTFail("expected rejection")
        } catch {
            XCTAssertTrue("\(error)".contains(".apk"), "\(error)")
        }
    }

    func testLogStreamClearsThenFiltersByUID() async throws {
        let shell = ScriptedShell([.success(""), .success("package:com.example.app uid:10123")])
        let command = try await platform(shell).logStream(deviceID: "emulator-5554", appID: "com.example.app", filter: "MyTag", level: nil)
        XCTAssertEqual(shell.commands[0], "'/sdk/platform-tools/adb' -s 'emulator-5554' logcat -c")
        XCTAssertEqual(command.executable, "/sdk/platform-tools/adb")
        XCTAssertEqual(command.arguments, ["-s", "emulator-5554", "logcat", "--uid=10123", "-v", "time", "-s", "MyTag"])
    }

    func testLogStreamWithoutAnInstalledAppFails() async {
        let shell = ScriptedShell([.success(""), .success("")])
        do {
            _ = try await platform(shell).logStream(deviceID: "emulator-5554", appID: "com.example.app", filter: nil, level: nil)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("com.example.app"), "\(error)")
        }
    }

    func testCleanupOrphansForceStopsUIA2AndRemovesForwards() async {
        let shell = ScriptedShell()
        await platform(shell).cleanupOrphans(deviceID: "emulator-5554")
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell am force-stop 'io.appium.uiautomator2.server'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell am force-stop 'io.appium.uiautomator2.server.test'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' forward --remove-all",
        ])
    }

    func testBuildReadsTheDeviceABIAndUsesTheResolvedModuleAndVariant() async throws {
        let metadataDir = scratch.appendingPathComponent("mobile/build/outputs/apk/free/debug")
        try FileManager.default.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        try """
        {"applicationId":"com.example.free","variantName":"freeDebug","elements":[{"type":"SINGLE","filters":[],"outputFile":"mobile-free-debug.apk"}]}
        """.write(to: metadataDir.appendingPathComponent("output-metadata.json"), atomically: true, encoding: .utf8)
        let shell = ScriptedShell([.success("arm64-v8a"), .failure(GrantivaError.commandFailed("no java", 1)), .success("BUILD SUCCESSFUL")])
        let request = PlatformBuildRequest(
            config: GrantivaConfig(platform: .android, android: AndroidProject()),
            resolved: ResolvedProject(android: AndroidProject(module: "mobile", variant: "freeDebug", buildArgs: ["-Px=1"])),
            deviceID: "emulator-5554",
            extraBuildSettings: ["-Px=1"]
        )
        let previous = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(scratch.path)
        defer { FileManager.default.changeCurrentDirectoryPath(previous) }
        let result = try await platform(shell).build(request)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.applicationId, "com.example.free")
        XCTAssertTrue(shell.commands[2].contains("':mobile:assembleFreeDebug' --console=plain '-Px=1'"), shell.commands[2])
    }

    func testFactoryMakesAndroidWhenAnSDKExists() throws {
        XCTAssertEqual(try DevicePlatformFactory.make(.ios).platform, .ios)
        // `.android` needs a real SDK on this machine; the error path is what
        // every machine can check.
        if AndroidSDK.locate() == nil {
            XCTAssertThrowsError(try DevicePlatformFactory.make(.android))
        } else {
            XCTAssertEqual(try DevicePlatformFactory.make(.android).platform, .android)
        }
    }
}
