import Foundation
import XCTest
@testable import GrantivaCore

final class RunnerReportWorkspaceTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-report-workspace-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    func testPrepareCreatesMissingDirectory() throws {
        let reportDir = scratch.appendingPathComponent("nested/report")

        try RunnerReportWorkspace.prepare(at: reportDir.path)

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: reportDir.path, isDirectory: &isDirectory
        ))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testPrepareRemovesOnlyStaleRunnerResults() throws {
        let reportDir = scratch.appendingPathComponent("report")
        let assetsDir = reportDir.appendingPathComponent("assets/old-flow")
        try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        try Data("old screenshot".utf8).write(
            to: assetsDir.appendingPathComponent("cmd-001.png")
        )
        try Data("{\"status\":\"passed\"}".utf8).write(
            to: reportDir.appendingPathComponent("report.json")
        )
        try Data("keep me".utf8).write(
            to: reportDir.appendingPathComponent("notes.txt")
        )

        try RunnerReportWorkspace.prepare(at: reportDir.path)

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: reportDir.appendingPathComponent("report.json").path
        ))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: reportDir.appendingPathComponent("assets").path
        ))
        XCTAssertEqual(
            try String(contentsOf: reportDir.appendingPathComponent("notes.txt"), encoding: .utf8),
            "keep me"
        )
    }
}
