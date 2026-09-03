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

    func testDetectionFailureIsPropagatedAfterCacheMiss() async {
        do {
            _ = try await ResolvedProject.resolve(detector: .failing, loadCache: { nil }, saveCache: { _ in })
            XCTFail("expected failure")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("ProjectDetector.failing"))
        }
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value
    init(_ value: Value = nil) where Value: ExpressibleByNilLiteral { storage = value }
    func set(_ value: Value) { lock.withLock { storage = value } }
    var value: Value { lock.withLock { storage } }
}
