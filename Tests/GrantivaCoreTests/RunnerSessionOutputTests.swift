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
        let project = scratch.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
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
