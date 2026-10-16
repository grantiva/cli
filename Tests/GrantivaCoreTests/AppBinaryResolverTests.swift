import Foundation
import XCTest
@testable import GrantivaCore

final class AppBinaryResolverTests: XCTestCase {
    func testMissingAndUnsupportedPathsAreRejected() throws {
        XCTAssertThrowsError(try AppBinaryResolver.resolve("/definitely/missing/Test.app"))
        let file = try temporaryDirectory().appendingPathComponent("binary.txt")
        try Data().write(to: file)
        XCTAssertThrowsError(try AppBinaryResolver.resolve(file.path))
    }

    func testValidSimulatorAppResolvesAndExposesBundleId() throws {
        let app = try makeApp(platforms: ["iPhoneSimulator"], bundleId: "com.example.app")
        let result = try AppBinaryResolver.resolve(app.path)
        XCTAssertEqual(result.appPath, AppBinaryResolver.canonicalPath(app.path))
        XCTAssertNil(result.tempDir)
        XCTAssertEqual(AppBinaryResolver.bundleId(from: app.path), "com.example.app")
    }

    /// B4-L53.P5: `appPath` is reported in realpath(3) spelling, as the
    /// other reported paths are (`dataContainerPath`, keep-alive owners):
    /// `/tmp/x` and `/private/tmp/x` both report `/private/tmp/x`, rather
    /// than `standardizingPath` turning `/private/tmp/x` into `/tmp/x`.
    func testAppPathIsReportedInItsRealpathSpellingWhicheverSpellingIsGiven() throws {
        let dir = URL(fileURLWithPath: "/tmp/grantiva-binary-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let app = dir.appendingPathComponent("Fixture.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        let plist = try PropertyListSerialization.data(
            fromPropertyList: ["CFBundleIdentifier": "com.example.app", "CFBundleSupportedPlatforms": ["iPhoneSimulator"]],
            format: .xml, options: 0
        )
        try plist.write(to: app.appendingPathComponent("Info.plist"))
        let expected = "/private" + app.path
        XCTAssertEqual(try AppBinaryResolver.resolve(app.path).appPath, expected)
        XCTAssertEqual(try AppBinaryResolver.resolve("/private" + app.path).appPath, expected)
        XCTAssertEqual(try AppBinaryResolver.resolve(app.path + "/").appPath, expected)
    }

    /// C13-2 (IOS-024): a built product (`--derived-data-path /tmp/...`, a
    /// scheme's build products, a Gradle APK) reports the same realpath
    /// spelling as `--app-file` does.
    func testABuiltProductPathIsReportedInItsRealpathSpelling() throws {
        let dir = URL(fileURLWithPath: "/tmp/grantiva-product-tests-\(UUID().uuidString)", isDirectory: true)
        let products = dir.appendingPathComponent("Build/Products/Debug-iphonesimulator", isDirectory: true)
        try FileManager.default.createDirectory(at: products, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        for name in ["Fixture.app", "app-debug.apk"] {
            let built = products.appendingPathComponent(name).path
            let result = BuildResult(success: true, duration: 0, warnings: [], errors: [], productPath: built)
            XCTAssertEqual(result.productPath, "/private" + built)
        }
        XCTAssertNil(BuildResult(success: false, duration: 0, warnings: [], errors: [], productPath: nil).productPath)
    }

    func testAnExtractedIPAReportsItsRealpathSpelling() throws {
        let app = try makeApp(platforms: ["iPhoneSimulator"], bundleId: "com.example.ipa")
        let staging = app.deletingLastPathComponent().appendingPathComponent("ipa-staging")
        try FileManager.default.createDirectory(at: staging.appendingPathComponent("Payload"), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: app, to: staging.appendingPathComponent("Payload/\(app.lastPathComponent)"))
        let ipa = app.deletingLastPathComponent().appendingPathComponent("Fixture.ipa")
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.currentDirectoryURL = staging
        zip.arguments = ["-qr", ipa.path, "Payload"]
        try zip.run(); zip.waitUntilExit()
        let resolved = try AppBinaryResolver.resolve(ipa.path)
        defer { resolved.cleanup() }
        XCTAssertEqual(resolved.appPath, AppBinaryResolver.canonicalPath(resolved.appPath))
        XCTAssertFalse(resolved.appPath.hasPrefix("/var/"), resolved.appPath)
    }

    func testCanonicalPathKeepsTheLastComponentAndFallsBackForAMissingParent() {
        XCTAssertEqual(AppBinaryResolver.canonicalPath("/private/tmp/x/../y.app"), "/private/tmp/y.app")
        XCTAssertEqual(AppBinaryResolver.canonicalPath("/definitely/missing/Test.app"), "/definitely/missing/Test.app")
    }

    func testDeviceBuildIsRejected() throws {
        let app = try makeApp(platforms: ["iPhoneOS"], bundleId: "com.example.device")
        XCTAssertThrowsError(try AppBinaryResolver.resolve(app.path)) { error in
            XCTAssertTrue(error.localizedDescription.contains("not iPhoneSimulator"))
        }
    }

    func testMissingInfoPlistIsRejected() throws {
        let app = try temporaryDirectory().appendingPathComponent("Empty.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        XCTAssertThrowsError(try AppBinaryResolver.resolve(app.path))
        XCTAssertNil(AppBinaryResolver.bundleId(from: app.path))
    }

    func testInvalidIPAIsRejected() throws {
        let ipa = try temporaryDirectory().appendingPathComponent("Broken.ipa")
        try Data("not a zip".utf8).write(to: ipa)
        XCTAssertThrowsError(try AppBinaryResolver.resolve(ipa.path))
    }

    func testIPAWithoutPayloadIsRejected() throws {
        let root = try temporaryDirectory()
        try Data().write(to: root.appendingPathComponent("placeholder"))
        let ipa = root.appendingPathComponent("MissingPayload.ipa")
        try makeZip(at: ipa, from: root, entries: ["placeholder"])
        XCTAssertThrowsError(try AppBinaryResolver.resolve(ipa.path))
    }

    func testIPAWithoutAppIsRejected() throws {
        let root = try temporaryDirectory()
        let payload = root.appendingPathComponent("Payload")
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        try Data().write(to: payload.appendingPathComponent("placeholder"))
        let ipa = root.appendingPathComponent("MissingApp.ipa")
        try makeZip(at: ipa, from: root, entries: ["Payload"])
        XCTAssertThrowsError(try AppBinaryResolver.resolve(ipa.path))
    }

    func testValidIPACanBeCleanedUp() throws {
        let root = try temporaryDirectory()
        let payload = root.appendingPathComponent("Payload")
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        let sourceApp = try makeApp(platforms: ["iPhoneSimulator"], bundleId: "com.example.ipa")
        let archivedApp = payload.appendingPathComponent("Test.app")
        try FileManager.default.copyItem(at: sourceApp, to: archivedApp)
        let ipa = root.appendingPathComponent("Valid.ipa")
        try makeZip(at: ipa, from: root, entries: ["Payload"])

        let result = try AppBinaryResolver.resolve(ipa.path)
        XCTAssertEqual(AppBinaryResolver.bundleId(from: result.appPath), "com.example.ipa")
        let extractedDirectory = try XCTUnwrap(result.tempDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedDirectory.path))
        result.cleanup()
        XCTAssertFalse(FileManager.default.fileExists(atPath: extractedDirectory.path))
    }

    private func makeApp(platforms: [String], bundleId: String) throws -> URL {
        let app = try temporaryDirectory().appendingPathComponent("Test.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleId,
            "CFBundleSupportedPlatforms": platforms,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: app.appendingPathComponent("Info.plist"))
        return app
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-binary-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func makeZip(at output: URL, from directory: URL, entries: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = directory
        process.arguments = ["-qr", output.path] + entries
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }
}
