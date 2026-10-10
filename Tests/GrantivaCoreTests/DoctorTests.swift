import Foundation
import XCTest
@testable import GrantivaCore

final class DoctorTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-doctor-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    // MARK: - a broken toolchain must not read as passing

    // `xcode-select -p` echoes $DEVELOPER_DIR back without checking it, so
    // `DEVELOPER_DIR=/nonexistent grantiva doctor` reported "✓ Xcode
    // /nonexistent" — the broken-CI-image case doctor exists to catch.
    func testXcodeCheckFailsWhenTheDeveloperDirectoryDoesNotExist() async throws {
        let previous = ProcessInfo.processInfo.environment["DEVELOPER_DIR"]
        setenv("DEVELOPER_DIR", scratch.appendingPathComponent("nonexistent").path, 1)
        defer {
            if let previous { setenv("DEVELOPER_DIR", previous, 1) } else { unsetenv("DEVELOPER_DIR") }
        }

        let check = await DoctorRunner().checkXcode()
        XCTAssertEqual(check.status, .error)
        XCTAssertNotNil(check.fix)
    }

    func testRunnerCheckReportsInstalledVersion() async throws {
        let runner = scratch.appendingPathComponent("grantiva-runner")
        let version = scratch.appendingPathComponent("version")
        try Data().write(to: runner)
        try "1.2.3".write(to: version, atomically: true, encoding: .utf8)

        let check = await DoctorRunner().checkRunner(
            runnerPath: runner.path,
            versionFilePath: version.path,
            expectedVersion: "1.2.3"
        )

        XCTAssertEqual(check.status, .ok)
        XCTAssertEqual(check.message, "grantiva-runner 1.2.3")
    }

    func testRunnerCheckWarnsWhenInstalledVersionIsStale() async throws {
        let runner = scratch.appendingPathComponent("grantiva-runner")
        let version = scratch.appendingPathComponent("version")
        try Data().write(to: runner)
        try "1.0.0".write(to: version, atomically: true, encoding: .utf8)

        let check = await DoctorRunner().checkRunner(
            runnerPath: runner.path,
            versionFilePath: version.path,
            expectedVersion: "2.0.0"
        )

        XCTAssertEqual(check.status, .warning)
        XCTAssertTrue(check.message.contains("1.0.0"), check.message)
        XCTAssertTrue(check.message.contains("2.0.0"), check.message)
        XCTAssertNotNil(check.fix)
    }

    func testRunnerCheckWarnsWhenVersionMarkerIsMissing() async throws {
        let runner = scratch.appendingPathComponent("grantiva-runner")
        try Data().write(to: runner)

        let check = await DoctorRunner().checkRunner(
            runnerPath: runner.path,
            versionFilePath: scratch.appendingPathComponent("missing-version").path,
            expectedVersion: "2.0.0"
        )

        XCTAssertEqual(check.status, .warning)
        XCTAssertTrue(check.message.contains("unknown"), check.message)
    }

    func testEmptyEnvironmentAPIKeyIsNotAuthenticated() {
        let check = DoctorRunner().checkGrantivaAuth(
            environment: ["GRANTIVA_API_KEY": "  \n"],
            storedCredentials: nil
        )

        XCTAssertEqual(check.status, .warning)
        XCTAssertTrue(check.message.contains("Not authenticated"), check.message)
    }

    // MARK: - exit status

    // `grantiva doctor || exit 1` as a CI preflight could never fire: doctor had
    // no exit-code path at all.
    func testAFailedRequiredCheckIsAFailure() {
        XCTAssertTrue(DoctorRunner.hasFailures(Self.sampleChecks))
    }

    // Optional checks are advisory and must not change the exit code — a
    // developer machine with no simulator booted and no grantiva.yml is fine.
    func testOptionalChecksAloneAreNotAFailure() {
        XCTAssertFalse(DoctorRunner.hasFailures([
            DoctorCheck(name: "Booted Simulator", status: .warning, message: "No simulator booted", fix: nil),
            DoctorCheck(name: "grantiva.yml", status: .warning, message: "Not found", fix: nil, section: .project),
            DoctorCheck(name: "Grantiva Auth", status: .warning, message: "Not authenticated", fix: nil, section: .cloud),
            DoctorCheck(name: "Xcode", status: .ok, message: "/Applications/Xcode.app", fix: nil),
        ]))
    }

    // MARK: - colour is for terminals

    // `grantiva doctor > log.txt` was writing raw SGR sequences into the file.
    func testFormatterEmitsNoEscapesWhenColourIsOff() {
        let output = DoctorFormatter(color: false).format(Self.sampleChecks)
        XCTAssertFalse(output.contains("\u{001B}"), "redirected output must carry no ANSI escapes")
        // The information the colour carried is still there in plain text.
        XCTAssertTrue(output.contains("✓"))
        XCTAssertTrue(output.contains("✗"))
        XCTAssertTrue(output.contains("Xcode not found"))
    }

    func testFormatterStillColoursWhenColourIsOn() {
        XCTAssertTrue(DoctorFormatter(color: true).format(Self.sampleChecks).contains("\u{001B}"))
    }

    func testNoColorEnvironmentVariableDisablesColour() {
        let previous = ProcessInfo.processInfo.environment["NO_COLOR"]
        setenv("NO_COLOR", "1", 1)
        defer {
            if let previous { setenv("NO_COLOR", previous, 1) } else { unsetenv("NO_COLOR") }
        }
        XCTAssertFalse(DoctorFormatter.terminalSupportsColor())
    }

    // MARK: - failures are visible in the footer

    func testFooterCountsFailuresAlongsidePassedAndOptional() {
        let output = DoctorFormatter(color: false).format(Self.sampleChecks)
        XCTAssertTrue(output.contains("1 passed"), output)
        XCTAssertTrue(output.contains("1 optional"), output)
        XCTAssertTrue(output.contains("1 failed"), output)
    }

    private static let sampleChecks: [DoctorCheck] = [
        DoctorCheck(name: "Runner", status: .ok, message: "grantiva-runner 1.0.0", fix: nil),
        DoctorCheck(
            name: "Xcode", status: .error, message: "Xcode not found",
            fix: "Install Xcode from the App Store"
        ),
        DoctorCheck(name: "Booted Simulator", status: .warning, message: "No simulator booted", fix: nil),
    ]

    func testAndroidSDKCheckIsAnErrorOnlyWhenAndroidIsRequired() async {
        let runner = DoctorRunner()
        let missingRequired = runner.checkAndroidSDK(sdk: nil, required: true)
        XCTAssertEqual(missingRequired.status, .error)
        XCTAssertTrue(missingRequired.fix?.contains("scripts/android-env.sh") == true)
        let missingOptional = runner.checkAndroidSDK(sdk: nil, required: false)
        XCTAssertEqual(missingOptional.status, .warning)
        let present = runner.checkAndroidSDK(sdk: AndroidSDK(root: scratch.path), required: true, environment: [:])
        XCTAssertEqual(present.status, .ok)
        XCTAssertEqual(present.message, scratch.path)
    }

    // Gradle and adb run from the same shell still use a stale ANDROID_HOME,
    // so doctor must not hide that it skipped it.
    func testAndroidSDKCheckWarnsAboutAStaleAndroidHome() throws {
        let sdk = scratch.appendingPathComponent("Library/Android/sdk")
        try FileManager.default.createDirectory(at: sdk.appendingPathComponent("platform-tools"), withIntermediateDirectories: true)
        try Data().write(to: sdk.appendingPathComponent("platform-tools/adb"))
        let environment = ["ANDROID_HOME": "/nonexistent"]
        let located = try XCTUnwrap(AndroidSDK.locate(environment: environment, home: scratch.path))

        let check = DoctorRunner().checkAndroidSDK(sdk: located, required: true, environment: environment)
        XCTAssertEqual(check.status, .warning)
        XCTAssertEqual(check.message, "\(sdk.path) (ANDROID_HOME=/nonexistent has no platform-tools/adb; unset or fix it)")

        let sdkRoot = DoctorRunner().checkAndroidSDK(sdk: located, required: true, environment: ["ANDROID_SDK_ROOT": "/stale"])
        XCTAssertEqual(sdkRoot.status, .warning)
        XCTAssertTrue(sdkRoot.message.contains("ANDROID_SDK_ROOT=/stale has no platform-tools/adb"), sdkRoot.message)
        XCTAssertEqual(sdkRoot.fix, "unset ANDROID_SDK_ROOT or export ANDROID_SDK_ROOT=\(sdk.path)")
        XCTAssertEqual(check.fix, "unset ANDROID_HOME or export ANDROID_HOME=\(sdk.path)")

        let fine = DoctorRunner().checkAndroidSDK(sdk: located, required: true, environment: ["ANDROID_HOME": sdk.path])
        XCTAssertEqual(fine.status, .ok)
        XCTAssertEqual(fine.message, sdk.path)
    }

    func testAVDCheckWarnsWhenNoneExist() async {
        let runner = DoctorRunner()
        let none = await runner.checkAVDs(list: { [] })
        XCTAssertEqual(none.status, .warning)
        XCTAssertTrue(none.fix?.contains("android-env.sh") == true)
        let some = await runner.checkAVDs(list: { ["Pixel_8_API_35"] })
        XCTAssertEqual(some.status, .ok)
        XCTAssertEqual(some.message, "Pixel_8_API_35")
    }

    func testConfigCheckNamesThePlatformsFile() {
        let runner = DoctorRunner()
        let android = runner.checkConfig(for: .android, directory: scratch.path)
        XCTAssertEqual(android.name, "grantiva-android.yml")
        XCTAssertEqual(android.status, .warning)
        XCTAssertEqual(android.fix, "Run: grantiva init --platform android")
    }

    // A config that `run` refuses must not read as "Found" in doctor.
    func testConfigCheckFlagsAFileThatDoesNotParse() throws {
        try "application_id: com.kylebrowning.landmarks\nscreens:\n  - name: Home\n    path: launch\n  bad: : :\n"
            .write(to: scratch.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        let check = DoctorRunner().checkConfig(for: .android, directory: scratch.path)
        XCTAssertEqual(check.status, .error)
        XCTAssertEqual(check.section, .project)
        XCTAssertTrue(check.message.hasPrefix("could not be parsed: 5:3"), check.message)
        XCTAssertFalse(check.message.contains("\n"), check.message)
        XCTAssertTrue(check.fix?.contains(scratch.appendingPathComponent("grantiva-android.yml").path) == true, "\(check.fix ?? "nil")")
    }

    func testConfigCheckDeclaredPlatformMismatchIsNotCalledAYAMLError() throws {
        try "platform: ios\n".write(to: scratch.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        let check = DoctorRunner().checkConfig(for: .android, directory: scratch.path)
        XCTAssertEqual(check.status, .error)
        XCTAssertTrue(check.message.contains("declares `platform: ios`"), check.message)
        XCTAssertEqual(check.fix, "Fix \(scratch.appendingPathComponent("grantiva-android.yml").path)")
    }

    func testConfigCheckPassesAFileThatParses() throws {
        try "module: app\n".write(to: scratch.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        let check = DoctorRunner().checkConfig(for: .android, directory: scratch.path)
        XCTAssertEqual(check.status, .ok)
        XCTAssertEqual(check.message, "Found")
    }

    func testNoBootedSimulatorFixNamesAnInstalledDeviceType() {
        XCTAssertEqual(DoctorRunner.noBootedSimulatorCheck(newestIPhone: "iPhone 18 Pro").fix, "Run: grantiva simulator ensure --name \"iPhone 18 Pro\"")
        XCTAssertEqual(DoctorRunner.noBootedSimulatorCheck(newestIPhone: nil).fix, "Run: grantiva simulator ensure --name \"iPhone 17 Pro\"")
    }

    // A mono-repo's android/ subproject is inside the work tree; advising
    // `git init` there would create a nested repository.
    func testGitCheckPassesInASubdirectoryOfAWorkTree() throws {
        let root = scratch.appendingPathComponent("root")
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("android/app"), withIntermediateDirectories: true)
        let check = DoctorRunner().checkGitRepository(directory: root.appendingPathComponent("android/app").path)
        XCTAssertEqual(check.status, .ok)
        XCTAssertEqual(check.message, "Detected")
    }

    func testGitCheckAcceptsAGitFileForWorktreesAndSubmodules() throws {
        try "gitdir: /elsewhere\n".write(to: scratch.appendingPathComponent(".git"), atomically: true, encoding: .utf8)
        XCTAssertEqual(DoctorRunner().checkGitRepository(directory: scratch.path).status, .ok)
    }

    func testGitCheckWarnsWithNoAncestorGitEntry() {
        // The temp directory lives outside any work tree.
        let check = DoctorRunner().checkGitRepository(directory: scratch.path)
        XCTAssertEqual(check.status, .warning)
        XCTAssertEqual(check.fix, "Run: git init")
    }

    func testRunAllChecksWithBothPlatformsOptionalNeverFails() async {
        let checks = await DoctorRunner().runAllChecks(platforms: [.ios, .android], required: false)
        XCTAssertTrue(checks.contains { $0.name == "Android SDK" })
        XCTAssertTrue(checks.contains { $0.name == "Xcode" })
        XCTAssertFalse(DoctorRunner.hasFailures(checks.filter { $0.name.hasPrefix("Android") || $0.name == "adb" || $0.name == "JDK" }))
    }
}
