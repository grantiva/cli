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

    func testStopInterruptsAndWaitsForCaptureProcess() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tail")
        process.arguments = ["-f", "/dev/null"]
        try process.run()

        try await RecorderLifecycle.stop(process)

        XCTAssertFalse(process.isRunning)
        XCTAssertNotEqual(process.terminationReason, .exit)
    }

    func testStopEscalatesWhenRecorderIgnoresInterrupt() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "trap '' INT; exec tail -f /dev/null"]
        try process.run()

        try await RecorderLifecycle.stop(
            process,
            gracefulAttempts: 1,
            terminationAttempts: 100,
            pollInterval: .milliseconds(1)
        )

        XCTAssertFalse(process.isRunning)
        XCTAssertNotEqual(process.terminationStatus, 0)
    }

    func testCleanupStopsRecorderWhenStartupTimesOutAndPreservesTimeout() async throws {
        let process = try makeRunningCaptureProcess()
        let recording = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("capture.mov")

        do {
            try await RecorderLifecycle.withCleanup(for: process) {
                try await RecorderLifecycle.waitForStart(of: recording, attempts: 0)
            }
            XCTFail("Expected startup timeout")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Timed out waiting for simulator recording to start exited with code 1")
        }

        XCTAssertFalse(process.isRunning)
    }

    func testCleanupStopsRecorderWhenDurationSleepIsCancelledAndPreservesCancellation() async throws {
        let process = try makeRunningCaptureProcess()
        let enteredSleep = expectation(description: "entered duration sleep")
        let task = Task {
            try await RecorderLifecycle.withCleanup(for: process) {
                enteredSleep.fulfill()
                try await Task.sleep(for: .seconds(60))
            }
        }

        await fulfillment(of: [enteredSleep], timeout: 1)
        task.cancel()

        do {
            try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected: cleanup must not replace the cancellation error.
        }

        XCTAssertFalse(process.isRunning)
    }

    private func makeRunningCaptureProcess() throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tail")
        process.arguments = ["-f", "/dev/null"]
        try process.run()
        return process
    }
}
