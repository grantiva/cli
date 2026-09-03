import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class CIInvocationCaptureTests: XCTestCase {
    func testCIInvocationIgnoresStaleSameNameAndRemovedScreenFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-ci-invocation-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let current = directory.appendingPathComponent("Current.png")
        let staleSameName = directory.appendingPathComponent("Failed.png")
        let removedScreen = directory.appendingPathComponent("Removed.png")
        try Data("current".utf8).write(to: current)
        try Data("stale".utf8).write(to: staleSameName)
        try Data("removed".utf8).write(to: removedScreen)

        let artifacts = try CICommand.currentInvocationArtifacts(from: [
            ScreenCapture(screenName: "Current", path: current.path, sizeBytes: 7),
            ScreenCapture(screenName: "Failed", path: "", sizeBytes: 0),
        ], outputDir: directory.path)

        XCTAssertEqual(artifacts.map(\.screenName), ["Current"])
        XCTAssertEqual(try artifacts.map { try String(contentsOfFile: $0.path!, encoding: .utf8) }, ["current"])
    }
}
