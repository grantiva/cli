import Foundation
import XCTest
@testable import GrantivaCore

/// What a run prints: the runner's relayed output (K18, K19, K90, K105) and
/// grantiva's own failure messages (K10, K19, K20, K93).
final class RunnerSessionOutputTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-output-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        RunnerNarration.isSilenced = false
        RunnerNarration.sink = RunnerNarration.standardError
        try? FileManager.default.removeItem(at: scratch)
    }

    // MARK: - K10: a --timeout kill is not an interrupt

    func testATimedOutFailureDropsTheRunnersInterruptAcknowledgement() {
        let message = RunnerSession.failureMessage(
            reason: "grantiva killed the runner after 30s (--timeout <seconds> to raise the cap).",
            stderr: "\nReceived interrupt, cleaning up...\n",
            timedOut: true
        )
        XCTAssertFalse(message.lowercased().contains("interrupt"), message)
        XCTAssertTrue(message.hasSuffix("to raise the cap)."), message)
    }

    func testRunnerStderrThatIsNotTheSignalAcknowledgementIsKept() {
        let message = RunnerSession.failureMessage(
            reason: "grantiva killed the runner after 30s (--timeout <seconds> to raise the cap).",
            stderr: "panic: driver crashed\nReceived interrupt, cleaning up...\n",
            timedOut: true
        )
        XCTAssertTrue(message.contains("panic: driver crashed"), message)
        XCTAssertFalse(message.contains("Received interrupt"), message)
    }

    /// B3-L48.2: the runner's own `Error:` line is the detail of one error,
    /// not a second `Error:` under a bare `Runner failed (exit 1):` line.
    func testTheRunnersErrorLineIsFoldedIntoOneError() {
        let message = RunnerSession.failureMessage(
            reason: "Runner failed (exit 1)",
            stderr: "Error: failed to create driver: start UIAutomator2: UIAutomator2 server not ready after 1s on each of 2 starts\n"
        )
        XCTAssertEqual(
            message,
            "Runner failed (exit 1): failed to create driver: start UIAutomator2: UIAutomator2 server not ready after 1s on each of 2 starts"
        )
        XCTAssertFalse(message.contains("Error:"), message)
        let multi = RunnerSession.failureMessage(reason: "Runner failed (exit 1)", stderr: "warning: slow\nError: boom\n")
        XCTAssertEqual(multi, "Runner failed (exit 1):\nwarning: slow\nboom")
    }

    /// C13-1: a long stderr is cut on a line boundary, with a marker, not
    /// mid-path (`che/wda-builds/.../runner.log`).
    func testALongRunnerStderrIsCutOnALineBoundaryWithAMarker() {
        let longLine = "Full log: /private/tmp/home/versions/1.1.28/devices/X/cache/wda-builds/sim/devices/X/runner.log"
        let lines = (1...60).map { "  ⚠ attempt \($0): \(longLine)" } + ["Error: failed to create driver: WDA start failed"]
        let message = RunnerSession.failureMessage(
            reason: "Runner failed (exit 1)", stderr: lines.joined(separator: "\n") + "\n"
        )
        let detail = message.components(separatedBy: "\n").dropFirst()
        XCTAssertEqual(detail.first, RunnerSession.elidedDetailMarker, message)
        for line in detail.dropFirst() {
            XCTAssertTrue(line.hasPrefix("  ⚠ attempt ") || line.hasPrefix("failed to create driver"), "mid-line cut: \(line)")
        }
        XCTAssertTrue(message.hasSuffix("failed to create driver: WDA start failed"), message)
        // A short stderr carries no marker.
        let short = RunnerSession.failureMessage(reason: "Runner failed (exit 1)", stderr: "warning: slow\nError: boom\n")
        XCTAssertFalse(short.contains(RunnerSession.elidedDetailMarker), short)
    }

    /// C13-1: lines the user already saw streamed, and lines the runner
    /// repeated, are not printed again under the error.
    func testTheDetailDropsLinesAlreadyStreamedAndRepeatedLines() {
        let stderr = """
          ⏳ Starting GrantivaAgent...
          ⚠ WDA startup failed on attempt 1/4: xcodebuild exited
        Full log: /tmp/x/runner.log
        === attempt 2/4 ===
          ⚠ WDA startup failed on attempt 1/4: xcodebuild exited


        Full log: /tmp/x/runner.log
        Error: failed to create driver
        """
        let message = RunnerSession.failureMessage(
            reason: "Runner failed (exit 1)", stderr: stderr,
            streamed: "  ✓ GrantivaAgent installed\n  ⏳ Starting GrantivaAgent...\n", runnerOutputShown: true
        )
        XCTAssertEqual(message, """
        Runner failed (exit 1):
        ⚠ WDA startup failed on attempt 1/4: xcodebuild exited
        Full log: /tmp/x/runner.log
        === attempt 2/4 ===
        failed to create driver
        """)
        // With the runner's output hidden, nothing was streamed to the user.
        let hidden = RunnerSession.failureMessage(
            reason: "Runner failed (exit 1)", stderr: "  ⏳ Starting GrantivaAgent...\nError: boom\n",
            streamed: "  ⏳ Starting GrantivaAgent...\n", runnerOutputShown: false
        )
        XCTAssertEqual(hidden, "Runner failed (exit 1):\n⏳ Starting GrantivaAgent...\nboom")
    }

    func testTheOutcomeCarriesWhatWasStreamedOnlyWhenItWasShown() async throws {
        let lease = try SimulatorLease.acquire(udid: "STREAM-\(UUID().uuidString)", directory: scratch.appendingPathComponent("locks").path)
        defer { lease.release() }
        for silenced in [true, false] {
            var request = RunnerExecution.Request(
                executable: "/bin/sh",
                arguments: ["-c", "printf 'shown line\\n'; printf 'Error: boom\\n' >&2; exit 1"],
                workingDirectory: scratch.path,
                lease: lease,
                keepAlive: false,
                timeoutSeconds: 30,
                pathMap: [:],
                reportDir: scratch.path,
                expectedFlows: 1,
                readyFile: ReadyFileSignal(path: nil)
            )
            request.silenced = silenced
            request.narrationSink = { _ in }
            let outcome = await RunnerExecution.run(request)
            XCTAssertEqual(outcome.streamed, silenced ? "" : "shown line\n")
            XCTAssertEqual(outcome.stderr, "Error: boom\n")
        }
    }

    func testAGenuineInterruptStillSaysInterrupted() {
        let message = RunnerSession.failureMessage(reason: "Runner interrupted", stderr: "")
        XCTAssertTrue(message.hasPrefix("Runner interrupted"), message)
    }

    // MARK: - K19: --quiet / --json silence the runner, and errors stand alone

    func testASilencedRequestRelaysNothingAndANormalOneRelaysEverything() async throws {
        let lease = try SimulatorLease.acquire(udid: "QUIET-\(UUID().uuidString)", directory: scratch.appendingPathComponent("locks").path)
        defer { lease.release() }
        for silenced in [true, false] {
            let collected = Collected()
            var request = RunnerExecution.Request(
                executable: "/bin/sh",
                arguments: ["-c", "printf '  grantiva-runner 1.0 - by Grantiva\\n    ✓ launchApp (1.0s)\\n'"],
                workingDirectory: scratch.path,
                lease: lease,
                keepAlive: false,
                timeoutSeconds: 30,
                pathMap: [:],
                reportDir: scratch.path,
                expectedFlows: 1,
                readyFile: ReadyFileSignal(path: nil)
            )
            request.silenced = silenced
            request.narrationSink = { collected.append($0) }
            _ = await RunnerExecution.run(request)
            if silenced {
                XCTAssertEqual(collected.text, "", "--quiet/--json must relay no runner line")
            } else {
                XCTAssertTrue(collected.text.contains("by Grantiva"), collected.text)
                XCTAssertTrue(collected.text.contains("✓ launchApp"), collected.text)
            }
        }
    }

    /// The runner's relayed output follows the same rule as grantiva's own
    /// narration: nothing after the interrupt notice.
    func testNarrateDropsRunnerOutputOnceAnInterruptIsUnderWay() {
        var collected: [String] = []
        var interrupted = false
        RunnerSession.narrate("  ✓ Found 1 test flow(s)\n", silenced: false, sink: { collected.append($0) }, interrupted: { interrupted })
        interrupted = true
        RunnerSession.narrate("Received interrupt, cleaning up...\n", silenced: false, sink: { collected.append($0) }, interrupted: { interrupted })
        XCTAssertEqual(collected, ["  ✓ Found 1 test flow(s)\n"])
    }

    func testNarrateHonoursTheProcessWideSwitch() {
        let collected = Collected()
        RunnerNarration.sink = { collected.append($0) }
        RunnerNarration.isSilenced = true
        RunnerSession.narrate("hidden\n")
        RunnerNarration.isSilenced = false
        RunnerSession.narrate("shown\n")
        XCTAssertEqual(collected.text, "shown\n")
        XCTAssertTrue(RunnerNarration.shouldSilence(json: true, quiet: false, verbose: false))
        XCTAssertTrue(RunnerNarration.shouldSilence(json: false, quiet: true, verbose: false))
        XCTAssertFalse(RunnerNarration.shouldSilence(json: true, quiet: true, verbose: true))
        XCTAssertFalse(RunnerNarration.shouldSilence(json: false, quiet: false, verbose: false))
    }

    func testAFailureMessageNamesTheFailedStepInsteadOfPointingAtSuppressedOutput() {
        let failure = RunnerReportSteps.Failure(
            flowName: "02-exact-negative", commandIndex: 2,
            action: "assertVisible: text=\"Golden Gate.*\", exact=true",
            message: "Element not visible: text='Golden Gate.*'", errorType: "assertion", unfinished: false
        )
        let message = RunnerSession.failureMessage(
            reason: "Runner failed (exit 1)", stderr: "", failure: failure, runnerOutputShown: false
        )
        XCTAssertTrue(message.hasPrefix(
            "Runner failed (exit 1): 02-exact-negative: assertVisible: text=\"Golden Gate.*\", exact=true: Element not visible"
        ), message)
        XCTAssertFalse(message.contains("see the runner output above"), message)
    }

    func testWithoutAFailedStepAndWithOutputHiddenTheMessageEndsCleanly() {
        let message = RunnerSession.failureMessage(reason: "Runner failed (exit 1)", stderr: "", runnerOutputShown: false)
        XCTAssertEqual(message, "Runner failed (exit 1).")
    }

    // MARK: - K93: the hierarchy remedy for element failures

    func testElementNotFoundAndNotVisibleFailuresCarryTheHierarchyHint() {
        let notFound = RunnerReportSteps.Failure(
            flowName: "nosuch", commandIndex: 1, action: "tapOn: text=\"No Such\"",
            message: "Element not found: text='No Such'", errorType: "element_not_found", unfinished: false
        )
        let notVisible = RunnerReportSteps.Failure(
            flowName: "neg", commandIndex: 2, action: "assertVisible: text=\"X\"",
            message: "Element not visible: text='X'", errorType: "assertion", unfinished: false
        )
        for failure in [notFound, notVisible] {
            let message = RunnerSession.failureMessage(reason: "Runner failed (exit 1)", stderr: "", failure: failure)
            XCTAssertTrue(message.hasSuffix("\nRun grantiva hierarchy (or the grantiva_a11y_tree MCP tool) to inspect the tree."), message)
            XCTAssertEqual(message.components(separatedBy: "grantiva hierarchy").count - 1, 1, message)
            XCTAssertTrue(message.contains(failure.action), "failure line carries the selector: \(message)")
        }
    }

    func testCrashesAndTimeoutsGetNoHierarchyHint() {
        let crash = RunnerReportSteps.Failure(
            flowName: "f", commandIndex: 1, action: "tapOn: text=\"Go\"",
            message: "App crashed", errorType: "app_crash", unfinished: false
        )
        let cutOff = RunnerReportSteps.Failure(
            flowName: "f", commandIndex: 1, action: "extendedWaitUntil: visible text=\"X\"",
            message: nil, errorType: nil, unfinished: true
        )
        for failure in [crash, cutOff] {
            let message = RunnerSession.failureMessage(reason: "Runner failed (exit 1)", stderr: "", failure: failure)
            XCTAssertFalse(message.contains("grantiva hierarchy"), message)
        }
    }

    /// C14 (N-14): the runner's launch failure already names the step
    /// (`launchApp: 'com…' crashed on launch`); the line does not say it twice.
    func testAFailureMessageThatNamesItsStepIsNotPrefixedTwice() {
        let crash = RunnerReportSteps.Failure(
            flowName: "99-crash", commandIndex: 0, action: "launchApp",
            message: "launchApp: 'com.kylebrowning.landmarks' crashed on launch: java.lang.RuntimeException: X",
            errorType: "app_crash", unfinished: false
        )
        XCTAssertEqual(crash.line, "99-crash: launchApp: 'com.kylebrowning.landmarks' crashed on launch: java.lang.RuntimeException: X")
        let tap = RunnerReportSteps.Failure(
            flowName: "f", commandIndex: 1, action: "tapOn: text=\"Go\"", message: "Element not found", errorType: nil, unfinished: false
        )
        XCTAssertEqual(tap.line, "f: tapOn: text=\"Go\": Element not found")
    }

    func testTheFailedStepIsReadFromTheRunnersReport() throws {
        let reportDir = scratch.appendingPathComponent("report")
        try FileManager.default.createDirectory(at: reportDir.appendingPathComponent("flows"), withIntermediateDirectories: true)
        try #"{"status":"failed","flows":[{"index":0,"id":"flow-000","name":"nosuch","dataFile":"flows/flow-000.json","status":"failed"}]}"#
            .write(to: reportDir.appendingPathComponent("report.json"), atomically: true, encoding: .utf8)
        try #"{"commands":[{"index":0,"type":"launchApp","yaml":"launchApp","status":"passed","duration":1800},{"index":1,"type":"tapOn","yaml":"tapOn: text=\"No Such\"","status":"failed","duration":12000,"error":{"type":"element_not_found","message":"Element not found: text='No Such'"}}]}"#
            .write(to: reportDir.appendingPathComponent("flows/flow-000.json"), atomically: true, encoding: .utf8)

        let failure = try XCTUnwrap(RunnerReportSteps.firstFailure(in: reportDir.path))
        XCTAssertEqual(failure.line, "nosuch: tapOn: text=\"No Such\": Element not found: text='No Such'")
        XCTAssertEqual(failure.commandIndex, 1)
        XCTAssertTrue(failure.wantsHierarchyHint)
    }

    // MARK: - K18: no deleted report paths

    static let runnerTail = """
      ✓ Tests completed. Generating reports...

      Reports: /var/folders/jv/T/grantiva-report-ABC
        ├── report.json
        ├── junit-report.xml
        └── allure-results/

      Paths:
        JSON:   /var/folders/jv/T/grantiva-report-ABC/report.json
        JUnit:  /var/folders/jv/T/grantiva-report-ABC/junit-report.xml
        Allure: /var/folders/jv/T/grantiva-report-ABC/allure-results

      Built by Grantiva

    """

    func testAnEphemeralReportDirectoryIsNeverPrinted() {
        let setup = "  ✓ Report directory: /private/var/folders/jv/T/grantiva-report-ABC\n"
        let filter = RunnerOutputFilter(ephemeralReportDir: "/var/folders/jv/T/grantiva-report-ABC")
        let relayed = filter.apply(setup + Self.runnerTail)
        XCTAssertFalse(relayed.contains("grantiva-report-ABC"), relayed)
        XCTAssertFalse(relayed.contains("Paths:"), relayed)
        XCTAssertTrue(relayed.contains("Report not kept; pass --report-dir <dir> to keep report.json, JUnit and Allure."), relayed)
        XCTAssertTrue(relayed.contains("Tests completed"), relayed)
        XCTAssertTrue(relayed.hasSuffix("  Built by Grantiva\n"), relayed)
    }

    func testAKeptReportDirectoryIsPrintedAsTheRunnerWroteIt() {
        let filter = RunnerOutputFilter(ephemeralReportDir: nil)
        XCTAssertTrue(filter.isEmpty)
        XCTAssertEqual(filter.apply(Self.runnerTail), Self.runnerTail)
    }

    func testTheFilterWorksAcrossArbitraryChunkBoundaries() {
        let text = Self.runnerTail
        let expected = RunnerOutputFilter(ephemeralReportDir: "/var/folders/jv/T/grantiva-report-ABC").apply(text)
        var filter = RunnerOutputFilter(ephemeralReportDir: "/var/folders/jv/T/grantiva-report-ABC")
        var output = ""
        var index = text.startIndex
        while index < text.endIndex {
            let end = text.index(index, offsetBy: 7, limitedBy: text.endIndex) ?? text.endIndex
            output += filter.consume(String(text[index..<end]))
            index = end
        }
        output += filter.flush()
        XCTAssertEqual(output, expected)
    }

    func testAPromptWithoutANewlineIsNotHeldBack() {
        var filter = RunnerOutputFilter(ephemeralReportDir: "/var/folders/x/grantiva-report-1")
        XCTAssertEqual(filter.consume("Session held. Press Ctrl-C to release"), "Session held. Press Ctrl-C to release")
    }

    // MARK: - K90-a: a screens `wait:` reads as a wait

    func testTheLiveLineOfAGeneratedWaitCarriesItsLabel() {
        let screens = [GrantivaConfig.Screen(name: "Caching", path: .steps([.init(tap: "Caching Demo"), .init(wait: 3)]))]
        let labels = FlowGenerator.waitLabels(inGenerated: FlowGenerator.generate(screens: screens, bundleId: "x"))
        // launchApp, tapOn, settle, evalScript (index 3), settle, takeScreenshot
        XCTAssertEqual(labels, [3: "Wait 3s"])
        let filter = RunnerOutputFilter(waitLabels: labels)
        let relayed = filter.apply("""
          [1/1] screens (grantiva.yml)
            ✓ launchApp (1.0s)
            ✓ tapOn: text="Caching Demo" (884ms)
            ✓ waitForAnimationToEnd (700ms)
            ✓ evalScript (3.0s)

        """)
        XCTAssertTrue(relayed.contains("    ✓ Wait 3s (3.0s)\n"), relayed)
        XCTAssertFalse(relayed.contains("evalScript"))
    }

    func testOnlyTheGeneratedWaitIsRelabelledNotAnotherEvalScript() {
        // A nested sub-flow's own evalScript is indented further and the
        // top-level one at another index keeps its name.
        let filter = RunnerOutputFilter(waitLabels: [2: "Wait 1s"])
        let relayed = filter.apply("""
          [1/1] screens (grantiva.yml)
            ✓ launchApp (1.0s)
                ✓ evalScript (10ms)
            ✓ runFlow (20ms)
            ✓ evalScript (1.0s)
            ✓ evalScript (5ms)

        """)
        XCTAssertTrue(relayed.contains("        ✓ evalScript (10ms)"), relayed)
        XCTAssertTrue(relayed.contains("    ✓ Wait 1s (1.0s)"), relayed)
        XCTAssertTrue(relayed.contains("    ✓ evalScript (5ms)"), relayed)
    }

    // MARK: - K11: the interrupt notice names the device

    func testTheInterruptNoticeNamesTheEmulatorOnAndroid() {
        XCTAssertTrue(SignalRelay.announcement(signalName: "SIGINT", deviceNoun: "emulator").contains("releasing emulator"))
        XCTAssertTrue(SignalRelay.announcement(signalName: "SIGINT", deviceNoun: "simulator").contains("releasing simulator"))
    }

    // MARK: - K20 / K90-b: a screens session is named, and never by a temp path

    func testTheGeneratedScreensFlowIsNamedAndMapsCommandsToScreens() {
        let screens = [
            GrantivaConfig.Screen(name: "Home", path: .launch),
            GrantivaConfig.Screen(name: "Broken", path: .steps([.init(tap: "No Such Element")])),
        ]
        let generated = FlowGenerator.generateWithMap(screens: screens, bundleId: "com.example")
        XCTAssertTrue(generated.yaml.contains("name: \"screens\"\n---"), generated.yaml)
        let commandCount = generated.yaml.components(separatedBy: "\n").filter { $0.hasPrefix("- ") }.count
        XCTAssertEqual(generated.owners.count, commandCount)
        // launchApp, settle, takeScreenshot Home, tapOn, settle, takeScreenshot Broken
        XCTAssertEqual(generated.owners.map(\.screen), ["Home", "Home", "Home", "Broken", "Broken", "Broken"])
        XCTAssertEqual(generated.owners[3].step, 0)
    }

    func testATimedOutScreensSessionSaysWhereItStoppedWithoutADanglingColon() {
        let reason = RunnerSession.screensTimeoutReason(seconds: 30, screen: "Slow")
        let message = RunnerSession.failureMessage(
            reason: reason, stderr: "Received interrupt, cleaning up...\n", timedOut: true
        )
        XCTAssertEqual(
            message,
            "grantiva killed the screens session after 30s (--timeout <seconds> to raise the cap). It was at screen \"Slow\"."
        )
        XCTAssertTrue(RunnerSession.isRunnerOutcomeFailure(GrantivaError.commandFailed(message, 1)))
    }

    func testAFailedScreenIsNamedWithItsStep() {
        let failure = RunnerReportSteps.Failure(
            flowName: "screens", commandIndex: 3, action: "tapOn: text=\"No Such Element\"",
            message: "Element not found: text='No Such Element'", errorType: "element_not_found", unfinished: false
        )
        XCTAssertEqual(
            RunnerSession.screenFailureLine(failure, screen: "Broken"),
            "Screen \"Broken\" failed at tapOn: text=\"No Such Element\": Element not found: text='No Such Element'"
        )
        XCTAssertEqual(
            RunnerSession.screen(for: failure, owners: [
                .init(screen: "Home", step: nil), .init(screen: "Home", step: nil), .init(screen: "Home", step: nil),
                .init(screen: "Broken", step: 0),
            ]),
            "Broken"
        )
    }

    func testAScreensSessionRelaysTheConfigFileNameNotTheStagedFlow() async throws {
        let collected = Collected()
        RunnerNarration.sink = { collected.append($0) }
        // The stand-in prints the summary header and a runFlow cycle error the
        // way the runner does, naming the flow file it was handed.
        let runner = try fakeRunner(body: """
        echo "  [1/1] screens ($flow) - Device: test"
        echo "circular dependency detected: $flow -> /x/a.yaml" >&2
        exit 1
        """)
        do {
            _ = try await RunnerSession.run(
                screens: [GrantivaConfig.Screen(name: "S", path: .launch)],
                bundleId: "com.example", udid: "OUT-\(UUID().uuidString)", platform: OutputStubPlatform(),
                runner: runner, outputDir: scratch.appendingPathComponent("captures").path, timeoutSeconds: 30
            )
            XCTFail("expected a failure")
        } catch {
            let message = "\(error)"
            XCTAssertTrue(message.contains("circular dependency detected: grantiva.yml -> /x/a.yaml"), message)
            XCTAssertFalse(message.contains("grantiva-flows-"), message)
        }
        XCTAssertTrue(collected.text.contains("[1/1] screens (grantiva.yml)"), collected.text)
        XCTAssertFalse(collected.text.contains("grantiva-flows-"), collected.text)
    }

    // MARK: - K105: runFlow lines name the sub-flow as written

    func testTheResolverReportsTheAsWrittenPathOfEachRewrittenRunFlow() throws {
        var asWritten: [String: String] = [:]
        let resolved = try FlowReferenceResolver.resolve(
            in: """
            appId: com.example
            ---
            - runFlow: 14-runflow-sub.yaml
            - runFlow:
                file: nested/other.yaml
            - repeat:
                times: 2
                commands:
                  - runFlow: inner.yaml
            """,
            relativeTo: "/project/.maestro",
            asWritten: &asWritten
        )
        XCTAssertTrue(resolved.contains("/project/.maestro/14-runflow-sub.yaml"), resolved)
        XCTAssertEqual(asWritten, [
            "/project/.maestro/14-runflow-sub.yaml": "14-runflow-sub.yaml",
            "/project/.maestro/nested/other.yaml": "nested/other.yaml",
            "/project/.maestro/inner.yaml": "inner.yaml",
        ])
    }

    func testRunFlowStepLinesShowTheAsWrittenSubFlowPath() async throws {
        let project = scratch.appendingPathComponent("project/.maestro/coverage")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let cwd = FileManager.default.currentDirectoryPath
        XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(scratch.appendingPathComponent("project").path))
        defer { FileManager.default.changeCurrentDirectoryPath(cwd) }
        try "appId: com.example\n---\n- launchApp\n- runFlow: sub.yaml\n"
            .write(to: project.appendingPathComponent("main.yaml"), atomically: true, encoding: .utf8)
        try "appId: com.example\n---\n- launchApp\n"
            .write(to: project.appendingPathComponent("sub.yaml"), atomically: true, encoding: .utf8)
        let collected = Collected()
        RunnerNarration.sink = { collected.append($0) }
        let subFlow = project.appendingPathComponent("sub.yaml").standardizedFileURL.path
        let runner = try fakeRunner(body: """
        echo "      ▸ Run \(subFlow)"
        echo "    ✓ runFlow: \(subFlow) (2.2s)"
        printf '{"status":"passed","flows":[{"index":0,"id":"flow-000","name":"main","sourceFile":"%s","assetsDir":"assets/flow-000","status":"passed"}]}' "$flow" > "$out/report.json"
        exit 0
        """)
        _ = try await RunnerSession.runFlowFiles(
            at: [project.appendingPathComponent("main.yaml").path],
            bundleId: "com.example", udid: "OUT-\(UUID().uuidString)", platform: OutputStubPlatform(),
            runner: runner, outputDir: scratch.appendingPathComponent("captures").path, timeoutSeconds: 30
        )
        XCTAssertTrue(collected.text.contains("▸ Run sub.yaml"), collected.text)
        XCTAssertTrue(collected.text.contains("✓ runFlow: sub.yaml (2.2s)"), collected.text)
        XCTAssertFalse(collected.text.contains(subFlow), collected.text)
    }

    // MARK: - L19: stdout steps name a sub-flow as written

    func testCollectedStepsNameTheSubFlowAsWritten() throws {
        let commands = try JSONDecoder().decode(RunnerReportSteps.FlowData.self, from: Data("""
        {"commands":[
          {"yaml":"runFlow: /abs/dir/sub.yaml","status":"passed","duration":2100},
          {"yaml":"runFlow: /abs/dir/sub.yaml","status":"failed","error":{"message":"in /abs/dir/sub.yaml: tapOn failed"}}
        ]}
        """.utf8)).commands ?? []
        let steps = RunnerReportSteps.steps(commands, pathMap: ["/abs/dir/sub.yaml": "sub.yaml"])
        XCTAssertEqual(steps.map(\.action), ["runFlow: sub.yaml", "runFlow: sub.yaml"])
        XCTAssertEqual(steps.last?.message, "in sub.yaml: tapOn failed")
    }

    func testRunAndFailureResultsNameTheSubFlowAsWritten() async throws {
        let project = scratch.appendingPathComponent("project-l19/.maestro/coverage")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let cwd = FileManager.default.currentDirectoryPath
        XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(scratch.appendingPathComponent("project-l19").path))
        defer { FileManager.default.changeCurrentDirectoryPath(cwd) }
        try "appId: com.example\n---\n- launchApp\n- runFlow: sub.yaml\n"
            .write(to: project.appendingPathComponent("main.yaml"), atomically: true, encoding: .utf8)
        try "appId: com.example\n---\n- launchApp\n"
            .write(to: project.appendingPathComponent("sub.yaml"), atomically: true, encoding: .utf8)
        let subFlow = project.appendingPathComponent("sub.yaml").standardizedFileURL.path
        func body(status: String, exit: Int) -> String {
            """
            mkdir -p "$out/flows"
            printf '{"commands":[{"yaml":"launchApp","status":"passed","duration":10},{"yaml":"runFlow: \(subFlow)","status":"\(status)","duration":20,"error":{"message":"\(subFlow) failed"}}]}' > "$out/flows/flow-000.json"
            printf '{"status":"\(status)","flows":[{"index":0,"id":"flow-000","name":"main","sourceFile":"%s","assetsDir":"assets/flow-000","status":"\(status)","dataFile":"flows/flow-000.json"}]}' "$flow" > "$out/report.json"
            exit \(exit)
            """
        }
        let passing = try await RunnerSession.runFlowFiles(
            at: [project.appendingPathComponent("main.yaml").path],
            bundleId: "com.example", udid: "OUT-\(UUID().uuidString)", platform: OutputStubPlatform(),
            runner: try fakeRunner(body: body(status: "passed", exit: 0)),
            outputDir: scratch.appendingPathComponent("captures").path, timeoutSeconds: 30
        )
        XCTAssertEqual(passing.first?.steps.map(\.action), ["launchApp", "runFlow: sub.yaml"])

        let report = RunnerFailureReport()
        do {
            _ = try await RunnerSession.runFlowFiles(
                at: [project.appendingPathComponent("main.yaml").path],
                bundleId: "com.example", udid: "OUT-\(UUID().uuidString)", platform: OutputStubPlatform(),
                runner: try fakeRunner(body: body(status: "failed", exit: 1)),
                outputDir: scratch.appendingPathComponent("captures").path, timeoutSeconds: 30, failureReport: report
            )
            XCTFail("expected a failure")
        } catch {
            XCTAssertFalse(error.localizedDescription.contains(subFlow), error.localizedDescription)
        }
        let failed = try XCTUnwrap(report.captures.first)
        XCTAssertEqual(failed.steps.map(\.action), ["launchApp", "runFlow: sub.yaml"])
        XCTAssertEqual(failed.steps.last?.message, "sub.yaml failed")
    }

    /// L10: a fail-fast run reports the flows it never started as skipped.
    func testTheFailureReportNamesTheSkippedFlows() throws {
        let reportDir = scratch.appendingPathComponent("skipped-report")
        try FileManager.default.createDirectory(at: reportDir, withIntermediateDirectories: true)
        try #"{"status":"failed","flows":[{"index":0,"id":"f0","name":"02-exact-negative","status":"failed","error":"boom"},{"index":1,"id":"f1","name":"02-favorite","status":"skipped","error":"run stopped"}]}"#
            .write(to: reportDir.appendingPathComponent("report.json"), atomically: true, encoding: .utf8)
        let report = RunnerFailureReport()
        report.record(reportDir: reportDir.path, preservedReportDir: nil)
        XCTAssertEqual(report.skippedFlows, ["02-favorite"])
        XCTAssertEqual(report.captures.map(\.screenName), ["02-exact-negative", "02-favorite"], "--json keeps every flow")
    }

    // MARK: - L20: a runFlow cycle names every hop the user's way

    func testEveryReachableSubFlowMapsToItsProjectRelativePath() throws {
        let project = scratch.appendingPathComponent("cycle")
        try FileManager.default.createDirectory(at: project.appendingPathComponent("flows"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent("shared"), withIntermediateDirectories: true)
        try "appId: com.example\n---\n- runFlow: b.yaml\n"
            .write(to: project.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8)
        try "appId: com.example\n---\n- runFlow: a.yaml\n"
            .write(to: project.appendingPathComponent("b.yaml"), atomically: true, encoding: .utf8)
        try "appId: com.example\n---\n- runFlow: ../shared/d.yaml\n"
            .write(to: project.appendingPathComponent("flows/c.yaml"), atomically: true, encoding: .utf8)
        try "appId: com.example\n---\n- runFlow: ../flows/c.yaml\n"
            .write(to: project.appendingPathComponent("shared/d.yaml"), atomically: true, encoding: .utf8)
        let root = project.standardizedFileURL.path

        let map = RunnerSession.expandedPathMap(FlowReferenceResolver.reachableFlowDisplayMap(
            roots: ["\(root)/a.yaml", "\(root)/flows/c.yaml"], cwd: root
        ))
        XCTAssertEqual(map["\(root)/a.yaml"], "a.yaml")
        XCTAssertEqual(map["\(root)/b.yaml"], "b.yaml")
        XCTAssertEqual(map["\(root)/shared/d.yaml"], "shared/d.yaml")
        let other = root.hasPrefix("/private/") ? String(root.dropFirst("/private".count)) : "/private" + root
        XCTAssertEqual(map["\(other)/a.yaml"], "a.yaml", "both spellings")
        XCTAssertEqual(map["\(other)/b.yaml"], "b.yaml", "both spellings")

        let line = "  - b.yaml: circular dependency detected: a.yaml -> \(other)/b.yaml -> \(root)/a.yaml -> b.yaml"
        XCTAssertEqual(
            OutputRewriter(replacements: map).rewrite(line),
            "  - b.yaml: circular dependency detected: a.yaml -> b.yaml -> a.yaml -> b.yaml"
        )
    }

    func testAFlowRunNamesEveryHopOfACycleAsWritten() async throws {
        let project = scratch.appendingPathComponent("cycle-run")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try "appId: com.example\n---\n- runFlow: b.yaml\n"
            .write(to: project.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8)
        try "appId: com.example\n---\n- runFlow: a.yaml\n"
            .write(to: project.appendingPathComponent("b.yaml"), atomically: true, encoding: .utf8)
        let root = project.standardizedFileURL.path
        let collected = Collected()
        RunnerNarration.sink = { collected.append($0) }
        // The runner names the staged flow, then the paths it resolved itself.
        let runner = try fakeRunner(body: """
        echo "  - b.yaml: circular dependency detected: $flow -> \(root)/b.yaml -> \(root)/a.yaml -> \(root)/b.yaml" >&2
        exit 1
        """)
        let cwd = FileManager.default.currentDirectoryPath
        XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(root))
        defer { FileManager.default.changeCurrentDirectoryPath(cwd) }
        do {
            _ = try await RunnerSession.runFlowFiles(
                at: ["a.yaml"], bundleId: "com.example", udid: "OUT-\(UUID().uuidString)", platform: OutputStubPlatform(),
                runner: runner, outputDir: scratch.appendingPathComponent("captures").path, timeoutSeconds: 30
            )
            XCTFail("expected a failure")
        } catch {
            let text = collected.text + error.localizedDescription
            XCTAssertTrue(text.contains("circular dependency detected: a.yaml -> b.yaml -> a.yaml -> b.yaml"), text)
            XCTAssertFalse(text.contains(root), text)
        }
    }

    func testSubdirectoryCycleUsesCanonicalProjectRelativeHops() async throws {
        let project = URL(fileURLWithPath: "/tmp/grantiva-cycle-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: project) }
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent("flows"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent("shared"), withIntermediateDirectories: true)
        try "appId: com.example\n---\n- runFlow: ../shared/b.yaml\n"
            .write(to: project.appendingPathComponent("flows/a.yaml"), atomically: true, encoding: .utf8)
        try "appId: com.example\n---\n- runFlow: ../flows/a.yaml\n"
            .write(to: project.appendingPathComponent("shared/b.yaml"), atomically: true, encoding: .utf8)
        for root in [project.path, project.resolvingSymlinksInPath().path] {
            let collected = Collected()
            RunnerNarration.sink = { collected.append($0) }
            // The bundled runner names the staged root, its absolute first reference,
            // then the untouched relative operands of unstaged subflows.
            let runner = try fakeRunner(body: """
            echo "  - ../shared/b.yaml: circular dependency detected: $flow -> \(root)/shared/b.yaml -> ../flows/a.yaml -> ../shared/b.yaml" >&2
            exit 1
            """)
            let cwd = FileManager.default.currentDirectoryPath
            XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(root))
            defer { FileManager.default.changeCurrentDirectoryPath(cwd) }
            do {
                _ = try await RunnerSession.runFlowFiles(
                    at: ["flows/a.yaml"], bundleId: "com.example", udid: "OUT-\(UUID().uuidString)", platform: OutputStubPlatform(),
                    runner: runner, outputDir: scratch.appendingPathComponent("captures").path, timeoutSeconds: 30
                )
                XCTFail("expected a failure")
            } catch {
                let text = collected.text + error.localizedDescription
                XCTAssertTrue(text.contains("circular dependency detected: flows/a.yaml -> shared/b.yaml -> flows/a.yaml -> shared/b.yaml"), text)
                XCTAssertFalse(text.contains(project.path), text)
            }
        }
    }

    // MARK: - Helpers

    /// A runner stand-in: `$out` is the `--output` dir and `$flow` the last
    /// flow file it was handed; `body` runs after both are set.
    private func fakeRunner(body: String) throws -> RunnerManager {
        let script = scratch.appendingPathComponent("runner-\(UUID().uuidString).sh")
        try """
        #!/bin/bash
        out=""; flow=""
        while [ $# -gt 0 ]; do
          case "$1" in
            --output) out="$2"; shift 2 ;;
            *.yaml|*.yml) flow="$1"; shift ;;
            *) shift ;;
          esac
        done
        mkdir -p "$out"
        \(body)
        """.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let dir = scratch.path
        return RunnerManager(
            ensureAvailable: {}, runnerPath: { script.path }, runnerDir: { dir },
            leaseDirectory: scratch.appendingPathComponent("locks").path
        )
    }
}

