import Foundation
import XCTest
@testable import GrantivaCore

final class RunnerSessionCleanupTests: XCTestCase {
    func testCleanupFinishesBeforeSuccessfulOperationReturns() async throws {
        let events = EventLog()

        let result = await RunnerSession.runWithStatusBarCleanup(
            udid: "TEST-UDID",
            clear: { udid in
                try? await Task.sleep(for: .milliseconds(10))
                await events.append("clear:\(udid)")
            },
            operation: {
                await events.append("operation")
                return 42
            }
        )

        XCTAssertEqual(result, 42)
        let values = await events.values
        XCTAssertEqual(values, ["operation", "clear:TEST-UDID"])
    }

    func testTerminationCleanupRestoresCaptureStateAndCleansOrphans() {
        let calls = LockedCalls()
        let fake = RecordingPlatform(calls: calls, restoreDelay: 0)

        RunnerSession.terminationCleanup(platform: fake, deviceID: "emulator-5554")()

        XCTAssertEqual(calls.values, ["restore(emulator-5554)", "cleanupOrphans(emulator-5554)"])
    }

    func testTerminationCleanupGivesUpAfterTheTimeout() {
        let fake = RecordingPlatform(calls: LockedCalls(), restoreDelay: 2)

        let start = Date()
        RunnerSession.terminationCleanup(platform: fake, deviceID: "emulator-5554", timeout: 0.05)()
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.5)
    }

    // MARK: - Ready file (A06)

    /// Without --report-dir the report lives in a temp dir that is deleted as
    /// the run returns, so the ready file must not point a waiter at it.
    func testAnEphemeralReportDirIsNotWrittenToTheReadyFile() async throws {
        let scratch = try FakeRunnerScratch()
        defer { scratch.remove() }

        _ = try await scratch.runFlows(reportDir: nil)

        let state = try ReadyFile.read(scratch.readyFile)
        XCTAssertEqual(state.status, "passed")
        XCTAssertNil(state.reportDir)
    }

    func testAPreservedReportDirIsWrittenToTheReadyFile() async throws {
        let scratch = try FakeRunnerScratch()
        defer { scratch.remove() }
        let reportDir = scratch.root.appendingPathComponent("report").path

        _ = try await scratch.runFlows(reportDir: reportDir)

        let state = try ReadyFile.read(scratch.readyFile)
        XCTAssertEqual(state.reportDir, reportDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(reportDir)/report.json"))
    }

    // MARK: - Interrupt (A06)

    /// The session's own interrupted branch: the runner dies because the relay
    /// reaped it, and the session must publish `interrupted`, not `failed`.
    func testAnInterruptDuringARunningFlowPublishesInterruptedFromTheSession() async throws {
        let scratch = try FakeRunnerScratch()
        defer { scratch.remove() }
        defer { SignalRelay.shared.resetTerminationForTesting() }
        let report = RunnerFailureReport()

        let interrupter = Task.detached {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            SignalRelay.shared.simulateTerminationForTesting()
        }
        do {
            _ = try await scratch.runFlows(
                reportDir: nil,
                reportJSON: #"{"status":"running","flows":[{"index":0,"id":"flow-000","name":"smoke","sourceFile":"@FLOW@","assetsDir":"assets/flow-000","status":"running"}]}"#,
                sleepSeconds: 30,
                failureReport: report
            )
            XCTFail("an interrupted run must not return captures")
        } catch {
            XCTAssertTrue("\(error)".contains("Runner interrupted"), "\(error)")
        }
        _ = try? await interrupter.value

        let state = try ReadyFile.read(scratch.readyFile)
        XCTAssertEqual(state.status, "interrupted")
        XCTAssertEqual(state.flows, [RunReadyState.Flow(name: "smoke", status: "interrupted")])
        XCTAssertNil(state.reportDir)
        XCTAssertEqual(report.captures.first?.steps.last?.status, .failed)
    }

    /// Ctrl-C after every flow passed (how a --keep-alive session is
    /// released): the verdict already published stays `passed`, and the
    /// failure report shows the passed flow.
    func testAnInterruptAfterTheFlowsPassedKeepsThePassedVerdict() async throws {
        let scratch = try FakeRunnerScratch()
        defer { scratch.remove() }
        defer { SignalRelay.shared.resetTerminationForTesting() }
        let report = RunnerFailureReport()

        let interrupter = Task.detached {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            SignalRelay.shared.simulateTerminationForTesting()
        }
        _ = try? await scratch.runFlows(reportDir: nil, sleepSeconds: 30, failureReport: report)
        _ = try? await interrupter.value

        XCTAssertEqual(try ReadyFile.read(scratch.readyFile).status, "passed")
        let captures = report.captures
        XCTAssertFalse(captures.isEmpty)
        XCTAssertTrue(captures.allSatisfy { $0.steps.allSatisfy { $0.status == .passed } })
    }

    // MARK: - Failure report (I12)

    static let failedReport = #"{"status":"failed","flows":[{"index":0,"id":"flow-000","name":"smoke","sourceFile":"@FLOW@","assetsDir":"assets/flow-000","dataFile":"flows/flow-000.json","status":"failed","error":"Element not found: text='Remove'"}]}"#
    static let failedFlow = #"{"id":"flow-000","name":"smoke","commands":[{"id":"cmd-000","type":"launchApp","yaml":"launchApp","status":"passed"},{"id":"cmd-001","type":"tapOn","yaml":"tapOn: text=\"Remove\"","status":"failed","error":{"type":"element_not_found","message":"Element not found: text='Remove'"}},{"id":"cmd-002","type":"takeScreenshot","yaml":"takeScreenshot","status":"skipped"}]}"#

    /// I12: the runner's report is read before the ephemeral report dir is
    /// deleted, so `run --json` can still print the failed step.
    func testARunnerFailureRecordsTheFailedStepBeforeThrowing() async throws {
        let scratch = try FakeRunnerScratch()
        defer { scratch.remove() }
        let report = RunnerFailureReport()

        do {
            _ = try await scratch.runFlows(
                reportDir: nil,
                reportJSON: Self.failedReport,
                flowFiles: ["flow-000.json": Self.failedFlow],
                exitStatus: 1,
                failureReport: report
            )
            XCTFail("a runner that exits 1 must fail the run")
        } catch {
            XCTAssertTrue("\(error)".contains("Runner failed (exit 1)"), "\(error)")
        }

        XCTAssertNil(report.reportDir, "an ephemeral report dir is gone and must not be named")
        let captures = report.captures
        XCTAssertEqual(captures.map(\.screenName), ["smoke"])
        let steps = try XCTUnwrap(captures.first?.steps)
        XCTAssertEqual(steps.map(\.action), ["launchApp", "tapOn: text=\"Remove\""])
        XCTAssertEqual(steps.map(\.status), [.passed, .failed])
        XCTAssertEqual(steps.last?.message, "Element not found: text='Remove'")
    }

    func testARunnerFailureNamesAPreservedReportDir() async throws {
        let scratch = try FakeRunnerScratch()
        defer { scratch.remove() }
        let report = RunnerFailureReport()
        let reportDir = scratch.root.appendingPathComponent("report").path

        _ = try? await scratch.runFlows(
            reportDir: reportDir, reportJSON: Self.failedReport, exitStatus: 1, failureReport: report
        )

        XCTAssertEqual(report.reportDir, reportDir)
        // No per-flow data file: the flow's own status and error still say
        // which flow failed and why.
        let step = try XCTUnwrap(report.captures.first?.steps.first)
        XCTAssertEqual(step.status, .failed)
        XCTAssertEqual(step.message, "Element not found: text='Remove'")
    }
}

