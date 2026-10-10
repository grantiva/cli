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
        var command = try RecordCommand.parse(["--duration", "1", "--output", "clip"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        do {
            try await command.run()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? ExitCode, .validationFailure, "\(error)")
        }
        XCTAssertTrue(fake.calls.isEmpty, "\(fake.calls)")
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
        var command = try RecordCommand.parse(["--duration", "1", "--platform", "ios", "--simulator", "Fake", "--output", "clip.mp4"])
        let fake = FakeDevicePlatform(platform: .ios)
        command.devicePlatform = InjectedDevicePlatform(fake)
        do {
            try await command.run()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? ExitCode, .validationFailure, "\(error)")
        }
        XCTAssertTrue(fake.calls.isEmpty, "\(fake.calls)")
    }

    /// A05: a static screen gives screenrecord one frame at 0 ms and a zero
    /// duration. The last frame is held to --duration, so 1000 ms resolves to it.
    func testAndroidStaticScreenRecordingHoldsTheLastFrameToTheRequestedDuration() async throws {
        let dir = try makeAndroidProject()
        defer { restoreDirectory(dir) }
        var command = try RecordCommand.parse(["--duration", "2", "--frames-at", "1000,2000"])
        let fake = FakeDevicePlatform(platform: .android)
        fake.recordingData = try XCTUnwrap(Data(base64Encoded: Self.staticScreenrecordMP4))
        command.devicePlatform = InjectedDevicePlatform(fake)
        try await command.run()

        let report = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: ".grantiva/recordings/recording.json"))) as? [String: Any]
        let frames = try XCTUnwrap(report?["frames"] as? [[String: Any]])
        XCTAssertEqual(frames.map { $0["requestedMilliseconds"] as? Int }, [1000, 2000])
        XCTAssertEqual(frames.map { $0["actualMilliseconds"] as? Int }, [0, 0], "the held frame is the one shown")
        for frame in frames {
            XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(frame["path"] as? String)))
        }
        let duration = try await AVURLAsset(url: URL(fileURLWithPath: ".grantiva/recordings/recording.mp4")).load(.duration)
        XCTAssertEqual(CMTimeGetSeconds(duration), 2, accuracy: 0.01)
    }

    func testAndroidFrameBeyondTheRequestedDurationStillThrows() async throws {
        let dir = try makeAndroidProject()
        defer { restoreDirectory(dir) }
        var command = try RecordCommand.parse(["--duration", "2", "--frames-at", "2500"])
        let fake = FakeDevicePlatform(platform: .android)
        fake.recordingData = try XCTUnwrap(Data(base64Encoded: Self.staticScreenrecordMP4))
        command.devicePlatform = InjectedDevicePlatform(fake)
        do {
            try await command.run()
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("ended at 2000ms before requested frame 2500ms"), "\(error)")
        }
    }

    /// `screenrecord --size 72x160 --time-limit 1` of an idle Pixel 8 API 35
    /// screen: one H.264 frame at 0 ms, every track duration 0.
    private static let staticScreenrecordMP4 = [
        "AAAAGGZ0eXBtcDQyAAAAAGlzb21tcDQyAAAGUW1vb3YAAABsbXZoZAAAAADm7z9O5u8/TgAAJxAAAAAAAAEAAAEAAAAAAAAAAAAA",
        "AAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAB2bWV0YQAA",
        "ACFoZGxyAAAAAAAAAABtZHRhAAAAAAAAAAAAAAAAAAAAACtrZXlzAAAAAAAAAAEAAAAbbWR0YWNvbS5hbmRyb2lkLnZlcnNpb24A",
        "AAAiaWxzdAAAABoAAAABAAAAEmRhdGEAAAABAAAAADE1AAACG3RyYWsAAABcdGtoZAAAAAfm7z9O5u8/TgAAAAEAAAAAAAAAAAAA",
        "AAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAAAAAASAAAAKAAAAAAAbdtZGlhAAAAIG1kaGQA",
        "AAAA5u8/TubvP04AAV+QAAAAAAAAAAAAAAAsaGRscgAAAAAAAAAAdmlkZQAAAAAAAAAAAAAAAFZpZGVvSGFuZGxlAAAAAWNtaW5m",
        "AAAAFHZtaGQAAAABAAAAAAAAAAAAAAAkZGluZgAAABxkcmVmAAAAAAAAAAEAAAAMdXJsIAAAAAEAAAEjc3RibAAAAKNzdHNkAAAA",
        "AAAAAAEAAACTYXZjMQAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAABIAKAASAAAAEgAAAAAAAAAAQAgICAgICAgICAgICAgICAgICAg",
        "ICAgICAgICAgICAgABj//wAAACphdmNDAULAKf/hABFnQsApjWhRXl5CDAIMDwiEagEABmjOAag1yAAAABNjb2xybmNseAAGAAEA",
        "BgAAAAAYc3R0cwAAAAAAAAABAAAAAQAAAAAAAAAUc3RzcwAAAAAAAAABAAAAAQAAABhzdHN6AAAAAAAAAAAAAAABAAAB2wAAABxz",
        "dHNjAAAAAAAAAAEAAAABAAAAAQAAAAEAAAAYY282NAAAAAAAAAABAAAAAAAADKAAAAGmdHJhawAAAFx0a2hkAAAAB+bvP07m7z9O",
        "AAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAB",
        "Qm1kaWEAAAAgbWRoZAAAAADm7z9O5u8/TgABX5AAAAAAAAAAAAAAACxoZGxyAAAAAAAAAABtZXRhAAAAAAAAAAAAAAAATWV0YWRI",
        "YW5kbGUAAAAA7m1pbmYAAAAMbm1oZAAAAAAAAAAkZGluZgAAABxkcmVmAAAAAAAAAAEAAAAMdXJsIAAAAAEAAAC2c3RibAAAAEpz",
        "dHNkAAAAAAAAAAEAAAA6bWV0dGFwcGxpY2F0aW9uL29jdGV0LXN0cmVhbQBhcHBsaWNhdGlvbi9vY3RldC1zdHJlYW0AAAAAGHN0",
        "dHMAAAAAAAAAAQAAAAEAAAAAAAAAGHN0c3oAAAAAAAAAAAAAAAEAAAAcAAAAHHN0c2MAAAAAAAAAAQAAAAEAAAABAAAAAQAAABhj",
        "bzY0AAAAAAAAAAEAAAAAAAAOowAAAaZ0cmFrAAAAXHRraGQAAAAH5u8/TubvP04AAAADAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "AAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAFCbWRpYQAAACBtZGhkAAAAAObvP07m7z9OAAFf",
        "kAAAAAAAAAAAAAAALGhkbHIAAAAAAAAAAG1ldGEAAAAAAAAAAAAAAABNZXRhZEhhbmRsZQAAAADubWluZgAAAAxubWhkAAAAAAAA",
        "ACRkaW5mAAAAHGRyZWYAAAAAAAAAAQAAAAx1cmwgAAAAAQAAALZzdGJsAAAASnN0c2QAAAAAAAAAAQAAADptZXR0YXBwbGljYXRp",
        "b24vb2N0ZXQtc3RyZWFtAGFwcGxpY2F0aW9uL29jdGV0LXN0cmVhbQAAAAAYc3R0cwAAAAAAAAABAAAAAQAAAAAAAAAYc3RzegAA",
        "AAAAAAAAAAAAAQAAACgAAAAcc3RzYwAAAAAAAAABAAAAAQAAAAEAAAABAAAAGGNvNjQAAAAAAAAAAQAAAAAAAA57AAAGJ2ZyZWUw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw",
        "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwAAAAAW1kYXQA",
        "AAAAAAACLwAAAddluAAEBZ/4lz4TxQABBE/ABcMVHmMPFqOLnq8AImFd/kOxci2Wlk/wSCkJ3+Y1KUN5AY+PvvvvwD+H9/IbEORx",
        "GmhCW+myDgAQZwxZRpY2pgX/ITEMQFYzlFBJvhMMOAAghftRTW9y0q5i+Dp6AtRmUGOViV/+8My4g6l7ieRqvwACCL47CZshfktd",
        "4MV1UW1HPtBHJJ8EfcBBF9Um7t6W3wYvGBeEOIncTiNQkdgCACY5zGOePf+WADDxTBCUVI9738wC6mUN5dic6TuH647AAhsJ3krs",
        "zP/+ABKY2TFLaj9VlBww9sxVliP/Ww/HYACbSTaTaSb/wIuwsRTwjDlaGH///8JQ+dDBioZMNddcnXXXXXXXXXXXXXXXXXXXXXXX",
        "X//H4IOD3l999/9P/gjgAOaHBCK00laSCAgj/7zOSGqMpSZjv4XON05SV9qVV/GItYx41GLEbVr+Hn8NB/Bt0gA2TNoTZSqzLE9J",
        "f9BqAD5ACcroBWakkdwUa+CEJxuSIxStySKKaAAIILUmNk+EopCrzGtV6VYkb8OAFTX8JqAAiMo7uwKisb4ADkdewi15n/2K0AZ+",
        "4QxNEId7jXUCCmUrSeJM3drnIxriEznchP8PInh//RIjVlYxTlNDMFBFVDFNRTIjAgAAALTWKXs6itwYAQAAAEcVysMxewAAI1ZW",
        "MU5TQzBQRVQxTUUhIwEAAAA/9KqJHwAAAA==",
    ].joined()

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
