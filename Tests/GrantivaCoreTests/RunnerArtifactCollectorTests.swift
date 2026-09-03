import Foundation
import XCTest
@testable import GrantivaCore

final class RunnerArtifactCollectorTests: XCTestCase {
    private var scratch: URL!
    private var reportDir: URL!
    private var outputDir: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-artifact-tests-\(UUID().uuidString)")
        reportDir = scratch.appendingPathComponent("report")
        outputDir = scratch.appendingPathComponent("captures")
        try FileManager.default.createDirectory(at: reportDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    func testUsesReportIndicesInsteadOfLexicalAssetDirectoryOrder() throws {
        try writeAsset("first", directory: "assets/z-flow")
        try writeAsset("second", directory: "assets/a-flow")
        try writeReport([
            flow(index: 1, id: "flow-b", source: "/staged/1/second.yaml", assets: "assets/a-flow"),
            flow(index: 0, id: "flow-a", source: "/staged/0/first.yaml", assets: "assets/z-flow"),
        ])

        let captures = try collect(
            paths: ["flows/first.yaml", "flows/second.yaml"],
            map: [
                "/staged/0/first.yaml": "flows/first.yaml",
                "/staged/1/second.yaml": "flows/second.yaml",
            ]
        )

        XCTAssertEqual(captures.map(\.screenName), ["first-shot", "second-shot"])
        XCTAssertEqual(try captures.map(contents), ["first", "second"])
    }

    func testIgnoresUnlistedAssetDirectories() throws {
        try writeAsset("current", directory: "assets/flow-000")
        try writeAsset("stale", directory: "assets/aaa-stale")
        try writeReport([
            flow(index: 0, id: "flow-000", source: "/staged/current.yaml", assets: "assets/flow-000"),
        ])

        let captures = try collect(
            paths: ["current.yaml"], map: ["/staged/current.yaml": "current.yaml"]
        )

        XCTAssertEqual(captures.map(\.screenName), ["current-shot"])
        XCTAssertEqual(try captures.map(contents), ["current"])
    }

    func testDuplicateBasenamesReceiveStableSuffixesWithoutOverwriting() throws {
        try writeAsset("smoke", directory: "assets/flow-000")
        try writeAsset("regression", directory: "assets/flow-001")
        try writeReport([
            flow(index: 0, id: "flow-000", source: "/staged/0/login.yaml", assets: "assets/flow-000"),
            flow(index: 1, id: "flow-001", source: "/staged/1/login.yaml", assets: "assets/flow-001"),
        ])

        let captures = try collect(
            paths: ["smoke/login.yaml", "regression/login.yaml"],
            map: [
                "/staged/0/login.yaml": "smoke/login.yaml",
                "/staged/1/login.yaml": "regression/login.yaml",
            ]
        )

        XCTAssertEqual(captures.map(\.screenName), ["login-1-shot", "login-2-shot"])
        XCTAssertEqual(try captures.map(contents), ["smoke", "regression"])
        XCTAssertEqual(Set(captures.map(\.path)).count, 2)
    }

    func testRejectsAssetDirectoryTraversal() throws {
        try writeReport([
            flow(index: 0, id: "flow-000", source: "/staged/flow.yaml", assets: "../outside"),
        ])

        XCTAssertThrowsError(try collect(
            paths: ["flow.yaml"], map: ["/staged/flow.yaml": "flow.yaml"]
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("escapes the report directory"))
        }
    }

    func testUniqueFlowNamesPreserveExistingCaptureNames() throws {
        try writeAsset("one", directory: "assets/flow-000")
        try writeAsset("two", directory: "assets/flow-001")
        try writeReport([
            flow(index: 0, id: "flow-000", source: "/staged/checkout.yaml", assets: "assets/flow-000"),
            flow(index: 1, id: "flow-001", source: "/staged/profile.yaml", assets: "assets/flow-001"),
        ])

        let captures = try collect(
            paths: ["checkout.yaml", "profile.yaml"],
            map: [
                "/staged/checkout.yaml": "checkout.yaml",
                "/staged/profile.yaml": "profile.yaml",
            ]
        )

        XCTAssertEqual(captures.map(\.screenName), ["checkout-shot", "profile-shot"])
    }

    private func collect(paths: [String], map: [String: String]) throws -> [ScreenCapture] {
        try RunnerArtifactCollector.collect(
            reportDir: reportDir.path,
            outputDir: outputDir.path,
            requestedFlowPaths: paths,
            stagedPathMap: map
        )
    }

    private func contents(_ capture: ScreenCapture) throws -> String {
        try String(contentsOfFile: capture.path, encoding: .utf8)
    }

    private func writeAsset(_ contents: String, directory: String) throws {
        let directoryURL = reportDir.appendingPathComponent(directory)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: directoryURL.appendingPathComponent("shot.png"))
    }

    private func writeReport(_ flows: [String]) throws {
        let json = "{\"flows\":[\(flows.joined(separator: ","))]}"
        try Data(json.utf8).write(to: reportDir.appendingPathComponent("report.json"))
    }

    private func flow(
        index: Int, id: String, source: String, assets: String
    ) -> String {
        """
        {"index":\(index),"id":"\(id)","name":"flow","sourceFile":"\(source)","assetsDir":"\(assets)"}
        """
    }
}
