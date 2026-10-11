import ArgumentParser
import AVFoundation
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
            XCTAssertEqual(error.localizedDescription, "Timed out waiting for simulator recording to start")
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
        // `--device` with `--emulator` is refused by validate() (L26-b).
        XCTAssertThrowsError(try RecordCommand.parse(["--duration", "2", "--emulator", "Pixel", "--device", "emulator-5556"])) { error in
            XCTAssertEqual(RecordCommand.message(for: error), "--device and --emulator are mutually exclusive; pass one.")
            XCTAssertEqual(RecordCommand.exitCode(for: error), .validationFailure)
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
        XCTAssertTrue(report.contains(#""udid" : "emulator-5598""#), report)
        // A05: Android names the emulator and serial too; the old keys stay.
        XCTAssertTrue(report.contains(#""emulator" : "Fake""#), report)
        XCTAssertTrue(report.contains(#""serial" : "emulator-5598""#), report)
        XCTAssertTrue(report.contains(#""video" : ".grantiva\/recordings\/recording.mp4""#), report)
    }

    // MARK: - Argument validation before recording (C14)

    func testMalformedFramesAtIsAUsageErrorAtParseTime() {
        XCTAssertThrowsError(try RecordCommand.parse(["--duration", "5", "--frames-at", "a,b"])) { error in
            XCTAssertEqual(RecordCommand.exitCode(for: error), .validationFailure, "\(error)")
            XCTAssertTrue(RecordCommand.message(for: error).contains("--frames-at"), RecordCommand.message(for: error))
        }
        XCTAssertThrowsError(try RecordCommand.parse(["--duration", "5", "--frames-at", "-1"]))
        XCTAssertEqual(try RecordCommand.parse(["--duration", "5", "--frames-at", "1500, 0,500,500"]).requestedFrames, [0, 500, 1500])
    }

    func testOutputWithoutAnExtensionIsRejectedBeforeRecording() async throws {
        let dir = try makeAndroidProject()
        defer { restoreDirectory(dir) }
        // Refused at parse time (L26-a), so no device is touched.
        XCTAssertThrowsError(try RecordCommand.parse(["--duration", "1", "--output", "clip"])) { error in
            XCTAssertEqual(RecordCommand.exitCode(for: error), .validationFailure, "\(error)")
            XCTAssertTrue(RecordCommand.message(for: error).contains("must end in .mp4"), RecordCommand.message(for: error))
        }
    }

    func testOutputExtensionMustMatchThePlatformsContainer() {
        XCTAssertNil(RecordCommand.outputExtensionProblem("/tmp/a.mov", platform: .ios))
        XCTAssertNil(RecordCommand.outputExtensionProblem("/tmp/a.MOV", platform: .ios))
        XCTAssertNil(RecordCommand.outputExtensionProblem("/tmp/a.mp4", platform: .android))
        // simctl writes a QuickTime container whatever the name, so .mp4 on
        // iOS would be a mislabelled file.
        let iosMP4 = RecordCommand.outputExtensionProblem("/tmp/a.mp4", platform: .ios)
        XCTAssertEqual(iosMP4, "--output must end in .mov on iOS (simctl records QuickTime); got /tmp/a.mp4. Try /tmp/a.mov.")
        XCTAssertEqual(
            RecordCommand.outputExtensionProblem("clips/a", platform: .ios),
            "--output must end in .mov on iOS (simctl records QuickTime); got clips/a. Try clips/a.mov."
        )
        XCTAssertNotNil(RecordCommand.outputExtensionProblem("/tmp/a.mov", platform: .android))
    }

    func testIOSMP4OutputIsRejectedBeforeTouchingTheSimulator() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("record-ios-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let previous = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(dir.path)
        defer { restoreDirectory((dir, previous)) }
        // Refused at parse time (L26-a), so the simulator is never touched.
        XCTAssertThrowsError(
            try RecordCommand.parse(["--duration", "1", "--platform", "ios", "--simulator", "Fake", "--output", "clip.mp4"])
        ) { error in
            XCTAssertEqual(RecordCommand.exitCode(for: error), .validationFailure, "\(error)")
            XCTAssertTrue(RecordCommand.message(for: error).contains("must end in .mov"), RecordCommand.message(for: error))
        }
    }

    /// A05: a static screen gives screenrecord one frame at 0 ms and a zero
    /// duration. The last frame is held to --duration, so 1000 ms resolves to it.
    func testAndroidStaticScreenRecordingHoldsTheLastFrameToTheRequestedDuration() async throws {
        let dir = try makeAndroidProject()
        defer { restoreDirectory(dir) }
        var command = try RecordCommand.parse(["--duration", "2", "--frames-at", "1000,2000"])
        let fake = FakeDevicePlatform(platform: .android)
        fake.recordingData = try XCTUnwrap(Data(base64Encoded: ScreenrecordFixture.staticScreenBase64))
        command.devicePlatform = InjectedDevicePlatform(fake)
        try await command.run()

        let report = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: ".grantiva/recordings/recording.json"))) as? [String: Any]
        let frames = try XCTUnwrap(report?["frames"] as? [[String: Any]])
        XCTAssertEqual(frames.map { $0["requestedMilliseconds"] as? Int }, [1000, 2000])
        XCTAssertEqual(frames.map { $0["actualMilliseconds"] as? Int }, [0, 0], "the held frame is the one shown")
        // K34-b: the report says when the screen last changed and how long the track ran before the hold.
        XCTAssertEqual(report?["lastFrameMilliseconds"] as? Int, 0)
        XCTAssertEqual(report?["recordedMilliseconds"] as? Int, 0)
        for frame in frames {
            XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(frame["path"] as? String)))
        }
        let duration = try await AVURLAsset(url: URL(fileURLWithPath: ".grantiva/recordings/recording.mp4")).load(.duration)
        XCTAssertEqual(CMTimeGetSeconds(duration), 2, accuracy: 0.01)
    }

    /// K84: a frame past --duration is refused before anything is recorded.
    func testAndroidFrameBeyondTheRequestedDurationIsRefusedBeforeRecording() throws {
        XCTAssertThrowsError(try RecordCommand.parse(["--duration", "2", "--frames-at", "2500"])) { error in
            XCTAssertEqual(RecordCommand.message(for: error), "--frames-at 2500 is past --duration 2 (2000 ms).")
        }
    }

    // MARK: - K34: the held-frame note and its statistics

    /// K34-a: frames at 0 ms and 50 ms held to 2 s: the last frame is at 50 ms,
    /// the value the JSON report gives for a frame requested after it.
    func testHeldRecordingNoteNamesTheLastFramesStart() throws {
        let timing = MP4LastFrameHold.Timing(frameCount: 2, lastFrameSeconds: 0.050, recordedSeconds: 0.100)
        let note = try XCTUnwrap(RecordCommand.heldRecordingNote(timing: timing, requestedSeconds: 2))
        XCTAssertTrue(note.contains("last frame is at 50ms"), note)
        XCTAssertFalse(note.contains("100ms"), note)
    }

    /// K34-b: the note prints when the last frame stays on screen for more
    /// than half of the requested duration, and not at exactly half.
    func testHeldRecordingNoteThresholdBoundary() {
        func note(_ lastFrame: Double) -> String? {
            RecordCommand.heldRecordingNote(
                timing: .init(frameCount: 2, lastFrameSeconds: lastFrame, recordedSeconds: lastFrame + 0.05), requestedSeconds: 2
            )
        }
        XCTAssertNil(note(1.0), "held exactly half")
        XCTAssertNotNil(note(0.999), "held more than half")
        XCTAssertNil(note(1.5))
    }

    /// K34-b: screenrecord gave the last frame (at 33 ms) a sample delta that
    /// already reaches the requested length, so nothing was rewritten; the
    /// frame was still on screen for nearly all of it, so the note prints.
    func testNotePrintsWhenTheRecorderAlreadyStretchedTheLastFrame() throws {
        let timing = MP4LastFrameHold.Timing(frameCount: 2, lastFrameSeconds: 0.033, recordedSeconds: 4.02)
        let diagnostics = RecordCommand.holdDiagnostics(.unchanged(timing), requestedSeconds: 4)
        XCTAssertNotNil(diagnostics.note)
        XCTAssertEqual(
            diagnostics.statistics,
            "Held frame: frames=2 lastFrame=33ms trackEnd=4020ms requested=4000ms lastFrameOnScreen=3967ms held=0ms noteThreshold=>2000ms note=printed"
        )
    }

    func testStatisticsExplainAMissingNote() {
        let late = RecordCommand.holdDiagnostics(
            .held(.init(frameCount: 3, lastFrameSeconds: 2.5, recordedSeconds: 2.55)), requestedSeconds: 4
        )
        XCTAssertNil(late.note)
        XCTAssertEqual(
            late.statistics,
            "Held frame: frames=3 lastFrame=2500ms trackEnd=2550ms requested=4000ms lastFrameOnScreen=1500ms held=1450ms noteThreshold=>2000ms note=not printed (the screen changed after the halfway point)"
        )
        let unreadable = RecordCommand.holdDiagnostics(.unreadable("no moov box"), requestedSeconds: 4)
        XCTAssertNil(unreadable.note)
        XCTAssertEqual(unreadable.statistics, "Held frame: not held; the recording could not be read (no moov box)")
    }

    // MARK: - K84: --frames-at past --duration

    func testFramesAtPastTheDurationIsAUsageErrorBeforeRecording() throws {
        XCTAssertThrowsError(try RecordCommand.parse(["--duration", "2", "--frames-at", "5000"])) { error in
            XCTAssertEqual(RecordCommand.exitCode(for: error), .validationFailure, "\(error)")
            XCTAssertEqual(RecordCommand.message(for: error), "--frames-at 5000 is past --duration 2 (2000 ms).")
        }
        XCTAssertEqual(try RecordCommand.parse(["--duration", "2", "--frames-at", "0,2000"]).requestedFrames, [0, 2000])
        XCTAssertThrowsError(try RecordCommand.parse(["--duration", "1.5", "--frames-at", "1501"])) { error in
            XCTAssertEqual(RecordCommand.message(for: error), "--frames-at 1501 is past --duration 1.5 (1500 ms).")
        }
    }

    /// K84: a timestamp within --duration passes validation; a recording
    /// that then ends short of it still fails after recording, as before.
    /// iOS has no hold, so the near-empty fixture ends before 1000 ms.
    func testRecordingThatEndsShortOfAValidTimestampStillFailsAfterRecording() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("record-short-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let previous = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(dir.path)
        defer { restoreDirectory((dir, previous)) }
        var command = try RecordCommand.parse(["--duration", "2", "--frames-at", "1000", "--platform", "ios", "--simulator", "Fake"])
        let fake = FakeDevicePlatform(platform: .ios)
        fake.recordingData = try XCTUnwrap(Data(base64Encoded: ScreenrecordFixture.staticScreenBase64))
        command.devicePlatform = InjectedDevicePlatform(fake)
        do {
            try await command.run()
            XCTFail("expected the post-recording error")
        } catch {
            XCTAssertTrue("\(error)".contains("before requested frame 1000ms"), "\(error)")
        }
        XCTAssertTrue(fake.calls.contains { $0.hasPrefix("recordVideo(") }, "\(fake.calls)")
    }

    /// K34-b fix round: when screenrecord already stretched the last frame,
    /// the note says so and gives the track's length, not "held to".
    func testNoteForARecorderStretchedFrameGivesTheTrackLength() throws {
        let timing = MP4LastFrameHold.Timing(frameCount: 2, lastFrameSeconds: 0.033, recordedSeconds: 4.02)
        let note = try XCTUnwrap(RecordCommand.holdDiagnostics(.unchanged(timing), requestedSeconds: 4).note)
        XCTAssertTrue(note.contains("last frame is at 33ms; screenrecord already kept it on screen to the end of the 4020ms track (requested 4.0s)"), note)
        XCTAssertFalse(note.contains("held to the requested"), note)
        let held = try XCTUnwrap(RecordCommand.holdDiagnostics(.held(timing), requestedSeconds: 5).note)
        XCTAssertTrue(held.contains("it was held to the requested 5.0s"), held)
    }

    func testOutcomeTimingAndOutOfRangeDiagnostics() {
        let timing = MP4LastFrameHold.Timing(frameCount: 1, lastFrameSeconds: 0, recordedSeconds: 0)
        XCTAssertEqual(MP4LastFrameHold.Outcome.held(timing).timing, timing)
        XCTAssertEqual(MP4LastFrameHold.Outcome.unchanged(timing).timing, timing)
        XCTAssertNil(MP4LastFrameHold.Outcome.unreadable("x").timing)
        XCTAssertNil(MP4LastFrameHold.Outcome.outOfRange(.infinity).timing)
        let diagnostics = RecordCommand.holdDiagnostics(.outOfRange(.infinity), requestedSeconds: .infinity)
        XCTAssertNil(diagnostics.note)
        XCTAssertEqual(diagnostics.statistics, "Held frame: not held; the requested length infs is out of range")
    }

    // MARK: - K85: one path style per report

    func testRelativeOutputGivesRelativePathsThroughout() async throws {
        let dir = try makeAndroidProject()
        defer { restoreDirectory(dir) }
        var command = try RecordCommand.parse(["--duration", "2", "--frames-at", "1000", "--output", "clips/a.mp4", "--json"])
        let fake = FakeDevicePlatform(platform: .android)
        fake.recordingData = try XCTUnwrap(Data(base64Encoded: ScreenrecordFixture.staticScreenBase64))
        command.devicePlatform = InjectedDevicePlatform(fake)
        try await command.run()

        let report = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: "clips/a.json"))) as? [String: Any]
        XCTAssertEqual(report?["video"] as? String, "clips/a.mp4")
        let frames = try XCTUnwrap(report?["frames"] as? [[String: Any]])
        XCTAssertEqual(frames.compactMap { $0["path"] as? String }, ["clips/a-frames/001000ms.png"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: "clips/a-frames/001000ms.png"))

        // Text mode prints the same relative paths, the frame report included.
        let decoded = try JSONDecoder().decode(RecordReport.self, from: Data(contentsOf: URL(fileURLWithPath: "clips/a.json")))
        XCTAssertEqual(RecordCommand.textLines(decoded, reportPath: RecordCommand.reportPath(forOutput: "clips/a.mp4")), [
            "Recording: clips/a.mp4",
            "Frame report: clips/a.json",
            "  1000ms -> 0ms: clips/a-frames/001000ms.png",
        ])
        XCTAssertEqual(RecordCommand.reportPath(forOutput: "/abs/a.mp4"), "/abs/a.json")
        XCTAssertEqual(RecordCommand.reportPath(forOutput: "a.mov"), "a.json")
    }

    func testAbsoluteOutputGivesAbsolutePathsThroughout() async throws {
        let dir = try makeAndroidProject()
        defer { restoreDirectory(dir) }
        let output = dir.0.appendingPathComponent("abs/a.mp4").path
        var command = try RecordCommand.parse(["--duration", "2", "--frames-at", "1000", "--output", output])
        let fake = FakeDevicePlatform(platform: .android)
        fake.recordingData = try XCTUnwrap(Data(base64Encoded: ScreenrecordFixture.staticScreenBase64))
        command.devicePlatform = InjectedDevicePlatform(fake)
        try await command.run()

        let reportPath = dir.0.appendingPathComponent("abs/a.json").path
        let report = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: reportPath))) as? [String: Any]
        XCTAssertEqual(report?["video"] as? String, output)
        let frames = try XCTUnwrap(report?["frames"] as? [[String: Any]])
        XCTAssertEqual(frames.compactMap { $0["path"] as? String }, [dir.0.appendingPathComponent("abs/a-frames/001000ms.png").path])
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

    /// K41: `--duration -1` is a usage error about the value.
    func testANegativeDurationIsTheRangeErrorNotAMissingValue() {
        XCTAssertThrowsError(try RecordCommand.parse(["--duration", "-1"])) { error in
            XCTAssertEqual(RecordCommand.message(for: error), "--duration must be greater than zero")
            XCTAssertEqual(RecordCommand.exitCode(for: error), .validationFailure)
        }
    }

    /// L26-a: the --output extension error has the usage-error shape: exit
    /// 64, the message, then the Usage and See lines.
    func testTheOutputExtensionErrorPrintsTheUsageLines() {
        for (platform, output, expected) in [("ios", "a.mp4", "mov"), ("android", "a.mov", "mp4"), ("ios", "a", "mov")] {
            let arguments = ["record", "--duration", "2", "--output", output, "--platform", platform]
            XCTAssertThrowsError(try GrantivaCommand.parseAsRoot(arguments)) { error in
                let lines = GrantivaCommand.fullMessage(for: error).components(separatedBy: "\n")
                XCTAssertEqual(lines.first, "Error: " + (RecordCommand.outputExtensionProblem(output, platform: Platform(rawValue: platform)!) ?? ""), "\(lines)")
                XCTAssertTrue(lines.first?.contains("must end in .\(expected)") == true, "\(lines)")
                XCTAssertTrue(lines.count > 1 && lines[1].hasPrefix("Usage: grantiva record"), "\(lines)")
                XCTAssertFalse(lines.joined().contains("Invalid argument"), "\(lines)")
                XCTAssertEqual(GrantivaCommand.exitCode(for: error), .validationFailure)
            }
        }
        XCTAssertNoThrow(try GrantivaCommand.parseAsRoot(["record", "--duration", "2", "--output", "a.mov", "--platform", "ios"]))
    }
}
