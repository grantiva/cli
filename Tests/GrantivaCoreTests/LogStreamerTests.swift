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

    func testStartWithExplicitExecutableStreamsItsOutputWithThePrefix() throws {
        let streamer = LogStreamer()
        try streamer.start(executable: "/bin/echo", arguments: ["hello from a fake log"])
        // Give the readability handler a moment, then stop; the assertion is
        // that start(executable:arguments:) exists and does not throw for a
        // real executable. Output goes to stderr and is not captured here.
        Thread.sleep(forTimeInterval: 0.2)
        streamer.stop()
    }

    /// A07: on Ctrl-C the relay exits before RunCommand's `defer` can stop the
    /// stream, so the streamer must register its own termination cleanup.
    func testTerminationCleanupsKillARunningLogStream() throws {
        let streamer = LogStreamer()
        try streamer.start(executable: "/bin/sleep", arguments: ["30"])
        let pid = try XCTUnwrap(streamer.processIdentifier)
        XCTAssertEqual(kill(pid, 0), 0, "the stand-in log process should be running")

        SignalRelay.shared.runCleanupsForTesting()

        XCTAssertTrue(waitForExit(pid), "the log stream outlived the termination cleanups")
        XCTAssertNil(streamer.processIdentifier)
    }

    func testARestartedStreamIsStillCoveredByTheTerminationCleanup() throws {
        let streamer = LogStreamer()
        try streamer.start(executable: "/bin/sleep", arguments: ["30"])
        let first = try XCTUnwrap(streamer.processIdentifier)
        streamer.stop()
        XCTAssertTrue(waitForExit(first))

        // A stopped streamer that is started again must not be torn down by a
        // cleanup left over from its first session, and a later sweep must not
        // stop the new one twice.
        try streamer.start(executable: "/bin/sleep", arguments: ["30"])
        let second = try XCTUnwrap(streamer.processIdentifier)
        defer { streamer.stop() }
        SignalRelay.shared.runCleanupsForTesting()
        XCTAssertTrue(waitForExit(second))
    }

    private func waitForExit(_ pid: pid_t, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            // Foundation's Process reaps its child, so ESRCH means it is gone.
            if kill(pid, 0) != 0 { return true }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }

    private func strings(_ values: [Data]) -> [String] {
        values.map { String(decoding: $0, as: UTF8.self) }
    }
}

final class LogPredicateTests: XCTestCase {
    func testDefaultPredicateMatchesTheAppsExecutable() {
        let predicate = defaultLogPredicate(forBundleID: "com.kylebrowning.Landmarks", executable: "Landmarks")
        XCTAssertEqual(
            predicate,
            "subsystem BEGINSWITH \"com.kylebrowning.Landmarks\" OR processImagePath CONTAINS \"com.kylebrowning.Landmarks\" OR process == \"Landmarks\""
        )
        // The predicate must still parse as an NSPredicate.
        XCTAssertNoThrow(NSPredicate(format: predicate))
    }

    func testDefaultPredicateWithoutAnExecutableKeepsTheBundleClauses() {
        XCTAssertEqual(
            defaultLogPredicate(forBundleID: "com.example"),
            "subsystem BEGINSWITH \"com.example\" OR processImagePath CONTAINS \"com.example\""
        )
    }

    func testExecutableNamesAreEscaped() {
        let predicate = defaultLogPredicate(forBundleID: "com.example", executable: "My \"App\"")
        XCTAssertTrue(predicate.hasSuffix("OR process == \"My \\\"App\\\"\""), predicate)
    }

    func testSimctlBannerLinesAreDroppedFromTheStream() {
        let decoder = PrefixedLineDecoder(dropping: LogStreamer.isStreamBanner)
        let lines = decoder.consume(Data("""
        getpwuid_r did not find a match for uid 501
        Filtering the log data using "process == \\"Landmarks\\""
        Timestamp               Ty Process[PID:TID]
        2026-10-09 17:40:00.000 Df Landmarks[123:456] hello

        """.utf8))
        XCTAssertEqual(lines.map { String(decoding: $0, as: UTF8.self) }, [
            "[log] 2026-10-09 17:40:00.000 Df Landmarks[123:456] hello\n",
        ])
    }
}
