import Foundation
import XCTest
@testable import GrantivaCore

final class ProjectResolutionTests: XCTestCase {
    func testProjectSlugParsesCommonRemoteFormats() {
        XCTAssertEqual(ProjectIdentifier.parseSlug(from: "https://github.com/grantiva/cli.git\n"), "grantiva/cli")
        XCTAssertEqual(ProjectIdentifier.parseSlug(from: "git@github.com:grantiva/cli.git"), "grantiva/cli")
        XCTAssertEqual(ProjectIdentifier.parseSlug(from: "ssh://git@github.com/grantiva/cli.git"), "grantiva/cli")
        XCTAssertEqual(ProjectIdentifier.parseSlug(from: "local-repository"), "local-repository")
    }

    func testFlagsAndConfigOverrideBinaryAndDetection() async throws {
        let config = GrantivaConfig(scheme: "ConfigScheme", workspace: "Config.xcworkspace", project: "Config.xcodeproj", simulator: "Config Phone", bundleId: "com.config", buildSettings: ["A=B"])
        let detected = DetectedProject(scheme: "Detected", project: "Detected.xcodeproj", workspace: "Detected.xcworkspace", bundleId: "com.detected")
        let result = try await ResolvedProject.resolve(
            schemeFlag: "FlagScheme", simulatorFlag: "Flag Phone", bundleIdFlag: "com.flag",
            config: config, detector: .failing, loadCache: { detected }, saveCache: { _ in },
            appBundleId: "com.binary"
        )
        XCTAssertEqual(result.scheme, "FlagScheme")
        XCTAssertEqual(result.bundleId, "com.flag")
        XCTAssertEqual(result.simulator, "Flag Phone")
        XCTAssertEqual(result.workspace, "Config.xcworkspace")
        XCTAssertEqual(result.project, "Config.xcodeproj")
        XCTAssertEqual(result.buildSettings, ["A=B"])
    }

    func testBinaryBundleIdPrecedesDetectedBundleId() async throws {
        let detected = DetectedProject(scheme: "Detected", bundleId: "com.detected")
        let result = try await ResolvedProject.resolve(
            loadCache: { detected }, saveCache: { _ in }, appBundleId: "com.binary"
        )
        XCTAssertEqual(result.scheme, "Detected")
        XCTAssertEqual(result.bundleId, "com.binary")
    }

    func testDetectionRunsAndSavesWhenCacheMisses() async throws {
        let saved = LockedValue<DetectedProject?>()
        let detector = ProjectDetector { DetectedProject(scheme: "Live", project: "Live.xcodeproj", bundleId: "com.live") }
        let result = try await ResolvedProject.resolve(
            detector: detector, loadCache: { nil }, saveCache: { saved.set($0) }
        )
        XCTAssertEqual(result.scheme, "Live")
        XCTAssertEqual(result.bundleId, "com.live")
        XCTAssertEqual(saved.value?.scheme, "Live")
    }

    func testSkipBuildAvoidsDetectionAndAllowsMissingScheme() async throws {
        let result = try await ResolvedProject.resolve(
            detector: .failing, loadCache: { XCTFail("cache should not be read"); return nil },
            saveCache: { _ in XCTFail("cache should not be written") }, skipBuild: true,
            appBundleId: "com.binary"
        )
        XCTAssertNil(result.scheme)
        XCTAssertEqual(result.bundleId, "com.binary")
    }

