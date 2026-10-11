import Foundation
import XCTest

/// README and docs/ statements that have drifted from the code before
/// (K62, K63, K64, K65, K66). Each check names the source of truth.
final class DocsContractTests: XCTestCase {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func text(_ path: String) throws -> String {
        try String(contentsOf: Self.root.appendingPathComponent(path), encoding: .utf8)
    }

    /// README.md, docs/*.md (not the plans under docs/superpowers or
    /// docs/plans) and every Swift source.
    private func shippedFiles() throws -> [String] {
        var paths = ["README.md"]
        let docs = try FileManager.default.contentsOfDirectory(atPath: Self.root.appendingPathComponent("docs").path)
        paths += docs.filter { $0.hasSuffix(".md") }.map { "docs/\($0)" }
        let sources = Self.root.appendingPathComponent("Sources")
        let enumerator = FileManager.default.enumerator(atPath: sources.path)
        while let item = enumerator?.nextObject() as? String {
            if item.hasSuffix(".swift") { paths.append("Sources/\(item)") }
        }
        return paths
    }

    // MARK: - K62: doctor's status values

    func testTheDoctorFilterSelectsAStatusDoctorEmits() throws {
        let readme = try text("README.md")
        XCTAssertTrue(readme.contains(#"grantiva doctor --json | jq '.[] | select(.status == "error")'"#))
        XCTAssertTrue(readme.contains("`ok`, `warning` or `error`"), "README names doctor's three status values")
        XCTAssertTrue(try text("Sources/GrantivaCore/Output/Output.swift").contains(#"select(.status == "error")"#))
        for path in try shippedFiles() {
            XCTAssertFalse(try text(path).contains(#"status == "fail""#), "\(path) filters doctor on a status it never emits")
        }
    }

    // MARK: - K63: the runner home's version directory is the install stamp

    func testTheDeviceHomePathNamesTheStampLikeTheRunnerHomeRow() throws {
        let readme = try text("README.md")
        XCTAssertTrue(readme.contains("`<runner home>/versions/<stamp>/devices/<udid>`"))
        XCTAssertTrue(readme.contains("`versions/<stamp>/`"))
        for path in try shippedFiles() where path.hasSuffix(".md") {
            XCTAssertFalse(try text(path).contains("runner version>/"), "\(path) names the directory by the runner version")
        }
    }

    // MARK: - K64: no internal incident note in the repository root

    func testNoShippedMarkdownClaimsAnOldVersionOrCarriesAnIncidentNote() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: Self.root.appendingPathComponent("SIMULATOR-LIFECYCLE.md").path))
        let markdown = try FileManager.default.contentsOfDirectory(atPath: Self.root.path).filter { $0.hasSuffix(".md") }
            + (try shippedFiles().filter { $0.hasPrefix("docs/") })
        for path in markdown {
            let body = try text(path)
            XCTAssertNil(body.range(of: #"\b1\.[0-9]+\.[0-9]+\b"#, options: .regularExpression).flatMap { range in
                // A runner version (1.1.28-grantiva.N) is not a CLI version claim.
                body[range.upperBound...].hasPrefix("-grantiva") ? nil : range
            }, "\(path) names an old grantiva version")
        }
    }

    // MARK: - K65: the prebuilt GrantivaAgent runtimes

    /// The runtimes the bundled runner tarball ships a prebuilt GrantivaAgent
    /// for, read from the tarball itself.
    private func bundledRuntimes() throws -> [String] {
        let tarball = Self.root.appendingPathComponent("Sources/GrantivaCore/Resources/grantiva-runner-arm64.tar.gz")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-tzf", tarball.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let listing = String(decoding: data, as: UTF8.self)
        let regex = try NSRegularExpression(pattern: #"sim-ios([0-9]+\.[0-9]+)-iphone"#)
        let matches = regex.matches(in: listing, range: NSRange(listing.startIndex..., in: listing))
        return Set(matches.compactMap { Range($0.range(at: 1), in: listing).map { String(listing[$0]) } })
            .sorted { $0.compare($1, options: .numeric) == .orderedAscending }
    }

    func testDumpHierarchyListsEveryPrebuiltRuntimeTheTarballShips() throws {
        let runtimes = try bundledRuntimes()
        XCTAssertFalse(runtimes.isEmpty, "the bundled tarball lists no prebuilt GrantivaAgent")
        let expected = runtimes.dropLast().joined(separator: ", ") + ", and " + runtimes.last!
        XCTAssertTrue(try text("docs/dump-hierarchy.md").contains("(it ships \(expected))"),
                      "docs/dump-hierarchy.md should list \(runtimes)")
    }

    // MARK: - K66: a from-source install keeps the resource bundle

    func testFromSourceCopiesTheResourceBundleBesideTheBinary() throws {
        let readme = try text("README.md")
        XCTAssertTrue(readme.contains("cp -R .build/release/grantiva .build/release/grantiva_GrantivaCore.bundle /usr/local/bin/"))
        XCTAssertFalse(readme.contains("cp .build/release/grantiva /usr/local/bin/grantiva"))
    }

    // MARK: - deferred README lines from the behaviour PRs

    func testTheJSONCasingRuleNoLongerWaitsOnASiblingChange() throws {
        XCTAssertFalse(try text("README.md").contains("sibling change"), "runner start/stop met the camelCase rule in #194")
    }

    func testTheReclaimSectionSaysTeardownStopsARunnerSession() throws {
        let readme = try text("README.md")
        XCTAssertFalse(readme.contains("`teardown --force`\nis only for a session whose runner was killed"))
        XCTAssertTrue(readme.contains("runnerSessionStopped"))
    }
}
