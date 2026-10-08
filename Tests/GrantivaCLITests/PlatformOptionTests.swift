import ArgumentParser
import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class PlatformOptionTests: XCTestCase {
    func testPlatformFlagParsesBothValues() throws {
        XCTAssertEqual(try PlatformOptions.parse(["--platform", "ios"]).platform, .ios)
        XCTAssertEqual(try PlatformOptions.parse(["--platform", "android"]).platform, .android)
        XCTAssertThrowsError(try PlatformOptions.parse(["--platform", "web"]))
    }

    func testLoadConfigIsLoudOnMalformedFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "scheme: [oops\n".write(to: dir.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
        let options = try PlatformOptions.parse([])
        XCTAssertThrowsError(try options.loadConfig(directory: dir, environment: [:])) { error in
            XCTAssertTrue("\(error)".contains("grantiva.yml"), "\(error)")
        }
    }

    func testLoadConfigWithNoFilesInAnXcodeDirectoryIsIOSWithNilConfig() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("Demo.xcodeproj"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let (platform, config) = try PlatformOptions.parse([]).loadConfig(directory: dir, environment: [:])
        XCTAssertEqual(platform, .ios)
        XCTAssertNil(config)
    }

    /// Before platforms existed every command was iOS and ran without any
    /// project file (e.g. `--app-file` + `--bundle-id`, or `diff compare`).
    /// A directory with nothing to detect keeps that behavior.
    func testLoadConfigInAnEmptyDirectoryFallsBackToIOS() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let (platform, config) = try PlatformOptions.parse([]).loadConfig(directory: dir, environment: [:])
        XCTAssertEqual(platform, .ios)
        XCTAssertNil(config)
    }

    func testEnvironmentPlatformWithoutConfigThrowsWhenOtherConfigExists() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "scheme: Demo\n".write(to: dir.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
        let options = try PlatformOptions.parse([])
        XCTAssertThrowsError(try options.loadConfig(directory: dir, environment: ["GRANTIVA_PLATFORM": "android"])) { error in
            XCTAssertTrue("\(error)".contains("GRANTIVA_PLATFORM=android"), "\(error)")
            XCTAssertTrue("\(error)".contains("grantiva-android.yml"), "\(error)")
        }
    }

    func testExplicitFlagForPlatformWithoutConfigThrowsWhenOtherConfigExists() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "scheme: Demo\n".write(to: dir.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
        let options = try PlatformOptions.parse(["--platform", "android"])
        XCTAssertThrowsError(try options.loadConfig(directory: dir, environment: [:])) { error in
            XCTAssertTrue("\(error)".contains("grantiva-android.yml"), "\(error)")
        }
    }
}
