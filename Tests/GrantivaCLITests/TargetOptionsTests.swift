import ArgumentParser
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class TargetOptionsTests: XCTestCase {
    func testIOSFlagsAreRejectedOnAndroidAndViceVersa() throws {
        let scheme = try TargetOptions.parse(["--scheme", "Demo"])
        XCTAssertThrowsError(try scheme.checkFlags(for: .android, derivedDataPath: nil)) { error in
            XCTAssertTrue("\(error)".contains("--scheme"), "\(error)")
            XCTAssertTrue("\(error)".contains("iOS"), "\(error)")
        }
        XCTAssertNoThrow(try scheme.checkFlags(for: .ios, derivedDataPath: nil))

        let module = try TargetOptions.parse(["--module", "app", "--device", "emulator-5554"])
        XCTAssertThrowsError(try module.checkFlags(for: .ios, derivedDataPath: nil)) { error in
            XCTAssertTrue("\(error)".contains("--module"), "\(error)")
        }
        XCTAssertNoThrow(try module.checkFlags(for: .android, derivedDataPath: nil))

        XCTAssertThrowsError(try TargetOptions.parse([]).checkFlags(for: .android, derivedDataPath: "/dd")) { error in
            XCTAssertTrue("\(error)".contains("--derived-data-path"), "\(error)")
        }
        XCTAssertThrowsError(try TargetOptions.parse([]).checkFlags(for: .ios, derivedDataPath: nil, logsTag: "T")) { error in
            XCTAssertTrue("\(error)".contains("--logs-tag"), "\(error)")
        }
        XCTAssertThrowsError(try TargetOptions.parse([]).checkFlags(for: .android, derivedDataPath: nil, logsPredicate: "p")) { error in
            XCTAssertTrue("\(error)".contains("--logs-predicate"), "\(error)")
        }
    }

    func testDeviceSerialIsValidated() throws {
        XCTAssertThrowsError(try TargetOptions.parse(["--device", "not a serial"]).checkFlags(for: .android, derivedDataPath: nil))
    }

    func testAndroidResolutionMergesFlagsOverConfigOverBinary() async throws {
        let config = GrantivaConfig(
            screens: [.init(name: "Home", path: .launch)], platform: .android,
            android: AndroidProject(module: "mobile", variant: "release", applicationId: "com.cfg", emulator: "Cfg_AVD", buildArgs: ["-Pa=1"])
        )
        let fromConfig = try await TargetOptions.parse([]).resolve(platform: .android, config: config, skipBuild: false, appID: "com.bin")
        XCTAssertEqual(fromConfig.android?.module, "mobile")
        XCTAssertEqual(fromConfig.android?.variant, "release")
        XCTAssertEqual(fromConfig.bundleId, "com.cfg")
        XCTAssertEqual(fromConfig.simulator, "Cfg_AVD")
        XCTAssertEqual(fromConfig.buildSettings, ["-Pa=1"])
        XCTAssertNil(fromConfig.scheme)
        XCTAssertEqual(fromConfig.screens.count, 1)

        let flags = try TargetOptions.parse(["--module", "app", "--variant", "debug", "--application-id", "com.flag", "--device", "emulator-5556"])
        let fromFlags = try await flags.resolve(platform: .android, config: config, skipBuild: false, appID: "com.bin")
        XCTAssertEqual(fromFlags.android?.module, "app")
        XCTAssertEqual(fromFlags.android?.variant, "debug")
        XCTAssertEqual(fromFlags.bundleId, "com.flag")
        XCTAssertEqual(fromFlags.simulator, "emulator-5556", "--device wins over the configured emulator")

        let bare = try await TargetOptions.parse([]).resolve(platform: .android, config: nil, skipBuild: true, appID: "com.bin")
        XCTAssertEqual(bare.android?.module, "app")
        XCTAssertEqual(bare.android?.variant, "debug")
        XCTAssertEqual(bare.bundleId, "com.bin")
        XCTAssertEqual(bare.simulator, "", "no emulator configured means auto-select")
    }

    func testInvalidApplicationIDIsRejected() async throws {
        do {
            _ = try await TargetOptions.parse(["--application-id", "bad id"]).resolve(platform: .android, config: nil, skipBuild: true, appID: nil)
            XCTFail("expected an error")
        } catch GrantivaError.invalidArgument(let message) {
            XCTAssertEqual(message, "Application ID \"bad id\" is not a valid Android application ID (letters, digits, underscores, at least one dot).")
        }
        for bad in ["com", "1com.x", "com..x", "com.x."] {
            XCTAssertThrowsError(try TargetOptions.resolveAndroid(
                moduleFlag: nil, variantFlag: nil, applicationIdFlag: bad, emulatorFlag: nil, deviceFlag: nil, config: nil, appID: nil
            ), bad)
        }
        let ok = try TargetOptions.resolveAndroid(
            moduleFlag: nil, variantFlag: nil, applicationIdFlag: "com.example_app.Demo1", emulatorFlag: nil, deviceFlag: nil, config: nil, appID: nil
        )
        XCTAssertEqual(ok.bundleId, "com.example_app.Demo1")
        XCTAssertNil(try TargetOptions.resolveAndroid(
            moduleFlag: nil, variantFlag: nil, applicationIdFlag: nil, emulatorFlag: nil, deviceFlag: nil, config: nil, appID: nil
        ).bundleId)
    }

    func testExtraBuildSettingsUseGradleArgsOnAndroid() async throws {
        let resolved = ResolvedProject(buildSettings: ["-Pa=1"], android: AndroidProject())
        XCTAssertEqual(try TargetOptions.parse([]).extraBuildSettings(platform: .android, derivedDataPath: nil, resolved: resolved), ["-Pa=1"])
        let ios = ResolvedProject(buildSettings: ["-quiet"])
        XCTAssertEqual(try TargetOptions.parse([]).extraBuildSettings(platform: .ios, derivedDataPath: "/dd", resolved: ios), ["-quiet", "-derivedDataPath", "/dd"])
    }

    func testAppIDMessagesNameThePlatformsFlag() {
        XCTAssertTrue(TargetOptions.appIDMessage(for: .ios).contains("--bundle-id"))
        XCTAssertTrue(TargetOptions.appIDMessage(for: .android).contains("--application-id"))
        XCTAssertTrue(TargetOptions.appIDMessage(for: .android).contains("grantiva-android.yml"))
    }
}
