import Foundation
import XCTest
@testable import GrantivaCore

/// A05: screenrecord writes frames only on change, so the container must be
/// stretched to hold the last frame until the requested duration.
final class MP4LastFrameHoldTests: XCTestCase {
    func testSingleZeroLengthFrameIsHeldToTheRequestedDuration() throws {
        let file = MP4Fixture(stts: [(1, 0)], mdhdDuration: 0, movieDuration: 0)
        let held = try XCTUnwrap(MP4LastFrameHold.hold(file.data, toSeconds: 2)?.data)
        let parsed = MP4Fixture.Parsed(held)
        XCTAssertEqual(parsed.stts, [[1, 180_000]])
        XCTAssertEqual(parsed.mdhdDuration, 180_000)
        XCTAssertEqual(parsed.tkhdDuration, 2_000)
        XCTAssertEqual(parsed.mvhdDuration, 2_000)
        XCTAssertEqual(parsed.elstDuration, 2_000)
        XCTAssertEqual(held.count, file.data.count, "a one-entry stts is rewritten in place")
        XCTAssertEqual(parsed.mdatPayload, MP4Fixture.mdatPayload)
    }

    func testRunOfEqualDeltasIsSplitAndChunkOffsetsFollowTheGrownMoov() throws {
        let file = MP4Fixture(stts: [(3, 3_000)], mdhdDuration: 9_000, movieDuration: 100)
        let held = try XCTUnwrap(MP4LastFrameHold.hold(file.data, toSeconds: 2)?.data)
        let parsed = MP4Fixture.Parsed(held)
        XCTAssertEqual(parsed.stts, [[2, 3_000], [1, 180_000 - 6_000]])
        XCTAssertEqual(held.count, file.data.count + 8)
        XCTAssertEqual(parsed.chunkOffset, file.chunkOffset + 8)
        XCTAssertEqual(Array(held[Int(parsed.chunkOffset)..<Int(parsed.chunkOffset) + 4]), MP4Fixture.mdatPayload)
        XCTAssertEqual(parsed.mvhdDuration, 2_000)
    }

    func testRecordingAlreadyAsLongAsRequestedIsLeftAlone() {
        let file = MP4Fixture(stts: [(60, 3_000)], mdhdDuration: 180_000, movieDuration: 2_000)
        XCTAssertNil(MP4LastFrameHold.hold(file.data, toSeconds: 2))
        XCTAssertNil(MP4LastFrameHold.hold(file.data, toSeconds: 1.5))
    }

    func testVersion1BoxesAreHeldThroughTheir64BitFields() throws {
        let file = MP4Fixture(stts: [(1, 0)], mdhdDuration: 0, movieDuration: 0, version1: true)
        let held = try XCTUnwrap(MP4LastFrameHold.hold(file.data, toSeconds: 2))
        XCTAssertEqual(held.recordedSeconds, 0)
        let parsed = MP4Fixture.Parsed(held.data)
        XCTAssertEqual(parsed.version, 1)
        XCTAssertEqual(parsed.stts, [[1, 180_000]])
        XCTAssertEqual(parsed.mdhdDuration, 180_000)
        XCTAssertEqual(parsed.tkhdDuration, 2_000)
        XCTAssertEqual(parsed.mvhdDuration, 2_000)
        XCTAssertEqual(parsed.elstDuration, 2_000)
        XCTAssertEqual(parsed.mdatPayload, MP4Fixture.mdatPayload)
    }

    func testRecordedSecondsIsTheTrackLengthBeforeTheHold() throws {
        let file = MP4Fixture(stts: [(3, 3_000)], mdhdDuration: 9_000, movieDuration: 100)
        XCTAssertEqual(try XCTUnwrap(MP4LastFrameHold.hold(file.data, toSeconds: 2)).recordedSeconds, 0.1, accuracy: 0.0001)
    }

    /// Review fix: a header box too short to hold its duration is malformed,
    /// not a duration of 0 to be written past the end of the payload.
    func testShortHeaderBoxesAreLeftAloneInsteadOfTrapping() {
        for box in ["mvhd", "mdhd", "tkhd"] {
            for version1 in [false, true] {
                let file = MP4Fixture(stts: [(1, 0)], mdhdDuration: 0, movieDuration: 0, version1: version1, truncating: box)
                XCTAssertNil(MP4LastFrameHold.hold(file.data, toSeconds: 2), "\(box) v\(version1 ? 1 : 0)")
            }
        }
    }

    func testNonMP4InputIsLeftAlone() {
        XCTAssertNil(MP4LastFrameHold.hold(Data(), toSeconds: 2))
        XCTAssertNil(MP4LastFrameHold.hold(Data("not a movie".utf8), toSeconds: 2))
    }
}

