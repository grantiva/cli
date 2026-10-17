import Foundation
import XCTest
@testable import GrantivaCore

final class ADBTests: XCTestCase {
    private let adbPath = "/sdk/platform-tools/adb"

    func testDevicesParsesSerialsAndStatesAndSkipsTheHeader() {
        let output = """
        List of devices attached
        emulator-5554          device product:sdk_gphone64_arm64 model:sdk_gphone64_arm64 device:emu64a transport_id:1
        R58M1234ABC            unauthorized usb:1-1 transport_id:2
        emulator-5556          offline
        """
        XCTAssertEqual(ADB.parseDevices(output), [
            ADBDevice(serial: "emulator-5554", state: "device"),
            ADBDevice(serial: "R58M1234ABC", state: "unauthorized"),
            ADBDevice(serial: "emulator-5556", state: "offline"),
        ])
        XCTAssertTrue(ADBDevice(serial: "emulator-5554", state: "device").isEmulator)
        XCTAssertFalse(ADBDevice(serial: "R58M1234ABC", state: "device").isEmulator)
        XCTAssertFalse(ADBDevice(serial: "emulator-5556", state: "offline").isUsable)
    }

    // MARK: - N-12: touch mode before captures

    /// Key input leaves the display out of touch mode, and the focused row
    /// stays highlighted in every capture after it. A touch DOWN then CANCEL
    /// at the bottom-left corner pixel (the navigation bar, never a click
    /// target, and cancelled so nothing is pressed) restores touch mode.
    func testRestoreTouchModeCancelsATouchAtTheBottomLeftCornerOnlyWhenOutOfTouchMode() async throws {
        let shell = ScriptedShell([.success("    init=1080x2400 420dpi cur=1080x2400 app=1080x2400\n    mInTouchMode=false\n")])
        let restored = try await ADB(path: adbPath, execute: shell.execute).restoreTouchMode(serial: "emulator-5560")
        XCTAssertTrue(restored)
        XCTAssertEqual(shell.commands.count, 2)
        XCTAssertTrue(shell.commands[0].contains("dumpsys window"), shell.commands[0])
        XCTAssertEqual(
            shell.commands[1],
            "'/sdk/platform-tools/adb' -s 'emulator-5560' shell 'input motionevent DOWN 0 2399 && input motionevent CANCEL 0 2399'"
        )

        let inTouchMode = ScriptedShell([.success("cur=1080x2400 app=1080x2400\nmInTouchMode=true\n")])
        let untouched = try await ADB(path: adbPath, execute: inTouchMode.execute).restoreTouchMode(serial: "emulator-5560")
        XCTAssertFalse(untouched)
        XCTAssertEqual(inTouchMode.commands.count, 1)
    }

    func testTouchModeStateParsesTheCurrentLogicalSize() {
        // Landscape: the logical height is the short side.
        let landscape = ADB.parseTouchModeState("init=1080x2400 420dpi cur=2400x1080 app=2400x1017\n  mInTouchMode=false")
        XCTAssertEqual(landscape?.inTouchMode, false)
        XCTAssertEqual(landscape?.height, 1080)
        XCTAssertNil(ADB.parseTouchModeState("mInTouchMode=false"), "no size, no safe point to touch")
        XCTAssertNil(ADB.parseTouchModeState("cur=1080x2400"), "no touch-mode line, nothing to restore")
    }

