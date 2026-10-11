import Foundation

/// Holds the last video frame of an MP4 until a requested duration.
///
/// `screenrecord` writes a frame only when the screen changes, so a recording
/// of a static screen is a single frame at 0 ms with a zero duration, and a
/// recording whose screen stopped changing ends at its last change. This
/// rewrites the container's timing (the last `stts` sample delta and the
/// `mdhd`/`tkhd`/`mvhd`/`elst` durations) so the last frame stays on screen
/// until the requested length. A track that ran past the requested length
/// (screenrecord gives its last frame the previous frame's delta when it
/// stops) has its last sample shortened to end there instead. No frame is
/// re-encoded.
public enum MP4LastFrameHold {
    /// The video track's frames as recorded, before any hold.
    public struct Timing: Sendable, Equatable {
        /// How many frames the track has.
        public let frameCount: Int
        /// When the last frame appears: the moment the screen last changed.
        public let lastFrameSeconds: Double
        /// Where the track ended before the hold (the last frame's end, from
        /// the sample delta the recorder gave it).
        public let recordedSeconds: Double

        public init(frameCount: Int, lastFrameSeconds: Double, recordedSeconds: Double) {
            self.frameCount = frameCount
            self.lastFrameSeconds = lastFrameSeconds
            self.recordedSeconds = recordedSeconds
        }
    }

    public struct Held: Sendable {
        /// The rewritten file.
        public let data: Data
        /// The track's frames before the hold.
        public let timing: Timing
        /// True when the track was shortened to the requested length rather
        /// than lengthened.
        public var trimmed: Bool = false
        /// How long the video ran before the hold (its last frame's end).
        public var recordedSeconds: Double { timing.recordedSeconds }
        /// When the last frame appears.
        public var lastFrameSeconds: Double { timing.lastFrameSeconds }
    }

    /// Why a file could not be read or rewritten.
    public struct Unreadable: Error, Sendable, Equatable {
        public let reason: String
        public init(_ reason: String) { self.reason = reason }
    }

    /// What `holdFile` did.
    public enum Outcome: Sendable, Equatable {
        /// The last frame was held to the requested length.
        case held(Timing)
        /// The track ran past the requested length (the recorder gave the
        /// last frame the previous frame's delta when it stopped); its last
        /// sample was shortened so the track ends at the requested length.
        /// The timing is as recorded, before the trim (K111).
        case trimmed(Timing)
        /// The track already lasted exactly the requested length, or its last
        /// frame starts after it (trimming would drop that frame); the file
        /// is as recorded.
        case unchanged(Timing)
        /// The requested length is not one this can write (not finite, not
        /// positive, or too large for the container's arithmetic). The file
        /// is untouched.
        case outOfRange(Double)
        /// The file is not an MP4 this understands; it is left untouched.
        case unreadable(String)

        /// The track's timing, when the file could be read.
        public var timing: Timing? {
            switch self {
            case .held(let timing), .trimmed(let timing), .unchanged(let timing): return timing
            case .outOfRange, .unreadable: return nil
            }
        }
    }

    /// screenrecord caps a file at 180 s; this bound only keeps the timescale
    /// arithmetic far from overflow.
    static func isInRange(_ seconds: Double) -> Bool {
        seconds.isFinite && seconds > 0 && seconds < 1_000_000
    }

    /// Rewrites the file in place when its last frame must be held, and says
    /// what it found either way.
    public static func holdFile(atPath path: String, toSeconds seconds: Double) throws -> Outcome {
        guard isInRange(seconds) else { return .outOfRange(seconds) }
        let url = URL(fileURLWithPath: path)
        switch process(try Data(contentsOf: url), toSeconds: seconds) {
        case .failure(let error):
            return .unreadable(error.reason)
        case .success(.unchanged(let timing)):
            return .unchanged(timing)
        case .success(.held(let held)):
            try held.data.write(to: url, options: .atomic)
            return held.trimmed ? .trimmed(held.timing) : .held(held.timing)
        }
    }

    /// The video track's frame count, last frame start and end, or why the
    /// file cannot be read. With several video tracks, the longest one.
    public static func timing(of data: Data) -> Result<Timing, Unreadable> {
        parseMovie([UInt8](data)).flatMap { videoTiming(of: $0.top[$0.moovIndex]) }
    }

