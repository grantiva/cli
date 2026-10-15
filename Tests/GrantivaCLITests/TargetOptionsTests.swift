import ArgumentParser
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class TargetOptionsTests: XCTestCase {
    func testExplicitEmptyTargetsAreRejectedBeforeForwarding() throws {
        for flag in ["--device", "--simulator", "--emulator"] {
            for value in ["", "   "] {
                XCTAssertThrowsError(try TargetOptions.parse([flag, value]).validate(), "\(flag) = \(value)")
            }
        }
        XCTAssertNoThrow(try TargetOptions.parse(["--simulator", "Grantiva iPhone 18 Pro"]).validate())
        XCTAssertThrowsError(try TargetOptions.parse(["--serial", "anything"]))
    }

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

    /// D2-12: with nothing else naming a platform, an Android-only target
    /// flag picks Android; `--simulator` (or no target) keeps iOS.
    func testFallbackPlatformFollowsTheTargetFlags() throws {
        XCTAssertEqual(try TargetOptions.parse([]).fallbackPlatform, .ios)
        XCTAssertEqual(try TargetOptions.parse(["--device", "emulator-5560"]).fallbackPlatform, .android)
        XCTAssertEqual(try TargetOptions.parse(["--emulator", "Pixel"]).fallbackPlatform, .android)
        XCTAssertEqual(try TargetOptions.parse(["--simulator", "iPhone 17", "--device", "emulator-5560"]).fallbackPlatform, .ios)
    }

    func testDeviceSerialIsValidated() throws {
        XCTAssertThrowsError(try TargetOptions.parse(["--device", "not a serial"]).checkFlags(for: .android, derivedDataPath: nil))
    }

    func testAndroidResolutionMergesFlagsOverConfig() async throws {
        let config = GrantivaConfig(
            screens: [.init(name: "Home", path: .launch)], platform: .android,
            android: AndroidProject(module: "mobile", variant: "release", applicationId: "com.cfg", emulator: "Cfg_AVD", buildArgs: ["-Pa=1"])
        )
        let fromConfig = try await TargetOptions.parse([]).resolve(platform: .android, config: config, skipBuild: false, appID: nil)
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

    /// A03: `--app-file app-paid-debug.apk` with `application_id` set to the
    /// free package tested the free one. The APK's own ID wins over config.
    func testAndroidResolutionPrefersTheAPKsApplicationIDOverConfig() async throws {
        let config = GrantivaConfig(
            flows: ["f.yaml"], platform: .android, android: AndroidProject(applicationId: "com.kylebrowning.landmarks")
        )
        let resolved = try TargetOptions.resolveAndroid(
            moduleFlag: nil, variantFlag: nil, applicationIdFlag: nil, emulatorFlag: nil, deviceFlag: nil,
            config: config, appID: "com.kylebrowning.landmarks.paid"
        )
        XCTAssertEqual(resolved.bundleId, "com.kylebrowning.landmarks.paid")
        XCTAssertEqual(resolved.android?.applicationId, "com.kylebrowning.landmarks.paid")
    }

    func testAndroidAppIDRanksFlagThenAppThenConfigAndReportsDisagreement() {
        let free = "com.kylebrowning.landmarks", paid = "com.kylebrowning.landmarks.paid"

        let fromApp = TargetOptions.androidAppID(flag: nil, binary: paid, configured: free)
        XCTAssertEqual(fromApp.id, paid)
        let configWarning = try? XCTUnwrap(fromApp.warning)
        XCTAssertTrue(configWarning?.contains("application_id \(free)") == true, "\(fromApp)")
        XCTAssertTrue(configWarning?.contains("testing \(paid)") == true, "\(fromApp)")

        let overridden = TargetOptions.androidAppID(flag: free, binary: paid, configured: nil)
        XCTAssertEqual(overridden.id, free, "--application-id still overrides")
        XCTAssertTrue(overridden.warning?.contains("--application-id \(free) differs") == true, "\(overridden)")
        XCTAssertTrue(overridden.warning?.contains(paid) == true, "\(overridden)")

        XCTAssertEqual(TargetOptions.androidAppID(flag: nil, binary: paid, configured: paid).warning, nil)
        XCTAssertEqual(TargetOptions.androidAppID(flag: paid, binary: paid, configured: free).warning, nil)
        XCTAssertEqual(TargetOptions.androidAppID(flag: nil, binary: nil, configured: free).id, free, "--no-build falls back to config")
        XCTAssertNil(TargetOptions.androidAppID(flag: nil, binary: nil, configured: nil).id)
    }

    /// K26: `build install` installs; only `run` tests.
    func testAppIDWarningFitsTheCommand() throws {
        let free = "com.kylebrowning.landmarks", paid = "com.kylebrowning.landmarks.paid"
        let install = try XCTUnwrap(AndroidProject.applicationID(override: nil, binary: paid, configured: free, purpose: .installing).warning)
        XCTAssertEqual(install, "application_id \(free) in grantiva-android.yml differs from the app's own application ID \(paid); installing \(paid). Update application_id to match.")
        let run = try XCTUnwrap(AndroidProject.applicationID(override: nil, binary: paid, configured: free, purpose: .testing).warning)
        XCTAssertTrue(run.contains("testing \(paid)"), run)
        let flagged = try XCTUnwrap(AndroidProject.applicationID(override: free, binary: paid, configured: nil, purpose: .installing).warning)
        XCTAssertTrue(flagged.contains("installing \(paid)"), flagged)
        XCTAssertFalse(flagged.contains("testing"), flagged)
        XCTAssertEqual(AndroidProject.applicationID(override: nil, binary: paid, configured: free).warning, run, "testing is the default")
    }

    func testInstalledAppIDPrefersTheBuiltVariantsIDOnAndroidOnly() throws {
        let config = GrantivaConfig(platform: .android, android: AndroidProject(applicationId: "com.cfg"))
        let resolved = ResolvedProject(bundleId: "com.cfg", android: AndroidProject(applicationId: "com.cfg"))
        var warnings: [String] = []
        XCTAssertEqual(
            try TargetOptions.parse([]).installedAppID(platform: .android, config: config, resolved: resolved, binaryID: "com.built") { warnings.append($0) },
            "com.built"
        )
        XCTAssertEqual(warnings.count, 1)
        let ios = ResolvedProject(bundleId: "com.ios")
        XCTAssertEqual(try TargetOptions.parse([]).installedAppID(platform: .ios, config: nil, resolved: ios, binaryID: "com.built") { _ in }, "com.ios")
    }

    func testInstallAppIDIsTheAppsOwnIDOnAndroid() {
        XCTAssertEqual(TargetOptions.installAppID(platform: .android, testID: "com.flag", binaryID: "com.built"), "com.built")
        XCTAssertEqual(TargetOptions.installAppID(platform: .android, testID: "com.cfg", binaryID: nil), "com.cfg")
        XCTAssertEqual(TargetOptions.installAppID(platform: .ios, testID: "com.ios", binaryID: "com.built"), "com.ios")
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

    /// L26-b: `--device` with `--emulator` is a usage error on every command
    /// that takes both: exit 64, the plain message, then the command's Usage
    /// lines. It is raised at parse time, before any config is read.
    func testDeviceAndEmulatorTogetherAreAUsageErrorEverywhere() throws {
        let message = "--device and --emulator are mutually exclusive; pass one."
        XCTAssertThrowsError(try TargetOptions.parse(["--device", "emulator-5554", "--emulator", "Pixel_8_API_35"])) { error in
            XCTAssertEqual(TargetOptions.message(for: error), message)
        }
        for command in [["run"], ["record", "--duration", "2"], ["runner", "start"], ["diff", "capture"], ["build", "install"]] {
            XCTAssertThrowsError(try GrantivaCommand.parseAsRoot(command + ["--device", "a", "--emulator", "b"])) { error in
                XCTAssertTrue(error is ValidationError || "\(type(of: error))".contains("CommandError"), "\(command): \(type(of: error))")
                let full = GrantivaCommand.fullMessage(for: error)
                let lines = full.components(separatedBy: "\n")
                XCTAssertEqual(lines.first, "Error: " + message, "\(command): \(full)")
                XCTAssertTrue(lines.count > 1 && lines[1].hasPrefix("Usage: grantiva \(command.prefix(2).filter { !$0.hasPrefix("-") }.joined(separator: " "))"), "\(command): \(full)")
                XCTAssertTrue(full.contains("See 'grantiva "), full)
                XCTAssertFalse(full.contains("Invalid argument"), full)
                XCTAssertEqual(GrantivaCommand.exitCode(for: error), .validationFailure, "\(command)")
            }
        }
    }
}
