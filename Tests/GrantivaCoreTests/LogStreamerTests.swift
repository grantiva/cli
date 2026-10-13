import Foundation
import XCTest
@testable import GrantivaCore

final class LogStreamerTests: XCTestCase {
    func testPIDReusedAfterInventoryNeverReceivesTheInitialSignal() {
        let original = LogStreamer.ProcessIdentity(seconds: 100, microseconds: 1)
        let replacement = LogStreamer.ProcessIdentity(seconds: 100, microseconds: 2)
        var current = original
        var signals: [Int32] = []
        var inventories = 0
        let owner = LogStreamer.OwnedLogChildren(
            deviceID: "DEVICE", marker: "grantiva-log-owned",
            snapshot: { _ in
                inventories += 1
                if inventories > 1 { return "" }
                // The old command was collected, but its PID is reused before
                // the caller signals. Both starts are in the same second.
                current = replacement
                return "500 log stream --predicate \"grantiva-log-owned\" == \"grantiva-log-owned\""
            }, identities: { [500: current] }, identity: { _ in current },
            signal: { pid, _ in signals.append(pid) }
        )
        XCTAssertTrue(owner.stop(gracePeriod: 0.1))
        XCTAssertEqual(signals, [], "the replacement PID was never owned by this run")
    }

    func testPIDReusedBetweenStableDiscoveryAndSignalIsRejected() {
        let original = LogStreamer.ProcessIdentity(seconds: 100, microseconds: 1)
        let replacement = LogStreamer.ProcessIdentity(seconds: 100, microseconds: 2)
        var current = original
        var inventories = 0
        var signals: [Int32] = []
        let owner = LogStreamer.OwnedLogChildren(
            deviceID: "DEVICE", marker: "grantiva-log-owned",
            snapshot: { _ in
                inventories += 1
                if inventories > 2 { return "" }
                if inventories == 2 { current = replacement }
                return "500 log stream --predicate \"grantiva-log-owned\" == \"grantiva-log-owned\""
            }, identities: { [500: current] }, identity: { _ in current },
            signal: { pid, _ in signals.append(pid) }
        )
        XCTAssertTrue(owner.stop(gracePeriod: 0.1))
        XCTAssertEqual(signals, [])
        XCTAssertGreaterThanOrEqual(inventories, 2)
    }

    func testInitialSignalRevalidatesTheExactMarker() {
        let original = LogStreamer.ProcessIdentity(seconds: 100, microseconds: 1)
        var inventories = 0
        var signals: [Int32] = []
        let owner = LogStreamer.OwnedLogChildren(
            deviceID: "DEVICE", marker: "grantiva-log-owned",
            snapshot: { _ in
                inventories += 1
                return inventories == 1
                    ? "500 log stream --predicate \"grantiva-log-owned\" == \"grantiva-log-owned\""
                    : "500 log stream --predicate \"grantiva-log-another-run\" == \"grantiva-log-another-run\""
            }, identities: { [500: original] }, identity: { _ in original },
            signal: { pid, _ in signals.append(pid) }
        )
        XCTAssertTrue(owner.stop(gracePeriod: 0.1))
        XCTAssertEqual(signals, [], "ownership must be revalidated before the first signal")
    }

    func testStalledInventoryIsBoundedAndItsExactChildIsReaped() throws {
        var pid: Int32 = 0
        let began = Date()
        XCTAssertThrowsError(try LogStreamer.processSnapshot(
            deadline: began.addingTimeInterval(0.1), executable: "/bin/sleep", arguments: ["0.5"],
            didSpawn: { pid = $0 }
        ))
        XCTAssertLessThan(Date().timeIntervalSince(began), 0.3)
        XCTAssertGreaterThan(pid, 0)
        XCTAssertNotEqual(kill(pid, 0), 0, "the timed-out inventory child must not be abandoned")
        XCTAssertEqual(errno, ESRCH)
    }

