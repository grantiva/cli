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
            XCTAssertTrue(error.localizedDescription.contains("No capture found for \"Missing\""))
        }
    }

    // MARK: - I02: --no-build device resolution

    /// Two booted devices and config `simulator: B`: the --no-build path uses B, never the platform default.
    func testNoBuildUsesConfiguredSimulatorNotFirstBooted() async throws {
        let fake = FakeDevicePlatform(platform: .ios)
        fake.bootedID = "B-UDID"; fake.bootedName = "B"
        let booted = try await DiffCommand.noBuildDevice(
            platform: .ios, explicit: nil, config: GrantivaConfig(simulator: "B"), sessionUDID: "SESSION-UDID", device: fake
        )
        XCTAssertEqual(booted.udid, "B-UDID")
        XCTAssertEqual(fake.calls, ["bootDevice(B)"])
    }

    func testNoBuildFlagWinsOverConfigAndSession() async throws {
        let fake = FakeDevicePlatform(platform: .ios)
        _ = try await DiffCommand.noBuildDevice(
            platform: .ios, explicit: "A", config: GrantivaConfig(simulator: "B"), sessionUDID: "SESSION-UDID", device: fake
        )
        XCTAssertEqual(fake.calls, ["bootDevice(A)"])
    }

    func testNoBuildFallsBackToTheRunnerSessionDevice() async throws {
        let fake = FakeDevicePlatform(platform: .ios)
        _ = try await DiffCommand.noBuildDevice(
            platform: .ios, explicit: nil, config: GrantivaConfig(), sessionUDID: "SESSION-UDID", device: fake
        )
        XCTAssertEqual(fake.calls, ["bootDevice(SESSION-UDID)"])
    }

    func testNoBuildUsesThePlatformDefaultOnlyWhenNothingIsNamed() async throws {
        let fake = FakeDevicePlatform(platform: .ios)
        _ = try await DiffCommand.noBuildDevice(platform: .ios, explicit: nil, config: nil, sessionUDID: nil, device: fake)
        XCTAssertEqual(fake.calls, ["defaultDevice"])
    }

    func testNoBuildOnAndroidHonoursTheConfiguredEmulator() async throws {
        let fake = FakeDevicePlatform(platform: .android)
        let config = GrantivaConfig(android: AndroidProject(emulator: "Pixel_8_API_35"))
        _ = try await DiffCommand.noBuildDevice(platform: .android, explicit: nil, config: config, sessionUDID: nil, device: fake)
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
