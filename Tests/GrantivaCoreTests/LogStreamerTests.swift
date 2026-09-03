import Foundation
import XCTest
@testable import GrantivaCore

final class LogStreamerTests: XCTestCase {
    func testDecoderEmitsWholeAndMultipleLines() {
        let decoder = PrefixedLineDecoder()

        XCTAssertEqual(strings(decoder.consume(Data("one\ntwo\n".utf8))), ["[log] one\n", "[log] two\n"])
        XCTAssertEqual(decoder.finish(), [])
    }

    func testDecoderBuffersFragmentedLineAndNewline() {
        let decoder = PrefixedLineDecoder()

        XCTAssertEqual(decoder.consume(Data("hel".utf8)), [])
        XCTAssertEqual(decoder.consume(Data("lo".utf8)), [])
        XCTAssertEqual(strings(decoder.consume(Data("\n".utf8))), ["[log] hello\n"])
    }

    func testDecoderPreservesUTF8ScalarSplitAcrossChunks() {
        let decoder = PrefixedLineDecoder()
        let bytes = Array("a🙂b\n".utf8)

        XCTAssertEqual(decoder.consume(Data(bytes.prefix(3))), [])
        XCTAssertEqual(strings(decoder.consume(Data(bytes.dropFirst(3)))), ["[log] a🙂b\n"])
    }

    func testDecoderStripsCarriageReturnFromCRLF() {
        let decoder = PrefixedLineDecoder()

        XCTAssertEqual(strings(decoder.consume(Data("one\r\ntwo\r\n".utf8))), ["[log] one\n", "[log] two\n"])
    }

    func testDecoderFlushesResidualLineOnlyOnce() {
        let decoder = PrefixedLineDecoder()

        XCTAssertEqual(strings(decoder.consume(Data("complete\npartial".utf8))), ["[log] complete\n"])
        XCTAssertEqual(strings(decoder.finish()), ["[log] partial\n"])
        XCTAssertEqual(decoder.finish(), [])
        XCTAssertEqual(decoder.consume(Data("ignored\n".utf8)), [])
    }

    func testIndependentDecodersDoNotCombinePipeFragments() {
        let stdout = PrefixedLineDecoder()
        let stderr = PrefixedLineDecoder()

        XCTAssertEqual(stdout.consume(Data("out".utf8)), [])
        XCTAssertEqual(stderr.consume(Data("err".utf8)), [])
        XCTAssertEqual(strings(stdout.consume(Data("put\n".utf8))), ["[log] output\n"])
        XCTAssertEqual(strings(stderr.consume(Data("or\n".utf8))), ["[log] error\n"])
    }

    private func strings(_ values: [Data]) -> [String] {
        values.map { String(decoding: $0, as: UTF8.self) }
    }
}
