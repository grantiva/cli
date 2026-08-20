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
        try await Task.sleep(for: .seconds(duration))
        if recorder.isRunning { recorder.terminate() }
        recorder.waitUntilExit()

        guard FileManager.default.fileExists(atPath: output) else {
            let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw GrantivaError.commandFailed("Grantiva recording produced no video: \(message)", recorder.terminationStatus)
        }

        let requested = try parseTimestamps()
        let frames = try extractFrames(from: outputURL, requestedMilliseconds: requested)
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

    private func extractFrames(from video: URL, requestedMilliseconds: [Int]) throws -> [RecordFrame] {
        guard !requestedMilliseconds.isEmpty else { return [] }
        let asset = AVURLAsset(url: video)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let frameDirectory = video.deletingLastPathComponent()
            .appendingPathComponent(video.deletingPathExtension().lastPathComponent + "-frames")
        try FileManager.default.createDirectory(at: frameDirectory, withIntermediateDirectories: true)

        return try requestedMilliseconds.map { requested in
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
                actualMilliseconds: Int((Double(actualTime.value) / Double(actualTime.timescale) * 1_000).rounded()),
                path: path.path
            )
        }
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