    func testFinalConfirmationInventorySharesTheRemainingCleanupDeadline() throws {
        let original = LogStreamer.ProcessIdentity(seconds: 100, microseconds: 1)
        var inventories = 0
        var inventoryPID: Int32 = 0
        var signals: [Int32] = []
        let began = Date()
        let owner = LogStreamer.OwnedLogChildren(
            deviceID: "DEVICE", marker: "grantiva-log-owned",
            snapshot: { deadline in
                inventories += 1
                if inventories <= 2 { return "500 log stream --predicate grantiva-log-owned" }
                return try LogStreamer.processSnapshot(
                    deadline: deadline, executable: "/bin/sleep", arguments: ["30"],
                    didSpawn: { inventoryPID = $0 }
                )
            }, identities: { [500: original] }, identity: { _ in original },
            signal: { _, signal in signals.append(signal) }
        )
        XCTAssertFalse(owner.stop(gracePeriod: 0.05))
        XCTAssertLessThan(Date().timeIntervalSince(began), 1.4)
        XCTAssertEqual(signals, [SIGTERM])
        XCTAssertEqual(inventories, 3, "no extra unbudgeted confirmation inventory")
        XCTAssertGreaterThan(inventoryPID, 0)
        XCTAssertNotEqual(kill(inventoryPID, 0), 0)
        XCTAssertEqual(errno, ESRCH)
        var status: Int32 = 0
        XCTAssertEqual(waitpid(inventoryPID, &status, WNOHANG), -1)
        XCTAssertEqual(errno, ECHILD, "Foundation must have reaped the inventory child")
    }

    func testInventoryDrainsOutputLargerThanThePipeWithoutBlocking() throws {
        let expected = String(repeating: "x", count: 131_072)
        let actual = try LogStreamer.processSnapshot(
            deadline: Date().addingTimeInterval(2), executable: "/usr/bin/printf", arguments: ["%s", expected]
        )
        XCTAssertEqual(actual, expected)
    }

    func testOwnedLogMatchingRequiresExecutableAndThisRunMarker() {
        let owner = LogStreamer.OwnedLogChildren(deviceID: "DEVICE", marker: "grantiva-log-owned", snapshot: { _ in "" })
        XCTAssertEqual(owner.matchingPIDs(in: """
        500 /usr/bin/log stream --predicate grantiva-log-owned
        501 /usr/bin/python helper.py log stream grantiva-log-owned
        502 log stream --predicate grantiva-log-other
        503 log show --predicate grantiva-log-owned
        504 log stream --predicate grantiva-log-owned-suffix
        505 log stream --predicate prefix-grantiva-log-owned
        """), [500])
    }

    func testFailedChildInventoryIsReportedAsIncompleteCleanup() throws {
        let streamer = LogStreamer()
        streamer.ownedLogChildren = .init(deviceID: "TEST-DEVICE", marker: "grantiva-log-test", snapshot: { _ in throw CocoaError(.fileReadUnknown) })
        try streamer.start(executable: "/usr/bin/true", arguments: [])
        let warning = captureStderr {
            XCTAssertFalse(streamer.stop())
            XCTAssertFalse(streamer.stop(), "a second call must not hide an incomplete cleanup")
        }
        XCTAssertEqual(warning, "Warning: could not confirm log-stream cleanup for TEST-DEVICE (grantiva-log-test).\n")
    }

    func testStopWaitsForTheOwnedLogChildAfterTheWrapperHasExited() throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["30"]
        try child.run()
        let other = Process()
        other.executableURL = URL(fileURLWithPath: "/bin/sleep")
        other.arguments = ["30"]
        try other.run()
        defer {
            if child.isRunning { child.terminate() }; child.waitUntilExit()
            if other.isRunning { other.terminate() }; other.waitUntilExit()
        }
        let streamer = LogStreamer()
        streamer.ownedLogChildren = .init(deviceID: "TEST-DEVICE", marker: "grantiva-log-test-owned", snapshot: { _ in
            let owned = child.isRunning ? "\(child.processIdentifier) log stream --predicate grantiva-log-test-owned\n" : ""
            return owned + "\(other.processIdentifier) log stream --predicate grantiva-log-another-run"
        })
        try streamer.start(executable: "/usr/bin/true", arguments: [])
        let wrapper = try XCTUnwrap(streamer.processIdentifier)
        XCTAssertTrue(waitForExit(wrapper))
        XCTAssertTrue(streamer.stop())
        XCTAssertFalse(child.isRunning, "the remote child must be absent before stop returns")
        XCTAssertTrue(other.isRunning, "another run's log child must survive")
    }

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

    /// K33: `adb logcat` and `simctl spawn … log stream` are named under
    /// --verbose when they start and when they stop.
    func testStartAndStopAreLoggedWithTheCommandLine() throws {
        let streamer = LogStreamer()
        let lines = try SubprocessLog.capturing {
            try streamer.start(executable: "/bin/sleep", arguments: ["30"])
            streamer.stop()
        }
        XCTAssertEqual(lines, ["$ /bin/sleep 30", "stopped by SIGTERM: /bin/sleep 30"])
    }

    private func captureStderr(_ body: () -> Void) -> String {
        let pipe = Pipe()
        let saved = dup(STDERR_FILENO)
        defer { dup2(saved, STDERR_FILENO); close(saved) }
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        body()
        dup2(saved, STDERR_FILENO)
        try? pipe.fileHandleForWriting.close()
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
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