    func testEveryCommandLineIsQuotedAndTargetsTheSerial() async throws {
        let shell = ScriptedShell()
        shell.fallback = ""
        let adb = ADB(path: adbPath, execute: shell.execute)
        let serial = "emulator-5554"
        _ = try await adb.devices()
        _ = try? await adb.avdName(serial: serial)
        _ = try await adb.getprop(serial: serial, "ro.product.cpu.abi")
        try await adb.launch(serial: serial, applicationId: "com.example.app")
        try await adb.forceStop(serial: serial, applicationId: "com.example.app")
        try await adb.uninstall(serial: serial, applicationId: "com.example.app")
        try await adb.screenshot(serial: serial, to: "/tmp/shot's.png")
        try await adb.emuKill(serial: serial)
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' devices -l",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' emu avd name",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell getprop 'ro.product.cpu.abi'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell monkey -p 'com.example.app' -c android.intent.category.LAUNCHER --pct-syskeys 0 1 2>&1",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell am force-stop 'com.example.app'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell pm uninstall 'com.example.app'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' exec-out screencap -p > '/tmp/shot'\\''s.png'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' emu kill",
        ])
    }

    func testAvdNameDropsTheOKLine() async throws {
        let shell = ScriptedShell([.success("Pixel_8_API_35\nOK")])
        let name = try await ADB(path: adbPath, execute: shell.execute).avdName(serial: "emulator-5554")
        XCTAssertEqual(name, "Pixel_8_API_35")
    }

    func testInstallRetriesOnceAfterUninstallOnUpdateIncompatible() async throws {
        let shell = ScriptedShell([
            .failure(GrantivaError.commandFailed("adb: failed to install app.apk: Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE: ...]", 1)),
            .success("Success"),
            .success("Success"),
        ])
        let adb = ADB(path: adbPath, execute: shell.execute)
        try await adb.install(serial: "emulator-5554", apk: "/b/app.apk", applicationId: "com.example.app")
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5554' install -r -t -d '/b/app.apk'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell pm uninstall 'com.example.app'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' install -r -t -d '/b/app.apk'",
        ])
    }

    func testInstallDoesNotRetryOtherFailures() async {
        let shell = ScriptedShell([.failure(GrantivaError.commandFailed("INSTALL_FAILED_INSUFFICIENT_STORAGE", 1))])
        let adb = ADB(path: adbPath, execute: shell.execute)
        do {
            try await adb.install(serial: "emulator-5554", apk: "/b/app.apk", applicationId: "com.example.app")
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(shell.commands.count, 1)
        }
    }

    func testDisplaySizePrefersOverrideThenPhysical() {
        XCTAssertEqual(ADB.parseDisplaySize("Physical size: 1080x2400\nOverride size: 720x1600")?.width, 720)
        XCTAssertEqual(ADB.parseDisplaySize("Physical size: 1080x2400")?.height, 2400)
        XCTAssertNil(ADB.parseDisplaySize("garbage"))
        XCTAssertEqual(ADB.parseDensity("Physical density: 420\nOverride density: 280"), 280)
        XCTAssertEqual(ADB.parseDensity("Physical density: 420"), 420)
    }

    func testPackageUIDMatchesTheExactPackageOnly() {
        let output = """
        package:com.android.settings uid:1000
        package:com.android.settings.auto_generated_rro_product__ uid:10028
        """
        XCTAssertEqual(ADB.parsePackageUID(output, applicationId: "com.android.settings"), 1000)
        XCTAssertNil(ADB.parsePackageUID(output, applicationId: "com.android"))
    }

    func testShellCommandIsQuotedAsOneArgument() async throws {
        let shell = ScriptedShell([.success("")])
        _ = try await ADB(path: adbPath, execute: shell.execute).shell(serial: "emulator-5554", "settings put global window_animation_scale 0")
        XCTAssertEqual(shell.commands, ["'/sdk/platform-tools/adb' -s 'emulator-5554' shell 'settings put global window_animation_scale 0'"])
    }

    func testForwardAllocatesALocalPortAndParsesIt() async throws {
        let shell = ScriptedShell([.success("61211\n")])
        let adb = ADB(path: "/sdk/platform-tools/adb", execute: shell.execute)
        let port = try await adb.forward(serial: "emulator-5554", devicePort: 6790)
        XCTAssertEqual(port, 61211)
        XCTAssertEqual(shell.commands, ["'/sdk/platform-tools/adb' -s 'emulator-5554' forward tcp:0 tcp:6790"])
    }

    func testForwardRejectsAnUnparseablePort() async {
        let shell = ScriptedShell([.success("error: device offline")])
        let adb = ADB(path: "/sdk/platform-tools/adb", execute: shell.execute)
        do {
            _ = try await adb.forward(serial: "emulator-5554", devicePort: 6790)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("Could not forward a local port to emulator-5554:6790"), "\(error)")
        }
    }

    func testParseForwardsKeepsOnlyThisSerial() {
        let output = """
        emulator-5554 tcp:61211 tcp:6790
        emulator-5556 tcp:61212 tcp:6790
        emulator-5554 tcp:7000 localabstract:uia2
        """
        XCTAssertEqual(ADB.parseForwards(output, serial: "emulator-5554"), [61211, 7000])
        XCTAssertEqual(ADB.parseForwards("", serial: "emulator-5554"), [])
    }

    func testRemoveForwardsListsThenRemovesEachOfThisSerial() async throws {
        let shell = ScriptedShell([.success("emulator-5554 tcp:61211 tcp:6790\nemulator-5556 tcp:61212 tcp:6790\nemulator-5554 tcp:7000 tcp:7000")])
        let adb = ADB(path: "/sdk/platform-tools/adb", execute: shell.execute)
        try await adb.removeForwards(serial: "emulator-5554")
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5554' forward --list",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' forward --remove tcp:61211",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' forward --remove tcp:7000",
        ])
    }

    func testScreenrecordPullAndRemoveCommandLines() async throws {
        let shell = ScriptedShell()
        let adb = ADB(path: "/sdk/platform-tools/adb", execute: shell.execute)
        try await adb.screenrecord(serial: "emulator-5554", remotePath: "/sdcard/grantiva-record.mp4", seconds: 5)
        try await adb.pull(serial: "emulator-5554", remotePath: "/sdcard/grantiva-record.mp4", to: "/tmp/out dir/rec.mp4")
        try await adb.removeFile(serial: "emulator-5554", remotePath: "/sdcard/grantiva-record.mp4")
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell screenrecord --time-limit 5 '/sdcard/grantiva-record.mp4'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' pull '/sdcard/grantiva-record.mp4' '/tmp/out dir/rec.mp4'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell rm -f '/sdcard/grantiva-record.mp4'",
        ])
    }

    // MARK: - K32 launch failures

    /// What `adb shell monkey` prints for a package that is not installed
    /// (exit 252): the argument trace, then the abort line.
    static let monkeyTrace = """
    args: [-p, com.example.app, -c, android.intent.category.LAUNCHER, --pct-syskeys, 0, 1]
     arg: "-p"
     arg: "com.example.app"
    data="com.example.app"
    data="android.intent.category.LAUNCHER"
    arg="--pct-syskeys" mCurArgData="null" mNextArg=5 argwas="--pct-syskeys" nextarg="0"
    data="0"
      bash arg: -p
    ** No activities found to run, monkey aborted.
    """

    func testLaunchOfAPackageThatIsNotInstalledSaysSoWithoutTheMonkeyTrace() async throws {
        let shell = ScriptedShell([.failure(GrantivaError.commandFailed(Self.monkeyTrace, 252))])
        do {
            try await ADB(path: adbPath, execute: shell.execute).launch(serial: "emulator-5554", applicationId: "com.example.app")
            XCTFail("expected an error")
        } catch {
            let message = error.localizedDescription
            XCTAssertTrue(message.hasPrefix(GrantivaError.notInstalledRoot(appID: "com.example.app", device: "emulator-5554")), message)
            XCTAssertTrue(message.hasPrefix("com.example.app is not installed on emulator-5554"), message)
            XCTAssertFalse(message.contains("arg="), message)
            XCTAssertFalse(message.contains("data="), message)
            XCTAssertFalse(message.contains("\n"), "one line: \(message)")
        }
    }

    /// monkey has exited 0 after aborting on some builds; the abort line still counts.
    func testLaunchThatPrintsTheAbortLineWithExitZeroStillFails() async throws {
        let shell = ScriptedShell([.success(Self.monkeyTrace)])
        do {
            try await ADB(path: adbPath, execute: shell.execute).launch(serial: "emulator-5554", applicationId: "com.example.app")
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("is not installed"), error.localizedDescription)
        }
    }

    func testLaunchFailingForAnotherReasonShowsOnlyTheLastMeaningfulLine() async throws {
        let output = """
        args: [-p, com.example.app]
         arg: "-p"
        data="com.example.app"
        ** Monkey aborted due to error.
        Events injected: 0
        """
        let shell = ScriptedShell([.failure(GrantivaError.commandFailed(output, 251))])
        do {
            try await ADB(path: adbPath, execute: shell.execute).launch(serial: "emulator-5554", applicationId: "com.example.app")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Could not launch com.example.app on emulator-5554: Monkey aborted due to error.")
        }
    }

    func testIsInstalledMatchesTheExactPackageOnly() async throws {
        let listed = ScriptedShell([.success("package:com.example.app.paid\npackage:com.example.app")])
        let adb = ADB(path: adbPath, execute: listed.execute)
        let installed = try await adb.isInstalled(serial: "emulator-5554", applicationId: "com.example.app")
        XCTAssertTrue(installed)
        XCTAssertEqual(listed.commands, ["'/sdk/platform-tools/adb' -s 'emulator-5554' shell 'pm list packages '\\''com.example.app'\\'''"])
        let other = ScriptedShell([.success("package:com.example.app.paid")])
        let otherInstalled = try await ADB(path: adbPath, execute: other.execute).isInstalled(serial: "emulator-5554", applicationId: "com.example.app")
        XCTAssertFalse(otherInstalled)
    }

    // MARK: - L46: the flush runs under an alarm, and without perl too

    func testSyncRunsUnderAnAlarmWhenPerlIsThere() async throws {
        let shell = ScriptedShell()
        let warnings = WarningLog()
        try await ADB(path: adbPath, execute: shell.execute)
            .sync(serial: "emulator-5554", timeoutSeconds: 5, isExecutable: { _ in true }, warn: warnings.append)
        XCTAssertEqual(shell.commands, ["'/usr/bin/perl' -e 'alarm shift; exec @ARGV' 5 '/sdk/platform-tools/adb' -s 'emulator-5554' shell 'sync'"])
        XCTAssertEqual(warnings.lines, [])
    }

    func testAMissingPerlStillFlushesAndWarns() async throws {
        let shell = ScriptedShell()
        let warnings = WarningLog()
        try await ADB(path: adbPath, execute: shell.execute)
            .sync(serial: "emulator-5554", timeoutSeconds: 5, perl: "/nonexistent/perl", warn: warnings.append)
        XCTAssertEqual(shell.commands, ["'/sdk/platform-tools/adb' -s 'emulator-5554' shell 'sync'"], "the flush is never skipped")
        XCTAssertEqual(warnings.lines.count, 1)
        XCTAssertTrue(warnings.lines[0].contains("/nonexistent/perl is not executable"), warnings.lines[0])
    }

    /// Header `env:` through a runner session on Android: the launcher
    /// activity is started with each value as a string extra, as the runner's
    /// `launchApp: arguments:` does (monkey cannot carry extras).
    func testLaunchWithExtrasStartsTheLauncherActivityWithStringExtras() async throws {
        let shell = ScriptedShell([
            .success("priority=0 preferredOrder=0 match=0x108000 specificIndex=-1 isDefault=true\ncom.example.app/.MainActivity\n"),
            .success("Starting: Intent { cmp=com.example.app/.MainActivity (has extras) }"),
        ])
        try await ADB(path: adbPath, execute: shell.execute).launch(
            serial: "emulator-5554", applicationId: "com.example.app", extras: ["NOTE": "it's here", "A": "1"]
        )
        XCTAssertEqual(shell.commands.count, 2, "\(shell.commands)")
        XCTAssertTrue(shell.commands[0].contains("resolve-activity --brief -c android.intent.category.LAUNCHER"), shell.commands[0])
        let start = shell.commands[1]
        XCTAssertTrue(start.contains("am start -W -n "), start)
        XCTAssertTrue(start.contains("com.example.app/.MainActivity"), start)
        XCTAssertTrue(start.contains("--es A "), start)
        XCTAssertTrue(start.contains("--es NOTE "), start)
        XCTAssertLessThan(start.range(of: "--es A ")!.lowerBound, start.range(of: "--es NOTE ")!.lowerBound)
    }

    func testLaunchWithExtrasOfAPackageWithNoLauncherActivitySaysItIsNotInstalled() async throws {
        let shell = ScriptedShell([.success("No activity found\n")])
        do {
            try await ADB(path: adbPath, execute: shell.execute).launch(
                serial: "emulator-5554", applicationId: "com.example.app", extras: ["A": "1"]
            )
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("is not installed"), error.localizedDescription)
        }
    }

    func testLaunchWithAnErrorFromAmStartFails() async throws {
        let shell = ScriptedShell([
            .success("com.example.app/.MainActivity\n"),
            .success("Starting: Intent { }\nError: Activity class {com.example.app/.MainActivity} does not exist."),
        ])
        do {
            try await ADB(path: adbPath, execute: shell.execute).launch(
                serial: "emulator-5554", applicationId: "com.example.app", extras: ["A": "1"]
            )
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("does not exist"), error.localizedDescription)
        }
    }
}

private final class WarningLog: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []
    var lines: [String] { lock.withLock { stored } }
    func append(_ line: String) { lock.withLock { stored.append(line) } }

}
