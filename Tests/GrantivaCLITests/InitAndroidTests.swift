import ArgumentParser
import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class InitAndroidTests: XCTestCase {
    private var dir: URL!
    private var previousDirectory: String!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("init-android-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        previousDirectory = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(dir.path)
    }

    override func tearDownWithError() throws {
        FileManager.default.changeCurrentDirectoryPath(previousDirectory)
        try? FileManager.default.removeItem(at: dir)
    }

    func testInitInAGradleDirectoryWritesTheAndroidFile() async throws {
        try "".write(to: dir.appendingPathComponent("settings.gradle.kts"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("mobile"), withIntermediateDirectories: true)
        try "plugins { id(\"com.android.application\") }".write(to: dir.appendingPathComponent("mobile/build.gradle.kts"), atomically: true, encoding: .utf8)
        try await InitCommand.parse([]).run()
        let yaml = try String(contentsOf: dir.appendingPathComponent("grantiva-android.yml"), encoding: .utf8)
        XCTAssertTrue(yaml.contains("module: mobile"), yaml)
        XCTAssertTrue(yaml.contains("variant: debug"), yaml)
        XCTAssertTrue(yaml.contains("emulator: Pixel_8_API_35"), yaml)
        XCTAssertTrue(yaml.contains("system_image: \"system-images;android-35;google_apis;arm64-v8a\""), yaml)
        XCTAssertTrue(yaml.contains("# application_id:"), yaml)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("grantiva.yml").path))
        let loaded = try GrantivaConfig.load(platform: .android, from: dir)
        XCTAssertEqual(loaded.android?.module, "mobile")
        XCTAssertEqual(loaded.screens.count, 1)
    }

    func testInitWithTheFlagAndAnApplicationIDWritesItUncommented() async throws {
        try await InitCommand.parse(["--platform", "android", "--application-id", "com.example.app"]).run()
        let yaml = try String(contentsOf: dir.appendingPathComponent("grantiva-android.yml"), encoding: .utf8)
        XCTAssertTrue(yaml.contains("\napplication_id: com.example.app\n"), yaml)
        XCTAssertTrue(yaml.contains("module: app"), yaml)
    }

    func testInitDoesNotOverwriteAnExistingAndroidFile() async throws {
        try "module: keep\n".write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        try await InitCommand.parse(["--platform", "android"]).run()
        XCTAssertEqual(try String(contentsOf: dir.appendingPathComponent("grantiva-android.yml"), encoding: .utf8), "module: keep\n")
    }

    func testDetectModulePrefersAppThenTheFirstApplicationModule() throws {
        XCTAssertEqual(InitCommand.detectModule(in: dir.path), "app")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("feature"), withIntermediateDirectories: true)
        try "plugins { id 'com.android.library' }".write(to: dir.appendingPathComponent("feature/build.gradle"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("phone"), withIntermediateDirectories: true)
        try "plugins { id 'com.android.application' }".write(to: dir.appendingPathComponent("phone/build.gradle"), atomically: true, encoding: .utf8)
        XCTAssertEqual(InitCommand.detectModule(in: dir.path), "phone")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("app"), withIntermediateDirectories: true)
        try "".write(to: dir.appendingPathComponent("app/build.gradle.kts"), atomically: true, encoding: .utf8)
        XCTAssertEqual(InitCommand.detectModule(in: dir.path), "app")
    }

    // MARK: - C12: init applies run's platform validation

    private func assertInitFails(_ arguments: [String], environment: [String: String] = [:], mentioning expected: String, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await InitCommand.parse(arguments).run(environment: environment)
            XCTFail("expected init \(arguments) to fail", file: file, line: line)
        } catch {
            XCTAssertTrue(error.localizedDescription.contains(expected), "\(error.localizedDescription)", file: file, line: line)
        }
        for name in ["grantiva.yml", "grantiva-android.yml"] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path), "\(name) was written", file: file, line: line)
        }
    }

    func testSchemeWithTheAndroidPlatformIsRejectedByName() async {
        try? "".write(to: dir.appendingPathComponent("settings.gradle"), atomically: true, encoding: .utf8)
        await assertInitFails(["--platform", "android", "--scheme", "X"], mentioning: "--scheme is an iOS option, but this is an Android project")
    }

    func testBundleIdWithTheAndroidPlatformIsRejectedByName() async {
        await assertInitFails(["--platform", "android", "--bundle-id", "a.b"], mentioning: "--bundle-id is an iOS option")
    }

    func testApplicationIdWithTheIOSPlatformIsRejectedByName() async {
        try? FileManager.default.createDirectory(at: dir.appendingPathComponent("App.xcodeproj"), withIntermediateDirectories: true)
        await assertInitFails(["--platform", "ios", "--application-id", "a.b"], mentioning: "--application-id is an Android option, but this is an iOS project")
    }

    func testAnInvalidEnvironmentPlatformIsAnError() async {
        await assertInitFails([], environment: ["GRANTIVA_PLATFORM": "windows"], mentioning: "GRANTIVA_PLATFORM is \"windows\"; expected ios or android.")
    }

    func testTheEnvironmentPlatformSelectsAndroid() async throws {
        try await InitCommand.parse([]).run(environment: ["GRANTIVA_PLATFORM": "android"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("grantiva-android.yml").path))
    }

    func testBothProjectsWithoutAFlagMentionsTheEnvironmentVariable() async {
        try? FileManager.default.createDirectory(at: dir.appendingPathComponent("App.xcodeproj"), withIntermediateDirectories: true)
        try? "".write(to: dir.appendingPathComponent("settings.gradle"), atomically: true, encoding: .utf8)
        await assertInitFails([], mentioning: "Pass --platform ios|android or set GRANTIVA_PLATFORM.")
    }
}

