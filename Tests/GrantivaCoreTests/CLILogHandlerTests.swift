import Logging
import XCTest
@testable import GrantivaCore

/// The handler exists because swift-log's `StreamLogHandler` renders
///
///     2026-08-29T14:33:17+0000 info com.grantiva.cli: [GrantivaCLI] Runner started
///
/// which is a log record, not something a person watching a build should read.
/// These pin what each level actually looks like.
final class CLILogHandlerTests: XCTestCase {
    private let stamp = "2026-08-29T14:33:17Z"

    private func render(_ level: Logger.Level, _ message: String = "Runner started (detached)") -> String {
        CLILogHandler.format(level: level, message: message, label: "com.grantiva.cli", timestamp: stamp)
    }

    // MARK: - Levels

    func testInfoAndNoticeRenderTheBareMessage() {
        // The point of the handler: at the default level the output is
        // indistinguishable from the line this replaced.
        XCTAssertEqual(render(.info), "Runner started (detached)")
        XCTAssertEqual(render(.notice), "Runner started (detached)")
    }

    func testInfoCarriesNoTimestampLabelOrLevel() {
        let line = render(.info)
        XCTAssertFalse(line.contains(stamp), line)
        XCTAssertFalse(line.contains("com.grantiva.cli"), line)
        XCTAssertFalse(line.contains("info"), line)
    }

    func testWarningUsesTheWordingAlreadyInTheCLI() {
        XCTAssertEqual(
            render(.warning, "failed to start log stream: broken pipe"),
            "Warning: failed to start log stream: broken pipe"
        )
    }

    func testErrorAndCriticalUseTheErrorPrefix() {
        XCTAssertEqual(render(.error, "Timed out waiting for WDA"), "Error: Timed out waiting for WDA")
        XCTAssertEqual(render(.critical, "Timed out waiting for WDA"), "Error: Timed out waiting for WDA")
    }

    func testDebugAndTraceCarryTheTimestampLabelAndLevel() {
        let line = render(.debug, "Booting simulator: iPhone 17")
        XCTAssertEqual(line, "[debug] \(stamp) com.grantiva.cli: Booting simulator: iPhone 17")
        XCTAssertTrue(render(.trace).hasPrefix("[trace] \(stamp) com.grantiva.cli: "))
    }

    func testMetadataAppearsOnlyAtDebugAndTraceAndIsSorted() {
        let metadata: Logger.Metadata = ["udid": "EXACT-UDID", "port": "8430"]
        XCTAssertEqual(
            CLILogHandler.format(
                level: .debug, message: "session", metadata: metadata,
                label: "com.grantiva.cli", timestamp: stamp
            ),
            "[debug] \(stamp) com.grantiva.cli: session port=8430 udid=EXACT-UDID"
        )
        XCTAssertEqual(
            CLILogHandler.format(
                level: .info, message: "session", metadata: metadata,
                label: "com.grantiva.cli", timestamp: stamp
            ),
            "session"
        )
    }

    // MARK: - Wiring

    func testLoggerRoutesThroughTheHandlerAndRespectsTheSharedLevel() {
        let captured = Captured()
        let logger = Logger(label: "com.grantiva.cli") { label in
            CLILogHandler(label: label, sink: { captured.append($0) })
        }

        let original = GrantivaLogLevel.current
        defer { GrantivaLogLevel.current = original }

        GrantivaLogLevel.current = .info
        logger.debug("suppressed at the default level")
        logger.info("Runner ready")
        XCTAssertEqual(captured.lines, ["Runner ready"])

        // --verbose: the level is shared, not baked into the handler instance,
        // so a logger built earlier still picks the change up.
        GrantivaLogLevel.current = .debug
        logger.debug("Preparing runner...")
        XCTAssertEqual(captured.lines.count, 2)
        XCTAssertTrue(captured.lines[1].hasPrefix("[debug] "), captured.lines[1])

        // --quiet: narration goes, warnings stay.
        GrantivaLogLevel.current = .warning
        logger.info("Building MyApp...")
        logger.warning("failed to start log stream")
        XCTAssertEqual(captured.lines.count, 3)
        XCTAssertEqual(captured.lines[2], "Warning: failed to start log stream")
    }

    // MARK: - Verbosity flags

    func testVerbosityDefaultsToInfo() {
        XCTAssertEqual(LogVerbosity.level(for: ["grantiva", "doctor"]), .info)
    }

    func testQuietDropsToWarning() {
        XCTAssertEqual(LogVerbosity.level(for: ["grantiva", "doctor", "--quiet"]), .warning)
    }

    func testVerboseRaisesToDebug() {
        XCTAssertEqual(LogVerbosity.level(for: ["grantiva", "doctor", "--verbose"]), .debug)
    }

    func testVerboseWinsOverQuiet() {
        XCTAssertEqual(LogVerbosity.level(for: ["grantiva", "run", "--quiet", "--verbose"]), .debug)
    }

    private final class Captured: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [String] = []
        func append(_ line: String) { lock.lock(); storage.append(line); lock.unlock() }
        var lines: [String] { lock.lock(); defer { lock.unlock() }; return storage }
    }
}

/// `--quiet` drops everything below `.warning`. Any diagnostic that is the sole
/// explanation for a long silence therefore has to sit at `.warning` or above,
/// or the flag turns a legible wait into an apparent hang.
final class QuietSurvivesLongWaitsTests: XCTestCase {
    func testCapacityWaitIsLoggedAboveTheQuietThreshold() {
        let sessions = [
            ManagedSimulatorSession(
                udid: "EXACT-UDID", name: "APP-652 iPhone 17", sessionId: "APP-652",
                ownerPID: 1, acquiredAt: Date(), state: .active
            )
        ]
        let wait = SimulatorManager.capacityWait(sessions: sessions, maximum: 4)

        XCTAssertEqual(wait.message, "Waiting for simulator capacity (1/4): APP-652 iPhone 17 [APP-652]")

        // The stall this explains runs to GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS
        // \u{2014} ten minutes by default \u{2014} and the caller cannot free a device
        // or raise the cap without being told which sessions hold them.
        let quiet = LogVerbosity.level(for: ["grantiva", "run", "--quiet"])
        XCTAssertGreaterThanOrEqual(
            wait.level, quiet,
            "--quiet would silence the only explanation for a ten-minute wait"
        )
        XCTAssertEqual(wait.level, .warning)
    }

    func testTheQuietThresholdIsWhatThatTestAssumes() {
        // Guards the test above against being satisfied by a lowered threshold.
        XCTAssertEqual(LogVerbosity.level(for: ["--quiet"]), .warning)
        XCTAssertGreaterThan(Logger.Level.warning, Logger.Level.notice)
        XCTAssertGreaterThan(Logger.Level.notice, Logger.Level.info)
    }
}
