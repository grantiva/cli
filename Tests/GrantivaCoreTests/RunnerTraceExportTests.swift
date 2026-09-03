import Foundation
import XCTest
@testable import GrantivaCore

final class RunnerTraceExportTests: XCTestCase {
    private var scratch: URL!
    private var reportDir: URL!
    private var outputDir: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-trace-export-tests-\(UUID().uuidString)")
        reportDir = scratch.appendingPathComponent("report")
        outputDir = scratch.appendingPathComponent("output")
        try FileManager.default.createDirectory(at: reportDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    func testFullExportUsesManifestOrderAndUserFlowNamesAndIgnoresExtraDirectories() throws {
        try writeArtifact("second", directory: "assets/z-runner-id", name: "cmd-002-after.png")
        try writeArtifact("first", directory: "assets/a-runner-id", name: "cmd-001-after.png")
        try writeArtifact("stale", directory: "assets/000-stale", name: "cmd-999-after.png")
        try writeArtifact("not a trace artifact", directory: "assets/a-runner-id", name: "cmd-001-debug.txt")
        try writeReport([
            flow(index: 1, id: "runner-b", source: "/staged/1/login.yaml", assets: "assets/z-runner-id"),
            flow(index: 0, id: "runner-a", source: "/staged/0/checkout.yaml", assets: "assets/a-runner-id"),
        ])

        export(
            paths: ["flows/checkout.yaml", "flows/login.yaml"],
            map: [
                "/staged/0/checkout.yaml": "flows/checkout.yaml",
                "/staged/1/login.yaml": "flows/login.yaml",
            ]
        )

        XCTAssertEqual(try traceFiles(), [
            "checkout-cmd-001-after.png",
            "login-cmd-002-after.png",
        ])
        XCTAssertEqual(try traceContents("checkout-cmd-001-after.png"), "first")
        XCTAssertEqual(try traceContents("login-cmd-002-after.png"), "second")
    }

    func testDuplicateBasenamesReceiveStableCollisionFreeNames() throws {
        try writeArtifact("one", directory: "assets/first", name: "cmd-001-after.png")
        try writeArtifact("two", directory: "assets/second", name: "cmd-001-after.png")
        try writeArtifact("reserved", directory: "assets/reserved", name: "cmd-001-after.png")
        try writeReport([
            flow(index: 0, id: "a", source: "/staged/0/login.yaml", assets: "assets/first"),
            flow(index: 1, id: "b", source: "/staged/1/login.yaml", assets: "assets/second"),
            flow(index: 2, id: "c", source: "/staged/2/login-1.yaml", assets: "assets/reserved"),
        ])

        export(
            paths: ["smoke/login.yaml", "regression/login.yaml", "login-1.yaml"],
            map: [
                "/staged/0/login.yaml": "smoke/login.yaml",
                "/staged/1/login.yaml": "regression/login.yaml",
                "/staged/2/login-1.yaml": "login-1.yaml",
            ]
        )

        XCTAssertEqual(try traceFiles(), [
            "login-1-cmd-001-after.png",
            "login-2-cmd-001-after.png",
            "login-3-cmd-001-after.png",
        ])
    }

    func testCaseVariantBasenamesCannotCollideOnCaseInsensitiveFileSystems() throws {
        try writeArtifact("upper", directory: "assets/first", name: "cmd-001-after.png")
        try writeArtifact("lower", directory: "assets/second", name: "cmd-001-after.png")
        try writeReport([
            flow(index: 0, id: "a", source: "/staged/Login.yaml", assets: "assets/first"),
            flow(index: 1, id: "b", source: "/staged/login.yaml", assets: "assets/second"),
        ])

        export(
            paths: ["smoke/Login.yaml", "regression/login.yaml"],
            map: [
                "/staged/Login.yaml": "smoke/Login.yaml",
                "/staged/login.yaml": "regression/login.yaml",
            ]
        )

        XCTAssertEqual(try traceFiles(), [
            "Login-1-cmd-001-after.png",
            "login-2-cmd-001-after.png",
        ])
    }

    func testMismatchedSourceAttributionExportsNothing() throws {
        try writeArtifact("foreign", directory: "assets/flow", name: "cmd-001-after.png")
        try writeReport([
            flow(index: 0, id: "flow", source: "/staged/foreign.yaml", assets: "assets/flow"),
        ])

        export(paths: ["expected.yaml"], map: ["/staged/expected.yaml": "expected.yaml"])

        XCTAssertFalse(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("trace").path))
    }

