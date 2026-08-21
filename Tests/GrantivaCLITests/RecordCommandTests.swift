import Foundation
import XCTest
@testable import GrantivaCLI

final class RecordCommandTests: XCTestCase {
    func testWaitForStartRecognizesSimulatorStagingMovie() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let recording = directory.appendingPathComponent("capture.mov")
        let staging = directory.appendingPathComponent("capture.mov.sb-fixture")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        FileManager.default.createFile(atPath: staging.path, contents: Data())

        try await RecorderLifecycle.waitForStart(of: recording)
    }

    func testStopInterruptsAndWaitsForCaptureProcess() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tail")
        process.arguments = ["-f", "/dev/null"]
        try process.run()

        RecorderLifecycle.stop(process)

        XCTAssertFalse(process.isRunning)
        XCTAssertNotEqual(process.terminationReason, .exit)
    }
}
