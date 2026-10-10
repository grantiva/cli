import AVFoundation
import CoreVideo
import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

/// MP4LastFrameHold against real files: the screenrecord fixture, corrupt
/// copies of it, and a two-frame AVAssetWriter movie AVFoundation must still
/// decode after the hold.
final class MP4LastFrameHoldFixtureTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("mp4hold-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testTruncatedRecordingIsLeftUnchanged() throws {
        let fixture = ScreenrecordFixture.staticScreen
        // Cut inside the ftyp, inside the moov, and inside the trailing mdat.
        for length in [20, 100, 900, fixture.count - 10] {
            let truncated = fixture.prefix(length)
            XCTAssertNil(MP4LastFrameHold.hold(Data(truncated), toSeconds: 2), "length \(length)")
            let path = dir.appendingPathComponent("truncated-\(length).mp4").path
            try Data(truncated).write(to: URL(fileURLWithPath: path))
            XCTAssertNil(try MP4LastFrameHold.holdFile(atPath: path, toSeconds: 2))
            XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: path)), Data(truncated))
        }
    }

    /// Review fix: a 64-bit box size of 2^64-1 used to trap converting to Int.
    func testHugeLargesizeIsLeftUnchanged() throws {
        var bytes = [UInt8](ScreenrecordFixture.staticScreen)
        let moov = try XCTUnwrap(boxOffset("moov", in: bytes))
        bytes.replaceSubrange(moov..<(moov + 4), with: [0, 0, 0, 1])
        bytes.replaceSubrange((moov + 8)..<(moov + 16), with: [UInt8](repeating: 0xFF, count: 8))
        let corrupt = Data(bytes)
        XCTAssertNil(MP4LastFrameHold.hold(corrupt, toSeconds: 2))
        let path = dir.appendingPathComponent("fuzzed.mp4").path
        try corrupt.write(to: URL(fileURLWithPath: path))
        XCTAssertNil(try MP4LastFrameHold.holdFile(atPath: path, toSeconds: 2))
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: path)), corrupt)
    }

    /// Every 32-bit word in the moov overwritten with sizes and counts that
    /// break naive arithmetic: the hold may succeed or decline, never trap.
    func testWordFuzzOverTheMoovNeverTraps() throws {
        let original = [UInt8](ScreenrecordFixture.staticScreen)
        let moov = try XCTUnwrap(boxOffset("moov", in: original))
        let moovEnd = moov + Int(original[moov..<(moov + 4)].reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
        for offset in stride(from: moov, to: moovEnd - 4, by: 4) {
            for word: UInt32 in [0, 1, 7, 0x7FFF_FFFF, 0xFFFF_FFFF] {
                var bytes = original
                for index in 0..<4 { bytes[offset + index] = UInt8(truncatingIfNeeded: word >> (24 - 8 * index)) }
                _ = MP4LastFrameHold.hold(Data(bytes), toSeconds: 2)
            }
        }
    }

    /// A two-sample movie written by AVAssetWriter with the moov first, so
    /// any growth of the moov must shift chunk offsets. After the hold
    /// AVFoundation still loads it, it lasts the requested length, and
    /// 1500 ms shows the frame at 500 ms.
    func testTwoFrameMovieStillDecodesAfterTheHold() async throws {
        let url = dir.appendingPathComponent("two-frames.mp4")
        try await writeTwoFrameMovie(to: url)
        let before = try await AVURLAsset(url: url).load(.duration)
        XCTAssertLessThan(CMTimeGetSeconds(before), 1.5)

        let recorded = try XCTUnwrap(try MP4LastFrameHold.holdFile(atPath: url.path, toSeconds: 2))
        XCTAssertEqual(recorded, CMTimeGetSeconds(before), accuracy: 0.05)

        let asset = AVURLAsset(url: url)
        let after = try await asset.load(.duration)
        XCTAssertEqual(CMTimeGetSeconds(after), 2, accuracy: 0.01)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        for (requested, expected) in [(0, 0), (1_500, 500)] {
            var actual = CMTime.zero
            _ = try generator.copyCGImage(at: CMTime(value: CMTimeValue(requested), timescale: 1_000), actualTime: &actual)
            XCTAssertEqual(Int((CMTimeGetSeconds(actual) * 1_000).rounded()), expected, "requested \(requested)")
        }
    }

    func testHeldRecordingNoteOnlyWhenMoreThanHalfWasHeld() {
        XCTAssertNil(RecordCommand.heldRecordingNote(recordedSeconds: 1.2, requestedSeconds: 2))
        XCTAssertNil(RecordCommand.heldRecordingNote(recordedSeconds: 1.0, requestedSeconds: 2))
        let note = RecordCommand.heldRecordingNote(recordedSeconds: 0, requestedSeconds: 2)
        XCTAssertNotNil(note)
        XCTAssertTrue(note?.contains("last frame is at 0ms") == true, note ?? "")
        XCTAssertTrue(note?.contains("device stayed connected") == true, note ?? "")
    }

    private func boxOffset(_ type: String, in bytes: [UInt8]) -> Int? {
        var offset = 0
        while offset + 8 <= bytes.count {
            let size = Int(bytes[offset..<(offset + 4)].reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
            if String(decoding: bytes[(offset + 4)..<(offset + 8)], as: UTF8.self) == type { return offset }
            guard size >= 8 else { return nil }
            offset += size
        }
        return nil
    }

    private func writeTwoFrameMovie(to url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        for (index, shade) in [UInt8(40), UInt8(220)].enumerated() {
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_32BGRA, nil, &buffer)
            let pixels = try XCTUnwrap(buffer)
            CVPixelBufferLockBaseAddress(pixels, [])
            memset(CVPixelBufferGetBaseAddress(pixels), Int32(shade), CVPixelBufferGetDataSize(pixels))
            CVPixelBufferUnlockBaseAddress(pixels, [])
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            XCTAssertTrue(adaptor.append(pixels, withPresentationTime: CMTime(value: CMTimeValue(index * 500), timescale: 1_000)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, "\(String(describing: writer.error))")
    }
}
