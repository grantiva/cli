import XCTest
@testable import GrantivaCore

final class TableFormatterTests: XCTestCase {
    func testEmptyDeviceListHasExplicitMessage() {
        XCTAssertEqual(TableFormatter().formatDevices([]), "No simulators found.")
    }

    func testDeviceDividerSpansTheLongestRenderedLine() {
        let output = TableFormatter().formatDevices([
            device(name: "Phone", runtime: "iOS 27.0 (24A123)"),
        ])
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[1].count, max(lines[0].count, lines[2].count))
        XCTAssertEqual(lines[1], String(repeating: "─", count: lines[1].count))
    }

    /// A13: Android captures name the emulator, not a simulator.
    func testCaptureNamesTheDeviceInEachPlatformsTerms() {
        let target = CaptureSimulatorTarget(
            name: "qa-reg-android", udid: "emulator-5554",
            geometry: SimulatorDisplayGeometry(points: [411, 914], pixels: [1080, 2400], scale: 2.625)
        )
        let result = CaptureResult(screens: [], directory: ".grantiva/captures/android", duration: 1, simulator: target)
        let android = TableFormatter().formatCapture(result, platform: .android)
        XCTAssertTrue(android.contains("  Emulator: qa-reg-android (emulator-5554)"), android)
        XCTAssertFalse(android.contains("Simulator:"), android)
        let ios = TableFormatter().formatCapture(result)
        XCTAssertTrue(ios.contains("  Simulator: qa-reg-android (emulator-5554)"), ios)
    }

    /// K89: a comparison where no screen had a baseline says so instead of passing.
    func testCompareHeadlineWithoutBaselines() {
        func screen(_ name: String, _ status: DiffStatus) -> ScreenDiff {
            ScreenDiff(screenName: name, status: status, pixelThreshold: 0.02, perceptualThreshold: 5, capturePath: "c", message: "m")
        }
        let none = TableFormatter().formatCompare(CompareResult(
            screens: [screen("A", .newScreen), screen("B", .newScreen)], passed: false, duration: 0
        ))
        XCTAssertTrue(none.hasPrefix("? No baselines: 2 new screens. Run: grantiva diff approve"), none)
        let mixed = TableFormatter().formatCompare(CompareResult(
            screens: [screen("A", .passed), screen("B", .newScreen)], passed: false, duration: 0
        ))
        XCTAssertTrue(mixed.hasPrefix("? Visual diff incomplete: 1 new screen has no baseline. Run: grantiva diff approve"), mixed)
        let failed = TableFormatter().formatCompare(CompareResult(
            screens: [screen("A", .failed), screen("B", .newScreen)], passed: false, duration: 0
        ))
        XCTAssertTrue(failed.hasPrefix("✗ Visual diff failed"), failed)
        let passed = TableFormatter().formatCompare(CompareResult(screens: [screen("A", .passed)], passed: true, duration: 0))
        XCTAssertTrue(passed.hasPrefix("✓ Visual diff passed"), passed)
    }

    func testAndroidBuildPrintsTheAPKPathInPlaceOfTheScheme() {
        let output = TableFormatter().formatBuild(BuildResult(
            success: true, duration: 1, warnings: [], errors: [],
            productPath: "/b/app-debug.apk", applicationId: "com.x"
        ))
        let lines = output.split(separator: "\n").map(String.init)

        XCTAssertTrue(lines.contains("  APK: /b/app-debug.apk"), output)
        XCTAssertFalse(output.contains("Scheme:"), output)
    }

    /// A10: a failed Android build has no scheme and no APK; print neither.
    func testFailedAndroidBuildPrintsNoSchemeLine() {
        let output = TableFormatter().formatBuild(BuildResult(
            success: false, duration: 1, warnings: [], errors: ["Task 'assembleNoSuchVariant' not found"],
            productPath: nil
        ))
        XCTAssertTrue(output.hasPrefix("✗ Build failed"), output)
        XCTAssertFalse(output.contains("Scheme:"), output)
        XCTAssertFalse(output.contains("APK:"), output)
    }

    func testIOSBuildStillPrintsTheScheme() {
        let output = TableFormatter().formatBuild(BuildResult(
            success: true, scheme: "Demo", duration: 1, warnings: [], errors: [],
            productPath: "/b/Demo.app"
        ))

        XCTAssertTrue(output.split(separator: "\n").map(String.init).contains("  Scheme: Demo"), output)
        XCTAssertFalse(output.contains("APK:"), output)
    }

    func testDeviceValuesCannotInjectAdditionalRowsOrTerminalControls() {
        let output = TableFormatter().formatDevices([
            device(name: "Phone\nforged\u{001B}[31m", runtime: "iOS\t27"),
        ])
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[2].contains("Phone forged�[31m"), output)
        XCTAssertTrue(lines[2].contains("iOS 27"), output)
        XCTAssertFalse(output.contains("\u{001B}"), output)
    }

    private func device(name: String, runtime: String) -> SimulatorDevice {
        SimulatorDevice(
            name: name,
            udid: "00000000-0000-0000-0000-000000000000",
            state: "Booted",
            runtime: runtime,
            isAvailable: true
        )
    }
}
