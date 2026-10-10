import Foundation
import XCTest
@testable import GrantivaCore

final class PlatformResolverTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func touch(_ name: String, directory: Bool = false) throws {
        let url = dir.appendingPathComponent(name)
        if directory {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } else {
            try "".write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func resolver(env: [String: String] = [:]) -> PlatformResolver {
        PlatformResolver(directory: dir, environment: env)
    }

    func testFlagWinsOverEverything() throws {
        try touch("grantiva.yml")
        XCTAssertEqual(try resolver(env: ["GRANTIVA_PLATFORM": "ios"]).resolve(flag: .android), .android)
        XCTAssertEqual(try resolver().resolve(flag: .android), .android)
    }

    func testEnvironmentWinsOverFiles() throws {
        try touch("grantiva.yml")
        XCTAssertEqual(try resolver(env: ["GRANTIVA_PLATFORM": "android"]).resolve(flag: nil), .android)
        XCTAssertEqual(try resolver(env: ["GRANTIVA_PLATFORM": "android\n"]).resolve(flag: nil), .android)
    }

    func testInvalidEnvironmentValueIsAnError() throws {
        XCTAssertThrowsError(try resolver(env: ["GRANTIVA_PLATFORM": "windows"]).resolve(flag: nil)) { error in
            XCTAssertTrue("\(error)".contains("GRANTIVA_PLATFORM"))
        }
    }

    func testSingleConfigFilePicksItsPlatform() throws {
        try touch("grantiva-android.yml")
        XCTAssertEqual(try resolver().resolve(flag: nil), .android)
        try touch("grantiva.yml")
        try FileManager.default.removeItem(at: dir.appendingPathComponent("grantiva-android.yml"))
        XCTAssertEqual(try resolver().resolve(flag: nil), .ios)
    }

    func testBothConfigFilesRequireTheFlag() throws {
        try touch("grantiva.yml")
        try touch("grantiva-android.yml")
        XCTAssertThrowsError(try resolver().resolve(flag: nil)) { error in
            XCTAssertTrue("\(error)".contains("--platform"))
        }
    }

    func testFlagWithoutAnyConfigIsAccepted() throws {
        XCTAssertEqual(try resolver().resolve(flag: .android), .android)
    }

    func testDirectoryDetectionIOS() throws {
        try touch("Demo.xcodeproj", directory: true)
        XCTAssertEqual(try resolver().resolve(flag: nil), .ios)
    }

    func testDirectoryDetectionAndroid() throws {
        try touch("settings.gradle.kts")
        XCTAssertEqual(try resolver().resolve(flag: nil), .android)
    }

    func testBothProjectKindsRequireTheFlag() throws {
        try touch("Demo.xcworkspace", directory: true)
        try touch("settings.gradle")
        XCTAssertThrowsError(try resolver().resolve(flag: nil)) { error in
            XCTAssertTrue("\(error)".contains("--platform"))
        }
    }

    func testMaestroDirectoryCountsAsConfigButNotAsPlatform() throws {
        try touch(".maestro", directory: true)
        try touch("settings.gradle")
        XCTAssertEqual(try resolver().resolve(flag: nil), .android)
    }

    func testNothingFoundMentionsBothPlatforms() throws {
        XCTAssertThrowsError(try resolver().resolve(flag: nil)) { error in
            let text = "\(error)"
            XCTAssertTrue(text.contains("grantiva.yml") && text.contains("grantiva-android.yml"), text)
        }
    }

    func testResolveOrDefaultFallsBackToIOSWhenNothingPointsAnywhere() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("resolver-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let resolver = PlatformResolver(directory: dir, environment: [:])
        XCTAssertEqual(try resolver.resolveOrDefault(flag: nil), .ios)
        XCTAssertThrowsError(try resolver.resolve(flag: nil))
        try "platform: android\n".write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        XCTAssertEqual(try resolver.resolveOrDefault(flag: nil), .android)
    }

    func testEnvironmentPlatform() throws {
        XCTAssertNil(try PlatformResolver(environment: [:]).environmentPlatform())
        XCTAssertNil(try PlatformResolver(environment: ["GRANTIVA_PLATFORM": ""]).environmentPlatform())
        XCTAssertEqual(try PlatformResolver(environment: ["GRANTIVA_PLATFORM": " Android "]).environmentPlatform(), .android)
        XCTAssertThrowsError(try PlatformResolver(environment: ["GRANTIVA_PLATFORM": "windows"]).environmentPlatform()) { error in
            XCTAssertTrue(error.localizedDescription.contains("GRANTIVA_PLATFORM is \"windows\"; expected ios or android."), "\(error)")
        }
    }
}
