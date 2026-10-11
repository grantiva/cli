import Foundation

/// Holds the last video frame of an MP4 until a requested duration.
///
/// `screenrecord` writes a frame only when the screen changes, so a recording
/// of a static screen is a single frame at 0 ms with a zero duration, and a
/// recording whose screen stopped changing ends at its last change. This
/// rewrites the container's timing (the last `stts` sample delta and the
/// `mdhd`/`tkhd`/`mvhd`/`elst` durations) so the last frame stays on screen
/// until the requested length. No frame is re-encoded.
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
        /// The track already lasted the requested length; the file is as recorded.
        case unchanged(Timing)
        /// The file is not an MP4 this understands; it is left untouched.
        case unreadable(String)
    }

    /// Rewrites the file in place when its last frame must be held, and says
    /// what it found either way.
    public static func holdFile(atPath path: String, toSeconds seconds: Double) throws -> Outcome {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let timing: Timing
        switch self.timing(of: data) {
        case .success(let value): timing = value
        case .failure(let error): return .unreadable(error.reason)
        }
        if let held = hold(data, toSeconds: seconds) {
            try held.data.write(to: url, options: .atomic)
            return .held(held.timing)
        }
        guard seconds.isFinite, seconds > 0, seconds < 1_000_000 else {
            return .unreadable("the requested length \(seconds)s is out of range")
        }
        // `hold` declines a track that already lasts the requested length;
        // any other refusal is a container it could not rewrite.
        guard timing.recordedSeconds + 0.000_5 >= seconds else {
            return .unreadable("the container's chunk offsets or durations could not be rewritten")
        }
        return .unchanged(timing)
    }

    /// The video track's frame count, last frame start and end, or why the
    /// file cannot be read. With several video tracks, the longest one.
    public static func timing(of data: Data) -> Result<Timing, Unreadable> {
        let bytes = [UInt8](data)
        guard let top = try? parseBoxes(bytes, 0, bytes.count) else {
            return .failure(Unreadable("the file's box sizes are malformed"))
        }
        guard let moov = top.first(where: { $0.type == "moov" }) else {
            return .failure(Unreadable("the file has no moov box (not an MP4, or not finalized)"))
        }
        var best: Timing?
        var reason = "the movie has no video track"
        for trak in moov.children where trak.type == "trak" {
            switch trackTiming(trak) {
            case .success(let timing):
                if timing.recordedSeconds >= (best?.recordedSeconds ?? -1) { best = timing }
            case .failure(let error):
                if error.reason != "not a video track" { reason = error.reason }
            }
        }
        return best.map { .success($0) } ?? .failure(Unreadable(reason))
    }

    private static func trackTiming(_ trak: Box) -> Result<Timing, Unreadable> {
        guard let mdia = trak.child("mdia") else { return .failure(Unreadable("a track has no mdia box")) }
        guard mdia.child("hdlr").map({ $0.handlerType() == "vide" }) == true else {
            return .failure(Unreadable("not a video track"))
        }
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

    /// The rewritten file, or nil when nothing needs to change or the file is
    /// malformed. Never traps on bad input.
    public static func hold(_ data: Data, toSeconds seconds: Double) -> Held? {
        // screenrecord caps a file at 180 s; this bound only keeps the
        // timescale arithmetic far from overflow.
        guard seconds.isFinite, seconds > 0, seconds < 1_000_000 else { return nil }
        let bytes = [UInt8](data)
        guard let top = try? parseBoxes(bytes, 0, bytes.count),
              let moovIndex = top.firstIndex(where: { $0.type == "moov" }) else { return nil }
        var moov = top[moovIndex]
        guard var mvhd = moov.child("mvhd"), let movieScale = mvhd.timescale(), movieScale > 0,
              let movieDuration = mvhd.duration() else { return nil }
        let movieTarget = UInt64((seconds * Double(movieScale)).rounded(.up))

        var recorded: Timing?
        for index in moov.children.indices where moov.children[index].type == "trak" {
            let before = moov.children[index]
            if holdTrack(&moov.children[index], seconds: seconds, movieTarget: movieTarget) != nil,
               case .success(let timing) = trackTiming(before),
               timing.recordedSeconds >= (recorded?.recordedSeconds ?? -1) {
                recorded = timing
            }
        }
        guard let recorded else { return nil }
        if movieDuration < movieTarget { mvhd.setDuration(movieTarget) }
        moov.replaceChild(mvhd)

        let oldSize = top[moovIndex].end - top[moovIndex].start
        var newMoov = moov.serialized()
        let growth = Int64(newMoov.count) - Int64(oldSize)
        if growth != 0 {
            // Chunk offsets that point past the moov move with it.
            guard (try? moov.shiftChunkOffsets(after: UInt64(top[moovIndex].start), by: growth)) != nil else { return nil }
            newMoov = moov.serialized()
        }
        var output = [UInt8]()
        output.reserveCapacity(bytes.count + newMoov.count - oldSize)
        output += bytes[0..<top[moovIndex].start]
        output += newMoov
        output += bytes[top[moovIndex].end..<bytes.count]
        return Held(data: Data(output), timing: recorded)
    }

    /// The track's length in seconds before the hold, or nil when the track
    /// is not video, already long enough, or malformed.
    private static func holdTrack(_ trak: inout Box, seconds: Double, movieTarget: UInt64) -> Double? {
        guard var mdia = trak.child("mdia"),
              mdia.child("hdlr").map({ $0.handlerType() == "vide" }) == true,
              var mdhd = mdia.child("mdhd"), let mediaScale = mdhd.timescale(), mediaScale > 0,
              mdhd.duration() != nil,
              var tkhd = trak.child("tkhd"), let previous = tkhd.trackDuration(),
              var minf = mdia.child("minf"), var stbl = minf.child("stbl"), var stts = stbl.child("stts"),
              var entries = stts.sttsEntries(), !entries.isEmpty
        else { return nil }
        let mediaTarget = UInt64((seconds * Double(mediaScale)).rounded())
        var current: UInt64 = 0
        for entry in entries {
            let (sum, overflow) = current.addingReportingOverflow(UInt64(entry.count) * UInt64(entry.delta))
            guard !overflow else { return nil }
            current = sum
        }
        guard current < mediaTarget else { return nil }
        let last = entries.removeLast()
        let heldDelta = UInt64(last.delta) + (mediaTarget - current)
        guard heldDelta <= UInt64(UInt32.max) else { return nil }
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
        return Double(current) / Double(mediaScale)
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
