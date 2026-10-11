import XCTest
@testable import GrantivaCLI
import GrantivaCore

private actor BaselineSaveRecorder {
    private var saves: [(String, Data)] = []

    func save(_ screenName: String, _ data: Data) -> String {
        saves.append((screenName, data))
        return "/baselines/\(ScreenArtifact.fileName(for: screenName))"
    }

    func recordedNames() -> [String] { saves.map(\.0) }
    func recordedData() -> [Data] { saves.map(\.1) }
}

private final class ComparedNames: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func add() { lock.lock(); value += 1; lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
}

final class DiffCommandTests: XCTestCase {
    func testCaptureArtifactsReturnsCanonicalArtifactsInDeterministicOrder() throws {
        let artifacts = try DiffCommand.captureArtifacts(from: [
            "Settings%2FGeneral.png",
            "Home.png",
        ])

        XCTAssertEqual(artifacts, [
            .init(fileName: "Home.png", screenName: "Home"),
            .init(fileName: "Settings%2FGeneral.png", screenName: "Settings/General"),
        ])
    }

    // Captures left by a version that percent-encoded spaces still compare;
    // when a fresh plain-named capture sits beside one, the fresh one wins.
    func testCaptureArtifactsAcceptLegacyNamesAndPreferTheCurrentForm() throws {
        XCTAssertEqual(try DiffCommand.captureArtifacts(from: ["Deep%20Links.png"]), [
            .init(fileName: "Deep%20Links.png", screenName: "Deep Links"),
        ])
        XCTAssertEqual(try DiffCommand.captureArtifacts(from: ["Deep%20Links.png", "Deep Links.png"]), [
            .init(fileName: "Deep Links.png", screenName: "Deep Links"),
        ])
    }

    func testCaptureArtifactsRejectsUndecodableScreenName() {
        XCTAssertThrowsError(try DiffCommand.captureArtifacts(from: ["%FF.png"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid capture filename \"%FF.png\""))
        }
    }

    func testCaptureArtifactsRejectsNonCanonicalAlias() {
        XCTAssertThrowsError(try DiffCommand.captureArtifacts(from: ["%48ome.png"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid capture filename \"%48ome.png\""))
        }
    }

    func testCaptureInvocationIgnoresStaleSameNameAndRemovedScreenFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-diff-invocation-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let current = directory.appendingPathComponent("Current.png")
        let staleSameName = directory.appendingPathComponent("Failed.png")
        let removedScreen = directory.appendingPathComponent("Removed.png")
        try Data("current".utf8).write(to: current)
        try Data("stale".utf8).write(to: staleSameName)
        try Data("removed".utf8).write(to: removedScreen)

        let artifacts = try DiffCommand.currentInvocationArtifacts(from: [
            ScreenCapture(screenName: "Current", path: current.path, sizeBytes: 7),
            ScreenCapture(screenName: "Failed", path: "", sizeBytes: 0),
        ], outputDir: directory.path)

