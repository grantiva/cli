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
        XCTAssertEqual(result.appPath, app.path)
        XCTAssertNil(result.tempDir)
        XCTAssertEqual(AppBinaryResolver.bundleId(from: app.path), "com.example.app")
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