    func testSeveralDetectedSchemesAndNoneConfiguredIsAnErrorListingThem() async {
        let detector = ProjectDetector {
            DetectedProject(scheme: "Landmarks", schemes: ["Landmarks", "Landmarks (UI Testing)"], project: "Landmarks.xcodeproj")
        }
        do {
            _ = try await ResolvedProject.resolve(detector: detector, loadCache: { nil }, saveCache: { _ in })
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                "Invalid argument: No scheme specified. Pass --scheme, set it in grantiva.yml, or use --app-file to provide a pre-built binary. Found: Landmarks, Landmarks (UI Testing)."
            )
        }
    }

    func testACachedDetectionWithSeveralSchemesDoesNotPickOne() async {
        let cached = DetectedProject(scheme: "Landmarks", schemes: ["Landmarks", "Landmarks (UI Testing)"])
        do {
            _ = try await ResolvedProject.resolve(detector: .failing, loadCache: { cached }, saveCache: { _ in })
            XCTFail("expected failure")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Found: Landmarks, Landmarks (UI Testing)"), error.localizedDescription)
        }
    }

    func testALegacyCacheWithoutTheSchemeListIsReDetected() async {
        var stale = DetectedProject(scheme: "Landmarks")
        stale.schemes = nil
        let legacy = stale
        let detector = ProjectDetector {
            DetectedProject(scheme: "Landmarks", schemes: ["Landmarks", "Landmarks (UI Testing)"])
        }
        do {
            _ = try await ResolvedProject.resolve(detector: detector, loadCache: { legacy }, saveCache: { _ in })
            XCTFail("expected failure")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Found: Landmarks, Landmarks (UI Testing)"), error.localizedDescription)
        }
    }

    func testOneDetectedSchemeStillResolvesSilently() async throws {
        let detector = ProjectDetector { DetectedProject(scheme: "Only", schemes: ["Only"]) }
        let result = try await ResolvedProject.resolve(detector: detector, loadCache: { nil }, saveCache: { _ in })
        XCTAssertEqual(result.scheme, "Only")
    }

    func testAnExplicitSchemeWinsOverSeveralDetectedOnes() async throws {
        let cached = DetectedProject(scheme: "Landmarks", schemes: ["Landmarks", "Landmarks (UI Testing)"], bundleId: "com.x")
        let result = try await ResolvedProject.resolve(
            schemeFlag: "Landmarks (UI Testing)", detector: .failing, loadCache: { cached }, saveCache: { _ in }
        )
        XCTAssertEqual(result.scheme, "Landmarks (UI Testing)")
    }

    func testDetectionFailureIsPropagatedAfterCacheMiss() async {
        do {
            _ = try await ResolvedProject.resolve(detector: .failing, loadCache: { nil }, saveCache: { _ in })
            XCTFail("expected failure")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("ProjectDetector.failing"))
        }
    }

    /// K71: `build build` has no --app-file, so its advice does not offer it.
    func testTheNoSchemeAdviceOffersAppFileOnlyToCommandsThatTakeIt() async {
        let detector = ProjectDetector { DetectedProject(scheme: "A", schemes: ["A", "B"]) }
        for acceptsAppFile in [false, true] {
            do {
                _ = try await ResolvedProject.resolve(detector: detector, loadCache: { nil }, saveCache: { _ in }, acceptsAppFile: acceptsAppFile)
                XCTFail("expected failure")
            } catch {
                let message = error.localizedDescription
                XCTAssertEqual(message.contains("--app-file"), acceptsAppFile, message)
                XCTAssertTrue(message.contains("Pass --scheme"), message)
                XCTAssertTrue(message.hasSuffix("Found: A, B."), message)
            }
        }
        XCTAssertEqual(ResolvedProject.noSchemeMessage(acceptsAppFile: false), "No scheme specified. Pass --scheme or set it in grantiva.yml.")
    }

    /// K72: a cache recorded when the project had one scheme cannot supply
    /// it once a second scheme file appears.
    func testACachedSingleSchemeIsDroppedWhenTheProjectGainsASecond() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("k72-\(UUID().uuidString)", isDirectory: true)
        let schemes = root.appendingPathComponent("App.xcodeproj/xcshareddata/xcschemes", isDirectory: true)
        try fm.createDirectory(at: schemes, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        try "<Scheme/>".write(to: schemes.appendingPathComponent("A.xcscheme"), atomically: true, encoding: .utf8)
        let past = Date().addingTimeInterval(-120)
        for path in ProjectDetector.schemeStatePaths(container: root.appendingPathComponent("App.xcodeproj")) where fm.fileExists(atPath: path) {
            try fm.setAttributes([.modificationDate: past], ofItemAtPath: path)
        }
        let cacheURL = root.appendingPathComponent(".grantiva/config.json")
        try ProjectDetector.writeCache(DetectedProject(scheme: "A", schemes: ["A"]), cacheURL: cacheURL)
        try fm.setAttributes([.modificationDate: Date().addingTimeInterval(-60)], ofItemAtPath: cacheURL.path)
        XCTAssertEqual(ProjectDetector.loadCache(cacheURL: cacheURL, projectDirectory: root)?.scheme, "A", "unchanged project: cache holds")

        try "<Scheme/>".write(to: schemes.appendingPathComponent("B.xcscheme"), atomically: true, encoding: .utf8)
        let detector = ProjectDetector { DetectedProject(scheme: "A", schemes: ["A", "B"]) }
        do {
            _ = try await ResolvedProject.resolve(
                detector: detector,
                loadCache: { ProjectDetector.loadCache(cacheURL: cacheURL, projectDirectory: root) },
                saveCache: { _ in }
            )
            XCTFail("expected the no-scheme error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("No scheme specified"), error.localizedDescription)
            XCTAssertTrue(error.localizedDescription.contains("Found: A, B."), error.localizedDescription)
        }
    }

    func testAWorkspaceCoversTheSchemeDirectoriesOfTheProjectsItReferences() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("k72ws-\(UUID().uuidString)", isDirectory: true)
        let workspace = root.appendingPathComponent("App.xcworkspace", isDirectory: true)
        try fm.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let elsewhere = fm.temporaryDirectory.appendingPathComponent("k72abs-\(UUID().uuidString)/Other.xcodeproj").path
        try #"<Workspace version = "1.0"><FileRef location = "group:Sub/App.xcodeproj"></FileRef><FileRef location = "absolute:\#(elsewhere)"></FileRef></Workspace>"#
            .write(to: workspace.appendingPathComponent("contents.xcworkspacedata"), atomically: true, encoding: .utf8)
        let paths = ProjectDetector.schemeStatePaths(container: workspace)
        XCTAssertTrue(paths.contains(root.appendingPathComponent("Sub/App.xcodeproj/xcshareddata/xcschemes").path), "\(paths)")
        XCTAssertTrue(paths.contains(elsewhere + "/xcshareddata/xcschemes"), "\(paths)")
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value
    init(_ value: Value = nil) where Value: ExpressibleByNilLiteral { storage = value }
    func set(_ value: Value) { lock.withLock { storage = value } }
    var value: Value { lock.withLock { storage } }
}