private final class LockedCalls: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    func append(_ value: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(value)
    }

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

/// Records the capture-restore calls a termination cleanup makes; every other
/// member is unused by these tests.
private struct RecordingPlatform: DevicePlatform {
    let calls: LockedCalls
    let restoreDelay: TimeInterval
    let platform: Platform = .android

    func bootDevice(named: String) async throws -> BootedDevice { fatalError() }
    func displayGeometry(deviceID: String) async throws -> DeviceGeometry { fatalError() }
    func build(_ request: PlatformBuildRequest) async throws -> BuildResult { fatalError() }
    func install(appID: String, productPath: String, deviceID: String) async throws {}
    func launch(appID: String, deviceID: String) async throws {}
    func terminate(appID: String, deviceID: String) async throws {}
    func uninstall(appID: String, deviceID: String) async throws {}
    func prepareForCapture(deviceID: String) async {}
    func restoreAfterCapture(deviceID: String) async {
        if restoreDelay > 0 { try? await Task.sleep(for: .seconds(restoreDelay)) }
        calls.append("restore(\(deviceID))")
    }
    func runnerGlobalArguments(deviceID: String, appFile: String?) -> [String] { [] }
    func runnerTestArguments() -> [String] { [] }
    func resolveBinary(_ path: String) async throws -> ResolvedBinary { fatalError() }
    func defaultDevice() async throws -> BootedDevice { fatalError() }
    func screenshot(deviceID: String, to path: String) async throws {}
    func logStream(deviceID: String, appID: String?, filter: String?, level: String?) async throws -> LogStreamCommand { fatalError() }
    func runnerEnvironment(runnerHome: String, deviceID: String) -> [String: String] { [:] }
    func cleanupOrphans(deviceID: String) async {
        calls.append("cleanupOrphans(\(deviceID))")
    }
    func attachDriver(deviceID: String, port: UInt16?) async throws -> DriverAttachment { fatalError() }
    func recordVideo(deviceID: String, to path: String, seconds: Double) async throws {}
}

