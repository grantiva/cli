import ArgumentParser
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class RunCommandTests: XCTestCase {
    func testMixedSuiteDoesNotHoldOrPublishBeforeExternalFlows() async throws {
        var events: [String] = []
        var published = false
        _ = try await RunCommand.runSuite(
            hasScreens: true, hasFlows: true, keepAlive: true, readyFile: "suite.ready", options: Self.failFastOptions,
            runScreens: { hold, ready, _ in
                XCTAssertFalse(hold, "holding here would prevent external flows from starting")
                if ready != nil { published = true }
                events.append("screens")
                return []
            },
            runFlows: { hold, ready, _ in
                XCTAssertFalse(published, "waiters must not be released before external flows")
                XCTAssertTrue(hold)
                XCTAssertEqual(ready, "suite.ready")
                events.append("flows")
                return []
            }
        )
        XCTAssertEqual(events, ["screens", "flows"])
    }

    func testSingleScreenSessionRetainsReadinessAndKeepAlive() async throws {
        _ = try await RunCommand.runSuite(
            hasScreens: true, hasFlows: false, keepAlive: true, readyFile: "suite.ready", options: Self.failFastOptions,
            runScreens: { hold, ready, _ in
                XCTAssertTrue(hold)
                XCTAssertEqual(ready, "suite.ready")
                return []
            },
            runFlows: { _, _, _ in XCTFail("No external flows configured"); return [] }
        )
    }

    func testFailedScreenCaptureCannotBeOverriddenByLaterFlowSuccess() async throws {
        do {
            _ = try await RunCommand.runSuite(
                hasScreens: true, hasFlows: true, keepAlive: true, readyFile: "suite.ready", options: Self.failFastOptions,
                runScreens: { _, _, _ in
                    [ScreenCapture(screenName: "missing", path: "", sizeBytes: 0,
                        steps: [StepResult(action: "Take screenshot", status: .failed, duration: 0)])]
                },
                runFlows: { _, _, _ in XCTFail("Failed captures must stop suite success"); return [] }
            )
            XCTFail("Expected suite failure")
        } catch {
            XCTAssertEqual(error as? ExitCode, .failure)
        }
    }

    private static let failFastOptions = RunCommand.SessionOptions(reportDir: nil, timeoutSeconds: 600, failFast: true)

    // C04: --report-dir, --timeout and --continue-on-failure reach the screens
    // session, not only the flows session.
    func testScreensSessionReceivesReportDirTimeoutAndContinueOnFailure() async throws {
        let command = try RunCommand.parse(["--report-dir", "out", "--timeout", "45", "--continue-on-failure"])
        let expected = RunCommand.SessionOptions(reportDir: "out", timeoutSeconds: 45, failFast: false)
        XCTAssertEqual(command.sessionOptions, expected)
        XCTAssertEqual(try RunCommand.parse([]).sessionOptions,
                       RunCommand.SessionOptions(reportDir: nil, timeoutSeconds: 600, failFast: true))

        var received: RunCommand.SessionOptions?
        _ = try await RunCommand.runSuite(
            hasScreens: true, hasFlows: false, keepAlive: false, readyFile: nil, options: command.sessionOptions,
            runScreens: { _, _, session in received = session; return [] },
            runFlows: { _, _, _ in XCTFail("No external flows configured"); return [] }
        )
        XCTAssertEqual(received, expected)
    }

    // C04: with flows after it, the screens session reports into a subdirectory
    // so the flows session cannot replace its report.json.
    func testMixedSuiteGivesTheScreensSessionItsOwnReportDirectory() async throws {
        let options = RunCommand.SessionOptions(reportDir: "out", timeoutSeconds: 90, failFast: true)
        var screens: RunCommand.SessionOptions?
        var flows: RunCommand.SessionOptions?
        _ = try await RunCommand.runSuite(
            hasScreens: true, hasFlows: true, keepAlive: false, readyFile: nil, options: options,
            runScreens: { _, _, session in screens = session; return [] },
            runFlows: { _, _, session in flows = session; return [] }
        )
        XCTAssertEqual(screens, RunCommand.SessionOptions(reportDir: "out/screens", timeoutSeconds: 90, failFast: true))
        XCTAssertEqual(flows, options)
    }

    // C04 (AND-F06): --continue-on-failure runs every flow after a failed
    // screens session, reports the failure, and publishes `failed`.
    func testContinueOnFailureStillRunsFlowsAfterAThrowingScreensSession() async throws {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("run-suite-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let ready = scratch.appendingPathComponent("suite.ready").path

        var flowsRan = false
        let captures = try await RunCommand.runSuite(
            hasScreens: true, hasFlows: true, keepAlive: false, readyFile: ready,
            options: RunCommand.SessionOptions(reportDir: nil, timeoutSeconds: 600, failFast: false),
            runScreens: { _, ready, _ in
                XCTAssertNil(ready)
                throw GrantivaError.commandFailed("Runner failed (exit 1)", 1)
            },
            runFlows: { _, ready, _ in
                flowsRan = true
                try ReadyFile.write(RunReadyState(status: "passed", flows: [.init(name: "smoke", status: "passed")]), to: ready!)
                return [ScreenCapture(screenName: "smoke", path: "", sizeBytes: 0,
                    steps: [StepResult(action: "Run flow", status: .passed, duration: 0)])]
            }
        )
        XCTAssertTrue(flowsRan)
        XCTAssertEqual(captures.map(\.screenName), ["screens", "smoke"])
        XCTAssertEqual(captures.first?.steps.first?.status, .failed)
        XCTAssertTrue(captures.first?.steps.first?.message?.contains("Runner failed") ?? false)
        let state = try ReadyFile.read(ready)
        XCTAssertEqual(state.status, "failed")
        XCTAssertEqual(state.flows, [.init(name: "smoke", status: "passed")])
    }

    func testContinueOnFailureStillRunsFlowsAfterAMissingScreenCapture() async throws {
        var flowsRan = false
        let captures = try await RunCommand.runSuite(
            hasScreens: true, hasFlows: true, keepAlive: false, readyFile: nil,
            options: RunCommand.SessionOptions(reportDir: nil, timeoutSeconds: 600, failFast: false),
            runScreens: { _, _, _ in
                [ScreenCapture(screenName: "missing", path: "", sizeBytes: 0,
                    steps: [StepResult(action: "Take screenshot", status: .failed, duration: 0)])]
            },
            runFlows: { _, _, _ in flowsRan = true; return [] }
        )
        XCTAssertTrue(flowsRan)
        XCTAssertEqual(captures.map(\.screenName), ["missing"])
    }

    func testContinueOnFailureStillStopsOnSetupErrorsAndCancellation() async throws {
        let errors: [Error] = [
            GrantivaError.commandFailed("Simulator TEST is already owned by another Grantiva run", 1),
            GrantivaError.runnerNotFound,
            CancellationError(),
        ]
        for thrown in errors {
            do {
                _ = try await RunCommand.runSuite(
                    hasScreens: true, hasFlows: true, keepAlive: false, readyFile: nil,
                    options: RunCommand.SessionOptions(reportDir: nil, timeoutSeconds: 600, failFast: false),
                    runScreens: { _, _, _ in throw thrown },
                    runFlows: { _, _, _ in XCTFail("\(thrown) must not let flows run"); return [] }
                )
                XCTFail("Expected \(thrown) to be rethrown")
            } catch {
                XCTAssertEqual("\(error)", "\(thrown)")
            }
        }
    }

    func testWithoutContinueOnFailureAThrowingScreensSessionStopsTheSuite() async throws {
        do {
            _ = try await RunCommand.runSuite(
                hasScreens: true, hasFlows: true, keepAlive: false, readyFile: nil, options: Self.failFastOptions,
                runScreens: { _, _, _ in throw GrantivaError.commandFailed("Runner failed (exit 1)", 1) },
                runFlows: { _, _, _ in XCTFail("fail-fast must not start flows"); return [] }
            )
            XCTFail("Expected suite failure")
        } catch {
            XCTAssertTrue("\(error)".contains("Runner failed"), "\(error)")
        }
    }

    func testTimeoutMustBeAtLeastThirtySeconds() throws {
        XCTAssertThrowsError(try RunCommand.parse(["--timeout", "29"])) { error in
            XCTAssertTrue(String(describing: error).contains("at least 30 seconds"))
        }
        XCTAssertEqual(try RunCommand.parse(["--timeout", "30"]).timeout, 30)
    }

    func testParsesReadyFileAndRepeatedEnvironmentPairs() throws {
        let command = try RunCommand.parse([
            "--flow", "flows/advertise.yaml",
            "--keep-alive",
            "--ready-file", "/tmp/advertise.ready",
            "--env", "GRANTIVA_PORT=51234",
            "--env", "MODE=peripheral",
        ])
        XCTAssertEqual(command.readyFile, "/tmp/advertise.ready")
        XCTAssertEqual(command.env, ["GRANTIVA_PORT=51234", "MODE=peripheral"])
        XCTAssertTrue(command.keepAlive)
        XCTAssertEqual(try FlowEnvironment.parse(command.env)["GRANTIVA_PORT"], "51234")
    }

    func testMalformedEnvironmentPairIsRejectedWithAClearError() throws {
        let command = try RunCommand.parse(["--env", "PORT"])
        XCTAssertThrowsError(try FlowEnvironment.parse(command.env)) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("PORT"), message)
            XCTAssertTrue(message.contains("expected KEY=VALUE"), message)
        }
    }

    func testDefaultsLeaveReadyFileAndEnvironmentUnset() throws {
        let command = try RunCommand.parse([])
        XCTAssertNil(command.readyFile)
        XCTAssertTrue(command.env.isEmpty)
        XCTAssertNil(command.reportDir)
    }

    // MARK: - --ready-file contract

    /// Runs `command` from an empty directory, where project resolution fails
    /// immediately — the cheapest stand-in for every setup failure (missing
    /// project, bad scheme, build failure, no simulator) that never reaches the
    /// runner.
    private func runInADirectoryWithNoProject(_ command: RunCommand) async -> Error? {
        let fileManager = FileManager.default
        let previous = fileManager.currentDirectoryPath
        let scratch = fileManager.temporaryDirectory
            .appendingPathComponent("grantiva-run-tests-\(UUID().uuidString)")
        try? fileManager.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer {
            fileManager.changeCurrentDirectoryPath(previous)
            try? fileManager.removeItem(at: scratch)
        }
        fileManager.changeCurrentDirectoryPath(scratch.path)
        do {
            try await command.run()
            return nil
        } catch {
            return error
        }
    }

    // A setup failure used to write nothing at all, so the documented waiter —
    // `while [ ! -f "$f" ]; do sleep 0.2; done`, which has no timeout — wedged
    // the job until CI's global limit.
    func testASetupFailureStillWritesANonPassedVerdict() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-ready-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let readyFile = directory.appendingPathComponent("ready.json").path

        let command = try RunCommand.parse(["--ready-file", readyFile])
        let error = await runInADirectoryWithNoProject(command)

        XCTAssertNotNil(error, "resolving a project in an empty directory must fail")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: readyFile),
            "a waiter must be released even when the run failed before the runner started"
        )
        let state = try ReadyFile.read(readyFile)
        XCTAssertFalse(state.passed)
        XCTAssertEqual(state.status, "failed")
    }

    // A file left by a previous run made the waiter return instantly and read
    // that run's verdict — CI proceeding on a stale `passed` against a run that
    // never started.
    func testAStaleReadyFileIsReplacedRatherThanLeftToBeMisread() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-ready-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let readyFile = directory.appendingPathComponent("ready.json").path
        try ReadyFile.write(RunReadyState(status: "passed", flows: []), to: readyFile)

        let command = try RunCommand.parse(["--ready-file", readyFile])
        _ = await runInADirectoryWithNoProject(command)

        XCTAssertNotEqual(
            try ReadyFile.read(readyFile).status, "passed",
            "the previous run's verdict must not survive into this one"
        )
    }

    // Startup deletes the file, so a path that cannot be written has to be
    // rejected there — not after a long suite, with the verdict undeliverable.
    func testAnUnwritableReadyFilePathFailsBeforeAnyWork() async throws {
        let command = try RunCommand.parse([
            "--ready-file", "/System/definitely-not-writable/ready.json",
        ])
        let error = await runInADirectoryWithNoProject(command)
        let message = String(describing: error)
        XCTAssertTrue(message.contains("ready-file"), message)
    }

    func testLogStreamNarrationNamesThePredicateOnIOSAndTheTagOnAndroid() {
        XCTAssertEqual(
            RunCommand.logStreamNarration(platform: .ios, predicate: "subsystem == \"com.x\"", tag: nil),
            "Streaming simulator logs (predicate: subsystem == \"com.x\")"
        )
        XCTAssertEqual(
            RunCommand.logStreamNarration(platform: .ios, predicate: "eventMessage CONTAINS \"x\"", tag: nil),
            "Streaming simulator logs (predicate: eventMessage CONTAINS \"x\")"
        )
        XCTAssertEqual(RunCommand.logStreamNarration(platform: .ios, predicate: nil, tag: nil), "Streaming simulator logs")
        XCTAssertEqual(RunCommand.logStreamNarration(platform: .android, predicate: nil, tag: nil), "Streaming emulator logs")
        XCTAssertEqual(RunCommand.logStreamNarration(platform: .android, predicate: nil, tag: "MyTag"), "Streaming emulator logs (tag: MyTag)")
    }

    func testChattyLogWarningIsTheBaseCommitWording() {
        XCTAssertEqual(
            RunCommand.unfilteredLogsWarning,
            "--logs requested but no bundle ID resolved; streaming without a predicate (very chatty)."
        )
    }
}