    /// The rewritten file, or nil when nothing needs to change, the length is
    /// out of range, or the file is malformed. Never traps on bad input.
    public static func hold(_ data: Data, toSeconds seconds: Double) -> Held? {
        guard isInRange(seconds), case .success(.held(let held)) = process(data, toSeconds: seconds) else { return nil }
        return held
    }

    private enum Processed {
        case held(Held)
        case unchanged(Timing)
    }

    /// Parses the file once, reads the video timing from that parse, and
    /// rewrites the same structure when the last frame needs holding.
    private static func process(_ data: Data, toSeconds seconds: Double) -> Result<Processed, Unreadable> {
        let bytes = [UInt8](data)
        let movie: (top: [Box], moovIndex: Int)
        switch parseMovie(bytes) {
        case .success(let value): movie = value
        case .failure(let error): return .failure(error)
        }
        let (top, moovIndex) = movie
        var moov = top[moovIndex]
        let timing: Timing
        switch videoTiming(of: moov) {
        case .success(let value): timing = value
        case .failure(let error): return .failure(error)
        }
        guard var mvhd = moov.child("mvhd") else { return .failure(Unreadable("the moov has no mvhd box")) }
        guard let movieScale = mvhd.timescale(), movieScale > 0, let movieDuration = mvhd.duration() else {
            return .failure(Unreadable("the mvhd box is too short or has a zero timescale"))
        }
        let movieTarget = UInt64((seconds * Double(movieScale)).rounded(.up))

        var heldAny = false
        var trimmedAny = false
        for index in moov.children.indices where moov.children[index].type == "trak" {
            switch holdTrack(&moov.children[index], seconds: seconds, movieTarget: movieTarget) {
            case .failure(let error): return .failure(error)
            case .success(.held): heldAny = true
            case .success(.trimmed): trimmedAny = true
            case .success(.none): break
            }
        }
        guard heldAny || trimmedAny else { return .success(.unchanged(timing)) }
        if movieDuration < movieTarget { mvhd.setDuration(movieTarget) }
        if trimmedAny, !heldAny {
            // The movie ends with its longest track, now the trimmed one
            // unless another track runs longer.
            let longest = moov.children.filter { $0.type == "trak" }
                .compactMap { $0.child("tkhd")?.trackDuration() }.max() ?? movieTarget
            if movieDuration > longest { mvhd.setDuration(longest) }
        }
        moov.replaceChild(mvhd)

        let oldSize = top[moovIndex].end - top[moovIndex].start
        var newMoov = moov.serialized()
        let growth = Int64(newMoov.count) - Int64(oldSize)
        if growth != 0 {
            // Chunk offsets that point past the moov move with it.
            guard (try? moov.shiftChunkOffsets(after: UInt64(top[moovIndex].start), by: growth)) != nil else {
                return .failure(Unreadable("a stco/co64 chunk offset leaves its range when the moov grows"))
            }
            newMoov = moov.serialized()
        }
        var output = [UInt8]()
        output.reserveCapacity(bytes.count + newMoov.count - oldSize)
        output += bytes[0..<top[moovIndex].start]
        output += newMoov
        output += bytes[top[moovIndex].end..<bytes.count]
        return .success(.held(Held(data: Data(output), timing: timing, trimmed: trimmedAny && !heldAny)))
    }

    private static func parseMovie(_ bytes: [UInt8]) -> Result<(top: [Box], moovIndex: Int), Unreadable> {
        guard let top = try? parseBoxes(bytes, 0, bytes.count) else {
            return .failure(Unreadable("the file's box sizes are malformed"))
        }
        guard let moovIndex = top.firstIndex(where: { $0.type == "moov" }) else {
            return .failure(Unreadable("the file has no moov box (not an MP4, or not finalized)"))
        }
        return .success((top, moovIndex))
    }

    private static func videoTiming(of moov: Box) -> Result<Timing, Unreadable> {
        var best: Timing?
        var reason = "the movie has no video track"
        for trak in moov.children where trak.type == "trak" {
            switch trackTiming(trak) {
            case .success(let timing):
                if timing.recordedSeconds >= (best?.recordedSeconds ?? -1) { best = timing }
            case .failure(let error):
                if error != notVideo { reason = error.reason }
            }
        }
        return best.map { .success($0) } ?? .failure(Unreadable(reason))
    }

    private static let notVideo = Unreadable("not a video track")

