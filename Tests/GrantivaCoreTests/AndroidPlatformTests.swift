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

    private func platform(
        _ shell: ScriptedShell, options: AndroidPlatform.Options = .init(),
        environment: [String: String] = ["PATH": "/usr/bin", "JAVA_HOME": "/nonexistent"]
    ) -> AndroidPlatform {
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
            environment: environment
        )
    }

    func testRunnerArgumentsForAndroid() {
        let p = platform(ScriptedShell())
        XCTAssertEqual(
            p.runnerGlobalArguments(deviceID: "emulator-5554", appFile: "/b/app.apk"),
            ["--platform", "android", "--device", "emulator-5554", "--no-ansi", "--no-app-install", "--app-file", "/b/app.apk"]
        )
        XCTAssertEqual(p.runnerTestArguments(), [])
        let env = p.runnerEnvironment(runnerHome: "/home/.grantiva/runner", deviceID: "emulator-5554")
        XCTAssertEqual(env["MAESTRO_RUNNER_HOME"], "/home/.grantiva/runner")
        XCTAssertEqual(env["ANDROID_HOME"], "/sdk")
        XCTAssertEqual(env["PATH"], "/sdk/platform-tools:/sdk/emulator:/usr/bin")
    }

    // MARK: - L48: the UIAutomator2 start limit can be raised

    func testRunnerArgumentsCarryTheDriverStartTimeoutWhenSet() {
        let p = platform(ScriptedShell(), environment: ["PATH": "/usr/bin", AndroidPlatform.driverStartTimeoutVariable: "120"])
        XCTAssertEqual(
            p.runnerGlobalArguments(deviceID: "emulator-5554", appFile: nil),
            ["--platform", "android", "--device", "emulator-5554", "--no-ansi", "--no-app-install", "--driver-start-timeout", "120"]
        )
        XCTAssertEqual(AndroidPlatform.driverStartTimeout(environment: [AndroidPlatform.driverStartTimeoutVariable: " 45 "]), 45)
        XCTAssertNil(AndroidPlatform.driverStartTimeout(environment: [AndroidPlatform.driverStartTimeoutVariable: "soon"]))
        XCTAssertNil(AndroidPlatform.driverStartTimeout(environment: [AndroidPlatform.driverStartTimeoutVariable: "0"]))
        XCTAssertNil(AndroidPlatform.driverStartTimeout(environment: [:]))
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

    /// N-12: a capture never starts with a key-focused row highlighted.
    func testPrepareRestoresTouchModeOnAnEmulator() async {
        let shell = ScriptedShell()
        shell.fallback = "cur=1080x2400\nmInTouchMode=false\n"
        await platform(shell).prepareForCapture(deviceID: "emulator-5554")
        XCTAssertTrue(
            shell.commands.contains { $0.contains("input motionevent DOWN 0 2399 && input motionevent CANCEL 0 2399") },
            "\(shell.commands)"
        )
    }

    func testPrepareRestoresACrashedRunFirst() async throws {
        let state = AndroidCaptureSettings.statePath(serial: "emulator-5554", directory: scratch.path)
        try JSONEncoder().encode(["global/window_animation_scale": "1.0"] as [String: String?]).write(to: URL(fileURLWithPath: state))
        let shell = ScriptedShell()
        shell.fallback = "1"
        await platform(shell).prepareForCapture(deviceID: "emulator-5554")
        // The restore's own `adb devices` pre-check may come first; the first
        // command sent to the device is the restore's demo-mode exit.
        let first = shell.commands.first { !$0.hasSuffix("devices -l") } ?? ""
        XCTAssertTrue(first.contains("command exit"), "the crash restore runs before anything else: \(first)")
        XCTAssertTrue(shell.commands.contains { $0.contains("settings put global window_animation_scale 1.0") })
    }

    func testResolveBinaryRequiresAnExistingAPKAndReadsItsID() async throws {
        let apk = scratch.appendingPathComponent("app.apk").path
        try Data().write(to: URL(fileURLWithPath: apk))
        let shell = ScriptedShell([.success(""), .success("com.example.app\n")])
        let resolved = try await platform(shell).resolveBinary(apk)
        // The realpath(3) spelling, as on iOS (B4-L53.P5).
        let canonical = AppBinaryResolver.canonicalPath(apk)
        XCTAssertEqual(resolved.appPath, canonical)
        XCTAssertEqual(resolved.appID, "com.example.app")
        XCTAssertEqual(shell.commands, [
            "/usr/libexec/java_home",
            "'/sdk/cmdline-tools/latest/bin/apkanalyzer' manifest application-id \(shellQuoted(canonical))",
        ])

        do {
            _ = try await platform(ScriptedShell()).resolveBinary(scratch.appendingPathComponent("Demo.app").path)
            XCTFail("expected rejection")
        } catch {
            XCTAssertTrue("\(error)".contains(".apk"), "\(error)")
        }
    }

    /// A08: the stream starts at the device's current time instead of
    /// clearing the whole logcat buffer, and filters by uid and tag.
    func testLogStreamStartsNowWithoutClearingAndFiltersByUID() async throws {
        let shell = ScriptedShell([.success("package:com.example.app uid:10123"), .success("1791592382\n")])
        let command = try await platform(shell).logStream(deviceID: "emulator-5554", appID: "com.example.app", filter: "MyTag", level: nil)
        XCTAssertFalse(shell.commands.contains { $0.contains("logcat -c") }, "\(shell.commands)")
        XCTAssertEqual(shell.commands[1], "'/sdk/platform-tools/adb' -s 'emulator-5554' shell 'date +%s'")
        XCTAssertEqual(command.executable, "/sdk/platform-tools/adb")
        XCTAssertEqual(command.arguments, ["-s", "emulator-5554", "logcat", "--uid=10123", "-v", "time", "-T", "1791592382.000", "-s", "MyTag:I"])
    }

    /// A08: the documented levels map to logcat priorities; no level is `default`.
    func testLogStreamMapsLevelsToLogcatPriorities() async throws {
        let expected: [(LogStreamLevel?, String)] = [(nil, "*:I"), (.default, "*:I"), (.info, "*:I"), (.debug, "*:D")]
        for (level, filter) in expected {
            let shell = ScriptedShell([.success("package:com.example uid:10123"), .success("1791592382")])
            let stream = try await platform(shell).logStream(deviceID: "emulator-5554", appID: "com.example", filter: nil, level: level)
            XCTAssertEqual(stream.arguments.suffix(2), ["-s", filter], "\(String(describing: level))")
            XCTAssertFalse(shell.commands.contains { $0.contains("logcat -c") })
        }
    }

    func testLogStreamFallsBackToHostTimeWhenTheDeviceClockCannotBeRead() async throws {
        let shell = ScriptedShell([.success("package:com.example uid:10123"), .failure(GrantivaError.commandFailed("offline", 1))])
        let stream = try await platform(shell).logStream(deviceID: "emulator-5554", appID: "com.example", filter: "T", level: .debug)
        XCTAssertEqual(Array(stream.arguments.prefix(7)), ["-s", "emulator-5554", "logcat", "--uid=10123", "-v", "time", "-T"])
        XCTAssertNotNil(stream.arguments[7].wholeMatch(of: /[0-1][0-9]-[0-3][0-9] [0-2][0-9]:[0-5][0-9]:[0-5][0-9]\.000/), stream.arguments[7])
        XCTAssertEqual(Array(stream.arguments.suffix(2)), ["-s", "T:D"])
    }

    func testLogcatTimeUsesLogcatsMonthDayForm() {
        let date = Date(timeIntervalSince1970: 1_791_592_382.75) // 2026-10-10 00:33:02.75 UTC
        XCTAssertEqual(AndroidPlatform.logcatTime(date, timeZone: TimeZone(identifier: "UTC")!), "10-10 00:33:02.000")
    }

    func testLogStreamWithoutAnInstalledAppFails() async {
        let shell = ScriptedShell([.success("")])
        do {
            _ = try await platform(shell).logStream(deviceID: "emulator-5554", appID: "com.example.app", filter: nil, level: nil)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("com.example.app"), "\(error)")
        }
    }

    func testRoutineOrphanCleanupPreservesUnownedSameDeviceForwards() async {
        let shell = ScriptedShell([
            .success(""), .success(""),
            .success("emulator-5554 tcp:61211 tcp:16791\nemulator-5556 tcp:61212 tcp:6790"),
        ])
        await platform(shell).cleanupOrphans(deviceID: "emulator-5554")
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell am force-stop 'io.appium.uiautomator2.server'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell am force-stop 'io.appium.uiautomator2.server.test'",
        ])
    }

    func testOrphanCleanupRemovesOnlyTheRecordedOwnedForward() async {
        let shell = ScriptedShell([.success("")])
        await platform(shell).removeOwnedForward(deviceID: "emulator-5554", localPort: 61211)
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5554' forward --remove tcp:61211",
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

    /// `build build` passes no device: the APK is chosen for the host's
    /// emulator ABI and no adb command runs.
    func testBuildWithoutADeviceReadsNoDeviceAndPicksTheHostABI() async throws {
        let metadataDir = scratch.appendingPathComponent("app/build/outputs/apk/debug")
        try FileManager.default.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        try """
        {"applicationId":"com.example","variantName":"debug","elements":[
          {"type":"ONE_OF_MANY","filters":[{"filterType":"ABI","value":"arm64-v8a"}],"outputFile":"app-arm64-v8a-debug.apk"},
          {"type":"ONE_OF_MANY","filters":[{"filterType":"ABI","value":"x86_64"}],"outputFile":"app-x86_64-debug.apk"}]}
        """.write(to: metadataDir.appendingPathComponent("output-metadata.json"), atomically: true, encoding: .utf8)
        let shell = ScriptedShell([.failure(GrantivaError.commandFailed("no java", 1)), .success("BUILD SUCCESSFUL")])
        let request = PlatformBuildRequest(
            config: GrantivaConfig(platform: .android, android: AndroidProject()),
            resolved: ResolvedProject(android: AndroidProject()),
            deviceID: "",
            extraBuildSettings: []
        )
        let previous = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(scratch.path)
        defer { FileManager.default.changeCurrentDirectoryPath(previous) }
        let result = try await platform(shell).build(request)
        XCTAssertTrue(result.success)
        XCTAssertFalse(shell.commands.contains { $0.contains("adb") }, "\(shell.commands)")
        XCTAssertEqual(result.productPath.map { URL(fileURLWithPath: $0).lastPathComponent }, "app-\(AndroidPlatform.hostEmulatorABI)-debug.apk")
    }

    /// `build build --device <serial>` never boots: an unattached serial
    /// fails naming it and the attached devices.
    func testAttachedDeviceNeverBootsAndNamesTheAttachedDevices() async throws {
        let shell = ScriptedShell([.success("List of devices attached\nemulator-5556 device\nR5CT offline")])
        do {
            _ = try await platform(shell).attachedDevice(serial: "emulator-5554")
            XCTFail("expected an error")
        } catch {
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("emulator-5554"), message)
            XCTAssertTrue(message.contains("emulator-5556 (device), R5CT (offline)"), message)
        }
        XCTAssertEqual(shell.commands, ["'/sdk/platform-tools/adb' devices -l"], "no listing of AVDs, no boot")

        let attached = ScriptedShell([.success("List of devices attached\nemulator-5554 device"), .success("Pixel_8_API_35\nOK")])
        let device = try await platform(attached).attachedDevice(serial: "emulator-5554")
        XCTAssertEqual(device, BootedDevice(udid: "emulator-5554", name: "Pixel_8_API_35"))
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

    func testLogStreamWithALevelAndNoTagFiltersEveryTagAtThatPriority() async throws {
        let shell = ScriptedShell([.success("package:com.example uid:10123"), .success("1791592382")])
        let stream = try await platform(shell).logStream(deviceID: "emulator-5554", appID: "com.example", filter: nil, level: .debug)
        XCTAssertEqual(stream.arguments, ["-s", "emulator-5554", "logcat", "--uid=10123", "-v", "time", "-T", "1791592382.000", "-s", "*:D"])
    }

    func testResolveBinaryRunsApkanalyzerWithJavaHomeWhenKnown() async throws {
        let apk = scratch.appendingPathComponent("app.apk").path
        FileManager.default.createFile(atPath: apk, contents: Data())
        let shell = ScriptedShell([.success("/jdk\n"), .success("com.example.app\n")])
        let sdk = AndroidSDK(root: "/sdk")
        let adb = ADB(path: sdk.adb, execute: shell.execute)
        let p = AndroidPlatform(
            sdk: sdk, adb: adb, gradle: GradleBuildRunner(execute: shell.execute),
            emulators: EmulatorManager(sdk: sdk, adb: adb, execute: shell.execute, spawn: { _, _ in 1 },
                                       provenance: AndroidProvenance(directory: scratch.path), bootTimeout: 1, pollInterval: 0.01),
            captureSettings: AndroidCaptureSettings(adb: adb, stateDirectory: scratch.path),
            execute: shell.execute, environment: ["PATH": "/usr/bin"]
        )
        let resolved = try await p.resolveBinary(apk)
        XCTAssertEqual(resolved.appID, "com.example.app")
        XCTAssertEqual(shell.commands, [
            "/usr/libexec/java_home",
            "JAVA_HOME='/jdk' '/sdk/cmdline-tools/latest/bin/apkanalyzer' manifest application-id \(shellQuoted(AppBinaryResolver.canonicalPath(apk)))",
        ])
    }

    func testAttachDriverWithoutAPortForwardsAndDetachRemovesIt() async throws {
        let shell = ScriptedShell([
            .success("61211"),                       // forward
            .success("Physical size: 1080x2400"),    // wm size
            .success("Physical density: 420"),       // wm density
            .success(""),                            // forward --remove
        ])
        let transport = UIAutomator2Transport { _ in (Data(#"{"value":[{"id":"s1"}]}"#.utf8), 200) }
        let p = platform(shell)
        let attachment = try await p.attachDriver(deviceID: "emulator-5554", port: nil, transport: transport)
        XCTAssertEqual(attachment.port, 61211)
        await attachment.detach()
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5554' forward tcp:0 tcp:6790",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell 'wm size'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell 'wm density'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' forward --remove tcp:61211",
        ])
    }

    func testAttachDriverWithAKnownPortDoesNotForwardAndDetachIsANoOp() async throws {
        let shell = ScriptedShell([.success("Physical size: 1080x2400"), .success("Physical density: 420")])
        let transport = UIAutomator2Transport { _ in (Data(#"{"value":[{"id":"s1"}]}"#.utf8), 200) }
        let attachment = try await platform(shell).attachDriver(deviceID: "emulator-5554", port: 7000, transport: transport)
        XCTAssertEqual(attachment.port, 7000)
        await attachment.detach()
        XCTAssertEqual(shell.commands.count, 2)
    }

    /// An adb restart drops the forward `runner start` recorded; attach makes
    /// a fresh one rather than fail.
    func testAttachDriverFallsBackToAFreshForwardWhenTheRecordedPortIsDead() async throws {
        let shell = ScriptedShell([
            .success("61211"),                       // forward
            .success("Physical size: 1080x2400"),    // wm size
            .success("Physical density: 420"),       // wm density
        ])
        let transport = UIAutomator2Transport { request in
            guard request.url?.port == 61211 else { throw URLError(.cannotConnectToHost) }
            return (Data(#"{"value":[{"id":"s1"}]}"#.utf8), 200)
        }
        let attachment = try await platform(shell).attachDriver(deviceID: "emulator-5554", port: 7000, transport: transport)
        XCTAssertEqual(attachment.port, 61211)
        XCTAssertEqual(shell.commands.first, "'/sdk/platform-tools/adb' -s 'emulator-5554' forward tcp:0 tcp:6790")
    }

    func testRecordVideoRecordsPullsAndRemoves() async throws {
        let shell = ScriptedShell()
        let out = scratch.appendingPathComponent("rec.mp4").path
        try await platform(shell).recordVideo(deviceID: "emulator-5554", to: out, seconds: 4.2)
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell screenrecord --time-limit 5 '/sdcard/grantiva-record.mp4'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' pull '/sdcard/grantiva-record.mp4' \(shellQuoted(out))",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell rm -f '/sdcard/grantiva-record.mp4'",
        ])
    }

    /// Review Focus 3.
    func testRecordVideoOver180SecondsIsRefusedBeforeTouchingTheDevice() async {
        let shell = ScriptedShell()
        do {
            try await platform(shell).recordVideo(deviceID: "emulator-5554", to: "/tmp/x.mp4", seconds: 200)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("Android recordings are capped at 180 seconds"), "\(error)")
        }
        XCTAssertTrue(shell.commands.isEmpty)
    }

    func testRecordVideoRefusesAnInfiniteDuration() async {
        let shell = ScriptedShell()
        do {
            try await platform(shell).recordVideo(deviceID: "emulator-5554", to: "/tmp/x.mp4", seconds: .infinity)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("capped at 180 seconds"), "\(error)")
        }
        XCTAssertTrue(shell.commands.isEmpty)
    }

    func testIsInstalledReadsThePackageListAndIsUnknownWhenAdbFails() async {
        let installed = await platform(ScriptedShell([.success("package:com.example.app")])).isInstalled(appID: "com.example.app", deviceID: "emulator-5554")
        XCTAssertEqual(installed, true)
        let missing = await platform(ScriptedShell([.success("package:com.example.app.paid")])).isInstalled(appID: "com.example.app", deviceID: "emulator-5554")
        XCTAssertEqual(missing, false)
        let unknown = await platform(ScriptedShell([.failure(GrantivaError.commandFailed("adb: device 'emulator-5554' not found", 1))]))
            .isInstalled(appID: "com.example.app", deviceID: "emulator-5554")
        XCTAssertNil(unknown, "an adb failure says nothing about the app")
    }
}
