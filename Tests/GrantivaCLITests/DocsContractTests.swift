import Foundation
import GrantivaCore
import XCTest

/// README and docs/ statements that have drifted from the code before
/// (K62, K63, K64, K65, K66). Each check names the source of truth.
final class DocsContractTests: XCTestCase {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func text(_ path: String) throws -> String {
        try String(contentsOf: Self.root.appendingPathComponent(path), encoding: .utf8)
    }

    /// README.md, every markdown file under docs/ (subdirectories such as
    /// docs/plans included, L30) except the internal notes under
    /// docs/superpowers, and every Swift source.
    private func shippedFiles() throws -> [String] {
        var paths = ["README.md"]
        let docs = FileManager.default.enumerator(atPath: Self.root.appendingPathComponent("docs").path)
        while let item = docs?.nextObject() as? String {
            if item.hasSuffix(".md"), !item.hasPrefix("superpowers/") { paths.append("docs/\(item)") }
        }
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

    /// Every `x.y.z` or `vx.y.z` version in `body` other than the current
    /// CLI version, skipping runner versions (`1.1.28-grantiva.N`), which are
    /// not CLI version claims.
    static func versionClaims(in body: String, current: String = grantivaVersion) -> [String] {
        body.matches(of: /(?:\bv|\b)([0-9]+\.[0-9]+\.[0-9]+)\b/)
            .filter { !body[$0.range.upperBound...].hasPrefix("-grantiva") }
            .map { String($0.output.1) }
            .filter { $0 != current }
    }

    func testVersionClaimsChecksEveryMatchNotOnlyTheFirst() {
        let body = "The stamp is 1.1.28-grantiva.10+android-drivers-2.\n\nShip 1.6.5 to Homebrew."
        XCTAssertEqual(Self.versionClaims(in: body), ["1.6.5"])
        XCTAssertEqual(Self.versionClaims(in: "Runner 1.1.28-grantiva.10 only."), [])
        XCTAssertEqual(Self.versionClaims(in: "written by \(grantivaVersion)"), [], "the current version is not stale")
        XCTAssertEqual(Self.versionClaims(in: "# v2.0.0 plan, then v2.0.0-rc1."), ["2.0.0", "2.0.0"], "a v prefix is still a version claim")
    }

    func testShippedDocsIncludeEveryDocsSubdirectoryButSuperpowers() throws {
        let docs = try shippedFiles().filter { $0.hasPrefix("docs/") }
        XCTAssertTrue(docs.contains("docs/mcp.md"))
        XCTAssertFalse(docs.contains { $0.hasPrefix("docs/superpowers/") }, "docs/superpowers holds internal notes")
        let subdirectories = try FileManager.default.contentsOfDirectory(atPath: Self.root.appendingPathComponent("docs").path)
            .filter { name in
                var isDirectory: ObjCBool = false
                return FileManager.default.fileExists(atPath: Self.root.appendingPathComponent("docs/\(name)").path, isDirectory: &isDirectory)
                    && isDirectory.boolValue && name != "superpowers"
            }
        for name in subdirectories {
            let markdown = FileManager.default.enumerator(atPath: Self.root.appendingPathComponent("docs/\(name)").path)?
                .compactMap { $0 as? String }.filter { $0.hasSuffix(".md") } ?? []
            for file in markdown {
                XCTAssertTrue(docs.contains("docs/\(name)/\(file)"), "docs/\(name)/\(file) is shipped and must be scanned")
            }
        }
    }

    func testNoShippedMarkdownClaimsAnOldVersionOrCarriesAnIncidentNote() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: Self.root.appendingPathComponent("SIMULATOR-LIFECYCLE.md").path))
        let markdown = try FileManager.default.contentsOfDirectory(atPath: Self.root.path).filter { $0.hasSuffix(".md") }
            + (try shippedFiles().filter { $0.hasPrefix("docs/") })
        for path in markdown {
            XCTAssertEqual(Self.versionClaims(in: try text(path)), [], "\(path) names a grantiva version other than \(grantivaVersion)")
        }
    }

    // MARK: - the runner's lineage is not named in prose

    /// `body` with fenced code blocks and inline code spans removed, so
    /// identifiers, paths and raw output are exempt.
    static func prose(_ body: String) -> String {
        body.replacing(/```[\s\S]*?```/, with: "").replacing(/`[^`\n]*`/, with: "")
    }

    /// Names of the project the runner derives from, found in `body`'s prose.
    static func lineageNames(in body: String) -> [String] {
        prose(body).matches(of: /(?i)devicelab|maestro-runner/).map { String($0.output) }
    }

    func testLineageNamesAreFoundOnlyInProse() {
        XCTAssertEqual(Self.lineageNames(in: "The Go runner (grantiva-runner, forked from devicelab-dev/maestro-runner)."), ["devicelab", "maestro-runner"])
        XCTAssertEqual(Self.lineageNames(in: "We drop DeviceLab."), ["DeviceLab"])
        XCTAssertEqual(Self.lineageNames(in: "The log is `maestro-runner.log`.\n```\nls drivers/android/devicelab\n```\n"), [])
        XCTAssertEqual(Self.lineageNames(in: "Run Maestro flows; set `MAESTRO_RUNNER_HOME`."), [], "the flow format and identifiers are exempt")
    }

    func testNoMarkdownNamesTheRunnersLineageInProse() throws {
        var paths = ["README.md"]
        let docs = FileManager.default.enumerator(atPath: Self.root.appendingPathComponent("docs").path)
        while let item = docs?.nextObject() as? String {
            if item.hasSuffix(".md") { paths.append("docs/\(item)") }
        }
        for path in paths {
            XCTAssertEqual(Self.lineageNames(in: try text(path)), [], "\(path) names the runner's lineage in prose")
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

    func testPublicCompatibilityNotesCoverBaselineNamesDatesSelectorsAndLifecycleJSON() throws {
        let readme = try text("README.md")
        let mcpDocs = try text("docs/mcp.md")

        XCTAssertTrue(readme.contains("legacy baseline"), "README must name legacy baseline compatibility")
        XCTAssertTrue(readme.contains("percent-encoded"), "README must name the old filename form")
        XCTAssertTrue(readme.contains("ambiguous `%`"), "README must explain why percent encoding changed")
        XCTAssertTrue(readme.contains("migration on approval"), "README must say approval performs migration")

        XCTAssertTrue(mcpDocs.contains("ISO 8601"))
        for key in ["timestamp", "detectedAt", "startedAt", "acquiredAt", "createdAt", "finishedAt"] {
            XCTAssertTrue(mcpDocs.contains("`\(key)`"), key)
        }
        XCTAssertTrue(mcpDocs.contains("1970-01-01T00:00:00Z"))
        XCTAssertTrue(mcpDocs.contains("label → identifier → placeholder"))
        for key in ["runnerSessionStopped", "leftoverProcesses", "reapedProcesses"] {
            XCTAssertTrue(mcpDocs.contains(#""\#(key)""#), key)
        }
    }
}