    private static func trackTiming(_ trak: Box) -> Result<Timing, Unreadable> {
        // A track without mdia/hdlr is not provably video: skipped, as the
        // hold skips it (L25).
        guard let mdia = trak.child("mdia"),
              mdia.child("hdlr").map({ $0.handlerType() == "vide" }) == true else { return .failure(notVideo) }
        guard let mdhd = mdia.child("mdhd"), let scale = mdhd.timescale(), scale > 0, mdhd.duration() != nil else {
            return .failure(Unreadable("the video track's mdhd box is missing or too short"))
        }
        guard let stts = mdia.child("minf")?.child("stbl")?.child("stts"), let entries = stts.sttsEntries(), !entries.isEmpty else {
            return .failure(Unreadable("the video track has no readable stts box"))
        }
        var end: UInt64 = 0
        var frames: UInt64 = 0
        for entry in entries {
            let (sum, overflow) = end.addingReportingOverflow(UInt64(entry.count) * UInt64(entry.delta))
            guard !overflow else { return .failure(Unreadable("the video track's stts durations overflow")) }
            end = sum
            frames += UInt64(entry.count)
        }
        // The last sample's start is the end minus its own delta; a run of
        // zero samples at the end does not move it.
        let last = entries.last(where: { $0.count > 0 })
        let lastStart = end - UInt64(last?.delta ?? 0)
        return .success(Timing(
            frameCount: Int(frames),
            lastFrameSeconds: Double(lastStart) / Double(scale),
            recordedSeconds: Double(end) / Double(scale)
        ))
    }

    private enum TrackChange { case none, held, trimmed }

    /// Holds a video track's last frame to the requested length, or trims a
    /// track that ran past it (K111): what changed, `.none` for a track that
    /// is not provably video (no mdia or hdlr, L25), already exactly long
    /// enough, or whose last frame starts after the requested length; or the
    /// atom that stopped it.
    private static func holdTrack(_ trak: inout Box, seconds: Double, movieTarget: UInt64) -> Result<TrackChange, Unreadable> {
        guard var mdia = trak.child("mdia"),
              mdia.child("hdlr").map({ $0.handlerType() == "vide" }) == true else { return .success(.none) }
        guard var mdhd = mdia.child("mdhd"), let mediaScale = mdhd.timescale(), mediaScale > 0, mdhd.duration() != nil else {
            return .failure(Unreadable("the video track's mdhd box is missing or too short"))
        }
        guard var tkhd = trak.child("tkhd"), let previous = tkhd.trackDuration() else {
            return .failure(Unreadable("the video track's tkhd box is missing or too short"))
        }
        guard var minf = mdia.child("minf"), var stbl = minf.child("stbl"), var stts = stbl.child("stts"),
              var entries = stts.sttsEntries(), !entries.isEmpty
        else { return .failure(Unreadable("the video track has no readable stts box")) }
        let mediaTarget = UInt64((seconds * Double(mediaScale)).rounded())
        var current: UInt64 = 0
        for entry in entries {
            let (sum, overflow) = current.addingReportingOverflow(UInt64(entry.count) * UInt64(entry.delta))
            guard !overflow else { return .failure(Unreadable("the video track's stts durations overflow")) }
            current = sum
        }
        if current > mediaTarget {
            // Shorten the last sample so the track ends at the target, never
            // before the last frame starts.
            guard let last = entries.last, last.count > 0 else { return .success(.none) }
            let lastStart = current - UInt64(last.delta)
            guard lastStart < mediaTarget else { return .success(.none) }
            entries.removeLast()
            if last.count > 1 { entries.append((last.count - 1, last.delta)) }
            entries.append((1, UInt32(mediaTarget - lastStart)))
            stts.setSttsEntries(entries)
            stbl.replaceChild(stts); minf.replaceChild(stbl); mdia.replaceChild(minf)
            mdhd.setDuration(mediaTarget); mdia.replaceChild(mdhd)
            trak.replaceChild(mdia)
            if previous > movieTarget {
                tkhd.setTrackDuration(movieTarget); trak.replaceChild(tkhd)
                if var edts = trak.child("edts"), var elst = edts.child("elst") {
                    elst.shortenLastEdit(by: previous - movieTarget)
                    edts.replaceChild(elst); trak.replaceChild(edts)
                }
            }
            return .success(.trimmed)
        }
        guard current < mediaTarget else { return .success(.none) }
        let last = entries.removeLast()
        let heldDelta = UInt64(last.delta) + (mediaTarget - current)
        guard heldDelta <= UInt64(UInt32.max) else {
            return .failure(Unreadable("the held stts sample delta does not fit in 32 bits"))
        }
        if last.count > 1 { entries.append((last.count - 1, last.delta)) }
        entries.append((1, UInt32(heldDelta)))
        stts.setSttsEntries(entries)
        stbl.replaceChild(stts); minf.replaceChild(stbl); mdia.replaceChild(minf)
        mdhd.setDuration(mediaTarget); mdia.replaceChild(mdhd)
        trak.replaceChild(mdia)

        if previous < movieTarget {
            tkhd.setTrackDuration(movieTarget); trak.replaceChild(tkhd)
            if var edts = trak.child("edts"), var elst = edts.child("elst") {
                elst.extendLastEdit(by: movieTarget - previous)
                edts.replaceChild(elst); trak.replaceChild(edts)
            }
        }
        return .success(.held)
    }

