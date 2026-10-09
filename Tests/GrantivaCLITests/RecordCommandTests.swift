import ArgumentParser
import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

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

    func testSimulatorIsOptionalAndTargetResolutionIsPerPlatform() throws {
        _ = try RecordCommand.parse(["--duration", "2"])
        XCTAssertEqual(RecordCommand.defaultOutput(for: .ios), ".grantiva/recordings/recording.mov")
        XCTAssertEqual(RecordCommand.defaultOutput(for: .android), ".grantiva/recordings/recording.mp4")

        XCTAssertEqual(try RecordCommand.target(platform: .ios, simulator: "iPhone 17", emulator: nil, device: nil, config: nil), "iPhone 17")
        XCTAssertEqual(try RecordCommand.target(platform: .ios, simulator: nil, emulator: nil, device: nil, config: GrantivaConfig(simulator: "iPhone 16")), "iPhone 16")
        XCTAssertThrowsError(try RecordCommand.target(platform: .ios, simulator: nil, emulator: nil, device: nil, config: nil)) { error in
            XCTAssertTrue("\(error)".contains("--simulator"), "\(error)")
        }
        XCTAssertThrowsError(try RecordCommand.target(platform: .ios, simulator: nil, emulator: "Pixel", device: nil, config: nil)) { error in
            XCTAssertTrue("\(error)".contains("--emulator is an Android option"), "\(error)")
        }
        XCTAssertEqual(try RecordCommand.target(platform: .android, simulator: nil, emulator: nil, device: "emulator-5556", config: nil), "emulator-5556")
        XCTAssertEqual(try RecordCommand.target(platform: .android, simulator: nil, emulator: "Pixel", device: nil, config: nil), "Pixel")
        XCTAssertThrowsError(try RecordCommand.target(platform: .android, simulator: nil, emulator: "Pixel", device: "emulator-5556", config: nil)) { error in
            XCTAssertTrue("\(error)".contains("mutually exclusive"), "\(error)")
        }
        XCTAssertEqual(try RecordCommand.target(platform: .android, simulator: nil, emulator: nil, device: nil,
                                                config: GrantivaConfig(platform: .android, android: AndroidProject(emulator: "Pixel_8_API_35"))), "Pixel_8_API_35")
        XCTAssertEqual(try RecordCommand.target(platform: .android, simulator: nil, emulator: nil, device: nil, config: nil), "")
        XCTAssertThrowsError(try RecordCommand.target(platform: .android, simulator: "iPhone", emulator: nil, device: nil, config: nil)) { error in
            XCTAssertTrue("\(error)".contains("--simulator is an iOS option"), "\(error)")
        }
    }

    /// Review Focus 3: the cap is enforced before any device call.
    func testAndroidRecordingOver180SecondsIsRefusedBeforeTouchingTheDevice() async throws {
        let dir = try makeAndroidProject()
        defer { restoreDirectory(dir) }
        var command = try RecordCommand.parse(["--duration", "200"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        do {
            try await command.run()
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("capped at 180 seconds"), "\(error)")
        }
        XCTAssertTrue(fake.calls.isEmpty, "\(fake.calls)")
    }

    func testAndroidInfiniteDurationIsRefusedInsteadOfTrapping() async throws {
        let dir = try makeAndroidProject()
        defer { restoreDirectory(dir) }
        var command = try RecordCommand.parse(["--duration", "inf"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        do {
            try await command.run()
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("capped at 180 seconds"), "\(error)")
        }
        XCTAssertTrue(fake.calls.isEmpty, "\(fake.calls)")
    }

    func testAndroidRecordGoesThroughThePlatformAndWritesTheReport() async throws {
        let dir = try makeAndroidProject()
        defer { restoreDirectory(dir) }
        var command = try RecordCommand.parse(["--duration", "1"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        try await command.run()
        XCTAssertEqual(fake.calls, ["bootDevice(Pixel_8_API_35)", "recordVideo(emulator-5598,1.0)", "displayGeometry(emulator-5598)"])
        let report = try String(contentsOfFile: ".grantiva/recordings/recording.json", encoding: .utf8)
        XCTAssertTrue(report.contains(#""simulator" : "Fake""#), report)
        XCTAssertTrue(report.contains(#""video" : ".grantiva\/recordings\/recording.mp4""#), report)
    }

    private func makeAndroidProject() throws -> (URL, String) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("record-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "module: app\nemulator: Pixel_8_API_35\n".write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        let previous = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(dir.path)
        unsetenv("GRANTIVA_PLATFORM")
        return (dir, previous)
    }

    private func restoreDirectory(_ state: (URL, String)) {
        FileManager.default.changeCurrentDirectoryPath(state.1)
        try? FileManager.default.removeItem(at: state.0)
    }
}
