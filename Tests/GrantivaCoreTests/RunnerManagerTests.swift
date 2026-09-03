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