    // MARK: - Boxes

    private static let containers: Set<String> = ["moov", "trak", "mdia", "minf", "stbl", "edts"]

    private struct Box {
        var type: String
        var start: Int
        var end: Int
        /// Payload after the header, for leaf boxes.
        var payload: [UInt8]
        var children: [Box]
        var isContainer: Bool

        func child(_ type: String) -> Box? { children.first { $0.type == type } }
        mutating func replaceChild(_ box: Box) {
            if let index = children.firstIndex(where: { $0.type == box.type }) { children[index] = box }
        }

        func serialized() -> [UInt8] {
            let body = isContainer ? children.flatMap { $0.serialized() } : payload
            var out = [UInt8]()
            let size = body.count + 8
            if size > Int(UInt32.max) {
                out += be32(1) + Array(type.utf8) + be64(UInt64(size + 8))
            } else {
                out += be32(UInt32(size)) + Array(type.utf8)
            }
            return out + body
        }

        // Full-box helpers (version in payload[0]).
        var version: UInt8 { payload.first ?? 0 }

        /// mvhd and mdhd share one layout.
        func timescale() -> UInt32? {
            let offset = version == 1 ? 20 : 12
            return payload.count >= offset + 4 ? read32(payload, offset) : nil
        }
        func duration() -> UInt64? {
            if version == 1 { return payload.count >= 32 ? read64(payload, 24) : nil }
            return payload.count >= 20 ? UInt64(read32(payload, 16)) : nil
        }
        mutating func setDuration(_ value: UInt64) {
            if version == 1 { write64(&payload, 24, value) } else { write32(&payload, 16, UInt32(min(value, UInt64(UInt32.max)))) }
        }
        func trackDuration() -> UInt64? {
            if version == 1 { return payload.count >= 36 ? read64(payload, 28) : nil }
            return payload.count >= 24 ? UInt64(read32(payload, 20)) : nil
        }
        mutating func setTrackDuration(_ value: UInt64) {
            if version == 1 { write64(&payload, 28, value) } else { write32(&payload, 20, UInt32(min(value, UInt64(UInt32.max)))) }
        }
        func handlerType() -> String? {
            payload.count >= 12 ? String(decoding: payload[8..<12], as: UTF8.self) : nil
        }
        func sttsEntries() -> [(count: UInt32, delta: UInt32)]? {
            guard payload.count >= 8 else { return nil }
            let count = Int(read32(payload, 4))
            guard payload.count >= 8 + count * 8 else { return nil }
            return (0..<count).map { (read32(payload, 8 + $0 * 8), read32(payload, 12 + $0 * 8)) }
        }
        mutating func setSttsEntries(_ entries: [(count: UInt32, delta: UInt32)]) {
            var out = Array(payload[0..<4]) + be32(UInt32(entries.count))
            for entry in entries { out += be32(entry.count) + be32(entry.delta) }
            payload = out
        }
        mutating func extendLastEdit(by amount: UInt64) {
            guard payload.count >= 8 else { return }
            let count = Int(read32(payload, 4))
            guard count > 0 else { return }
            let entrySize = version == 1 ? 20 : 12
            let offset = 8 + (count - 1) * entrySize
            guard payload.count >= offset + entrySize else { return }
            if version == 1 {
                let (sum, overflow) = read64(payload, offset).addingReportingOverflow(amount)
                write64(&payload, offset, overflow ? .max : sum)
            } else {
                write32(&payload, offset, UInt32(min(UInt64(read32(payload, offset)) + amount, UInt64(UInt32.max))))
            }
        }

