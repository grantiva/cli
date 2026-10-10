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

    /// A06: validation runs before `run()`, so a usage error used to leave no
    /// ready file and the documented `while [ ! -f ... ]` waiter spun forever.
    func testAValidationFailureStillWritesAFailedReadyFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-ready-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let readyFile = directory.appendingPathComponent("ready.json").path

        XCTAssertThrowsError(try RunCommand.parse(["--timeout", "5", "--ready-file", readyFile]))

        let state = try ReadyFile.read(readyFile)
        XCTAssertEqual(state.status, "failed")
        XCTAssertEqual(state.error, "--timeout must be at least 30 seconds.")
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

    /// A08: `--logs-level` is validated against the documented values.
    func testLogsLevelAcceptsOnlyTheDocumentedValues() throws {
        XCTAssertEqual(try RunCommand.parse(["--logs-level", "default"]).logsLevel, .default)
        XCTAssertEqual(try RunCommand.parse(["--logs-level", "info"]).logsLevel, .info)
        XCTAssertEqual(try RunCommand.parse(["--logs-level", "debug"]).logsLevel, .debug)
        XCTAssertNil(try RunCommand.parse([]).logsLevel)
        XCTAssertThrowsError(try RunCommand.parse(["--logs-level", "warning"])) { error in
            XCTAssertEqual(RunCommand.exitCode(for: error), .validationFailure)
            let message = RunCommand.message(for: error)
            XCTAssertTrue(message.contains("warning"), message)
            XCTAssertTrue(message.contains("default") && message.contains("info") && message.contains("debug"), message)
        }
    }

    func testDefaultsLeaveReadyFileAndEnvironmentUnset() throws {
        let command = try RunCommand.parse([])
        XCTAssertNil(command.readyFile)
        XCTAssertTrue(command.env.isEmpty)
        XCTAssertNil(command.reportDir)
    }

    // MARK: - run --json on failure (I12)

    /// A project with one flow and a stand-in runner that writes a failed
    /// report and exits 1, run from inside it.
    private func withFailingRunnerProject(_ body: (URL, RunnerManager) async throws -> Void) async throws {
        let fileManager = FileManager.default
        let dir = fileManager.temporaryDirectory.appendingPathComponent("grantiva-json-\(UUID().uuidString)")
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let previous = fileManager.currentDirectoryPath
        defer {
            fileManager.changeCurrentDirectoryPath(previous)
            try? fileManager.removeItem(at: dir)
        }
        try "module: app\nemulator: Pixel_8_API_35\nflows:\n  - smoke.yaml\n"
            .write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        try "appId: com.placeholder\n---\n- launchApp\n"
            .write(to: dir.appendingPathComponent("smoke.yaml"), atomically: true, encoding: .utf8)
        let runner = dir.appendingPathComponent("fake-runner").path
        try #"""
        #!/bin/sh
        while [ $# -gt 0 ]; do
          if [ "$1" = "--output" ]; then out="$2"; shift; fi
          flow="$1"
          shift
        done
        mkdir -p "$out/flows"
        printf '{"status":"failed","flows":[{"index":0,"id":"flow-000","name":"smoke","sourceFile":"%s","assetsDir":"assets/flow-000","dataFile":"flows/flow-000.json","status":"failed","error":"Element not found: text=Remove"}]}' "$flow" > "$out/report.json"
        printf '{"commands":[{"yaml":"launchApp","status":"passed"},{"yaml":"tapOn: Remove","status":"failed","error":{"message":"Element not found: text=Remove"}}]}' > "$out/flows/flow-000.json"
        echo "flow smoke failed" >&2
        exit 1
        """#.write(toFile: runner, atomically: true, encoding: .utf8)
        chmod(runner, 0o755)
        fileManager.changeCurrentDirectoryPath(dir.path)
        unsetenv("GRANTIVA_PLATFORM")
        try await body(dir, RunnerManager(ensureAvailable: {}, runnerPath: { runner }, runnerDir: { dir.path }))
    }

    func testJSONRunnerFailureStillPrintsTheResultWithTheFailedStep() async throws {
        try await withFailingRunnerProject { _, runner in
            var command = try RunCommand.parse([
                "--json", "--no-build", "--application-id", "com.fake", "--timeout", "30", "--report-dir", "rep",
            ])
            command.devicePlatform = InjectedDevicePlatform(FakeDevicePlatform(platform: .android))
            command.runnerManager = runner
            let stdout = CapturedLines()
            command.resultOutput = ResultOutput { stdout.append($0) }

            do {
                try await command.run()
                XCTFail("a failed flow must fail the run")
            } catch {
                XCTAssertTrue("\(error)".contains("Runner failed (exit 1)"), "\(error)")
            }

            XCTAssertEqual(stdout.values.count, 1, "exactly one JSON document: \(stdout.values)")
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(stdout.values.joined().utf8)) as? [String: Any]
            )
            XCTAssertEqual(json["allPassed"] as? Bool, false)
            XCTAssertTrue((json["error"] as? String)?.contains("Runner failed (exit 1)") == true, "\(json)")
            XCTAssertTrue((json["reportDir"] as? String)?.hasSuffix("/rep") == true, "\(json)")
            let screens = try XCTUnwrap(json["screens"] as? [[String: Any]])
            XCTAssertEqual(screens.first?["name"] as? String, "smoke")
            XCTAssertEqual(screens.first?["passed"] as? Bool, false)
            let steps = try XCTUnwrap(screens.first?["steps"] as? [[String: Any]])
            let failed = try XCTUnwrap(steps.first { $0["status"] as? String == "failed" })
            XCTAssertEqual(failed["action"] as? String, "tapOn: Remove")
            XCTAssertEqual(failed["message"] as? String, "Element not found: text=Remove")
        }
    }

    func testJSONSetupFailurePrintsAnErrorDocument() async throws {
        var command = try RunCommand.parse(["--json"])
        let stdout = CapturedLines()
        command.resultOutput = ResultOutput { stdout.append($0) }

        let error = await runInADirectoryWithNoProject(command)

        XCTAssertNotNil(error)
        XCTAssertEqual(stdout.values.count, 1, "\(stdout.values)")
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(stdout.values.joined().utf8)) as? [String: Any]
        )
        XCTAssertEqual(json["allPassed"] as? Bool, false)
        XCTAssertEqual((json["screens"] as? [Any])?.count, 0)
        XCTAssertFalse((json["error"] as? String ?? "").isEmpty, "\(json)")
        XCTAssertNil(json["reportDir"])
    }

    func testJSONBuildFailureIsARunResult() async throws {
        try await withFailingRunnerProject { _, runner in
            var command = try RunCommand.parse(["--json", "--application-id", "com.fake", "--timeout", "30"])
            let fake = FakeDevicePlatform(platform: .android)
            fake.buildResult = BuildResult(success: false, duration: 0, warnings: [], errors: ["e: Main.kt:3 unresolved"], productPath: nil, applicationId: nil)
            command.devicePlatform = InjectedDevicePlatform(fake)
            command.runnerManager = runner
            let stdout = CapturedLines()
            command.resultOutput = ResultOutput { stdout.append($0) }

            _ = try? await command.run()

            XCTAssertEqual(stdout.values.count, 1, "\(stdout.values)")
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(stdout.values.joined().utf8)) as? [String: Any]
            )
            XCTAssertEqual(json["allPassed"] as? Bool, false)
            XCTAssertEqual((json["screens"] as? [Any])?.count, 0)
            XCTAssertEqual(json["error"] as? String, "Build failed\ne: Main.kt:3 unresolved")
        }
    }

    /// Releasing a --keep-alive session with Ctrl-C after every flow passed
    /// is a passing run, matching the `passed` ready file.
    func testAnInterruptAfterAllFlowsPassedIsAPassingDocument() {
        let report = RunnerFailureReport()
        report.recordEarlierCaptures([
            ScreenCapture(screenName: "smoke", path: "", sizeBytes: 0, steps: [StepResult(action: "launchApp", status: .passed, duration: 0)]),
        ])
        let error = GrantivaError.commandFailed("Runner interrupted:\n", 0)

        let failed = RunCommand.failureResult(error: error, report: report)
        XCTAssertFalse(failed.allPassed, "passing captures alone are not a passing verdict")
        XCTAssertNotNil(failed.error)

        report.markPassedBeforeInterrupt()
        let released = RunCommand.failureResult(error: error, report: report)
        XCTAssertTrue(released.allPassed)
        XCTAssertNil(released.error)
    }

    /// A failed screens session stops the suite before the flows; the
    /// document keeps the screens it captured instead of `screens: []`.
    func testEarlierScreenCapturesAreReported() {
        let report = RunnerFailureReport()
        report.recordEarlierCaptures([
            ScreenCapture(screenName: "Home", path: "", sizeBytes: 0, steps: [StepResult(action: "Capture Home", status: .failed, duration: 0, message: "missing")]),
        ])
        let result = RunCommand.failureResult(error: ExitCode.failure, report: report)
        XCTAssertEqual(result.screens.map(\.name), ["Home"])
        XCTAssertEqual(result.screens.first?.steps.first?.message, "missing")
        XCTAssertEqual(result.error, "Run failed (exit 1)")
    }

    func testWithoutJSONAFailurePrintsNoResultDocument() async throws {
        var command = try RunCommand.parse([])
        let stdout = CapturedLines()
        command.resultOutput = ResultOutput { stdout.append($0) }
        _ = await runInADirectoryWithNoProject(command)
        XCTAssertEqual(stdout.values, [])
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

    /// A10: Android narrates module, variant, and device, not scheme/simulator.
    func testResolvedNarrationUsesEachPlatformsTerms() {
        let android = ResolvedProject(
            scheme: nil, project: nil, workspace: nil, bundleId: "com.kylebrowning.landmarks", buildSettings: [],
            simulator: "emulator-5554", screens: [], flows: ["flow.yaml"],
            android: AndroidProject(module: "app", variant: "freeDebug")
        )
        XCTAssertEqual(
            RunCommand.resolvedNarration(platform: .android, resolved: android),
            "Resolved: module=app variant=freeDebug device=emulator-5554 screens=0 flows=1"
        )
        let ios = ResolvedProject(
            scheme: "Landmarks", project: nil, workspace: nil, bundleId: nil, buildSettings: [],
            simulator: "iPhone 17", screens: [], flows: ["flow.yaml"]
        )
        XCTAssertEqual(
            RunCommand.resolvedNarration(platform: .ios, resolved: ios),
            "Resolved: scheme=Landmarks simulator=iPhone 17 screens=0 flows=1"
        )
    }

    func testFlowRunTakesBundleIdFromFlowHeaderWhenNoneIsGiven() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).yaml").path
        try "appId: com.kylebrowning.Landmarks\n---\n- launchApp\n".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertEqual(RunCommand.flowBundleId(flowPath: path, resolved: nil, explicit: nil), "com.kylebrowning.Landmarks")
        XCTAssertEqual(
            RunCommand.flowBundleId(flowPath: path, resolved: "com.detected", explicit: nil), "com.kylebrowning.Landmarks",
            "the flow names its app; a detected ID is only a guess"
        )
        XCTAssertEqual(RunCommand.flowBundleId(flowPath: path, resolved: "com.flag", explicit: "com.flag"), "com.flag")
    }

    func testFlowRunIgnoresVariableAppIdHeader() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).yaml").path
        try "appId: ${APP_ID}\n---\n- launchApp\n".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertEqual(RunCommand.flowBundleId(flowPath: path, resolved: "com.detected", explicit: nil), "com.detected")
        XCTAssertNil(RunCommand.flowBundleId(flowPath: path, resolved: nil, explicit: nil))
    }

    func testFlowRunDoesNotParseUnrelatedMaestroFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(".maestro"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "appId: a.b\n---\n- back\n".write(
            to: dir.appendingPathComponent(".maestro/02-bad.yaml"), atomically: true, encoding: .utf8
        )
        let options = try PlatformOptions.parse(["--platform", "ios"])
        XCTAssertThrowsError(try options.loadConfig(directory: dir, environment: [:]))
        let (_, config) = try options.loadConfig(directory: dir, environment: [:], includeMaestroDirectory: false)
        XCTAssertNil(config)
    }

    // MARK: - Nothing to run (C18)

    private func runIn(files: [String: String], _ arguments: [String], platform: Platform) async -> Error? {
        let fileManager = FileManager.default
        let previous = fileManager.currentDirectoryPath
        let scratch = fileManager.temporaryDirectory
            .appendingPathComponent("grantiva-run-c18-\(UUID().uuidString)")
        try? fileManager.createDirectory(at: scratch, withIntermediateDirectories: true)
        for (name, contents) in files {
            try? contents.write(to: scratch.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        defer {
            fileManager.changeCurrentDirectoryPath(previous)
            try? fileManager.removeItem(at: scratch)
        }
        fileManager.changeCurrentDirectoryPath(scratch.path)
        do {
            var command = try RunCommand.parse(arguments)
            command.devicePlatform = InjectedDevicePlatform(FakeDevicePlatform(platform: platform))
            try await command.run()
            return nil
        } catch {
            return error
        }
    }

    func testNoAndroidConfigNamesTheAndroidFileAndInit() async {
        let error = await runIn(
            files: ["settings.gradle.kts": "rootProject.name = \"x\"\n"],
            ["--no-build", "--platform", "android"], platform: .android
        )
        XCTAssertEqual(
            (error as? GrantivaError)?.errorDescription,
            "Invalid argument: No grantiva-android.yml here. Create one with grantiva init --platform android."
        )
    }

    func testNoIOSConfigNamesGrantivaYmlAndInit() async {
        let error = await runIn(files: [:], ["--no-build"], platform: .ios)
        XCTAssertEqual(
            (error as? GrantivaError)?.errorDescription,
            "Invalid argument: No grantiva.yml here. Create one with grantiva init."
        )
    }

    func testEmptyConfigSaysNothingIsConfiguredInTheResolvedFile() async {
        let error = await runIn(
            files: ["grantiva-android.yml": "application_id: com.example\n"],
            ["--no-build", "--platform", "android"], platform: .android
        )
        XCTAssertEqual(
            (error as? GrantivaError)?.errorDescription,
            "Invalid argument: No screens or flows configured in grantiva-android.yml"
        )
    }

    // MARK: - --no-build with the app missing (I15)

    func testNoBuildWithTheAppNotInstalledFailsBeforeTheRunnerStarts() async throws {
        let fake = FakeDevicePlatform(platform: .ios)
        fake.bootedName = "qa-ios-1"
        fake.installed = false
        let runnerUsed = LockedFlag()
        let fileManager = FileManager.default
        let previous = fileManager.currentDirectoryPath
        let scratch = fileManager.temporaryDirectory.appendingPathComponent("grantiva-run-i15-\(UUID().uuidString)")
        try fileManager.createDirectory(at: scratch, withIntermediateDirectories: true)
        try "bundle_id: com.kylebrowning.Landmarks\nsimulator: qa-ios-1\nflows:\n  - smoke.yaml\n"
            .write(to: scratch.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
        defer {
            fileManager.changeCurrentDirectoryPath(previous)
            try? fileManager.removeItem(at: scratch)
        }
        fileManager.changeCurrentDirectoryPath(scratch.path)

        var command = try RunCommand.parse(["--no-build", "--platform", "ios"])
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.runnerManager = RunnerManager(
            ensureAvailable: {},
            runnerPath: { runnerUsed.set(); return "/usr/bin/false" },
            runnerDir: { runnerUsed.set(); return NSTemporaryDirectory() }
        )
        do {
            try await command.run()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                "com.kylebrowning.Landmarks is not installed on qa-ios-1. Drop --no-build or run grantiva build install."
            )
        }
        XCTAssertFalse(runnerUsed.value, "the runner must never be launched")
        XCTAssertTrue(fake.calls.contains("isInstalled(com.kylebrowning.Landmarks)"), "\(fake.calls)")
    }
}

final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = false
    var value: Bool { lock.withLock { stored } }
    func set() { lock.withLock { stored = true } }
}

private final class CapturedLines: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    func append(_ line: String) { lock.withLock { storage.append(line) } }
    var values: [String] { lock.withLock { storage } }
}
