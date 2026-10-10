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

    func testEmptyIOSFileLoadsAsDefaults() throws {
        try write("grantiva.yml", "")
        let config = try GrantivaConfig.load(platform: .ios, from: dir)
        XCTAssertEqual(config.platform, .ios)
        XCTAssertTrue(config.screens.isEmpty)
        XCTAssertNil(config.android)
    }

    func testWhitespaceOnlyIOSFileLoadsAsDefaults() throws {
        try write("grantiva.yml", "   \n\n")
        let config = try GrantivaConfig.load(platform: .ios, from: dir)
        XCTAssertEqual(config.platform, .ios)
        XCTAssertTrue(config.screens.isEmpty)
    }

    func testCommentsOnlyAndroidFileLoadsAsDefaults() throws {
        try write("grantiva-android.yml", "# just a comment\n")
        let config = try GrantivaConfig.load(platform: .android, from: dir)
        XCTAssertEqual(config.platform, .android)
        XCTAssertEqual(config.android?.module, "app")
        XCTAssertTrue(config.screens.isEmpty)
    }

    func testMaestroFormatParseErrorNamesTheFile() throws {
        try write("grantiva.yml", "appId: com.example.demo\n---\n- launchApp\n- tapOn: [unclosed\n")
        XCTAssertThrowsError(try GrantivaConfig.load(platform: .ios, from: dir)) { error in
            XCTAssertTrue("\(error)".contains("grantiva.yml could not be parsed"), "\(error)")
        }
    }

    func testMultiDocumentMaestroFileStillLoads() throws {
        try write("grantiva.yml", "appId: com.example.demo\n---\n- launchApp\n- takeScreenshot: Home\n")
        let config = try GrantivaConfig.load(platform: .ios, from: dir)
        XCTAssertEqual(config.bundleId, "com.example.demo")
        XCTAssertEqual(config.platform, .ios)
    }

    // C19: unknown keys are reported with their line, and the load still succeeds.
    func testUnknownKeysYieldDiagnosticsWithLineNumbers() throws {
        try write("grantiva.yml", """
            schem: Landmarks
            simulator: qa-cli-1
            bundle_id: com.kylebrowning.Landmarks
            screen:
              - name: Home
                path: launch
            """)
        let config = try GrantivaConfig.load(platform: .ios, from: dir)
        XCTAssertEqual(config.warnings, [
            #"grantiva.yml:1: unknown key "schem" (did you mean "scheme"?)"#,
            #"grantiva.yml:4: unknown key "screen" (did you mean "screens"?)"#,
        ])
        XCTAssertEqual(config.bundleId, "com.kylebrowning.Landmarks")
    }

    func testUnknownNestedKeysAreReported() throws {
        try write("grantiva-android.yml", """
            application_id: com.example
            modul: app
            screens:
              - name: Home
                path: launch
                titel: Home
              - name: Tab
                path:
                  - tpa: "Lakes"
                  - tap: {text: "Landmarks", exakt: true}
            diff:
              threshold: 0.1
              perceptual_threshold: 3
              tolerance: 1
            """)
        let config = try GrantivaConfig.load(platform: .android, from: dir)
        XCTAssertEqual(config.warnings, [
            #"grantiva-android.yml:2: unknown key "modul" (did you mean "module"?)"#,
            #"grantiva-android.yml:14: unknown key "tolerance""#,
            #"grantiva-android.yml:6: unknown key "titel""#,
            #"grantiva-android.yml:9: unknown key "tpa" (did you mean "tap"?)"#,
            #"grantiva-android.yml:10: unknown key "exakt" (did you mean "exact"?)"#,
        ])
    }

    func testUnknownKeysAreAttachedToADecodingError() throws {
        try write("grantiva.yml", """
            screens:
              - name: Home
                pth: launch
            """)
        XCTAssertThrowsError(try GrantivaConfig.load(platform: .ios, from: dir)) { error in
            XCTAssertTrue(
                error.localizedDescription.contains(#"grantiva.yml:3: unknown key "pth" (did you mean "path"?)"#),
                error.localizedDescription
            )
        }
    }

    func testKnownKeysProduceNoWarnings() throws {
        try write("grantiva.yml", """
            scheme: App
            workspace: App.xcworkspace
            project: App.xcodeproj
            simulator: iPhone 17
            bundle_id: com.example
            build_settings: ["A=1"]
            platform: ios
            flows: []
            screens:
              - name: Home
                path:
                  - tap: {text: "Go", exact: true}
                  - swipe: up
                  - type: "x"
                  - wait: 1
                  - assert_visible: "Go"
                  - assert_not_visible: "No"
                  - run_flow: "f.yaml"
            diff:
              threshold: 0.02
              perceptual_threshold: 5
            a11y:
              rules: [missing_label]
            """)
        XCTAssertEqual(try GrantivaConfig.load(platform: .ios, from: dir).warnings, [])
    }

    func testMaestroFormatFilesAreNotCheckedForUnknownKeys() throws {
        try write("grantiva.yml", """
            appId: com.example
            ---
            - launchApp
            - takeScreenshot: Home
            """)
        XCTAssertEqual(try GrantivaConfig.load(platform: .ios, from: dir).warnings, [])
    }

    // C15: an unknown swipe direction is a config error naming file, screen, and value.
    func testUnknownSwipeDirectionIsRejected() throws {
        try write("grantiva.yml", """
            bundle_id: com.example
            screens:
              - name: Diag
                path:
                  - swipe: diagonal
            """)
        XCTAssertThrowsError(try GrantivaConfig.load(platform: .ios, from: dir)) { error in
            XCTAssertTrue(
                error.localizedDescription.contains(
                    #"grantiva.yml: screen "Diag": swipe direction "diagonal" is not one of up, down, left, right"#
                ),
                error.localizedDescription
            )
        }
    }

    func testSwipeDirectionsAreCaseInsensitive() throws {
        try write("grantiva.yml", """
            bundle_id: com.example
            screens:
              - name: Mixed
                path:
                  - swipe: Up
                  - swipe: DOWN
            """)
        let config = try GrantivaConfig.load(platform: .ios, from: dir)
        guard case .steps(let steps) = config.screens[0].path else { return XCTFail("expected steps") }
        XCTAssertEqual(steps.map(\.swipe), ["Up", "DOWN"])
    }

    // A13: `tap`, `assert_visible` and `assert_not_visible` take `{text:, exact:}`.
    func testLabelMappingFormDecodes() throws {
        try write("grantiva.yml", """
            bundle_id: com.example
            screens:
              - name: Tab
                path:
                  - tap: {text: "Landmarks", exact: true}
                  - assert_visible: {text: "Lakes", exact: true}
                  - assert_not_visible: {text: "Back"}
                  - tap: "Lakes"
            """)
        let config = try GrantivaConfig.load(platform: .ios, from: dir)
        guard case .steps(let steps) = config.screens[0].path else { return XCTFail("expected steps") }
        XCTAssertEqual(steps[0].tap, "Landmarks")
        XCTAssertTrue(steps[0].tapExact)
        XCTAssertEqual(steps[1].assertVisible, "Lakes")
        XCTAssertTrue(steps[1].assertVisibleExact)
        XCTAssertEqual(steps[2].assertNotVisible, "Back")
        XCTAssertFalse(steps[2].assertNotVisibleExact)
        XCTAssertEqual(steps[3].tap, "Lakes")
        XCTAssertFalse(steps[3].tapExact)
    }
}