        mutating func shortenLastEdit(by amount: UInt64) {
            guard payload.count >= 8 else { return }
            let count = Int(read32(payload, 4))
            guard count > 0 else { return }
            let entrySize = version == 1 ? 20 : 12
            let offset = 8 + (count - 1) * entrySize
            guard payload.count >= offset + entrySize else { return }
            if version == 1 {
                let value = read64(payload, offset)
                write64(&payload, offset, value > amount ? value - amount : 0)
            } else {
                let value = UInt64(read32(payload, offset))
                write32(&payload, offset, UInt32(value > amount ? value - amount : 0))
            }
        }

        mutating func shiftChunkOffsets(after position: UInt64, by delta: Int64) throws {
            if isContainer {
                for index in children.indices { try children[index].shiftChunkOffsets(after: position, by: delta) }
                return
            }
            guard type == "stco" || type == "co64", payload.count >= 8 else { return }
            let count = Int(read32(payload, 4))
            let width = type == "co64" ? 8 : 4
            guard payload.count >= 8 + count * width else { return }
            for index in 0..<count {
                let offset = 8 + index * width
                let value = width == 8 ? read64(payload, offset) : UInt64(read32(payload, offset))
                guard value > position else { continue }
                // Offsets are positive and the moov grows by a few bytes, so a
                // shifted offset only leaves its range in a corrupt file.
                guard value <= UInt64(Int64.max) else { throw Malformed() }
                let (shifted, overflow) = Int64(value).addingReportingOverflow(delta)
                guard !overflow, shifted >= 0 else { throw Malformed() }
                if width == 8 {
                    write64(&payload, offset, UInt64(shifted))
                } else {
                    guard shifted <= Int64(UInt32.max) else { throw Malformed() }
                    write32(&payload, offset, UInt32(shifted))
                }
            }
        }
    }

    private struct Malformed: Error {}

    private static func parseBoxes(_ bytes: [UInt8], _ start: Int, _ end: Int) throws -> [Box] {
        var boxes: [Box] = []
        var offset = start
        while offset + 8 <= end {
            var declared = UInt64(read32(bytes, offset))
            let type = String(decoding: bytes[(offset + 4)..<(offset + 8)], as: UTF8.self)
            var header = 8
            if declared == 1 {
                guard offset + 16 <= end else { throw Malformed() }
                declared = read64(bytes, offset + 8); header = 16
            } else if declared == 0 {
                declared = UInt64(end - offset)
            }
            // Compare in UInt64 before converting: a corrupt size must not trap.
            guard declared >= UInt64(header), declared <= UInt64(end - offset) else { throw Malformed() }
            let size = Int(declared)
            let isContainer = containers.contains(type)
            let children = isContainer ? try parseBoxes(bytes, offset + header, offset + size) : []
            let payload = isContainer ? [] : Array(bytes[(offset + header)..<(offset + size)])
            boxes.append(Box(type: type, start: offset, end: offset + size, payload: payload, children: children, isContainer: isContainer))
            offset += size
        }
        return boxes
    }
}

private func read32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
    bytes[offset..<(offset + 4)].reduce(0) { $0 << 8 | UInt32($1) }
}

private func read64(_ bytes: [UInt8], _ offset: Int) -> UInt64 {
    bytes[offset..<(offset + 8)].reduce(0) { $0 << 8 | UInt64($1) }
}

private func write32(_ bytes: inout [UInt8], _ offset: Int, _ value: UInt32) {
    for index in 0..<4 { bytes[offset + index] = UInt8(truncatingIfNeeded: value >> (24 - 8 * index)) }
}

private func write64(_ bytes: inout [UInt8], _ offset: Int, _ value: UInt64) {
    for index in 0..<8 { bytes[offset + index] = UInt8(truncatingIfNeeded: value >> (56 - 8 * index)) }
}

private func be32(_ value: UInt32) -> [UInt8] {
    (0..<4).map { UInt8(truncatingIfNeeded: value >> (24 - 8 * $0)) }
}

private func be64(_ value: UInt64) -> [UInt8] {
    (0..<8).map { UInt8(truncatingIfNeeded: value >> (56 - 8 * $0)) }
}
