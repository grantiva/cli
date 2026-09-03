import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class DiffCommandTests: XCTestCase {
    func testCaptureArtifactsReturnsCanonicalArtifactsInDeterministicOrder() throws {
        let artifacts = try DiffCommand.captureArtifacts(from: [
            "Settings%2FGeneral.png",
            "Home.png",
        ])

        XCTAssertEqual(artifacts, [
            .init(fileName: "Home.png", screenName: "Home"),
            .init(fileName: "Settings%2FGeneral.png", screenName: "Settings/General"),
        ])
    }

    func testCaptureArtifactsRejectsUndecodableScreenName() {
        XCTAssertThrowsError(try DiffCommand.captureArtifacts(from: ["%FF.png"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid capture filename \"%FF.png\""))
        }
    }

    func testCaptureArtifactsRejectsNonCanonicalAlias() {
        XCTAssertThrowsError(try DiffCommand.captureArtifacts(from: ["%48ome.png"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid capture filename \"%48ome.png\""))
        }
    }

    func testCaptureInvocationIgnoresStaleSameNameAndRemovedScreenFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-diff-invocation-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let current = directory.appendingPathComponent("Current.png")
        let staleSameName = directory.appendingPathComponent("Failed.png")
        let removedScreen = directory.appendingPathComponent("Removed.png")
        try Data("current".utf8).write(to: current)
        try Data("stale".utf8).write(to: staleSameName)
        try Data("removed".utf8).write(to: removedScreen)

        let artifacts = try DiffCommand.currentInvocationArtifacts(from: [
            ScreenCapture(screenName: "Current", path: current.path, sizeBytes: 7),
            ScreenCapture(screenName: "Failed", path: "", sizeBytes: 0),
        ], outputDir: directory.path)

        XCTAssertEqual(artifacts.map(\.screenName), ["Current"])
        XCTAssertEqual(try artifacts.map { try String(contentsOfFile: $0.path!, encoding: .utf8) }, ["current"])
    }
}
