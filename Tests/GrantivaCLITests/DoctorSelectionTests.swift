import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class DoctorSelectionTests: XCTestCase {
    func testSelectionFollowsFlagEnvConfigDirectoryThenBoth() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var selection = DoctorCommand.platformSelection(flag: .android, directory: dir, environment: [:])
        XCTAssertEqual(selection.platforms, [.android]); XCTAssertTrue(selection.required)

        selection = DoctorCommand.platformSelection(flag: nil, directory: dir, environment: ["GRANTIVA_PLATFORM": "ios"])
        XCTAssertEqual(selection.platforms, [.ios]); XCTAssertTrue(selection.required)

        selection = DoctorCommand.platformSelection(flag: nil, directory: dir, environment: [:])
        XCTAssertEqual(selection.platforms, [.ios, .android]); XCTAssertFalse(selection.required)

        try "".write(to: dir.appendingPathComponent("settings.gradle"), atomically: true, encoding: .utf8)
        selection = DoctorCommand.platformSelection(flag: nil, directory: dir, environment: [:])
        XCTAssertEqual(selection.platforms, [.android]); XCTAssertTrue(selection.required)

        try "".write(to: dir.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
        selection = DoctorCommand.platformSelection(flag: nil, directory: dir, environment: [:])
        XCTAssertEqual(selection.platforms, [.ios]); XCTAssertTrue(selection.required, "a config file beats directory detection")

        try "".write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        selection = DoctorCommand.platformSelection(flag: nil, directory: dir, environment: [:])
        XCTAssertEqual(selection.platforms, [.ios, .android]); XCTAssertTrue(selection.required, "both configs: both toolchains are required")
    }
}
