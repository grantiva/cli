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
        XCTAssertEqual(parsed.stts, [[1, 180_000]] as [[UInt32]])
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
        XCTAssertEqual(parsed.stts, [[2, 3_000], [1, 174_000]] as [[UInt32]], "180 000 minus the 6 000 already recorded")
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
        XCTAssertEqual(parsed.stts, [[1, 180_000]] as [[UInt32]])
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

    // MARK: - K34: the last frame's start, the track end, and why nothing was held

    /// K34-a: three 33 ms frames start at 0, 33 and 67 ms; the track ends at 100 ms.
    func testTimingReportsTheLastFramesStartAndTheTrackEnd() throws {
        let file = MP4Fixture(stts: [(3, 3_000)], mdhdDuration: 9_000, movieDuration: 100)
        let timing = try MP4LastFrameHold.timing(of: file.data).get()
        XCTAssertEqual(timing.frameCount, 3)
        XCTAssertEqual(timing.lastFrameSeconds, 0.0667, accuracy: 0.0001)
        XCTAssertEqual(timing.recordedSeconds, 0.1, accuracy: 0.0001)
        let held = try XCTUnwrap(MP4LastFrameHold.hold(file.data, toSeconds: 2))
        XCTAssertEqual(held.lastFrameSeconds, 0.0667, accuracy: 0.0001)
        XCTAssertEqual(held.recordedSeconds, 0.1, accuracy: 0.0001)
    }

    func testASingleFrameStartsAndEndsAtZero() throws {
        let file = MP4Fixture(stts: [(1, 0)], mdhdDuration: 0, movieDuration: 0)
        let timing = try MP4LastFrameHold.timing(of: file.data).get()
        XCTAssertEqual(timing.frameCount, 1)
        XCTAssertEqual(timing.lastFrameSeconds, 0)
        XCTAssertEqual(timing.recordedSeconds, 0)
    }

    /// K34-b: screenrecord can give its last frame a sample delta that
    /// reaches past the requested length. The timing is still reported as
    /// recorded so the caller can tell how long that frame stayed; since
    /// K111 the track is trimmed to the requested length.
    func testHoldFileReportsTheTimingWhenTheTrackAlreadyLastsTheRequestedLength() throws {
        let file = MP4Fixture(stts: [(1, 3_000), (1, 200_000)], mdhdDuration: 203_000, movieDuration: 2_256)
        let url = try temporaryFile(file.data)
        defer { try? FileManager.default.removeItem(at: url) }
        guard case .trimmed(let timing) = try MP4LastFrameHold.holdFile(atPath: url.path, toSeconds: 2) else {
            return XCTFail("expected the overrun to be trimmed")
        }
        XCTAssertEqual(timing.frameCount, 2)
        XCTAssertEqual(timing.lastFrameSeconds, 0.0333, accuracy: 0.0001)
        XCTAssertEqual(timing.recordedSeconds, 2.2556, accuracy: 0.0001)
        XCTAssertEqual(MP4Fixture.Parsed(try Data(contentsOf: url)).stts, [[1, 3_000], [1, 177_000]] as [[UInt32]])
    }

    // MARK: - K111: an overrunning recording is trimmed to the requested length

    /// Frames at 0 and 3.079 s; screenrecord gave the last one the previous
    /// delta, so the track ends at 6.157 s for a 4 s request.
    func testAnOverrunningTrackIsTrimmedToTheRequestedLength() throws {
        let file = MP4Fixture(stts: [(1, 277_088), (1, 277_088)], mdhdDuration: 554_176, movieDuration: 6_157)
        let url = try temporaryFile(file.data)
        defer { try? FileManager.default.removeItem(at: url) }
        guard case .trimmed(let timing) = try MP4LastFrameHold.holdFile(atPath: url.path, toSeconds: 4) else {
            return XCTFail("expected the overrun to be trimmed")
        }
        XCTAssertEqual(timing.recordedSeconds, 6.1575, accuracy: 0.0001, "the pre-trim end stays visible")
        XCTAssertEqual(timing.lastFrameSeconds, 3.0788, accuracy: 0.0001)
        let parsed = MP4Fixture.Parsed(try Data(contentsOf: url))
        XCTAssertEqual(parsed.stts, [[1, 277_088], [1, 82_912]] as [[UInt32]])
        XCTAssertEqual(parsed.mdhdDuration, 360_000)
        XCTAssertEqual(parsed.tkhdDuration, 4_000)
        XCTAssertEqual(parsed.mvhdDuration, 4_000)
        XCTAssertEqual(parsed.elstDuration, 4_000)
        XCTAssertEqual(parsed.mdatPayload, MP4Fixture.mdatPayload)
    }

    func testATrackExactlyAsLongAsRequestedIsUnchanged() throws {
        let file = MP4Fixture(stts: [(1, 277_088), (1, 82_912)], mdhdDuration: 360_000, movieDuration: 4_000)
        let url = try temporaryFile(file.data)
        defer { try? FileManager.default.removeItem(at: url) }
        guard case .unchanged = try MP4LastFrameHold.holdFile(atPath: url.path, toSeconds: 4) else {
            return XCTFail("expected the file to be left as it is")
        }
        XCTAssertEqual(try Data(contentsOf: url), file.data)
    }

    /// The last frame itself starts after the requested length: trimming
    /// would drop it, so the file is left as recorded.
    func testALastFrameAfterTheRequestedLengthIsNotTrimmed() throws {
        let file = MP4Fixture(stts: [(1, 400_000), (1, 100_000)], mdhdDuration: 500_000, movieDuration: 5_556)
        let url = try temporaryFile(file.data)
        defer { try? FileManager.default.removeItem(at: url) }
        guard case .unchanged(let timing) = try MP4LastFrameHold.holdFile(atPath: url.path, toSeconds: 4) else {
            return XCTFail("expected the file to be left as it is")
        }
        XCTAssertGreaterThan(timing.lastFrameSeconds, 4)
        XCTAssertEqual(try Data(contentsOf: url), file.data)
    }

    // MARK: - L25: a malformed extra track does not stop the hold

    func testAnExtraTrackWithoutMdiaIsSkippedInEitherOrder() throws {
        for position in [MP4Fixture.ExtraTrak.Position.after, .before] {
            for kind in [MP4Fixture.ExtraTrak.Kind.noMdia, .mdiaWithoutHdlr] {
                let file = MP4Fixture(
                    stts: [(1, 0)], mdhdDuration: 0, movieDuration: 0,
                    extraTrak: .init(position: position, kind: kind)
                )
                let url = try temporaryFile(file.data)
                defer { try? FileManager.default.removeItem(at: url) }
                guard case .held(let timing) = try MP4LastFrameHold.holdFile(atPath: url.path, toSeconds: 4) else {
                    XCTFail("\(position) \(kind): expected the video track to be held"); continue
                }
                XCTAssertEqual(timing.frameCount, 1)
                let held = try Data(contentsOf: url)
                XCTAssertEqual(MP4Fixture.Parsed(held).stts, [[1, 360_000]] as [[UInt32]], "\(position) \(kind)")
                XCTAssertEqual(MP4Fixture.traks(in: held).filter { !$0.contains(Array("stts".utf8)) },
                               [file.extraTrakBytes], "\(position) \(kind): the extra trak is byte-identical")
            }
        }
    }

    func testAFileWithOnlyAnMdiaLessTrackHasNoVideoTrack() {
        let file = MP4Fixture(stts: [(1, 0)], mdhdDuration: 0, movieDuration: 0, extraTrak: .init(position: .after, kind: .noMdia), omitVideo: true)
        XCTAssertEqual(MP4LastFrameHold.timing(of: file.data), .failure(.init("the movie has no video track")))
    }

    // MARK: - Fixture helpers


    func testHoldFileReportsTheTimingOfAHeldTrack() throws {
        let file = MP4Fixture(stts: [(2, 4_500)], mdhdDuration: 9_000, movieDuration: 100)
        let url = try temporaryFile(file.data)
        defer { try? FileManager.default.removeItem(at: url) }
        guard case .held(let timing) = try MP4LastFrameHold.holdFile(atPath: url.path, toSeconds: 2) else {
            return XCTFail("expected the last frame to be held")
        }
        XCTAssertEqual(timing.frameCount, 2)
        XCTAssertEqual(timing.lastFrameSeconds, 0.05, accuracy: 0.0001)
        XCTAssertEqual(timing.recordedSeconds, 0.1, accuracy: 0.0001)
    }

    /// K34-b: a file the parser cannot read says why instead of a bare nil.
    func testAFileThatCannotBeParsedReportsWhy() throws {
        let url = try temporaryFile(Data("not a movie".utf8))
        defer { try? FileManager.default.removeItem(at: url) }
        guard case .unreadable(let reason) = try MP4LastFrameHold.holdFile(atPath: url.path, toSeconds: 2) else {
            return XCTFail("expected the file to be reported unreadable")
        }
        XCTAssertEqual(reason, "the file's box sizes are malformed")
        // A well-formed file without a movie box names what is missing.
        let ftypOnly = Data([0, 0, 0, 16] + Array("ftyp".utf8) + Array("isom".utf8) + [0, 0, 0, 0])
        XCTAssertEqual(MP4LastFrameHold.timing(of: ftypOnly), .failure(.init("the file has no moov box (not an MP4, or not finalized)")))
        XCTAssertThrowsError(try MP4LastFrameHold.timing(of: Data()).get())
        let truncated = MP4Fixture(stts: [(1, 0)], mdhdDuration: 0, movieDuration: 0, truncating: "mdhd")
        switch MP4LastFrameHold.timing(of: truncated.data) {
        case .success: XCTFail("a truncated mdhd is not a readable track")
        case .failure(let error): XCTAssertFalse(error.reason.isEmpty)
        }
    }

    /// Fix round: an out-of-range length is not "unreadable", and a missing
    /// atom is named.
    func testOutOfRangeLengthAndMissingAtomsAreNamed() throws {
        let file = MP4Fixture(stts: [(1, 0)], mdhdDuration: 0, movieDuration: 0)
        let url = try temporaryFile(file.data)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try MP4LastFrameHold.holdFile(atPath: url.path, toSeconds: .infinity), .outOfRange(.infinity))
        XCTAssertEqual(try MP4LastFrameHold.holdFile(atPath: url.path, toSeconds: 0), .outOfRange(0))
        XCTAssertEqual(try Data(contentsOf: url), file.data)

        for (box, reason) in [
            ("mvhd", "the mvhd box is too short or has a zero timescale"),
            ("tkhd", "the video track's tkhd box is missing or too short"),
        ] {
            let truncated = MP4Fixture(stts: [(1, 0)], mdhdDuration: 0, movieDuration: 0, truncating: box)
            let path = try temporaryFile(truncated.data)
            defer { try? FileManager.default.removeItem(at: path) }
            XCTAssertEqual(try MP4LastFrameHold.holdFile(atPath: path.path, toSeconds: 2), .unreadable(reason), box)
        }
    }

    private func temporaryFile(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("hold-\(UUID().uuidString).mp4")
        try data.write(to: url)
        return url
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
    /// A second `trak` that is not a readable video track (L25).
    struct ExtraTrak {
        enum Position { case before, after }
        enum Kind { case noMdia, mdiaWithoutHdlr }
        let position: Position
        let kind: Kind
    }

    /// The extra trak as written (empty without one).
    let extraTrakBytes: [UInt8]

    init(
        stts: [(UInt32, UInt32)], mdhdDuration: UInt32, movieDuration: UInt32, version1: Bool = false, truncating: String? = nil,
        extraTrak: ExtraTrak? = nil, omitVideo: Bool = false
    ) {
        func box(_ type: String, _ body: [UInt8]) -> [UInt8] {
            let body = type == truncating ? Array(body.prefix(version1 ? 24 : 16)) : body
            return be(UInt32(body.count + 8)) + Array(type.utf8) + body
        }
        func full(_ type: String, _ body: [UInt8]) -> [UInt8] { box(type, [version1 ? 1 : 0, 0, 0, 0] + body) }
        func time(_ value: UInt32) -> [UInt8] { version1 ? be(0) + be(value) : be(value) }
        func extraTrakBox(_ kind: ExtraTrak.Kind) -> [UInt8] {
            let tkhd = full("tkhd", time(0) + time(0) + be(2) + be(0) + time(1_234) + [UInt8](repeating: 0, count: 60))
            switch kind {
            case .noMdia: return box("trak", tkhd)
            case .mdiaWithoutHdlr:
                return box("trak", tkhd + box("mdia", full("mdhd", time(0) + time(0) + be(1_000) + time(1_234) + be(0))))
            }
        }
        func moov(chunkOffset: UInt32) -> [UInt8] {
            let mvhd = full("mvhd", time(0) + time(0) + be(1_000) + time(movieDuration) + [UInt8](repeating: 0, count: 80))
            let tkhd = full("tkhd", time(0) + time(0) + be(1) + be(0) + time(movieDuration) + [UInt8](repeating: 0, count: 60))
            let elst = full("elst", be(1) + time(movieDuration) + time(0) + be(0x0001_0000))
            let mdhd = full("mdhd", time(0) + time(0) + be(90_000) + time(mdhdDuration) + be(0))
            let hdlr = box("hdlr", [0, 0, 0, 0] + be(0) + Array("vide".utf8) + [UInt8](repeating: 0, count: 13))
            let sttsBox = box("stts", [0, 0, 0, 0] + be(UInt32(stts.count)) + stts.flatMap { be($0.0) + be($0.1) })
            let stco = box("stco", [0, 0, 0, 0] + be(1) + be(chunkOffset))
            let stbl = box("stbl", sttsBox + stco)
            let trak = omitVideo ? [] : box("trak", tkhd + box("edts", elst) + box("mdia", mdhd + hdlr + box("minf", stbl)))
            let extra = extraTrak.map { extraTrakBox($0.kind) } ?? []
            return box("moov", mvhd + (extraTrak?.position == .before ? extra + trak : trak + extra))
        }
        extraTrakBytes = extraTrak.map { extraTrakBox($0.kind) } ?? []
        let ftyp = box("ftyp", Array("isom".utf8) + be(0))
        let offset = UInt32(ftyp.count + moov(chunkOffset: 0).count + 8)
        chunkOffset = offset
        data = Data(ftyp + moov(chunkOffset: offset) + box("mdat", Self.mdatPayload))
    }

    /// The raw bytes of every `trak` in the movie.
    static func traks(in data: Data) -> [[UInt8]] {
        let b = [UInt8](data)
        var result: [[UInt8]] = []
        func walk(_ start: Int, _ end: Int) {
            var o = start
            while o + 8 <= end {
                let size = Int(read(b, o)); let type = String(decoding: b[(o + 4)..<(o + 8)], as: UTF8.self)
                if type == "trak" { result.append(Array(b[o..<(o + size)])) }
                if type == "moov" { walk(o + 8, o + size) }
                o += size
            }
        }
        walk(0, b.count)
        return result
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
