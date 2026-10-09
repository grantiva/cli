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
        XCTAssertEqual(bodies.first, "am broadcast -a com.android.systemui.demo -e command exit")
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
}