    func testAssetDirectoryTraversalExportsNothing() throws {
        let outside = scratch.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try Data("foreign".utf8).write(to: outside.appendingPathComponent("cmd-001-after.png"))
        try writeReport([
            flow(index: 0, id: "flow", source: "/staged/flow.yaml", assets: "../outside"),
        ])

        export(paths: ["flow.yaml"], map: ["/staged/flow.yaml": "flow.yaml"])

        XCTAssertFalse(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("trace").path))
    }

    func testArtifactSymlinkTraversalExportsNothing() throws {
        let outside = scratch.appendingPathComponent("outside.png")
        try Data("foreign".utf8).write(to: outside)
        let assets = reportDir.appendingPathComponent("assets/flow")
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: assets.appendingPathComponent("cmd-001-after.png"),
            withDestinationURL: outside
        )
        try writeReport([
            flow(index: 0, id: "flow", source: "/staged/flow.yaml", assets: "assets/flow"),
        ])

        export(paths: ["flow.yaml"], map: ["/staged/flow.yaml": "flow.yaml"])

        XCTAssertFalse(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("trace").path))
    }

    func testTrailingKeepsLastStepAndPreviousAfterImageOnly() throws {
        try writeArtifact("before", directory: "assets/flow", name: "cmd-001-before.png")
        try writeArtifact("last-good", directory: "assets/flow", name: "cmd-001-after.png")
        try writeArtifact("failure-before", directory: "assets/flow", name: "cmd-002-before.png")
        try writeArtifact("hierarchy", directory: "assets/flow", name: "cmd-002-hierarchy.xml")
        try writeReport([
            flow(index: 0, id: "flow", source: "/staged/flow.yaml", assets: "assets/flow"),
        ])

        export(
            snapshot: "trailing",
            paths: ["flow.yaml"],
            map: ["/staged/flow.yaml": "flow.yaml"]
        )

        XCTAssertEqual(try traceFiles(), [
            "flow-cmd-001-after.png",
            "flow-cmd-002-before.png",
            "flow-cmd-002-hierarchy.xml",
        ])
    }

    private func export(
        snapshot: String = "full",
        paths: [String],
        map: [String: String]
    ) {
        RunnerSession.exportTraceArtifacts(
            reportDir: reportDir.path,
            outputDir: outputDir.path,
            snapshot: snapshot,
            requestedFlowPaths: paths,
            stagedPathMap: map
        )
    }

    private func traceFiles() throws -> [String] {
        try FileManager.default.contentsOfDirectory(
            atPath: outputDir.appendingPathComponent("trace").path
        ).sorted()
    }

    private func traceContents(_ name: String) throws -> String {
        try String(
            contentsOf: outputDir.appendingPathComponent("trace").appendingPathComponent(name),
            encoding: .utf8
        )
    }

    private func writeArtifact(_ contents: String, directory: String, name: String) throws {
        let directoryURL = reportDir.appendingPathComponent(directory)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: directoryURL.appendingPathComponent(name))
    }

    private func writeReport(_ flows: [String]) throws {
        let json = "{\"flows\":[\(flows.joined(separator: ","))]}"
        try Data(json.utf8).write(to: reportDir.appendingPathComponent("report.json"))
    }

    private func flow(index: Int, id: String, source: String, assets: String) -> String {
        """
        {"index":\(index),"id":"\(id)","name":"flow","sourceFile":"\(source)","assetsDir":"\(assets)"}
        """
    }
}
