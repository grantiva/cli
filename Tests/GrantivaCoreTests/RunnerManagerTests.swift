import Foundation
import XCTest
@testable import GrantivaCore

final class RunnerManagerTests: XCTestCase {
    func testMatchingVersionUsesExistingRunnerWithoutExtraction() throws {
        let paths = try makePaths()
        try Data().write(to: URL(fileURLWithPath: paths.binary))
        try "v1".write(toFile: paths.version, atomically: true, encoding: .utf8)
        var extracted = false
        try RunnerManager.installIfNeeded(paths: paths, version: "v1") { _ in extracted = true }
        XCTAssertFalse(extracted)
    }

    func testInstallWritesVersionAndExecutableRunner() throws {
        let paths = try makePaths()
        try RunnerManager.installIfNeeded(paths: paths, version: "v2") { destination in
            FileManager.default.createFile(atPath: "\(destination)/grantiva-runner", contents: Data())
        }
        XCTAssertEqual(try String(contentsOfFile: paths.version, encoding: .utf8), "v2")
        let mode = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: paths.binary)[.posixPermissions] as? NSNumber).intValue
        XCTAssertEqual(mode & 0o777, 0o755)
    }

    func testUpdatePreservesCacheContents() throws {
        let paths = try makePaths(withCache: true)
        try RunnerManager.installIfNeeded(paths: paths, version: "v2") { destination in
            FileManager.default.createFile(atPath: "\(destination)/grantiva-runner", contents: Data())
        }
        XCTAssertEqual(try String(contentsOfFile: "\(paths.cache)/artifact", encoding: .utf8), "cached")
    }

    func testExtractionFailureRestoresCache() throws {
        let paths = try makePaths(withCache: true)
        XCTAssertThrowsError(try RunnerManager.installIfNeeded(paths: paths, version: "v2") { _ in
            throw GrantivaError.commandFailed("extract failed", 1)
        })
        XCTAssertEqual(try String(contentsOfFile: "\(paths.cache)/artifact", encoding: .utf8), "cached")
    }

    private func makePaths(withCache: Bool = false) throws -> Paths {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-runner-manager-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let base = root.appendingPathComponent("runner").path
        try FileManager.default.createDirectory(atPath: base, withIntermediateDirectories: true)
        let paths = Paths(base: base, binary: "\(base)/grantiva-runner", version: "\(base)/version", cache: "\(base)/cache")
        if withCache {
            try FileManager.default.createDirectory(atPath: paths.cache, withIntermediateDirectories: true)
            try "cached".write(toFile: "\(paths.cache)/artifact", atomically: true, encoding: .utf8)
        }
        return paths
    }

    func testArchTarballsNoLongerCarryTheAndroidDrivers() throws {
        for arch in ["arm64", "amd64"] {
            let url = try XCTUnwrap(RunnerManager.embeddedTarballURL(arch: arch))
            let listing = try listTarball(url)
            XCTAssertTrue(listing.contains("./grantiva-runner"), arch)
            XCTAssertFalse(listing.contains { $0.hasPrefix("./drivers/android/") }, "APKs ship once, in android-drivers.tar.gz: \(arch)")
            XCTAssertFalse(listing.contains { $0.contains("/._") }, "no AppleDouble entries: \(arch)")
        }
    }

    func testEmbeddedDriversTarballContainsTheUIAutomator2APKs() throws {
        let url = try XCTUnwrap(RunnerManager.embeddedDriversTarballURL())
        let listing = try listTarball(url)
        XCTAssertTrue(listing.contains("./drivers/android/appium-uiautomator2-server-v9.11.1.apk"))
        XCTAssertTrue(listing.contains("./drivers/android/appium-uiautomator2-server-debug-androidTest.apk"))
        XCTAssertEqual(listing.filter { $0.hasSuffix(".apk") }.count, 2, "only the two UIA2 APKs ship")
        XCTAssertFalse(listing.contains { $0.contains("/._") })
    }

    func testInstallStampChangesWhenDriversMoveButRunnerVersionDoesNot() {
        XCTAssertEqual(RunnerManager.runnerVersion, "1.1.18-grantiva.7")
        XCTAssertEqual(RunnerManager.installStamp, "1.1.18-grantiva.7+android-drivers-2")
    }

    func testLiveExtractionLaysOutBothTarballs() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("runner-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: base) }
        try RunnerManager.installIfNeeded(
            baseDir: base, binaryPath: "\(base)/grantiva-runner", versionFilePath: "\(base)/version",
            cacheDir: "\(base)/cache", version: RunnerManager.installStamp, extract: RunnerManager.extractEmbedded
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(base)/grantiva-runner"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(base)/drivers/android/appium-uiautomator2-server-v9.11.1.apk"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(base)/drivers/ios/WebDriverAgent/package.json"))
    }

    private func listTarball(_ url: URL) throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-tzf", url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
    }
}

private struct Paths {
    let base: String
    let binary: String
    let version: String
    let cache: String
}

private extension RunnerManager {
    static func installIfNeeded(paths: Paths, version: String, extract: (String) throws -> Void) throws {
        try installIfNeeded(baseDir: paths.base, binaryPath: paths.binary, versionFilePath: paths.version, cacheDir: paths.cache, version: version, extract: extract)
    }
}
