import ArgumentParser
import AVFoundation
import Foundation
import GrantivaCore
import ImageIO
import UniformTypeIdentifiers

/// Grantiva-owned simulator recording and timestamped frame extraction.
///
/// This deliberately keeps all simulator selection and capture mechanics in
/// Grantiva: callers never need to invoke simctl or Device Hub directly.
struct RecordCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "record",
        abstract: "Record a simulator and extract PNG frames at exact requested timestamps."
    )

    @OptionGroup var options: GlobalOptions

    @Option(name: .long, help: "Simulator name or UDID to record")
    var simulator: String

    @Option(name: .long, help: "Recording duration in seconds")
    var duration: Double

    @Option(name: .long, help: "Output .mov path (default: .grantiva/recordings/recording.mov)")
    var output: String = ".grantiva/recordings/recording.mov"

    @Option(name: .long, help: "Comma-separated frame timestamps in milliseconds, e.g. 0,150,300,600")
    var framesAt: String?

    var simulatorManager: SimulatorManager = .live

    func run() async throws {
        guard duration > 0 else {
            throw GrantivaError.invalidArgument("--duration must be greater than zero")
        }
        let device = try await simulatorManager.boot(nameOrUDID: simulator)
        let outputURL = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: outputURL)

        let recorder = Process()
        recorder.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        recorder.arguments = ["simctl", "io", device.udid, "recordVideo", "--codec=h264", output]
        let stderr = Pipe()
        recorder.standardError = stderr
        try recorder.run()
        try await RecorderLifecycle.withCleanup(for: recorder) {
            try await RecorderLifecycle.waitForStart(of: outputURL)
            try await Task.sleep(for: .seconds(duration))
        }

        guard FileManager.default.fileExists(atPath: output) else {
            let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw GrantivaError.commandFailed("Grantiva recording produced no video: \(message)", recorder.terminationStatus)
        }

        let requested = try parseTimestamps()
        let geometry = try await simulatorManager.displayGeometry(udid: device.udid)
        let target = CaptureSimulatorTarget(name: device.name, udid: device.udid, geometry: geometry)
        let frames = try await extractFrames(
            from: outputURL,
            requestedMilliseconds: requested,
            expectedPixels: target.pixelDimensions
        )
        let report = RecordReport(
            simulator: device.name,
            udid: device.udid,
            video: output,
            requestedDurationSeconds: duration,
            frames: frames
        )
        let reportURL = outputURL.deletingPathExtension().appendingPathExtension("json")
        try JSONEncoder.pretty.encode(report).write(to: reportURL)

        if options.json {
            print(try JSONOutput.string(report))
        } else {
            print("Recording: \(output)")
            print("Frame report: \(reportURL.path)")
            for frame in frames {
                print("  \(frame.requestedMilliseconds)ms -> \(frame.actualMilliseconds)ms: \(frame.path)")
            }
        }
    }

    private func parseTimestamps() throws -> [Int] {
        guard let framesAt, !framesAt.isEmpty else { return [] }
        let values = try framesAt.split(separator: ",").map { part -> Int in
            guard let value = Int(part.trimmingCharacters(in: .whitespaces)), value >= 0 else {
                throw GrantivaError.invalidArgument("--frames-at must contain non-negative integer milliseconds")
            }
            return value
        }
        return Array(Set(values)).sorted()
    }

    private func extractFrames(
        from video: URL,
        requestedMilliseconds: [Int],
        expectedPixels: SimulatorProvisionResult.Dimensions
    ) async throws -> [RecordFrame] {
        guard !requestedMilliseconds.isEmpty else { return [] }
        let asset = AVURLAsset(url: video)
        let duration = try await asset.load(.duration)
        guard duration.isNumeric else {
            throw GrantivaError.commandFailed("Grantiva recording has no readable duration", 1)
        }
        let longestRequested = CMTime(value: CMTimeValue(requestedMilliseconds.last!), timescale: 1_000)
        guard CMTimeCompare(duration, longestRequested) >= 0 else {
            let recordedMilliseconds = Int((CMTimeGetSeconds(duration) * 1_000).rounded(.down))
            throw GrantivaError.commandFailed(
                "Grantiva recording ended at \(recordedMilliseconds)ms before requested frame \(requestedMilliseconds.last!)ms",
                1
            )
        }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let frameDirectory = video.deletingLastPathComponent()
            .appendingPathComponent(video.deletingPathExtension().lastPathComponent + "-frames")
        try FileManager.default.createDirectory(at: frameDirectory, withIntermediateDirectories: true)

        let frames = try requestedMilliseconds.map { requested in
            let requestedTime = CMTime(value: CMTimeValue(requested), timescale: 1_000)
            var actualTime = CMTime.zero
            let image = try generator.copyCGImage(at: requestedTime, actualTime: &actualTime)
            let path = frameDirectory.appendingPathComponent(String(format: "%06dms.png", requested))
            guard let destination = CGImageDestinationCreateWithURL(path as CFURL, UTType.png.identifier as CFString, 1, nil) else {
                throw GrantivaError.commandFailed("Could not create PNG at \(path.path)", 1)
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw GrantivaError.commandFailed("Could not write PNG at \(path.path)", 1)
            }
            return RecordFrame(
                requestedMilliseconds: requested,
                actualMilliseconds: Int((CMTimeGetSeconds(actualTime) * 1_000).rounded()),
                path: path.path
            )
        }
        try ScreenshotNormalizer.normalize(
            captures: frames.map { .init(screenName: "\($0.requestedMilliseconds)ms", path: $0.path, sizeBytes: 0) },
            expectedPixels: expectedPixels
        )
        return frames
    }
}

/// Stops simctl recordVideo using the same interrupt semantics as Control-C.
///
/// simctl writes to a staging movie while recording and finalizes/renames it
/// when it receives SIGINT. SIGTERM can leave the requested output empty while
/// the staging file remains behind, especially for short captures.
enum RecorderLifecycle {
    static func withCleanup<T>(for process: Process, operation: () async throws -> T) async rethrows -> T {
        defer { stop(process) }
        return try await operation()
    }

    static func waitForStart(
        of recordingURL: URL,
        attempts: Int = 100,
        pollInterval: Duration = .milliseconds(100)
    ) async throws {
        let directory = recordingURL.deletingLastPathComponent()
        let stagingPrefix = recordingURL.lastPathComponent + ".sb-"
        for _ in 0..<attempts {
            let entries = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            if entries.contains(where: { $0.lastPathComponent.hasPrefix(stagingPrefix) }) {
                return
            }
            try await Task.sleep(for: pollInterval)
        }
        throw GrantivaError.commandFailed("Timed out waiting for simulator recording to start", 1)
    }

    static func stop(_ process: Process) {
        if process.isRunning { process.interrupt() }
        process.waitUntilExit()
    }
}

private struct RecordReport: Codable {
    let simulator: String
    let udid: String
    let video: String
    let requestedDurationSeconds: Double
    let frames: [RecordFrame]
}

private struct RecordFrame: Codable {
    let requestedMilliseconds: Int
    let actualMilliseconds: Int
    let path: String
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
