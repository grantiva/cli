import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class DoctorSelectionTests: XCTestCase {
    func testSelectionFollowsFlagEnvConfigDirectoryThenBoth() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var selection = try DoctorCommand.platformSelection(flag: .android, directory: dir, environment: [:])
        XCTAssertEqual(selection.platforms, [.android]); XCTAssertTrue(selection.required)

        selection = try DoctorCommand.platformSelection(flag: nil, directory: dir, environment: ["GRANTIVA_PLATFORM": "ios"])
        XCTAssertEqual(selection.platforms, [.ios]); XCTAssertTrue(selection.required)

        selection = try DoctorCommand.platformSelection(flag: nil, directory: dir, environment: [:])
        XCTAssertEqual(selection.platforms, [.ios, .android]); XCTAssertFalse(selection.required)

        try "".write(to: dir.appendingPathComponent("settings.gradle"), atomically: true, encoding: .utf8)
        selection = try DoctorCommand.platformSelection(flag: nil, directory: dir, environment: [:])
        XCTAssertEqual(selection.platforms, [.android]); XCTAssertTrue(selection.required)

        try "".write(to: dir.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
        selection = try DoctorCommand.platformSelection(flag: nil, directory: dir, environment: [:])
        XCTAssertEqual(selection.platforms, [.ios]); XCTAssertTrue(selection.required, "a config file beats directory detection")

        try "".write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        selection = try DoctorCommand.platformSelection(flag: nil, directory: dir, environment: [:])
        XCTAssertEqual(selection.platforms, [.ios, .android]); XCTAssertTrue(selection.required, "both configs: both toolchains are required")
    }

    func testAnInvalidEnvironmentPlatformIsAnErrorLikeRun() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        XCTAssertThrowsError(try DoctorCommand.platformSelection(flag: nil, directory: dir, environment: ["GRANTIVA_PLATFORM": "windows"])) { error in
            XCTAssertTrue("\(error.localizedDescription)".contains("GRANTIVA_PLATFORM is \"windows\"; expected ios or android."), "\(error)")
        }
        // The flag still wins over a bad environment value, as in `run`.
        XCTAssertEqual(try DoctorCommand.platformSelection(flag: .ios, directory: dir, environment: ["GRANTIVA_PLATFORM": "windows"]).platforms, [.ios])
    }

    func testBothProjectsDetectedWithoutAFlagIsAdviceNotAFailure() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("App.xcodeproj"), withIntermediateDirectories: true)
        try "".write(to: dir.appendingPathComponent("settings.gradle.kts"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: dir) }

        let selection = try DoctorCommand.platformSelection(flag: nil, directory: dir, environment: [:])
        XCTAssertEqual(selection.platforms, [.ios, .android])
        XCTAssertFalse(selection.required, "an ambiguous root is diagnosed, not failed")
        let advice = try XCTUnwrap(selection.advice)
        XCTAssertEqual(advice.status, .warning)
        XCTAssertEqual(advice.message, "Found both an Xcode project and Gradle settings")
        XCTAssertEqual(advice.fix, "Pass --platform ios|android or set GRANTIVA_PLATFORM.")
        XCTAssertFalse(DoctorRunner.hasFailures([advice]))
        XCTAssertNil(try DoctorCommand.platformSelection(flag: .ios, directory: dir, environment: [:]).advice)
        XCTAssertEqual(try DoctorCommand.platformSelection(flag: nil, directory: dir, environment: ["GRANTIVA_PLATFORM": "android"]).platforms, [.android])
    }
}
