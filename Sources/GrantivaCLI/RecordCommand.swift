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

    // `.unconditional`: `--duration -1` is a value to reject by range, not a
    // missing value followed by an unknown option.
    @Option(name: .long, parsing: .unconditional, help: "Recording duration in seconds (Android caps a recording at 180)")
    var duration: Double

    @Option(name: .long, help: "Output video path. Must end in .mov on iOS and .mp4 on Android, the containers each platform records (default: .grantiva/recordings/recording.mov on iOS, .mp4 on Android)")
    var output: String?

    @Option(name: .long, help: "Comma-separated frame timestamps in milliseconds, e.g. 0,150,300,600")
    var framesAt: String?

    /// Empty means "make one from the resolved platform"; tests inject a fake.
    var devicePlatform = InjectedDevicePlatform()

    func validate() throws {
        guard duration > 0 else {
            throw ValidationError("--duration must be greater than zero")
        }
        let frames = try Self.parseTimestamps(framesAt)
        if let problem = Self.framePastDurationProblem(frames: frames, duration: duration) {
            throw ValidationError(problem)
        }
    }

    /// A requested frame past the end of the recording can be refused before
    /// anything is recorded (and before the previous video is replaced). A
    /// frame exactly at the end is accepted.
    static func framePastDurationProblem(frames: [Int], duration: Double) -> String? {
        guard let last = frames.last, duration.isFinite, duration > 0 else { return nil }
        let durationMilliseconds = duration * 1_000
        guard Double(last) > durationMilliseconds.rounded(.toNearestOrEven) else { return nil }
        let shownDuration = duration.rounded() == duration ? String(Int(duration)) : String(duration)
        return "--frames-at \(last) is past --duration \(shownDuration) (\(Int(durationMilliseconds.rounded())) ms)."
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
            if emulator != nil { throw TargetOptions.otherPlatformFlagError("--emulator", platform: .ios) }
            if device != nil { throw TargetOptions.otherPlatformFlagError("--device", platform: .ios) }
            guard let name = simulator ?? config?.simulator else {
                throw GrantivaError.invalidArgument("No simulator named. Pass --simulator or set simulator in grantiva.yml.")
            }
            return name
        case .android:
            if simulator != nil { throw TargetOptions.otherPlatformFlagError("--simulator", platform: .android) }
            if device != nil, emulator != nil {
                throw GrantivaError.invalidArgument("--device and --emulator are mutually exclusive; pass one.")
            }
            if let device { _ = try DeviceID.validate(device, flag: "--device") }
            return device ?? emulator ?? config?.android?.emulator ?? ""
        }
    }

    /// The last frame on screen for more than half of the recording is worth
    /// a word: the screen may simply have been idle, but a disconnected
    /// device looks the same. Measured from when the last frame appears, so
    /// it holds whether Grantiva stretched that frame or the recorder already
    /// gave it a long sample.
    /// `stretchedByRecorder` is the `.unchanged` case: Grantiva rewrote
    /// nothing because screenrecord already gave the last frame a sample
    /// that reaches the track's end, so the note gives that length instead.
    static func heldRecordingNote(
        timing: MP4LastFrameHold.Timing, requestedSeconds: Double, stretchedByRecorder: Bool = false
    ) -> String? {
        guard requestedSeconds - timing.lastFrameSeconds > requestedSeconds / 2 else { return nil }
        let lastFrameMs = milliseconds(timing.lastFrameSeconds)
        let how = stretchedByRecorder
            ? "screenrecord already kept it on screen to the end of the \(milliseconds(timing.recordedSeconds))ms track (requested \(requestedSeconds)s). "
            : "it was held to the requested \(requestedSeconds)s. "
        return "The recording's last frame is at \(lastFrameMs)ms; " + how
            + "screenrecord writes frames only when the screen changes, so this is expected for an idle screen; "
            + "if the screen was changing, check that the device stayed connected."
    }

    /// The note (when it applies) and the `--verbose` statistics line that
    /// explains it, or its absence.
    static func holdDiagnostics(
        _ outcome: MP4LastFrameHold.Outcome, requestedSeconds: Double
    ) -> (note: String?, statistics: String) {
        let timing: MP4LastFrameHold.Timing
        switch outcome {
        case .held(let value), .trimmed(let value), .unchanged(let value): timing = value
        case .outOfRange(let seconds):
            return (nil, "Held frame: not held; the requested length \(seconds)s is out of range")
        case .unreadable(let reason):
            return (nil, "Held frame: not held; the recording could not be read (\(reason))")
        }
        let stretchedByRecorder = if case .unchanged = outcome { true } else { false }
        let note = heldRecordingNote(timing: timing, requestedSeconds: requestedSeconds, stretchedByRecorder: stretchedByRecorder)
        let requestedMs = milliseconds(requestedSeconds)
        let lastFrameMs = milliseconds(timing.lastFrameSeconds)
        let endMs = milliseconds(timing.recordedSeconds)
        let held = stretchedByRecorder ? 0 : max(requestedMs - endMs, 0)
        let verdict = note != nil ? "printed" : "not printed (the screen changed after the halfway point)"
        // K111: an overrun is trimmed to the request; trackEnd stays the
        // recorded end so the overrun is visible.
        let trim: String
        switch outcome {
        case .trimmed: trim = " trimmed=\(max(endMs - requestedMs, 0))ms"
        case .unchanged where lastFrameMs > requestedMs:
            trim = "; not trimmed: the last frame starts at \(lastFrameMs)ms, after the requested \(requestedMs)ms"
        default: trim = ""
        }
        let statistics = "Held frame: frames=\(timing.frameCount) lastFrame=\(lastFrameMs)ms trackEnd=\(endMs)ms "
            + "requested=\(requestedMs)ms lastFrameOnScreen=\(max(requestedMs - lastFrameMs, 0))ms held=\(held)ms"
            + (trim.hasPrefix(";") ? "" : trim)
            + " noteThreshold=>\(milliseconds(requestedSeconds / 2))ms note=\(verdict)"
            + (trim.hasPrefix(";") ? trim : "")
        return (note, statistics)
    }

    /// The JSON report beside the video, in the style of `--output`.
    static func reportPath(forOutput outputPath: String) -> String {
        sibling(of: outputPath, replacingExtensionWith: "json")
    }

    /// The text-mode result: the video, the report and one line per frame.
    static func textLines(_ report: RecordReport, reportPath: String) -> [String] {
        ["Recording: \(report.video)", "Frame report: \(reportPath)"]
            + report.frames.map { "  \($0.requestedMilliseconds)ms -> \($0.actualMilliseconds)ms: \($0.path)" }
    }

    private static func milliseconds(_ seconds: Double) -> Int { Int((seconds * 1_000).rounded()) }

    /// A path next to `path` in the same style: relative stays relative to the
    /// current directory, absolute stays absolute.
    static func sibling(of path: String, replacingExtensionWith newExtension: String? = nil, appending suffix: String = "") -> String {
        let name = path as NSString
        let stem = (name.lastPathComponent as NSString).deletingPathExtension + suffix
        let file = newExtension.map { "\(stem).\($0)" } ?? stem
        let parent = name.deletingLastPathComponent
        return parent.isEmpty ? file : (parent as NSString).appendingPathComponent(file)
    }

    func run() async throws {
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
        var heldTiming: MP4LastFrameHold.Timing?
        if platform == .android {
            // screenrecord writes a frame only when the screen changes, so a
            // static screen ends at its last change: hold that frame to --duration.
            let outcome = try MP4LastFrameHold.holdFile(atPath: outputPath, toSeconds: duration)
            heldTiming = outcome.timing
            let diagnostics = Self.holdDiagnostics(outcome, requestedSeconds: duration)
            GrantivaLog.logger.debug("\(diagnostics.statistics)")
            if let note = diagnostics.note {
                GrantivaLog.logger.warning("\(note)")
            }
        }

        let requested = requestedFrames
        let geometry = try await platformDevice.displayGeometry(deviceID: booted.udid)
        let frames = try await extractFrames(
            from: outputPath,
            requestedMilliseconds: requested,
            expectedPixels: geometry.dimensions
        )
        let report = RecordReport(
            simulator: booted.name,
            udid: booted.udid,
            emulator: platform == .android ? booted.name : nil,
            serial: platform == .android ? booted.udid : nil,
            video: outputPath,
            requestedDurationSeconds: duration,
            lastFrameMilliseconds: heldTiming.map { Self.milliseconds($0.lastFrameSeconds) },
            recordedMilliseconds: heldTiming.map { Self.milliseconds($0.recordedSeconds) },
            frames: frames
        )
        // Every path in the report and the text output is in the style of
        // --output: relative to the current directory, or absolute.
        let reportPath = Self.reportPath(forOutput: outputPath)
        try JSONEncoder.pretty.encode(report).write(to: URL(fileURLWithPath: reportPath))

        if options.json {
            Output.line(try JSONOutput.string(report))
        } else {
            Self.textLines(report, reportPath: reportPath).forEach(Output.line)
        }
    }

    private func extractFrames(
        from videoPath: String,
        requestedMilliseconds: [Int],
        expectedPixels: SimulatorProvisionResult.Dimensions
    ) async throws -> [RecordFrame] {
        guard !requestedMilliseconds.isEmpty else { return [] }
        let video = URL(fileURLWithPath: videoPath)
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
        let frameDirectoryPath = Self.sibling(of: videoPath, appending: "-frames")
        let frameDirectory = URL(fileURLWithPath: frameDirectoryPath, isDirectory: true)
        try FileManager.default.createDirectory(at: frameDirectory, withIntermediateDirectories: true)

        let frames = try requestedMilliseconds.map { requested in
            let requestedTime = CMTime(value: CMTimeValue(requested), timescale: 1_000)
            var actualTime = CMTime.zero
            let image = try generator.copyCGImage(at: requestedTime, actualTime: &actualTime)
            let fileName = String(format: "%06dms.png", requested)
            let path = frameDirectory.appendingPathComponent(fileName)
            let reportedPath = (frameDirectoryPath as NSString).appendingPathComponent(fileName)
            guard let destination = CGImageDestinationCreateWithURL(path as CFURL, UTType.png.identifier as CFString, 1, nil) else {
                throw GrantivaError.commandFailed("Could not create PNG at \(reportedPath)", 1)
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw GrantivaError.commandFailed("Could not write PNG at \(reportedPath)", 1)
            }
            return RecordFrame(
                requestedMilliseconds: requested,
                actualMilliseconds: Int((CMTimeGetSeconds(actualTime) * 1_000).rounded()),
                path: reportedPath
            )
        }
        try ScreenshotNormalizer.normalize(
            captures: frames.map { .init(screenName: "\($0.requestedMilliseconds)ms", path: $0.path, sizeBytes: 0) },
            expectedPixels: expectedPixels
        )
        return frames
    }
}

/// `simulator` and `udid` name the device on both platforms (kept for
/// compatibility); Android adds the same values as `emulator` (the AVD name,
/// or the serial of a physical device) and `serial`.
struct RecordReport: Codable {
    let simulator: String
    let udid: String
    let emulator: String?
    let serial: String?
    let video: String
    let requestedDurationSeconds: Double
    /// Android only: when the last recorded frame appears (the screen's last
    /// change) and where the track ended before the hold, so a caller can
    /// see why the held-frame note did or did not print.
    let lastFrameMilliseconds: Int?
    let recordedMilliseconds: Int?
    let frames: [RecordFrame]
}

struct RecordFrame: Codable {
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