final class Collected: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = ""
    func append(_ text: String) { lock.withLock { storage += text } }
    var text: String { lock.withLock { storage } }
}

/// An iOS device with no device behind it: every capture hook is a no-op.
struct OutputStubPlatform: DevicePlatform {
    var platform: Platform = .ios

    func bootDevice(named: String) async throws -> BootedDevice { fatalError() }
    func displayGeometry(deviceID: String) async throws -> DeviceGeometry { fatalError() }
    func build(_ request: PlatformBuildRequest) async throws -> BuildResult { fatalError() }
    func install(appID: String, productPath: String, deviceID: String) async throws {}
    func launch(appID: String, deviceID: String) async throws {}
    func terminate(appID: String, deviceID: String) async throws {}
    func uninstall(appID: String, deviceID: String) async throws {}
    func prepareForCapture(deviceID: String) async {}
    func restoreAfterCapture(deviceID: String) async {}
    func runnerGlobalArguments(deviceID: String, appFile: String?) -> [String] { ["--device", deviceID] }
    func runnerTestArguments() -> [String] { [] }
    func resolveBinary(_ path: String) async throws -> ResolvedBinary { fatalError() }
    func defaultDevice() async throws -> BootedDevice { fatalError() }
    func screenshot(deviceID: String, to path: String) async throws {}
    func logStream(deviceID: String, appID: String?, filter: String?, level: LogStreamLevel?) async throws -> LogStreamCommand { fatalError() }
    func runnerEnvironment(runnerHome: String, deviceID: String) -> [String: String] { [:] }
    func cleanupOrphans(deviceID: String) async {}
    func attachDriver(deviceID: String, port: UInt16?) async throws -> DriverAttachment { fatalError() }
    func recordVideo(deviceID: String, to path: String, seconds: Double) async throws {}
}

