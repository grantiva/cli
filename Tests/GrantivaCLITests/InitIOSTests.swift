import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class InitIOSTests: XCTestCase {
    private let placeholderScheme = "No Xcode project found; scheme \"MyApp\" is a placeholder. Edit grantiva.yml or pass --scheme."

    func testAnEmptyDirectoryWarnsThatTheSchemeIsAPlaceholder() {
        let (yaml, warnings) = InitCommand.iosTemplate(scheme: nil, detectedScheme: nil, bundleId: nil, newestIPhone: "iPhone 17")
        XCTAssertEqual(warnings, [placeholderScheme])
        XCTAssertTrue(yaml.contains("scheme: MyApp\n"), yaml)
        XCTAssertTrue(yaml.contains("simulator: iPhone 17\n"), yaml)
    }

    func testASchemeFlagOrADetectedSchemeIsNotAPlaceholder() {
        XCTAssertEqual(InitCommand.iosTemplate(scheme: "X", detectedScheme: nil, bundleId: nil, newestIPhone: "iPhone 17").warnings, [])
        XCTAssertEqual(InitCommand.iosTemplate(scheme: nil, detectedScheme: "Landmarks", bundleId: nil, newestIPhone: "iPhone 17").warnings, [])
    }

    func testTheSimulatorIsMarkedAsAPlaceholderWhenNoIPhoneTypeIsInstalled() {
        let (yaml, warnings) = InitCommand.iosTemplate(scheme: "X", detectedScheme: nil, bundleId: nil, newestIPhone: nil)
        XCTAssertTrue(yaml.contains("simulator: iPhone 17 Pro\n"), yaml)
        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(warnings[0].contains("simulator \"iPhone 17 Pro\" is a placeholder"), warnings[0])
    }

    func testTheGeneratedFileStillLoads() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("init-ios-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let (yaml, _) = InitCommand.iosTemplate(scheme: "Demo", detectedScheme: nil, bundleId: "com.example.demo", newestIPhone: "iPhone 17")
        try yaml.write(to: dir.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
        let config = try GrantivaConfig.load(platform: .ios, from: dir)
        XCTAssertEqual(config.scheme, "Demo")
        XCTAssertEqual(config.simulator, "iPhone 17")
        XCTAssertEqual(config.bundleId, "com.example.demo")
    }
}