        XCTAssertEqual(artifacts.map(\.screenName), ["Current"])
        XCTAssertEqual(try artifacts.map { try String(contentsOfFile: $0.path!, encoding: .utf8) }, ["current"])
    }

    func testCompareCoversPassedFailedNewAndErrorScreens() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-diff-pipeline-\(UUID().uuidString)")
        let captureDirectory = root.appendingPathComponent("captures")
        let diffDirectory = captureDirectory.appendingPathComponent("diffs")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: diffDirectory, withIntermediateDirectories: true)

        let screens = ["Pass", "Settings/Failure", "New", "Error"]
        let artifacts = try screens.map { screenName in
            let fileName = ScreenArtifact.fileName(for: screenName)
            try Data(screenName.utf8).write(to: captureDirectory.appendingPathComponent(fileName))
            return DiffCommand.CaptureArtifact(fileName: fileName, screenName: screenName)
        }
        let baselineNames: Set<String> = ["Pass", "Settings/Failure", "Error"]
        let store = BaselineStore(
            save: { _, _ in "" },
            load: { screenName in baselineNames.contains(screenName) ? Data("baseline".utf8) : nil },
            list: { [] },
            delete: { _ in },
            baselineDirectory: { "/baselines" }
        )
        let differ = ImageDiffer { _, current in
            let value = String(decoding: current, as: UTF8.self)
            if value == "Error" { throw GrantivaError.invalidImage }
            if value == "Pass" {
                return DiffOutput(pixelDiffPercent: 0.01, perceptualDistance: 1, diffImageData: Data())
            }
            return DiffOutput(pixelDiffPercent: 0.5, perceptualDistance: 20, diffImageData: Data("diff".utf8))
        }

        let outcome = try await DiffCommand.compare(
            artifacts,
            captureDirectory: captureDirectory.path,
            diffDirectory: diffDirectory.path,
            config: .init(threshold: 0.02, perceptualThreshold: 5),
            store: store,
            differ: differ
        )

        XCTAssertFalse(outcome.passed)
        XCTAssertEqual(outcome.screens.map(\.status), [.passed, .failed, .newScreen, .error])
        XCTAssertEqual(outcome.screens[1].diffImagePath, diffDirectory.appendingPathComponent("Settings%2FFailure_diff.png").path)
        XCTAssertEqual(try String(contentsOf: diffDirectory.appendingPathComponent("Settings%2FFailure_diff.png"), encoding: .utf8), "diff")
        XCTAssertNil(outcome.screens[0].diffImagePath)
        XCTAssertTrue(outcome.screens[2].message.contains("diff approve"))
        XCTAssertTrue(outcome.screens[3].message.hasPrefix("Error: "))
    }

    func testApprovePromotesAllCanonicalCaptures() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-diff-approve-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let artifacts = try ["Home", "Settings/General"].map { screenName in
            let fileName = ScreenArtifact.fileName(for: screenName)
            try Data(screenName.utf8).write(to: directory.appendingPathComponent(fileName))
            return DiffCommand.CaptureArtifact(fileName: fileName, screenName: screenName)
        }
        let recorder = BaselineSaveRecorder()
        let store = BaselineStore(
            save: { name, data in await recorder.save(name, data) },
            load: { _ in nil }, list: { [] }, delete: { _ in }, baselineDirectory: { "/baselines" }
        )

        let approved = try await DiffCommand.approve(
            [], availableArtifacts: artifacts, captureDirectory: directory.path, store: store
        )

        let recordedNames = await recorder.recordedNames()
        let recordedData = await recorder.recordedData()
        XCTAssertEqual(approved, ["Home", "Settings/General"])
        XCTAssertEqual(recordedNames, approved)
        XCTAssertEqual(recordedData, [Data("Home".utf8), Data("Settings/General".utf8)])
    }

    func testApproveRejectsRequestedScreenWithoutCapture() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-diff-approve-missing-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        do {
            _ = try await DiffCommand.approve(
                ["Missing"], availableArtifacts: [], captureDirectory: directory.path, store: .failing
            )
            XCTFail("Expected a missing-capture error")
        } catch {
            // K49: one sentence naming the screen and the directory, not
            // the directory message wrapped around it.
            XCTAssertEqual(
                error.localizedDescription,
                "No capture found for \"Missing\" in \(directory.path). Run: grantiva diff capture"
            )
            XCTAssertFalse(error.localizedDescription.contains("No captures found in"))
        }
    }

    // MARK: - K108: the failure line names the threshold that was exceeded

    func testFailureMessageNamesTheExceededThreshold() async throws {
        let cases: [(pixel: Double, perceptual: Double, message: String)] = [
            (0.0003, 63.6, "Failed: perceptual=63.6 exceeds perceptual_threshold 5.0 (pixel=0.03%, threshold 2.00%)"),
            (0.0797, 1.2, "Failed: pixel=7.97% exceeds threshold 2.00% (perceptual=1.2, perceptual_threshold 5.0)"),
            (0.0797, 6.4, "Failed: pixel=7.97% exceeds threshold 2.00% and perceptual=6.4 exceeds perceptual_threshold 5.0"),
        ]
        for testCase in cases {
            let outcome = try await compareOneScreen(
                baseline: true,
                differ: ImageDiffer { _, _ in
                    DiffOutput(pixelDiffPercent: testCase.pixel, perceptualDistance: testCase.perceptual, diffImageData: Data())
                }
            )
            XCTAssertEqual(outcome.screens.map(\.status), [.failed])
            XCTAssertEqual(outcome.screens.first?.message, testCase.message)
        }
    }

    // MARK: - K89: a comparison with no baselines is not a pass

    func testCompareWithoutBaselinesDoesNotPass() async throws {
        let outcome = try await compareOneScreen(baseline: false, differ: .failing)
        XCTAssertFalse(outcome.passed)
        XCTAssertEqual(outcome.screens.map(\.status), [.newScreen])
    }

    func testCompareWithMatchingBaselinesPasses() async throws {
        let outcome = try await compareOneScreen(
            baseline: true,
            differ: ImageDiffer { _, _ in DiffOutput(pixelDiffPercent: 0, perceptualDistance: 0, diffImageData: Data()) }
        )
        XCTAssertTrue(outcome.passed)
    }

    /// One capture named Home, optionally with a baseline, through `compare`.
    private func compareOneScreen(baseline: Bool, differ: ImageDiffer) async throws -> DiffCommand.ComparisonOutcome {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-diff-one-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let diffs = root.appendingPathComponent("diffs")
        try FileManager.default.createDirectory(at: diffs, withIntermediateDirectories: true)
        try Data("Home".utf8).write(to: root.appendingPathComponent("Home.png"))
        let store = BaselineStore(
            save: { _, _ in "" }, load: { _ in baseline ? Data("baseline".utf8) : nil }, list: { [] }, delete: { _ in },
            baselineDirectory: { "/baselines" }
        )
        return try await DiffCommand.compare(
            [.init(fileName: "Home.png", screenName: "Home")],
            captureDirectory: root.path, diffDirectory: diffs.path,
            config: .init(threshold: 0.02, perceptualThreshold: 5), store: store, differ: differ
        )
    }

    // MARK: - K51: a compare with nothing to compare creates nothing

    func testCompareWithoutCapturesCreatesNoDirectories() async throws {
        for platform in ["ios", "android"] {
            try await inTemporaryDirectory { dir in
                do {
                    try await DiffCommand.CompareCommand.parse(["--platform", platform]).run()
                    XCTFail("expected noCaptures")
                } catch GrantivaError.noCaptures {
                } catch {
                    XCTFail("\(platform): \(error)")
                }
                XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent(".grantiva").path), platform)
            }
        }
    }

    /// K51 asked for `diff approve` to be verified as well.
    func testApproveWithoutCapturesCreatesNoDirectories() async throws {
        for platform in ["ios", "android"] {
            try await inTemporaryDirectory { dir in
                do {
                    try await DiffCommand.ApproveCommand.parse(["--platform", platform]).run()
                    XCTFail("expected noCaptures")
                } catch GrantivaError.noCaptures {
                } catch {
                    XCTFail("\(platform): \(error)")
                }
                XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent(".grantiva").path), platform)
            }
        }
    }

    // MARK: - K82-b: only configured screens are approved and compared

    func testConfiguredScreensSelectTheVisualDiffSet() throws {
        let artifacts = try DiffCommand.captureArtifacts(from: [
            "Home.png", "Settings.png", "failure-1.png", "flow-cmd-003-Home.png",
        ])
        let selection = DiffCommand.configuredArtifacts(artifacts, screens: ["Home", "Settings", "Detail"])
        XCTAssertEqual(selection.kept.map(\.screenName), ["Home", "Settings"])
        XCTAssertEqual(selection.ignored.map(\.screenName), ["failure-1", "flow-cmd-003-Home"])
        // Without configured screens (no config file) everything stays.
        XCTAssertEqual(DiffCommand.configuredArtifacts(artifacts, screens: nil).kept.count, 4)
    }

    func testApproveWritesBaselinesOnlyForConfiguredScreens() async throws {
        try await inTemporaryDirectory { dir in
            try """
            module: app
            screens:
              - name: Home
                path: launch
              - name: Settings
                path: launch
            """.write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
            try FileManager.default.createDirectory(atPath: ".grantiva/captures/android", withIntermediateDirectories: true)
            for name in ["Home", "Settings", "failure-1", "flow-cmd-003-Home"] {
                try Data([0x89, 0x50]).write(to: URL(fileURLWithPath: ".grantiva/captures/android/\(name).png"))
            }

            try await DiffCommand.ApproveCommand.parse(["--platform", "android"]).run()

            let baselines = try FileManager.default.contentsOfDirectory(atPath: ".grantiva/baselines/android").sorted()
            XCTAssertEqual(baselines, ["Home.png", "Settings.png"])
        }
    }

    func testCompareComparesOnlyConfiguredScreens() async throws {
        try await inTemporaryDirectory { dir in
            try """
            module: app
            screens:
              - name: Home
                path: launch
            """.write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
            for sub in ["captures", "baselines"] {
                try FileManager.default.createDirectory(atPath: ".grantiva/\(sub)/android", withIntermediateDirectories: true)
                for name in ["Home", "failure-1", "flow-cmd-003-Home"] {
                    try Data([0x89, 0x50]).write(to: URL(fileURLWithPath: ".grantiva/\(sub)/android/\(name).png"))
                }
            }
            let compared = ComparedNames()
            var command = try DiffCommand.CompareCommand.parse(["--platform", "android"])
            command.imageDiffer = ImageDiffer { _, _ in
                compared.add()
                return DiffOutput(pixelDiffPercent: 0, perceptualDistance: 0, diffImageData: Data())
            }
            try await command.run()
            XCTAssertEqual(compared.count, 1, "only Home is compared")
            // K51: with captures present, compare still creates diffs/.
            var isDirectory: ObjCBool = false
            XCTAssertTrue(FileManager.default.fileExists(atPath: ".grantiva/captures/android/diffs", isDirectory: &isDirectory))
            XCTAssertTrue(isDirectory.boolValue)
        }
    }

    /// Fix round: when every capture is set aside, the error names the
    /// configured screens without a capture instead of "No captures found".
    func testOnlyUnconfiguredCapturesNameTheMissingScreens() async throws {
        try await inTemporaryDirectory { dir in
            try """
            module: app
            screens:
              - name: Home
                path: launch
              - name: Settings
                path: launch
            """.write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
            try FileManager.default.createDirectory(atPath: ".grantiva/captures/android", withIntermediateDirectories: true)
            for name in ["failure-1", "flow-cmd-003-Home"] {
                try Data([0x89, 0x50]).write(to: URL(fileURLWithPath: ".grantiva/captures/android/\(name).png"))
            }
            let expected = "No capture found for the configured screens (Home, Settings) in .grantiva/captures/android; "
                + "its 2 other files are not configured screens (failure-1, flow-cmd-003-Home). Run: grantiva diff capture"
            for run in [
                { try await DiffCommand.ApproveCommand.parse(["--platform", "android"]).run() },
                { try await DiffCommand.CompareCommand.parse(["--platform", "android"]).run() },
            ] as [() async throws -> Void] {
                do {
                    try await run()
                    XCTFail("expected an error")
                } catch {
                    XCTAssertEqual(error.localizedDescription, expected)
                }
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: ".grantiva/baselines"))
            XCTAssertFalse(FileManager.default.fileExists(atPath: ".grantiva/captures/android/diffs"))
        }
    }

    /// Fix round: the ignored files reach `--json` consumers.
    func testIgnoredFilesAreInTheJSONDocuments() throws {
        let compare = try JSONOutput.string(CompareResult(screens: [], passed: true, duration: 0, ignored: ["failure-1"]))
        XCTAssertTrue(compare.contains(#""ignored" : ["#) && compare.contains("failure-1"), compare)
        let approve = try JSONOutput.string(ApproveResult(approvedScreens: ["Home"], baselineDirectory: "b", ignored: ["failure-1"]))
        XCTAssertTrue(approve.contains(#""ignored" : ["#) && approve.contains("failure-1"), approve)
        XCTAssertFalse(try JSONOutput.string(CompareResult(screens: [], passed: true, duration: 0)).contains("ignored"))
    }

    /// Fix round: approve reads the config for the screen set; a file it
    /// cannot parse stops it with the file named and the parse error.
    func testApproveNamesAnUnparseableConfig() async throws {
        try await inTemporaryDirectory { dir in
            try "module: app\nscreens: [unclosed\n".write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
            do {
                try await DiffCommand.ApproveCommand.parse(["--platform", "android"]).run()
                XCTFail("expected an error")
            } catch {
                let message = error.localizedDescription
                XCTAssertTrue(message.hasPrefix("diff approve reads grantiva-android.yml for the configured screens and could not parse it: "), message)
                XCTAssertTrue(message.hasSuffix("Fix grantiva-android.yml and run grantiva diff approve again."), message)
            }
        }
    }

    // MARK: - K55: one capture document shape

    func testCaptureResultCarriesTheEmulatorObjectOnAndroidOnly() throws {
        let target = CaptureSimulatorTarget(
            name: "fix2", udid: "emulator-5554",
            geometry: SimulatorDisplayGeometry(points: [411, 914], pixels: [1080, 2400], scale: 2.625)
        )
        let android = CaptureResult(screens: [], directory: "d", duration: 1, target: target, platform: .android)
        XCTAssertEqual(android.emulator, target)
        XCTAssertEqual(android.simulator, target)
        let ios = CaptureResult(screens: [], directory: "d", duration: 1, target: target, platform: .ios)
        XCTAssertNil(ios.emulator)
        XCTAssertEqual(DiffCommand.captureResult(screens: [], directory: "d", duration: 1, target: target, platform: .android).emulator, target)
    }

    // MARK: - I02: --no-build device resolution

    /// Two booted devices and config `simulator: B`: the --no-build path uses B, never the platform default.
    func testNoBuildUsesConfiguredSimulatorNotFirstBooted() async throws {
        let fake = FakeDevicePlatform(platform: .ios)
        fake.bootedID = "B-UDID"; fake.bootedName = "B"
        let booted = try await DiffCommand.noBuildDevice(
            platform: .ios, explicit: nil, config: GrantivaConfig(simulator: "B"), sessionUDID: { "SESSION-UDID" }, device: fake
        )
        XCTAssertEqual(booted.udid, "B-UDID")
        XCTAssertEqual(fake.calls, ["bootDevice(B)"])
    }

    /// R04: with no config file, capture names the missing file and its path
    /// instead of reporting that the (absent) file has no screens.
    func testCaptureWithoutAConfigFileNamesTheMissingFile() async throws {
        try await inTemporaryDirectory { dir in
            var command = try DiffCommand.CaptureCommand.parse(["--no-build", "--platform", "ios"])
            let fake = FakeDevicePlatform(platform: .ios)
            command.devicePlatform = InjectedDevicePlatform(fake)
            do {
                try await command.run()
                XCTFail("expected the missing config file to stop the capture")
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                XCTAssertTrue(message.contains("grantiva.yml not found at "), message)
                XCTAssertTrue(message.contains("/grantiva.yml"), message)
                XCTAssertTrue(message.contains("grantiva init"), message)
                XCTAssertFalse(message.contains("No screens configured"), message)
            }
            XCTAssertTrue(fake.calls.isEmpty, "\(fake.calls)")
        }
    }

    func testCaptureWithAConfigFileWithoutScreensStillSaysSo() async throws {
        try await inTemporaryDirectory { dir in
            try "bundle_id: com.example.app\n".write(to: dir.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
            var command = try DiffCommand.CaptureCommand.parse(["--no-build", "--platform", "ios"])
            command.devicePlatform = InjectedDevicePlatform(FakeDevicePlatform(platform: .ios))
            do {
                try await command.run()
                XCTFail("expected the empty screens list to stop the capture")
            } catch {
                XCTAssertTrue("\(error)".contains("No screens configured in grantiva.yml"), "\(error)")
            }
        }
    }

    /// I02 end to end through `run()`: config `simulator: B` under --no-build reaches the platform as B.
    func testCaptureNoBuildRunUsesTheConfiguredSimulator() async throws {
        try await inTemporaryDirectory { dir in
            try """
            simulator: B
            screens:
              - name: Home
                path: launch
            """.write(to: dir.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
            var command = try DiffCommand.CaptureCommand.parse(["--no-build", "--platform", "ios"])
            let fake = FakeDevicePlatform(platform: .ios)
            command.devicePlatform = InjectedDevicePlatform(fake)
            do {
                try await command.run()
                XCTFail("expected the missing bundle ID to stop the capture after device resolution")
            } catch {
                XCTAssertTrue("\(error)".contains("Bundle ID is required"), "\(error)")
            }
            XCTAssertEqual(fake.calls, ["bootDevice(B)"])
        }
    }

    /// The runner session is only consulted when neither the flag nor the config names a device.
    func testNoBuildDoesNotLookUpTheSessionWhenADeviceIsNamed() async throws {
        let fake = FakeDevicePlatform(platform: .ios)
        _ = try await DiffCommand.noBuildDevice(
            platform: .ios, explicit: nil, config: GrantivaConfig(simulator: "B"),
            sessionUDID: { XCTFail("session looked up"); return nil }, device: fake
        )
        XCTAssertEqual(fake.calls, ["bootDevice(B)"])
    }

    func testNoBuildFlagWinsOverConfigAndSession() async throws {
        let fake = FakeDevicePlatform(platform: .ios)
        _ = try await DiffCommand.noBuildDevice(
            platform: .ios, explicit: "A", config: GrantivaConfig(simulator: "B"), sessionUDID: { "SESSION-UDID" }, device: fake
        )
        XCTAssertEqual(fake.calls, ["bootDevice(A)"])
    }

    func testNoBuildFallsBackToTheRunnerSessionDevice() async throws {
        let fake = FakeDevicePlatform(platform: .ios)
        _ = try await DiffCommand.noBuildDevice(
            platform: .ios, explicit: nil, config: GrantivaConfig(), sessionUDID: { "SESSION-UDID" }, device: fake
        )
        XCTAssertEqual(fake.calls, ["bootDevice(SESSION-UDID)"])
    }

    func testNoBuildUsesThePlatformDefaultOnlyWhenNothingIsNamed() async throws {
        let fake = FakeDevicePlatform(platform: .ios)
        _ = try await DiffCommand.noBuildDevice(platform: .ios, explicit: nil, config: nil, sessionUDID: { nil }, device: fake)
        XCTAssertEqual(fake.calls, ["defaultDevice"])
    }

    func testNoBuildOnAndroidHonoursTheConfiguredEmulator() async throws {
        let fake = FakeDevicePlatform(platform: .android)
        let config = GrantivaConfig(android: AndroidProject(emulator: "Pixel_8_API_35"))
        _ = try await DiffCommand.noBuildDevice(platform: .android, explicit: nil, config: config, sessionUDID: { nil }, device: fake)
        XCTAssertEqual(fake.calls, ["bootDevice(Pixel_8_API_35)"])
    }

    func testRunnerSessionDeviceMustMatchThePlatform() {
        XCTAssertEqual(DiffCommand.sessionUDID("B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C", for: .ios), "B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C")
        XCTAssertNil(DiffCommand.sessionUDID("emulator-5554", for: .ios))
        XCTAssertEqual(DiffCommand.sessionUDID("emulator-5554", for: .android), "emulator-5554")
        XCTAssertNil(DiffCommand.sessionUDID("B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C", for: .android))
        XCTAssertNil(DiffCommand.sessionUDID(nil, for: .ios))
    }

    func testDirectoriesArePerPlatform() {
        XCTAssertEqual(DiffCommand.captureDirectory(for: .ios), ".grantiva/captures")
        XCTAssertEqual(DiffCommand.captureDirectory(for: .android), ".grantiva/captures/android")
        XCTAssertEqual(DiffCommand.baselineDirectory(for: .ios), ".grantiva/baselines")
        XCTAssertEqual(DiffCommand.baselineDirectory(for: .android), ".grantiva/baselines/android")
        // K82-b: `run` keeps its shots out of the visual-diff directory.
        XCTAssertEqual(RunCommand.captureDirectory(for: .ios), ".grantiva/run-captures")
        XCTAssertEqual(RunCommand.captureDirectory(for: .android), ".grantiva/run-captures/android")
    }

    func testAndroidBaselineStoreIsLocalEvenWhenAuthenticated() async throws {
        let credentials = AuthCredentials(apiKey: "key", baseURL: "https://example.invalid")
        let store = try await DiffCommand.resolveBaselineStore(platform: .android, credentials: credentials)
        XCTAssertEqual(store.baselineDirectory(), ".grantiva/baselines/android")
        let anonymous = try await DiffCommand.resolveBaselineStore(platform: .android, credentials: nil)
        XCTAssertEqual(anonymous.baselineDirectory(), ".grantiva/baselines/android")
    }

    func testIOSBaselineStoreIsUnchangedWhenAnonymous() async throws {
        let store = try await DiffCommand.resolveBaselineStore(platform: .ios, credentials: nil)
        XCTAssertEqual(store.baselineDirectory(), ".grantiva/baselines")
    }

    /// Review Focus 5: approving Android captures never touches the iOS baseline root.
    func testApproveOnAndroidWritesOnlyUnderTheAndroidDirectory() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let previous = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(dir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(previous) }
        try "module: app\n".write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(atPath: ".grantiva/captures/android", withIntermediateDirectories: true)
        try Data([0x89, 0x50]).write(to: URL(fileURLWithPath: ".grantiva/captures/android/Home.png"))

        try await DiffCommand.ApproveCommand.parse([]).run()

        XCTAssertTrue(FileManager.default.fileExists(atPath: ".grantiva/baselines/android/Home.png"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: ".grantiva/baselines/Home.png"))
    }

    private func inTemporaryDirectory(_ body: (URL) async throws -> Void) async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let previous = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(dir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(previous) }
        try await body(dir)
    }

    private func withEnvironment(_ key: String, _ value: String?, _ body: () async throws -> Void) async rethrows {
        let previous = ProcessInfo.processInfo.environment[key]
        if let value { setenv(key, value, 1) } else { unsetenv(key) }
        defer {
            if let previous { setenv(key, previous, 1) } else { unsetenv(key) }
        }
        try await body()
    }

    func testBareApproveSurfacesAnAmbiguousDirectory() async throws {
        try await withEnvironment("GRANTIVA_PLATFORM", nil) {
            try await inTemporaryDirectory { dir in
                try "scheme: Demo\n".write(to: dir.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
                try "module: app\n".write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
                do {
                    try await DiffCommand.ApproveCommand.parse([]).run()
                    XCTFail("expected an error")
                } catch {
                    XCTAssertTrue("\(error)".contains("--platform"), "\(error)")
                }
            }
        }
    }

    func testBareCompareSurfacesAnAmbiguousDirectory() async throws {
        try await withEnvironment("GRANTIVA_PLATFORM", nil) {
            try await inTemporaryDirectory { dir in
                try "scheme: Demo\n".write(to: dir.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
                try "module: app\n".write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
                do {
                    try await DiffCommand.CompareCommand.parse([]).run()
                    XCTFail("expected an error")
                } catch {
                    XCTAssertTrue("\(error)".contains("--platform"), "\(error)")
                }
            }
        }
    }

    func testBareApproveHonorsGrantivaPlatformEnvironment() async throws {
        try await withEnvironment("GRANTIVA_PLATFORM", "android") {
            try await inTemporaryDirectory { dir in
                try "module: app\n".write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
                try FileManager.default.createDirectory(atPath: ".grantiva/captures/android", withIntermediateDirectories: true)
                try Data([0x89, 0x50]).write(to: URL(fileURLWithPath: ".grantiva/captures/android/Home.png"))

                try await DiffCommand.ApproveCommand.parse([]).run()

                XCTAssertTrue(FileManager.default.fileExists(atPath: ".grantiva/baselines/android/Home.png"))
                XCTAssertFalse(FileManager.default.fileExists(atPath: ".grantiva/baselines/Home.png"))
            }
        }
    }
}
