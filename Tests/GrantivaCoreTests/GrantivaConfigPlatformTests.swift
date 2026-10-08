import Foundation
import XCTest
@testable import GrantivaCore

final class GrantivaConfigPlatformTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func write(_ name: String, _ contents: String) throws {
        try contents.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    func testAndroidFileDecodesAndroidKeysWithDefaults() throws {
        try write("grantiva-android.yml", """
            application_id: com.example.demo
            emulator: Pixel_8_API_35
            screens:
              - name: Home
                path: launch
            """)
        let config = try GrantivaConfig.load(platform: .android, from: dir)
        XCTAssertEqual(config.platform, .android)
        let android = try XCTUnwrap(config.android)
        XCTAssertEqual(android.module, "app")
        XCTAssertEqual(android.variant, "debug")
        XCTAssertEqual(android.applicationId, "com.example.demo")
        XCTAssertEqual(android.emulator, "Pixel_8_API_35")
        XCTAssertEqual(android.buildArgs, [])
        XCTAssertEqual(config.screens.count, 1)
        XCTAssertNil(config.scheme)
    }

    func testAndroidFileHonoursExplicitKeys() throws {
        try write("grantiva-android.yml", """
            platform: android
            module: mobile
            variant: freeDebug
            system_image: "system-images;android-35;google_apis;arm64-v8a"
            build_args: ["-PfastBuild=true"]
            """)
        let android = try XCTUnwrap(try GrantivaConfig.load(platform: .android, from: dir).android)
        XCTAssertEqual(android.module, "mobile")
        XCTAssertEqual(android.variant, "freeDebug")
        XCTAssertEqual(android.systemImage, "system-images;android-35;google_apis;arm64-v8a")
        XCTAssertEqual(android.buildArgs, ["-PfastBuild=true"])
    }

    func testAndroidFileWithIOSPlatformKeyIsRejected() throws {
        try write("grantiva-android.yml", "platform: ios\n")
        XCTAssertThrowsError(try GrantivaConfig.load(platform: .android, from: dir)) { error in
            XCTAssertTrue("\(error)".contains("platform: ios"), "\(error)")
        }
    }

    func testIOSFileStillLoadsThroughTheOldEntryPoint() throws {
        try write("grantiva.yml", "scheme: Demo\nsimulator: iPhone 16\n")
        let config = try GrantivaConfig.load(from: dir)
        XCTAssertEqual(config.platform, .ios)
        XCTAssertEqual(config.scheme, "Demo")
        XCTAssertNil(config.android)
    }

    func testMalformedYAMLIsReportedWithTheParserMessage() throws {
        try write("grantiva.yml", "scheme: Demo\nscreens:\n  - name: Home\n   path: launch\n")
        XCTAssertThrowsError(try GrantivaConfig.load(platform: .ios, from: dir)) { error in
            let text = "\(error)"
            XCTAssertTrue(text.contains("grantiva.yml"), text)
            XCTAssertTrue(text.contains("line") || text.contains("Line"), text)
        }
    }

    func testLoadIfPresentReturnsNilOnlyWhenNoFileExists() throws {
        XCTAssertNil(try GrantivaConfig.loadIfPresent(platform: .android, from: dir))
        try write("grantiva-android.yml", "module: [unclosed\n")
        XCTAssertThrowsError(try GrantivaConfig.loadIfPresent(platform: .android, from: dir))
    }

    func testAndroidLoadDoesNotFallBackToMaestroDirectory() throws {
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(".maestro"), withIntermediateDirectories: true)
        XCTAssertNil(try GrantivaConfig.loadIfPresent(platform: .android, from: dir))
    }
}