/// L09: Android `init` warns, like iOS, when the default AVD exists and
/// Grantiva did not create it; one sentence shape for both.
final class InitAndroidDefaultAVDTests: XCTestCase {
    func testWarnsForAnExistingAVDGrantivaDidNotCreate() {
        XCTAssertEqual(
            InitCommand.existingAVDWarning(name: DefaultEmulator.name, avds: ["Other", DefaultEmulator.name], createdByGrantiva: []),
            "An AVD named \"Pixel_8_API_35\" already exists and was not created by Grantiva; runs from this directory will boot and drive it. "
                + "To keep them off it, set emulator: in grantiva-android.yml to a name of your own, for example \"Grantiva_Pixel_8_API_35\" "
                + "(create it with `grantiva emulator ensure --name Grantiva_Pixel_8_API_35`)."
        )
    }

    func testNoWarningWhenAbsentOrCreatedByGrantiva() {
        XCTAssertNil(InitCommand.existingAVDWarning(name: DefaultEmulator.name, avds: ["Other"], createdByGrantiva: []))
        XCTAssertNil(InitCommand.existingAVDWarning(name: DefaultEmulator.name, avds: [DefaultEmulator.name], createdByGrantiva: [DefaultEmulator.name]))
    }

    func testTheIOSWarningHasTheSameShape() throws {
        let device = SimulatorDevice(name: "iPhone 18 Pro", udid: "FE441EE5", state: "Shutdown", runtime: "iOS-27-0", isAvailable: true)
        let warning = try XCTUnwrap(InitCommand.existingSimulatorWarning(name: "iPhone 18 Pro", devices: [device], createdByGrantiva: []))
        XCTAssertEqual(
            warning,
            "A simulator named \"iPhone 18 Pro\" (FE441EE5) already exists and was not created by Grantiva; runs from this directory will boot and drive it. "
                + "To keep them off it, set simulator: in grantiva.yml to a name of your own, for example \"Grantiva iPhone 18 Pro\" "
                + "(create it with `grantiva simulator ensure --name \"Grantiva iPhone 18 Pro\"`)."
        )
    }

    func testTheDefaultAVDNameIsDefinedOnce() throws {
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/GrantivaCLI/InitCommand.swift")
        XCTAssertFalse(try String(contentsOf: source, encoding: .utf8).contains("\"Pixel_8_API_35\""))
    }
}
