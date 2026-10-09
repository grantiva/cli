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
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell monkey -p 'com.example.app' -c android.intent.category.LAUNCHER --pct-syskeys 0 1",
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
}
