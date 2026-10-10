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
    /// Rewrites the file in place. Returns false when the file already lasts
    /// `seconds` or is not an MP4 this understands (it is then left untouched).
    @discardableResult
    public static func holdFile(atPath path: String, toSeconds seconds: Double) throws -> Bool {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        guard let held = hold(data, toSeconds: seconds) else { return false }
        try held.write(to: url, options: .atomic)
        return true
    }

    /// The rewritten file, or nil when nothing needs to change.
    public static func hold(_ data: Data, toSeconds seconds: Double) -> Data? {
        guard seconds.isFinite, seconds > 0 else { return nil }
        let bytes = [UInt8](data)
        guard let top = try? parseBoxes(bytes, 0, bytes.count),
              let moovIndex = top.firstIndex(where: { $0.type == "moov" }) else { return nil }
        var moov = top[moovIndex]
        guard var mvhd = moov.child("mvhd"), let movieScale = mvhd.timescale(), movieScale > 0 else { return nil }
        let movieTarget = UInt64((seconds * Double(movieScale)).rounded(.up))

        var changed = false
        for index in moov.children.indices where moov.children[index].type == "trak" {
            if holdTrack(&moov.children[index], seconds: seconds, movieTarget: movieTarget) {
                changed = true
            }
        }
        guard changed else { return nil }
        if (mvhd.duration() ?? 0) < movieTarget { mvhd.setDuration(movieTarget) }
        moov.replaceChild(mvhd)

        let oldSize = top[moovIndex].end - top[moovIndex].start
        var newMoov = moov.serialized()
        let growth = Int64(newMoov.count) - Int64(oldSize)
        if growth != 0 {
            // Chunk offsets that point past the moov move with it.
            moov.shiftChunkOffsets(after: UInt64(top[moovIndex].start), by: growth)
            newMoov = moov.serialized()
        }
        var output = [UInt8]()
        output.reserveCapacity(bytes.count + newMoov.count - oldSize)
        output += bytes[0..<top[moovIndex].start]
        output += newMoov
        output += bytes[top[moovIndex].end..<bytes.count]
        return Data(output)
    }

    private static func holdTrack(_ trak: inout Box, seconds: Double, movieTarget: UInt64) -> Bool {
        guard var mdia = trak.child("mdia"),
              mdia.child("hdlr").map({ $0.handlerType() == "vide" }) == true,
              var mdhd = mdia.child("mdhd"), let mediaScale = mdhd.timescale(), mediaScale > 0,
              var minf = mdia.child("minf"), var stbl = minf.child("stbl"), var stts = stbl.child("stts"),
              var entries = stts.sttsEntries(), !entries.isEmpty
        else { return false }
        let mediaTarget = UInt64((seconds * Double(mediaScale)).rounded())
        let current = entries.reduce(UInt64(0)) { $0 + UInt64($1.count) * UInt64($1.delta) }
        guard current < mediaTarget else { return false }
        let last = entries.removeLast()
        let heldDelta = UInt64(last.delta) + (mediaTarget - current)
        guard heldDelta <= UInt64(UInt32.max) else { return false }
        if last.count > 1 { entries.append((last.count - 1, last.delta)) }
        entries.append((1, UInt32(heldDelta)))
        stts.setSttsEntries(entries)
        stbl.replaceChild(stts); minf.replaceChild(stbl); mdia.replaceChild(minf)
        mdhd.setDuration(mediaTarget); mdia.replaceChild(mdhd)
        trak.replaceChild(mdia)

        if var tkhd = trak.child("tkhd") {
            let previous = tkhd.trackDuration() ?? 0
            if previous < movieTarget {
                tkhd.setTrackDuration(movieTarget); trak.replaceChild(tkhd)
                if var edts = trak.child("edts"), var elst = edts.child("elst") {
                    elst.extendLastEdit(by: movieTarget - previous)
                    edts.replaceChild(elst); trak.replaceChild(edts)
                }
            }
        }
        return true
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
                write64(&payload, offset, read64(payload, offset) + amount)
            } else {
                write32(&payload, offset, UInt32(min(UInt64(read32(payload, offset)) + amount, UInt64(UInt32.max))))
            }
        }

        mutating func shiftChunkOffsets(after position: UInt64, by delta: Int64) {
            if isContainer {
                for index in children.indices { children[index].shiftChunkOffsets(after: position, by: delta) }
                return
            }
            guard type == "stco" || type == "co64", payload.count >= 8 else { return }
            let count = Int(read32(payload, 4))
            let width = type == "co64" ? 8 : 4
            guard payload.count >= 8 + count * width else { return }
            for index in 0..<count {
                let offset = 8 + index * width
                if width == 8 {
                    let value = read64(payload, offset)
                    if value > position { write64(&payload, offset, UInt64(Int64(value) + delta)) }
                } else {
                    let value = UInt64(read32(payload, offset))
                    if value > position { write32(&payload, offset, UInt32(Int64(value) + delta)) }
                }
            }
        }
    }

    private struct Malformed: Error {}

    private static func parseBoxes(_ bytes: [UInt8], _ start: Int, _ end: Int) throws -> [Box] {
        var boxes: [Box] = []
        var offset = start
        while offset + 8 <= end {
            var size = Int(read32(bytes, offset))
            let type = String(decoding: bytes[(offset + 4)..<(offset + 8)], as: UTF8.self)
            var header = 8
            if size == 1 {
                guard offset + 16 <= end else { throw Malformed() }
                size = Int(read64(bytes, offset + 8)); header = 16
            } else if size == 0 {
                size = end - offset
            }
            guard size >= header, offset + size <= end else { throw Malformed() }
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
