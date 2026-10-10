import ArgumentParser
import AVFoundation
import Foundation
import GrantivaCore
import ImageIO
import UniformTypeIdentifiers

/// Grantiva-owned device recording and timestamped frame extraction.
///
/// All device selection and capture mechanics stay in Grantiva: callers never
/// invoke simctl, adb, or Device Hub directly.
struct RecordCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "record",
        abstract: "Record a simulator or emulator and extract PNG frames at exact requested timestamps."
    )

    @OptionGroup var options: GlobalOptions
    @OptionGroup var platformOptions: PlatformOptions

    @Option(name: .long, help: "Simulator name or UDID to record (iOS; reads simulator from grantiva.yml if omitted)")
    var simulator: String?

    @Option(name: .long, help: "AVD name to record, booting it if needed (Android; reads emulator from grantiva-android.yml if omitted)")
    var emulator: String?

    @Option(name: .long, help: "adb serial of an attached emulator or device (Android)")
    var device: String?

    @Option(name: .long, help: "Recording duration in seconds (Android caps a recording at 180)")
    var duration: Double

    @Option(name: .long, help: "Output video path. Must end in .mov on iOS and .mp4 on Android, the containers each platform records (default: .grantiva/recordings/recording.mov on iOS, .mp4 on Android)")
    var output: String?

    @Option(name: .long, help: "Comma-separated frame timestamps in milliseconds, e.g. 0,150,300,600")
    var framesAt: String?

    /// Empty means "make one from the resolved platform"; tests inject a fake.
    var devicePlatform = InjectedDevicePlatform()

    func validate() throws {
        _ = try Self.parseTimestamps(framesAt)
    }

    /// The parsed, de-duplicated `--frames-at` values. `validate()` has
    /// already rejected malformed input by the time `run()` reads this.
    var requestedFrames: [Int] {
        (try? Self.parseTimestamps(framesAt)) ?? []
    }

    static func parseTimestamps(_ framesAt: String?) throws -> [Int] {
        guard let framesAt, !framesAt.isEmpty else { return [] }
        let values = try framesAt.split(separator: ",").map { part -> Int in
            guard let value = Int(part.trimmingCharacters(in: .whitespaces)), value >= 0 else {
                throw ValidationError("--frames-at must contain non-negative integer milliseconds, e.g. 0,150,300; got \(framesAt)")
            }
            return value
        }
        return Array(Set(values)).sorted()
    }

    /// The extension each platform's recorder actually writes: simctl writes
    /// QuickTime whatever the name, and screenrecord writes MPEG-4. A file
    /// named otherwise is mislabelled, and one with no extension cannot be
    /// opened by AVFoundation for frame extraction.
    static func outputExtensionProblem(_ path: String, platform: Platform) -> String? {
        let expected = platform == .ios ? "mov" : "mp4"
        let name = path as NSString
        guard name.pathExtension.lowercased() != expected else { return nil }
        let reason = platform == .ios ? "on iOS (simctl records QuickTime)" : "on Android (screenrecord records MPEG-4)"
        let suggestion = name.deletingPathExtension + "." + expected
        return "--output must end in .\(expected) \(reason); got \(path). Try \(suggestion)."
    }

    static func defaultOutput(for platform: Platform) -> String {
        platform == .ios ? ".grantiva/recordings/recording.mov" : ".grantiva/recordings/recording.mp4"
    }

    /// The device name the platform boots. iOS needs a simulator; Android
    /// may leave it empty and let the platform pick the running emulator.
    static func target(platform: Platform, simulator: String?, emulator: String?, device: String?, config: GrantivaConfig?) throws -> String {
        switch platform {
        case .ios:
            if emulator != nil { throw GrantivaError.invalidArgument("--emulator is an Android option, but this is an iOS project.") }
            if device != nil { throw GrantivaError.invalidArgument("--device is an Android option, but this is an iOS project.") }
            guard let name = simulator ?? config?.simulator else {
                throw GrantivaError.invalidArgument("No simulator named. Pass --simulator or set simulator in grantiva.yml.")
            }
            return name
        case .android:
            if simulator != nil { throw GrantivaError.invalidArgument("--simulator is an iOS option, but this is an Android project.") }
            if device != nil, emulator != nil {
                throw GrantivaError.invalidArgument("--device and --emulator are mutually exclusive; pass one.")
            }
            if let device { _ = try DeviceID.validate(device, flag: "--device") }
            return device ?? emulator ?? config?.android?.emulator ?? ""
        }
    }

    /// A hold longer than half the recording is worth a word: the screen may
    /// simply have been idle, but a disconnected device looks the same.
    static func heldRecordingNote(recordedSeconds: Double, requestedSeconds: Double) -> String? {
        guard requestedSeconds - recordedSeconds > requestedSeconds / 2 else { return nil }
        let recordedMs = Int((recordedSeconds * 1_000).rounded())
        return "The recording's last frame is at \(recordedMs)ms; it was held to the requested \(requestedSeconds)s. "
            + "screenrecord writes frames only when the screen changes, so this is expected for an idle screen; "
            + "if the screen was changing, check that the device stayed connected."
    }

    func run() async throws {
        guard duration > 0 else {
            throw GrantivaError.invalidArgument("--duration must be greater than zero")
        }
        let (platform, config) = try platformOptions.loadConfig()
        let targetName = try Self.target(platform: platform, simulator: simulator, emulator: emulator, device: device, config: config)
        if platform == .android, !(duration.isFinite && duration <= Double(AndroidPlatform.maximumRecordingSeconds)) {
            throw GrantivaError.invalidArgument(
                "Android recordings are capped at \(AndroidPlatform.maximumRecordingSeconds) seconds per file (screenrecord --time-limit); --duration \(duration) is too long."
            )
        }
        let outputPath = output ?? Self.defaultOutput(for: platform)
        if let problem = Self.outputExtensionProblem(outputPath, platform: platform) {
            // A usage error, but it needs the resolved platform, so it is
            // raised here rather than in validate(); ExitCode keeps the
            // usage line out of it.
            GrantivaLog.logger.error("\(problem)")
            throw ExitCode.validationFailure
        }
        let platformDevice = try devicePlatform.make(platform)

        let booted = try await platformDevice.bootDevice(named: targetName)
        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: outputURL)

        try await platformDevice.recordVideo(deviceID: booted.udid, to: outputPath, seconds: duration)
        guard FileManager.default.fileExists(atPath: outputPath) else {
            throw GrantivaError.commandFailed("Grantiva recording produced no video at \(outputPath)", 1)
        }
        if platform == .android {
            // screenrecord writes a frame only when the screen changes, so a
            // static screen ends at its last change: hold that frame to --duration.
            if let recorded = try MP4LastFrameHold.holdFile(atPath: outputPath, toSeconds: duration),
               let note = Self.heldRecordingNote(recordedSeconds: recorded, requestedSeconds: duration) {
                GrantivaLog.logger.warning("\(note)")
            }
        }

        let requested = requestedFrames
        let geometry = try await platformDevice.displayGeometry(deviceID: booted.udid)
        let frames = try await extractFrames(
            from: outputURL,
            requestedMilliseconds: requested,
            expectedPixels: geometry.dimensions
        )
        let report = RecordReport(
            simulator: booted.name,
            udid: booted.udid,
            video: outputPath,
            requestedDurationSeconds: duration,
            frames: frames
        )
        let reportURL = outputURL.deletingPathExtension().appendingPathExtension("json")
        try JSONEncoder.pretty.encode(report).write(to: reportURL)

        if options.json {
            Output.line(try JSONOutput.string(report))
        } else {
            Output.line("Recording: \(outputPath)")
            Output.line("Frame report: \(reportURL.path)")
            for frame in frames {
                Output.line("  \(frame.requestedMilliseconds)ms -> \(frame.actualMilliseconds)ms: \(frame.path)")
            }
        }
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
