import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class InitIOSTests: XCTestCase {
    private let placeholderScheme = "No Xcode project found; scheme \"MyApp\" is a placeholder. Edit grantiva.yml or pass --scheme."

    func testAnEmptyDirectoryWarnsThatTheSchemeIsAPlaceholder() {
        let (yaml, warnings) = InitCommand.iosTemplate(scheme: nil, detected: nil, bundleId: nil, newestIPhone: "iPhone 17")
        XCTAssertEqual(warnings, [placeholderScheme])
        XCTAssertTrue(yaml.contains("scheme: MyApp\n"), yaml)
        XCTAssertTrue(yaml.contains("simulator: iPhone 17\n"), yaml)
    }

    func testASchemeFlagOrADetectedSchemeIsNotAPlaceholder() {
        XCTAssertEqual(InitCommand.iosTemplate(scheme: "X", detected: nil, bundleId: nil, newestIPhone: "iPhone 17").warnings, [])
        XCTAssertEqual(InitCommand.iosTemplate(scheme: nil, detected: .init(container: "Landmarks", schemes: ["Landmarks"]), bundleId: nil, newestIPhone: "iPhone 17").warnings, [])
    }

    func testTheSimulatorIsMarkedAsAPlaceholderWhenNoIPhoneTypeIsInstalled() {
        let (yaml, warnings) = InitCommand.iosTemplate(scheme: "X", detected: nil, bundleId: nil, newestIPhone: nil)
        XCTAssertTrue(yaml.contains("simulator: iPhone 17 Pro\n"), yaml)
        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(warnings[0].contains("simulator \"iPhone 17 Pro\" is a placeholder"), warnings[0])
    }

    func testTheGeneratedFileStillLoads() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("init-ios-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let (yaml, _) = InitCommand.iosTemplate(scheme: "Demo", detected: nil, bundleId: "com.example.demo", newestIPhone: "iPhone 17")
        try yaml.write(to: dir.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
        let config = try GrantivaConfig.load(platform: .ios, from: dir)
        XCTAssertEqual(config.scheme, "Demo")
        XCTAssertEqual(config.simulator, "iPhone 17")
        XCTAssertEqual(config.bundleId, "com.example.demo")
    }

    /// K38: several shared schemes are never guessed silently.
    func testSeveralSchemesWriteNoGuessAndWarnNamingThem() throws {
        let detected = InitCommand.DetectedSchemes(container: "Landmarks", schemes: ["Landmarks", "Landmarks (UI Testing)"])
        let (yaml, warnings) = InitCommand.iosTemplate(scheme: nil, detected: detected, bundleId: nil, newestIPhone: "iPhone 17")
        XCTAssertEqual(warnings, ["Several schemes found: Landmarks, Landmarks (UI Testing). Set scheme in grantiva.yml or pass --scheme."])
        XCTAssertFalse(yaml.contains("\nscheme:"), yaml)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("init-k38-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try yaml.write(to: dir.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
        let config = try GrantivaConfig.load(platform: .ios, from: dir)
        XCTAssertNil(config.scheme, "run then reports the same ambiguity instead of building a guess")
    }

    func testAnExplicitSchemeIsWrittenSilentlyEvenWithSeveralDetected() {
        let detected = InitCommand.DetectedSchemes(container: "Landmarks", schemes: ["Landmarks", "Landmarks (UI Testing)"])
        let (yaml, warnings) = InitCommand.iosTemplate(scheme: "Landmarks (UI Testing)", detected: detected, bundleId: nil, newestIPhone: "iPhone 17")
        XCTAssertEqual(warnings, [])
        XCTAssertTrue(yaml.contains("scheme: Landmarks (UI Testing)\n"), yaml)
    }

    func testOneSchemeIsWrittenWithNoWarning() {
        let detected = InitCommand.DetectedSchemes(container: "App", schemes: ["App Scheme"])
        let (yaml, warnings) = InitCommand.iosTemplate(scheme: nil, detected: detected, bundleId: nil, newestIPhone: "iPhone 17")
        XCTAssertEqual(warnings, [])
        XCTAssertTrue(yaml.contains("\nscheme: App Scheme\n"), yaml)
    }
}