/// ftyp, moov(mvhd, trak(tkhd, edts(elst), mdia(mdhd, hdlr vide, minf(stbl(stts, stco))))), mdat.
private struct MP4Fixture {
    static let mdatPayload: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
    let data: Data
    let chunkOffset: UInt32

    /// `version1` writes 64-bit mvhd/tkhd/mdhd/elst; `truncating` cuts that
    /// leaf box's payload just before its duration field (an mvhd/mdhd keeps
    /// its timescale).
    init(stts: [(UInt32, UInt32)], mdhdDuration: UInt32, movieDuration: UInt32, version1: Bool = false, truncating: String? = nil) {
        func box(_ type: String, _ body: [UInt8]) -> [UInt8] {
            let body = type == truncating ? Array(body.prefix(version1 ? 24 : 16)) : body
            return be(UInt32(body.count + 8)) + Array(type.utf8) + body
        }
        func full(_ type: String, _ body: [UInt8]) -> [UInt8] { box(type, [version1 ? 1 : 0, 0, 0, 0] + body) }
        func time(_ value: UInt32) -> [UInt8] { version1 ? be(0) + be(value) : be(value) }
        func moov(chunkOffset: UInt32) -> [UInt8] {
            let mvhd = full("mvhd", time(0) + time(0) + be(1_000) + time(movieDuration) + [UInt8](repeating: 0, count: 80))
            let tkhd = full("tkhd", time(0) + time(0) + be(1) + be(0) + time(movieDuration) + [UInt8](repeating: 0, count: 60))
            let elst = full("elst", be(1) + time(movieDuration) + time(0) + be(0x0001_0000))
            let mdhd = full("mdhd", time(0) + time(0) + be(90_000) + time(mdhdDuration) + be(0))
            let hdlr = box("hdlr", [0, 0, 0, 0] + be(0) + Array("vide".utf8) + [UInt8](repeating: 0, count: 13))
            let sttsBox = box("stts", [0, 0, 0, 0] + be(UInt32(stts.count)) + stts.flatMap { be($0.0) + be($0.1) })
            let stco = box("stco", [0, 0, 0, 0] + be(1) + be(chunkOffset))
            let stbl = box("stbl", sttsBox + stco)
            let trak = box("trak", tkhd + box("edts", elst) + box("mdia", mdhd + hdlr + box("minf", stbl)))
            return box("moov", mvhd + trak)
        }
        let ftyp = box("ftyp", Array("isom".utf8) + be(0))
        let offset = UInt32(ftyp.count + moov(chunkOffset: 0).count + 8)
        chunkOffset = offset
        data = Data(ftyp + moov(chunkOffset: offset) + box("mdat", Self.mdatPayload))
    }

    struct Parsed {
        var stts: [[UInt32]] = []
        var mdhdDuration: UInt32 = 0
        var tkhdDuration: UInt32 = 0
        var mvhdDuration: UInt32 = 0
        var elstDuration: UInt32 = 0
        var chunkOffset: UInt32 = 0
        var version: UInt8 = 0
        var mdatPayload: [UInt8] = []

        init(_ data: Data) {
            let bytes = [UInt8](data)
            walk(bytes, 0, bytes.count)
        }

        private mutating func walk(_ b: [UInt8], _ start: Int, _ end: Int) {
            var o = start
            while o + 8 <= end {
                let size = Int(read(b, o)); let type = String(decoding: b[(o + 4)..<(o + 8)], as: UTF8.self)
                let p = o + 8
                switch type {
                case "moov", "trak", "edts", "mdia", "minf", "stbl": walk(b, p, o + size)
                // Version-1 fields are 64-bit; the fixtures keep the high word 0.
                case "mvhd": version = b[p]; mvhdDuration = b[p] == 1 ? read(b, p + 28) : read(b, p + 16)
                case "tkhd": tkhdDuration = b[p] == 1 ? read(b, p + 32) : read(b, p + 20)
                case "mdhd": mdhdDuration = b[p] == 1 ? read(b, p + 28) : read(b, p + 16)
                case "elst": elstDuration = b[p] == 1 ? read(b, p + 12) : read(b, p + 8)
                case "stco": chunkOffset = read(b, p + 8)
                case "stts": stts = (0..<Int(read(b, p + 4))).map { [read(b, p + 8 + $0 * 8), read(b, p + 12 + $0 * 8)] }
                case "mdat": mdatPayload = Array(b[p..<(o + size)])
                default: break
                }
                o += size
            }
        }
    }
}

private func be(_ value: UInt32) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: value >> (24 - 8 * $0)) } }
private func read(_ b: [UInt8], _ o: Int) -> UInt32 { b[o..<(o + 4)].reduce(0) { $0 << 8 | UInt32($1) } }
