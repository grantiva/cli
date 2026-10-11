import Foundation
import XCTest
@testable import GrantivaCore

final class AndroidCaptureSettingsTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("android-capture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private func settings(_ shell: ScriptedShell) -> AndroidCaptureSettings {
        AndroidCaptureSettings(adb: ADB(path: "/sdk/platform-tools/adb", execute: shell.execute), stateDirectory: scratch.path)
    }

    private func shellBody(_ command: String) -> String {
        // "'/sdk/platform-tools/adb' -s 'emulator-5554' shell '<body>'" -> body
        let marker = " shell '"
        guard let range = command.range(of: marker) else { return command }
        return String(command[range.upperBound...].dropLast()).replacingOccurrences(of: "'\\''", with: "'")
    }

    func testPrepareSavesCurrentValuesThenSetsDemoModeScalesAndRotation() async throws {
        let reads: [Result<String, Error>] = [
            .success("0"), .success("1.0"), .success("1.0"), .success("1.0"), .success("1"), .success("null"),
        ]
        let shell = ScriptedShell(reads)
        try await settings(shell).prepare(serial: "emulator-5554")
        let bodies = shell.commands.map(shellBody)
        XCTAssertEqual(Array(bodies.prefix(6)), [
            "settings get global sysui_demo_allowed",
            "settings get global window_animation_scale",
            "settings get global transition_animation_scale",
            "settings get global animator_duration_scale",
            "settings get system accelerometer_rotation",
            "settings get system user_rotation",
        ])
        XCTAssertEqual(Array(bodies.dropFirst(6)), [
            "settings put global sysui_demo_allowed 1",
            "am broadcast -a com.android.systemui.demo -e command enter",
            "am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941",
            "am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false",
            "am broadcast -a com.android.systemui.demo -e command notifications -e visible false",
            "am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4",
            "am broadcast -a com.android.systemui.demo -e command network -e mobile show -e datatype none -e level 4",
            "settings put global window_animation_scale 0",
            "settings put global transition_animation_scale 0",
            "settings put global animator_duration_scale 0",
            "settings put system accelerometer_rotation 0",
            "settings put system user_rotation 0",
        ])
        let state = AndroidCaptureSettings.statePath(serial: "emulator-5554", directory: scratch.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: state))
        let saved = try JSONDecoder().decode([String: String?].self, from: Data(contentsOf: URL(fileURLWithPath: state)))
        XCTAssertEqual(saved["global/window_animation_scale"], "1.0")
        XCTAssertEqual(saved["system/user_rotation"] ?? nil, nil, "null reads back as absent")
    }

    func testRestoreWritesSavedValuesExitsDemoModeAndDeletesTheFile() async throws {
        let state = AndroidCaptureSettings.statePath(serial: "emulator-5554", directory: scratch.path)
        let saved: [String: String?] = [
            "global/sysui_demo_allowed": "0", "global/window_animation_scale": "1.0",
            "global/transition_animation_scale": "1.0", "global/animator_duration_scale": "1.0",
            "system/accelerometer_rotation": "1", "system/user_rotation": nil,
        ]
        try JSONEncoder().encode(saved).write(to: URL(fileURLWithPath: state))
        let shell = ScriptedShell()
        await settings(shell).restore(serial: "emulator-5554")
        let bodies = shell.commands.map(shellBody)
        XCTAssertEqual(bodies.first { !$0.hasSuffix("devices -l") }, "am broadcast -a com.android.systemui.demo -e command exit")
        XCTAssertTrue(bodies.contains("settings put global window_animation_scale 1.0"))
        XCTAssertTrue(bodies.contains("settings put system accelerometer_rotation 1"))
        XCTAssertTrue(bodies.contains("settings delete system user_rotation"), "a null value is deleted, not written as the string null")
        XCTAssertTrue(bodies.contains("settings put global sysui_demo_allowed 0"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: state))
    }

    func testRestoreIfCrashedRestoresWhenAFileIsLeftAndIsANoOpOtherwise() async throws {
        let shell = ScriptedShell()
        let settings = settings(shell)
        let untouched = await settings.restoreIfCrashed(serial: "emulator-5554")
        XCTAssertFalse(untouched)
        XCTAssertTrue(shell.commands.isEmpty)

        let state = AndroidCaptureSettings.statePath(serial: "emulator-5554", directory: scratch.path)
        try JSONEncoder().encode(["global/window_animation_scale": "1.0"] as [String: String?]).write(to: URL(fileURLWithPath: state))
        let restored = await settings.restoreIfCrashed(serial: "emulator-5554")
        XCTAssertTrue(restored)
        XCTAssertTrue(shell.commands.map(shellBody).contains("settings put global window_animation_scale 1.0"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: state))
    }

    func testStatePathSanitizesTheSerial() {
        XCTAssertEqual(
            AndroidCaptureSettings.statePath(serial: "192.168.1.10:5555", directory: ".grantiva"),
            ".grantiva/android-settings-192.168.1.10_5555.json"
        )
    }

    // MARK: - K06: a device that briefly leaves adb after a fresh boot

    private func quickSettings(_ shell: ScriptedShell, timeout: TimeInterval = 2, grace: TimeInterval = 2) -> AndroidCaptureSettings {
        AndroidCaptureSettings(
            adb: ADB(path: "/sdk/platform-tools/adb", execute: shell.execute), stateDirectory: scratch.path,
            reconnectTimeout: timeout, absentGrace: grace, pollInterval: .milliseconds(1)
        )
    }

    private func writeState(_ saved: [String: String?]) throws -> String {
        let state = AndroidCaptureSettings.statePath(serial: "emulator-5554", directory: scratch.path)
        try JSONEncoder().encode(saved).write(to: URL(fileURLWithPath: state))
        return state
    }

    private static let gone = GrantivaError.commandFailed("adb: device 'emulator-5554' not found", 1)
    private static let offline = GrantivaError.commandFailed("adb: device offline", 1)
    private static let listed = "List of devices attached\nemulator-5554\tdevice product:sdk model:x\n"
    private static let empty = "List of devices attached\n"

    func testRestoreWaitsForADeviceThatLeftAdbAndRetriesTheCommandOnce() async throws {
        let state = try writeState(["global/window_animation_scale": "1.0", "system/accelerometer_rotation": "1"])
        let shell = ScriptedShell([
            .success(Self.listed),                                        // pre-check: attached
            .failure(Self.gone),                                          // exit demo mode: device gone
            .success(Self.empty),                                         // not back yet
            .success("List of devices attached\nemulator-5554\toffline\n"), // back, not ready
            .success(Self.listed),
        ])
        let warnings = await quickSettings(shell).restore(serial: "emulator-5554")
        let bodies = shell.commands.map(shellBody)
        XCTAssertEqual(bodies.filter { $0 == "am broadcast -a com.android.systemui.demo -e command exit" }.count, 2,
                       "the failed command is retried once the device is back")
        XCTAssertEqual(shell.commands.filter { $0.hasSuffix("devices -l") }.count, 4)
        XCTAssertTrue(bodies.contains("settings put global window_animation_scale 1.0"))
        XCTAssertTrue(bodies.contains("settings put system accelerometer_rotation 1"))
        XCTAssertEqual(warnings, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: state))
    }

    func testAnOfflineDeviceMidRestoreIsWaitedOnAndTheSettingRetried() async throws {
        _ = try writeState(["global/window_animation_scale": "1.0", "global/transition_animation_scale": "1.0"])
        let shell = ScriptedShell([
            .success(Self.listed),   // pre-check
            .success(""),            // exit demo mode
            .failure(Self.offline),  // window_animation_scale: offline
            .success(Self.listed),   // devices -l
        ])
        let warnings = await quickSettings(shell).restore(serial: "emulator-5554")
        let bodies = shell.commands.map(shellBody)
        XCTAssertEqual(bodies.filter { $0 == "settings put global window_animation_scale 1.0" }.count, 2)
        XCTAssertTrue(bodies.contains("settings put global transition_animation_scale 1.0"))
        XCTAssertEqual(warnings, [])
    }

    func testADeviceThatDoesNotComeBackGetsOneWarningAndNoFurtherCommands() async throws {
        let state = try writeState([
            "global/window_animation_scale": "1.0", "global/transition_animation_scale": "1.0",
            "system/accelerometer_rotation": "1",
        ])
        let shell = ScriptedShell([.success("List of devices attached\nemulator-5554\toffline\n"), .failure(Self.gone)])
        shell.fallback = Self.empty
        let warnings = await quickSettings(shell, timeout: 0.05).restore(serial: "emulator-5554")
        XCTAssertEqual(warnings.count, 1, "\(warnings)")
        XCTAssertTrue(warnings.first?.contains("emulator-5554") == true, "\(warnings)")
        XCTAssertTrue(warnings.first?.contains("left adb") == true, "\(warnings)")
        XCTAssertFalse(shell.commands.map(shellBody).contains { $0.hasPrefix("settings ") },
                       "nothing more is sent to a device that is gone")
        XCTAssertFalse(FileManager.default.fileExists(atPath: state))
    }

    func testADeviceAdbDoesNotListAtTheStartGetsOnlyTheShortGrace() async throws {
        _ = try writeState(["global/window_animation_scale": "1.0"])
        let shell = ScriptedShell([.success(Self.empty), .failure(Self.gone)])
        shell.fallback = Self.empty
        let start = Date()
        let warnings = await quickSettings(shell, timeout: 30, grace: 0.05).restore(serial: "emulator-5554")
        XCTAssertLessThan(Date().timeIntervalSince(start), 5, "a dead emulator must not hold the restore for the full wait")
        XCTAssertEqual(warnings.count, 1, "\(warnings)")
        XCTAssertTrue(warnings[0].contains("0.05 s"), warnings[0])
    }

    func testNoStateFileSendsNothing() async {
        let shell = ScriptedShell()
        let warnings = await quickSettings(shell).restore(serial: "emulator-5554")
        XCTAssertEqual(warnings, [])
        XCTAssertTrue(shell.commands.isEmpty, "\(shell.commands)")
    }

    func testARetryThatFindsTheDeviceGoneAgainWarnsOnceAndStops() async throws {
        _ = try writeState(["global/window_animation_scale": "1.0", "global/transition_animation_scale": "1.0"])
        let shell = ScriptedShell([
            .success(Self.listed),   // pre-check
            .success(""),            // exit demo mode
            .failure(Self.offline),  // window_animation_scale
            .success(Self.listed),   // back
            .failure(Self.gone),     // retry: gone again
        ])
        let warnings = await quickSettings(shell).restore(serial: "emulator-5554")
        XCTAssertEqual(warnings.count, 1, "\(warnings)")
        XCTAssertTrue(warnings[0].contains("left adb again"), warnings[0])
        XCTAssertFalse(shell.commands.map(shellBody).contains("settings put global transition_animation_scale 1.0"))
    }

    func testAnOrdinaryFailureIsNotWaitedOn() async throws {
        _ = try writeState(["global/window_animation_scale": "1.0"])
        let shell = ScriptedShell([
            .success(Self.listed), .success(""),
            .failure(GrantivaError.commandFailed("Security exception: permission denied", 1)),
        ])
        let warnings = await quickSettings(shell).restore(serial: "emulator-5554")
        XCTAssertEqual(shell.commands.filter { $0.hasSuffix("devices -l") }.count, 1, "only the pre-check")
        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(warnings[0].contains("global/window_animation_scale"), warnings[0])
    }

    func testDeviceGoneRecognisesOnlyAdbsWordings() {
        XCTAssertTrue(AndroidCaptureSettings.deviceLeftAdb(Self.gone))
        XCTAssertTrue(AndroidCaptureSettings.deviceLeftAdb(Self.offline))
        XCTAssertTrue(AndroidCaptureSettings.deviceLeftAdb(GrantivaError.commandFailed("adb: no devices/emulators found", 1)))
        XCTAssertTrue(AndroidCaptureSettings.deviceLeftAdb(GrantivaError.commandFailed("adb: error: closed", 1)))
        XCTAssertTrue(AndroidCaptureSettings.deviceLeftAdb(GrantivaError.commandFailed("adb: device still connecting", 1)))
        XCTAssertFalse(AndroidCaptureSettings.deviceLeftAdb(GrantivaError.commandFailed("Security exception", 1)))
        XCTAssertFalse(AndroidCaptureSettings.deviceLeftAdb(GrantivaError.commandFailed("/system/bin/sh: settings: not found", 127)),
                       "a command the device could not find is not the device leaving adb")
    }
}
