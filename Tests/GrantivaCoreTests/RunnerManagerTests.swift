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

    func testReinstallKeepsLocksReportsAndXcconfig() throws {
        let paths = try makePaths()
        try seedInstall(paths, version: "v1", binary: "old-runner")
        let fm = FileManager.default
        try fm.createDirectory(atPath: "\(paths.base)/locks", withIntermediateDirectories: true)
        try "held".write(toFile: "\(paths.base)/locks/lease", atomically: true, encoding: .utf8)
        try fm.createDirectory(atPath: "\(paths.base)/reports", withIntermediateDirectories: true)
        try "report".write(toFile: "\(paths.base)/reports/run.json", atomically: true, encoding: .utf8)
        try "xcconfig".write(toFile: "\(paths.base)/grantiva-wda.xcconfig", atomically: true, encoding: .utf8)

        try RunnerManager.installIfNeeded(paths: paths, version: "v2") { destination in
            try "new-runner".write(toFile: "\(destination)/grantiva-runner", atomically: true, encoding: .utf8)
            try fm.createDirectory(atPath: "\(destination)/drivers/android", withIntermediateDirectories: true)
            try "new-apk".write(toFile: "\(destination)/drivers/android/server.apk", atomically: true, encoding: .utf8)
        }

        XCTAssertEqual(try String(contentsOfFile: "\(paths.base)/locks/lease", encoding: .utf8), "held")
        XCTAssertEqual(try String(contentsOfFile: "\(paths.base)/reports/run.json", encoding: .utf8), "report")
        XCTAssertEqual(try String(contentsOfFile: "\(paths.base)/grantiva-wda.xcconfig", encoding: .utf8), "xcconfig")
        XCTAssertEqual(try String(contentsOfFile: paths.binary, encoding: .utf8), "new-runner")
        XCTAssertEqual(try String(contentsOfFile: paths.version, encoding: .utf8), "v2")
        XCTAssertEqual(try String(contentsOfFile: "\(paths.base)/drivers/android/server.apk", encoding: .utf8), "new-apk")
        XCTAssertFalse(fm.fileExists(atPath: "\(paths.base)/drivers/android/old.apk"), "drivers/ is replaced, not merged")
        let leftovers = try fm.contentsOfDirectory(atPath: paths.base).filter { $0.hasPrefix(".") && $0 != ".last-used" }
        XCTAssertEqual(leftovers, [], "staging and backup directories are cleaned up")
    }

    func testFailedExtractLeavesPreviousInstallIntact() throws {
        let paths = try makePaths()
        try seedInstall(paths, version: "v1", binary: "old-runner")
        try FileManager.default.createDirectory(atPath: "\(paths.base)/locks", withIntermediateDirectories: true)
        try "held".write(toFile: "\(paths.base)/locks/lease", atomically: true, encoding: .utf8)
        let before = try snapshot(paths.base)

        XCTAssertThrowsError(try RunnerManager.installIfNeeded(paths: paths, version: "v2") { destination in
            try "partial".write(toFile: "\(destination)/grantiva-runner", atomically: true, encoding: .utf8)
            throw GrantivaError.commandFailed("extract failed", 1)
        })

        XCTAssertEqual(try snapshot(paths.base), before)
    }

    func testMissingResourceBundleThrowsAndLeavesInstallIntact() throws {
        let paths = try makePaths()
        try seedInstall(paths, version: "garbage", binary: "old-runner")
        let before = try snapshot(paths.base)

        XCTAssertThrowsError(try RunnerManager.installIfNeeded(paths: paths, version: "v2") { destination in
            try RunnerManager.extractEmbedded(into: destination, bundle: nil)
        }) { error in
            XCTAssertTrue(error is GrantivaError, "\(error)")
            XCTAssertTrue(error.localizedDescription.contains("grantiva_GrantivaCore.bundle"), error.localizedDescription)
        }

        XCTAssertEqual(try snapshot(paths.base), before)
    }

    func testInstallingStampBKeepsStampAUsable() throws {
        let root = try makePaths().base
        let fm = FileManager.default
        func install(_ stamp: String) throws -> Paths {
            let dir = RunnerManager.installDir(baseDir: root, stamp: stamp)
            let paths = Paths(base: dir, binary: "\(dir)/grantiva-runner", version: "\(dir)/version", cache: "\(root)/cache")
            try RunnerManager.installIfNeeded(paths: paths, version: stamp) { destination in
                try "runner-\(stamp)".write(toFile: "\(destination)/grantiva-runner", atomically: true, encoding: .utf8)
            }
            return paths
        }
        let a = try install("A")
        try "built".write(toFile: "\(root)/cache/wda", atomically: true, encoding: .utf8)
        let b = try install("B")

        XCTAssertNotEqual(a.base, b.base)
        XCTAssertEqual(try String(contentsOfFile: a.binary, encoding: .utf8), "runner-A")
        XCTAssertEqual(try String(contentsOfFile: a.version, encoding: .utf8), "A")
        XCTAssertEqual(try String(contentsOfFile: b.binary, encoding: .utf8), "runner-B")
        XCTAssertTrue(fm.isExecutableFile(atPath: a.binary))
        XCTAssertEqual(try String(contentsOfFile: "\(b.base)/cache/wda", encoding: .utf8), "built", "the WDA build cache is shared across stamps")

        var extracted = false
        try RunnerManager.installIfNeeded(paths: a, version: "A") { _ in extracted = true }
        XCTAssertFalse(extracted, "running version A after B does not re-extract A")
    }

    func testTarballCacheNeverReplacesTheSharedCacheButFillsMissingConfigs() throws {
        let paths = try makePaths(withCache: true)
        let fm = FileManager.default
        try fm.createDirectory(atPath: "\(paths.cache)/wda-builds/sim-a", withIntermediateDirectories: true)
        try "mine".write(toFile: "\(paths.cache)/wda-builds/sim-a/build", atomically: true, encoding: .utf8)
        try RunnerManager.installIfNeeded(paths: paths, version: "v2") { destination in
            fm.createFile(atPath: "\(destination)/grantiva-runner", contents: Data())
            for config in ["sim-a", "sim-b"] {
                try fm.createDirectory(atPath: "\(destination)/cache/wda-builds/\(config)", withIntermediateDirectories: true)
                try "prebuilt".write(toFile: "\(destination)/cache/wda-builds/\(config)/build", atomically: true, encoding: .utf8)
            }
        }
        XCTAssertEqual(try String(contentsOfFile: "\(paths.cache)/artifact", encoding: .utf8), "cached")
        XCTAssertEqual(try String(contentsOfFile: "\(paths.cache)/wda-builds/sim-a/build", encoding: .utf8), "mine")
        XCTAssertEqual(try String(contentsOfFile: "\(paths.cache)/wda-builds/sim-b/build", encoding: .utf8), "prebuilt")
    }

    func testRunnerHomeOverrideIsMadeAbsolute() {
        let cwd = FileManager.default.currentDirectoryPath
        XCTAssertEqual(RunnerManager.resolveBaseDir(environment: ["GRANTIVA_RUNNER_HOME": "rh/../runner"]), "\(cwd)/runner")
        XCTAssertEqual(RunnerManager.resolveBaseDir(environment: ["GRANTIVA_RUNNER_HOME": "/tmp/x/"]), "/tmp/x")
        XCTAssertTrue(RunnerManager.resolveBaseDir(environment: [:]).hasSuffix("/.grantiva/runner"))
    }

    func testEveryCallTouchesLastUsed() throws {
        let paths = try makePaths()
        try seedInstall(paths, version: "v1", binary: "runner")
        let marker = "\(paths.base)/.last-used"
        try RunnerManager.installIfNeeded(paths: paths, version: "v1") { _ in XCTFail("no extract on the fast path") }
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker))
        let old = Date(timeIntervalSinceNow: -86_400)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: marker)
        try RunnerManager.installIfNeeded(paths: paths, version: "v1") { _ in }
        let touched = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: marker)[.modificationDate] as? Date)
        XCTAssertGreaterThan(touched, old.addingTimeInterval(3600))
    }

    func testPruneDeletesOnlyOldUnusedSiblingInstalls() throws {
        let versions = try makePaths().base + "/versions"
        let fm = FileManager.default
        let old = Date(timeIntervalSinceNow: -31 * 86_400)
        func make(_ stamp: String, marker: String?, date: Date) throws {
            let dir = "\(versions)/\(stamp)"
            try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
            if let marker {
                fm.createFile(atPath: "\(dir)/\(marker)", contents: Data())
                try fm.setAttributes([.modificationDate: date], ofItemAtPath: "\(dir)/\(marker)")
            }
        }
        try make("old", marker: ".last-used", date: old)
        try make("old-version-only", marker: "version", date: old)
        try make("recent", marker: ".last-used", date: Date())
        try make("old-in-use", marker: ".last-used", date: old)
        try make("current", marker: ".last-used", date: old)
        try make("no-marker", marker: nil, date: old)
        try make(".staging-x", marker: "version", date: old)

        RunnerManager.pruneStaleInstalls(versionsDir: versions, keeping: "current", isInUse: { $0 == "old-in-use" })

        let remaining = Set(try fm.contentsOfDirectory(atPath: versions))
        XCTAssertEqual(remaining, ["recent", "old-in-use", "current", "no-marker", ".staging-x"])
    }

    func testPruneSkipsAStampWhoseInstallLockIsHeld() throws {
        let root = try makePaths().base
        let versions = "\(root)/versions", locks = "\(root)/locks"
        let fm = FileManager.default
        try fm.createDirectory(atPath: "\(versions)/busy", withIntermediateDirectories: true)
        try fm.createDirectory(atPath: locks, withIntermediateDirectories: true)
        fm.createFile(atPath: "\(versions)/busy/.last-used", contents: Data())
        try fm.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -31 * 86_400)], ofItemAtPath: "\(versions)/busy/.last-used")
        let held = open("\(locks)/install-busy.lock", O_RDWR | O_CREAT, 0o644)
        XCTAssertEqual(flock(held, LOCK_EX), 0)

        RunnerManager.pruneStaleInstalls(versionsDir: versions, keeping: "current", locksDir: locks, isInUse: { _ in false })
        XCTAssertTrue(fm.fileExists(atPath: "\(versions)/busy"))

        flock(held, LOCK_UN); close(held)
        RunnerManager.pruneStaleInstalls(versionsDir: versions, keeping: "current", locksDir: locks, isInUse: { _ in false })
        XCTAssertFalse(fm.fileExists(atPath: "\(versions)/busy"))
    }

    func testRunnerProcessCheckFindsNothingForAnUnusedInstall() {
        XCTAssertFalse(RunnerManager.runnerProcessExists(installDir: "/nonexistent/versions/1.0+x"))
    }

    func testConcurrentInstallsOfOneStampExtractOnce() throws {
        let paths = try makePaths()
        let lock = "\(paths.base)/../locks/install-v1.lock"
        let counter = NSLock()
        nonisolated(unsafe) var extracts = 0
        nonisolated(unsafe) var errors: [Error] = []
        DispatchQueue.concurrentPerform(iterations: 4) { _ in
            do {
                try RunnerManager.installIfNeeded(
                    baseDir: paths.base, binaryPath: paths.binary, versionFilePath: paths.version,
                    cacheDir: paths.cache, version: "v1", lockPath: lock
                ) { destination in
                    counter.lock(); extracts += 1; counter.unlock()
                    Thread.sleep(forTimeInterval: 0.2)
                    FileManager.default.createFile(atPath: "\(destination)/grantiva-runner", contents: Data("r".utf8))
                }
            } catch {
                counter.lock(); errors.append(error); counter.unlock()
            }
        }
        XCTAssertEqual(errors.count, 0, "\(errors)")
        XCTAssertEqual(extracts, 1)
        XCTAssertEqual(try String(contentsOfFile: paths.version, encoding: .utf8), "v1")
    }

    private func seedInstall(_ paths: Paths, version: String, binary: String) throws {
        try binary.write(toFile: paths.binary, atomically: true, encoding: .utf8)
        try version.write(toFile: paths.version, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(atPath: "\(paths.base)/drivers/android", withIntermediateDirectories: true)
        try "old-apk".write(toFile: "\(paths.base)/drivers/android/old.apk", atomically: true, encoding: .utf8)
    }

    /// Relative path -> contents for every file under `root`.
    private func snapshot(_ root: String) throws -> [String: String] {
        var result: [String: String] = [:]
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(atPath: root))
        while let relative = enumerator.nextObject() as? String {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: "\(root)/\(relative)", isDirectory: &isDirectory)
            result[relative] = isDirectory.boolValue ? "<dir>" : try String(contentsOfFile: "\(root)/\(relative)", encoding: .utf8)
        }
        return result
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
            cacheDir: "\(base)/cache", version: RunnerManager.installStamp, extract: { try RunnerManager.extractEmbedded(into: $0) }
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