private actor EventLog {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}

/// A scratch project with a stand-in grantiva-runner: a shell script that
/// writes `reportJSON` (and any `flowFiles`) into the `--output` dir it is
/// given and exits with `exitStatus`. `@FLOW@` in the report becomes the
/// staged flow path, as the real runner records it.
struct FakeRunnerScratch {
    let root: URL
    let readyFile: String

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-fake-runner-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        readyFile = root.appendingPathComponent("ready.json").path
        try "appId: com.fake\n---\n- launchApp\n"
            .write(to: root.appendingPathComponent("smoke.yaml"), atomically: true, encoding: .utf8)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    func runFlows(
        reportDir: String?,
        reportJSON: String = #"{"status":"passed","flows":[{"index":0,"id":"flow-000","name":"smoke","sourceFile":"@FLOW@","assetsDir":"assets/flow-000","status":"passed"}]}"#,
        flowFiles: [String: String] = [:],
        exitStatus: Int32 = 0,
        sleepSeconds: Int = 0,
        failureReport: RunnerFailureReport? = nil
    ) async throws -> [ScreenCapture] {
        var script = """
        #!/bin/sh
        while [ $# -gt 0 ]; do
          if [ "$1" = "--output" ]; then out="$2"; shift; fi
          flow="$1"
          shift
        done
        mkdir -p "$out/flows"
        cat > "$out/report.json" <<'GRANTIVA_EOF'
        \(reportJSON)
        GRANTIVA_EOF
        sed -i '' "s|@FLOW@|$flow|g" "$out/report.json"

        """
        for (name, contents) in flowFiles {
            script += """
            cat > "$out/flows/\(name)" <<'GRANTIVA_EOF'
            \(contents)
            GRANTIVA_EOF

            """
        }
        if sleepSeconds > 0 { script += "sleep \(sleepSeconds)\n" }
        script += "exit \(exitStatus)\n"
        let runner = root.appendingPathComponent("fake-runner").path
        try script.write(toFile: runner, atomically: true, encoding: .utf8)
        chmod(runner, 0o755)

        let manager = RunnerManager(ensureAvailable: {}, runnerPath: { runner }, runnerDir: { root.path })
        let flow = root.appendingPathComponent("smoke.yaml").path
        return try await RunnerSession.runFlowFiles(
            at: [flow],
            bundleId: "com.fake",
            udid: "FAKE-\(UUID().uuidString)",
            platform: RecordingPlatform(calls: LockedCalls(), restoreDelay: 0),
            runner: manager,
            outputDir: root.appendingPathComponent("captures").path,
            reportDir: reportDir,
            timeoutSeconds: 30,
            readyFile: readyFile,
            failureReport: failureReport
        )
    }
}