/// L18: the summary names a step as the live line does.
extension RunnerSessionOutputTests {
    func testSummaryWaitLabelMatchesTheLiveLine() {
        typealias Step = GrantivaConfig.Screen.Step
        XCTAssertEqual(RunnerSession.stepAction(for: Step(wait: 3)), "Wait 3s")
        XCTAssertEqual(RunnerSession.stepAction(for: Step(wait: 1.5)), "Wait 1.5s")
        XCTAssertEqual(RunnerSession.stepAction(for: Step(wait: 3)), FlowGenerator.waitLabel(seconds: 3))
    }

    func testSummaryLabelsKeepTheExactQualifier() {
        typealias Step = GrantivaConfig.Screen.Step
        XCTAssertEqual(RunnerSession.stepAction(for: Step(tap: "Lakes", tapExact: true)), "Tap on \"Lakes\" (exact)")
        XCTAssertEqual(
            RunnerSession.stepAction(for: Step(assertVisible: "Mono Lake", assertVisibleExact: true)),
            "Assert visible \"Mono Lake\" (exact)"
        )
        XCTAssertEqual(
            RunnerSession.stepAction(for: Step(assertNotVisible: "Golden Gate.*", assertNotVisibleExact: true)),
            "Assert not visible \"Golden Gate.*\" (exact)"
        )
        XCTAssertEqual(RunnerSession.stepAction(for: Step(tap: "Lakes")), "Tap on \"Lakes\"")
        XCTAssertEqual(RunnerSession.stepAction(for: Step(assertVisible: "Mono Lake")), "Assert visible \"Mono Lake\"")
    }
}
