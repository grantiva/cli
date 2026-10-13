import Foundation
import XCTest
@testable import GrantivaCore

/// What is read back from the runner's report directory: real step results
/// (K17, K21-b), captures that are only `takeScreenshot` points (K82-a), a
/// report that ends terminal after a kill (K80) and a `trailing` report dir
/// trimmed to the trailing set (K81).
final class RunnerReportContractTests: XCTestCase {
    private var scratch: URL!
    private var reportDir: URL!
    private var outputDir: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-report-contract-\(UUID().uuidString)")
        reportDir = scratch.appendingPathComponent("report")
        outputDir = scratch.appendingPathComponent("captures")
        try FileManager.default.createDirectory(at: reportDir.appendingPathComponent("flows"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    // MARK: - K82-a / K21-b / K17: one entry per flow, real steps, named captures only

    func testOnlyTakeScreenshotPointsBecomeCaptures() throws {
        try writeFlowReport(name: "01-browse", status: "passed", commands: Self.browseCommands)
        for file in ["cmd-000-before.png", "cmd-000-after.png", "cmd-003-before.png", "cmd-003-Home.png"] {
            try write("png", to: "assets/flow-000/\(file)")
        }

        let entries = try collect()

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.screenName, "01-browse")
        XCTAssertEqual(entries.first?.kind, .flow)
        XCTAssertEqual(entries.first?.screenshots.map(\.name), ["01-browse-cmd-003-Home"])
        let copied = try FileManager.default.contentsOfDirectory(atPath: outputDir.path)
        XCTAssertEqual(copied, ["01-browse-cmd-003-Home.png"], "no -before/-after file outside trace/")
    }

    func testStepsAreTheRunnersCommandsWithTheirMeasuredDurations() throws {
        try writeFlowReport(name: "01-browse", status: "passed", commands: Self.browseCommands)

        let steps = try XCTUnwrap(collect().first?.steps)

        XCTAssertEqual(steps.map(\.action), ["launchApp", "tapOn: text=\"Favorites\"", "waitForAnimationToEnd", "takeScreenshot"])
        XCTAssertEqual(steps.map(\.duration), [1.883, 1.6, 0.601, 0.145])
        XCTAssertEqual(steps.map(\.status), [.passed, .passed, .passed, .passed])
    }

    func testTheFailurePathCarriesTheSameRealDurations() throws {
        try writeFlowReport(name: "02-exact-negative", status: "failed", commands: """
        [{"index":0,"type":"launchApp","yaml":"launchApp","status":"passed","duration":2000},
         {"index":1,"type":"assertVisible","yaml":"assertVisible: text=\\"X\\"","status":"failed","duration":12600,
          "error":{"type":"assertion","message":"Element not visible"}},
         {"index":2,"type":"takeScreenshot","yaml":"takeScreenshot","status":"skipped"}]
        """)
        let steps = try XCTUnwrap(RunnerFailureReport.captures(reportDir: reportDir.path).first?.steps)
        XCTAssertEqual(steps.map(\.duration), [2.0, 12.6])
        XCTAssertEqual(steps.map(\.status), [.passed, .failed])
        XCTAssertEqual(steps.last?.message, "Element not visible")
    }

    /// L79: runner v4 reports a failed optional command as warned while the
    /// flow and the following required command remain passed.
    func testWarnedOptionalCommandIsRetainedWithItsError() throws {
        try writeFlowReport(name: "optional-miss", status: "passed", commands: """
        [{"index":0,"type":"launchApp","yaml":"launchApp","status":"passed","duration":1365},
         {"index":1,"type":"tapOn","yaml":"tapOn: text=\\\"No Such Element fix4-3\\\"","status":"warned","duration":7164,
          "error":{"type":"element_not_found","message":"Element not found: text='No Such Element fix4-3'"}},
         {"index":2,"type":"assertVisible","yaml":"assertVisible: text=\\\"Landmarks\\\"","status":"passed","duration":65}]
        """)

        let capture = try XCTUnwrap(collect(requestedFlow: "optional-miss.yaml").first)
        XCTAssertEqual(capture.steps.map(\.action), [
            "launchApp", "tapOn: text=\"No Such Element fix4-3\"", "assertVisible: text=\"Landmarks\"",
        ])
        XCTAssertEqual(capture.steps.map(\.status.rawValue), ["passed", "warned", "passed"])
        XCTAssertEqual(capture.steps[1].message, "Element not found: text='No Such Element fix4-3'")
        XCTAssertTrue(capture.steps.allSatisfy { $0.status != .failed })
    }

    func testScreenStepsCarryTheDurationsOfTheCommandsTheyGenerated() throws {
        let screens = [
            GrantivaConfig.Screen(name: "Home", path: .launch),
            GrantivaConfig.Screen(name: "Favorites", path: .steps([.init(tap: "Favorites")])),
        ]
        let owners = FlowGenerator.generateWithMap(screens: screens, bundleId: "com.example").owners
        // launchApp, settle, shot Home, tapOn, settle, settle-before-shot is skipped, shot Favorites
        XCTAssertEqual(owners.count, 6)
        let commands = (0..<owners.count).map { index in
            #"{"index":\#(index),"type":"t\#(index)","yaml":"t\#(index)","status":"passed","duration":\#((index + 1) * 100)}"#
        }.joined(separator: ",")
        try writeFlowReport(name: "screens", status: "passed", commands: "[\(commands)]")
        try write("png", to: "assets/flow-000/cmd-002-Home.png")
        try write("png", to: "assets/flow-000/cmd-005-Favorites.png")

        let captures = RunnerSession.screenCaptures(
            screens: screens, reportDir: reportDir.path, outputDir: outputDir.path, owners: owners,
            failure: nil, failedScreen: nil
        )

        XCTAssertEqual(captures.map(\.screenName), ["Home", "Favorites"])
        // Home: the launch-only screen reports all three of its commands.
        XCTAssertEqual(captures[0].steps.map(\.duration), [0.6])
        // Favorites: the tap and the settle it generated (400 + 500 ms).
        XCTAssertEqual(captures[1].steps.map(\.action), ["Tap on \"Favorites\""])
        XCTAssertEqual(captures[1].steps.map(\.duration), [0.9])
        XCTAssertFalse(captures[1].path.isEmpty)
    }

    func testAFailedScreensSessionNamesTheFailedScreenAndKeepsTheOnesBefore() throws {
        let screens = [
            GrantivaConfig.Screen(name: "Home", path: .launch),
            GrantivaConfig.Screen(name: "Broken", path: .steps([.init(tap: "No Such Element")])),
            GrantivaConfig.Screen(name: "Later", path: .launch),
        ]
        let owners = FlowGenerator.generateWithMap(screens: screens, bundleId: "com.example").owners
        try writeFlowReport(name: "screens", status: "failed", commands: """
        [{"index":0,"yaml":"launchApp","status":"passed","duration":1000},
         {"index":1,"yaml":"waitForAnimationToEnd","status":"passed","duration":100},
         {"index":2,"yaml":"takeScreenshot","status":"passed","duration":100},
         {"index":3,"yaml":"tapOn: text=\\"No Such Element\\"","status":"failed","duration":12000,
          "error":{"type":"element_not_found","message":"Element not found: text='No Such Element'"}},
         {"index":4,"yaml":"waitForAnimationToEnd","status":"skipped"},
         {"index":5,"yaml":"takeScreenshot","status":"skipped"},
         {"index":6,"yaml":"waitForAnimationToEnd","status":"skipped"},
         {"index":7,"yaml":"takeScreenshot","status":"skipped"}]
        """)
        try write("png", to: "assets/flow-000/cmd-002-Home.png")
        let failure = try XCTUnwrap(RunnerReportSteps.firstFailure(in: reportDir.path))
        let failedScreen = RunnerSession.screen(for: failure, owners: owners)
        XCTAssertEqual(failedScreen, "Broken")

        let captures = RunnerSession.screenCaptures(
            screens: screens, reportDir: reportDir.path, outputDir: outputDir.path, owners: owners,
            failure: failure, failedScreen: failedScreen
        )

        XCTAssertEqual(captures.map(\.screenName), ["Home", "Broken", "Later"])
        XCTAssertTrue(captures[0].steps.allSatisfy { $0.status == .passed })
        XCTAssertEqual(captures[1].steps.last?.status, .failed)
        XCTAssertEqual(captures[1].steps.last?.message, "Element not found: text='No Such Element'")
        XCTAssertEqual(captures[2].steps.first?.message, "Not captured: the screens session stopped at screen \"Broken\"")
    }

    // MARK: - K80: a killed run's report ends terminal

    func testATimeoutFinalisesARunningReport() throws {
        try write(Self.runningReport, to: "report.json")
        try write(Self.runningFlow, to: "flows/flow-000.json")
        try write(Self.runningJUnit, to: "junit-report.xml")

        RunnerReportFinalizer.finalize(
            reportDir: reportDir.path, status: "failed",
            reason: "grantiva stopped the run at the --timeout cap (30s)"
        )

        let report = try json("report.json")
        XCTAssertEqual(report["status"] as? String, "failed")
        let summary = try XCTUnwrap(report["summary"] as? [String: Any])
        XCTAssertEqual(summary["running"] as? Int, 0)
        XCTAssertEqual(summary["failed"] as? Int, 1)
        let flow = try XCTUnwrap((report["flows"] as? [[String: Any]])?.first)
        XCTAssertEqual(flow["status"] as? String, "failed")
        XCTAssertTrue((flow["error"] as? String)?.contains("--timeout") == true)
        XCTAssertEqual((flow["commands"] as? [String: Any])?["running"] as? Int, 0)

        let flowData = try json("flows/flow-000.json")
        XCTAssertEqual(flowData["status"] as? String, "failed")
        let commands = try XCTUnwrap(flowData["commands"] as? [[String: Any]])
        XCTAssertEqual(commands.map { $0["status"] as? String }, ["passed", "failed"])

        let junit = try String(contentsOf: reportDir.appendingPathComponent("junit-report.xml"), encoding: .utf8)
        XCTAssertTrue(junit.contains("<failure message=\"grantiva stopped the run at the --timeout cap (30s)\""), junit)
        XCTAssertTrue(junit.contains("<testsuites tests=\"1\" failures=\"1\""), junit)
        XCTAssertTrue(junit.contains("<testsuite name=\"maestro-runner\" tests=\"1\" failures=\"1\""), junit)

        // The ready file and the report agree.
        XCTAssertEqual(RunnerReportIndex.load(reportDir: reportDir.path)?.readyState.status, "failed")
    }

    func testAnInterruptFinalisesAsInterrupted() throws {
        try write(Self.runningReport, to: "report.json")
        RunnerReportFinalizer.finalize(reportDir: reportDir.path, status: "interrupted", reason: "grantiva was interrupted")
        let report = try json("report.json")
        XCTAssertEqual(report["status"] as? String, "interrupted")
        XCTAssertEqual((report["flows"] as? [[String: Any]])?.first?["status"] as? String, "interrupted")
    }

    func testAFinishedReportIsLeftAlone() throws {
        let finished = #"{"status":"passed","summary":{"total":1,"passed":1},"flows":[{"name":"a","status":"passed"}]}"#
        try write(finished, to: "report.json")
        RunnerReportFinalizer.finalize(reportDir: reportDir.path, status: "failed", reason: "x")
        XCTAssertEqual(try json("report.json")["status"] as? String, "passed")
    }

    // MARK: - K81: --snapshot trailing trims the report directory

    func testTrailingKeepsTheLastGoodAfterShotAndTheFailingStepsShots() throws {
        try writeFlowReport(name: "02-exact-negative", status: "failed", commands: """
        [{"index":0,"yaml":"launchApp","status":"passed","artifacts":{"screenshotBefore":"assets/flow-000/cmd-000-before.png","screenshotAfter":"assets/flow-000/cmd-000-after.png"}},
         {"index":1,"yaml":"assertVisible","status":"passed","artifacts":{"screenshotBefore":"assets/flow-000/cmd-001-before.png","screenshotAfter":"assets/flow-000/cmd-001-after.png"}},
         {"index":2,"yaml":"assertVisible","status":"failed","artifacts":{"screenshotBefore":"assets/flow-000/cmd-002-before.png","screenshotAfter":"assets/flow-000/cmd-002-after.png"}}]
        """)
        for index in 0...2 {
            for kind in ["before", "after"] {
                try write("shot-\(index)-\(kind)", to: "assets/flow-000/cmd-00\(index)-\(kind).png")
                try write("shot-\(index)-\(kind)", to: "allure-results/hash\(index)\(kind)-attachment.png")
            }
        }
        try write("named", to: "assets/flow-000/cmd-001-Home.png")
        try write("""
        {"name":"02-exact-negative","attachments":[{"name":"s","source":"hash0before-attachment.png","type":"image/png"},{"name":"s","source":"hash2after-attachment.png","type":"image/png"}],
         "steps":[{"name":"launchApp","attachments":[{"name":"after","source":"hash0after-attachment.png","type":"image/png"}]}]}
        """, to: "allure-results/abc-result.json")

        RunnerTraceTrimmer.trimTrailing(reportDir: reportDir.path)

        let assets = try FileManager.default.contentsOfDirectory(atPath: reportDir.appendingPathComponent("assets/flow-000").path).sorted()
        XCTAssertEqual(assets, ["cmd-001-Home.png", "cmd-001-after.png", "cmd-002-after.png", "cmd-002-before.png"])
        let allure = try FileManager.default.contentsOfDirectory(atPath: reportDir.appendingPathComponent("allure-results").path)
            .filter { $0.hasSuffix(".png") }.sorted()
        XCTAssertEqual(allure, ["hash1after-attachment.png", "hash2after-attachment.png", "hash2before-attachment.png"])

        let result = try String(contentsOf: reportDir.appendingPathComponent("allure-results/abc-result.json"), encoding: .utf8)
        XCTAssertFalse(result.contains("hash0before"), result)
        XCTAssertFalse(result.contains("hash0after"), result)
        XCTAssertTrue(result.contains("hash2after"), result)

        let flowData = try json("flows/flow-000.json")
        let artifacts = (flowData["commands"] as? [[String: Any]])?.map { $0["artifacts"] as? [String: String] ?? [:] }
        XCTAssertEqual(artifacts?[0], [:], "references to removed shots are dropped")
        XCTAssertEqual(artifacts?[1], ["screenshotAfter": "assets/flow-000/cmd-001-after.png"])
        XCTAssertEqual(artifacts?[2].count, 2)
    }

    func testStepShotNamesAreToldApartFromNamedScreenshots() {
        XCTAssertTrue(RunnerTraceTrimmer.isStepShot("cmd-000-before.png"))
        XCTAssertTrue(RunnerTraceTrimmer.isStepShot("cmd-012-after.png"))
        XCTAssertFalse(RunnerTraceTrimmer.isStepShot("cmd-003-Home.png"))
        XCTAssertFalse(RunnerTraceTrimmer.isStepShot("cmd-003-Landmark Detail.png"))
    }

    // MARK: - Fixtures

    static let browseCommands = """
    [{"index":0,"type":"launchApp","yaml":"launchApp","status":"passed","duration":1883},
     {"index":1,"type":"tapOn","yaml":"tapOn: text=\\"Favorites\\"","status":"passed","duration":1600},
     {"index":2,"type":"waitForAnimationToEnd","yaml":"waitForAnimationToEnd","status":"passed","duration":601},
     {"index":3,"type":"takeScreenshot","yaml":"takeScreenshot","status":"passed","duration":145,
      "artifacts":{"screenshotAfter":"assets/flow-000/cmd-003-Home.png"}}]
    """

    static let runningReport = """
    {"status":"running","summary":{"total":1,"passed":0,"failed":0,"skipped":0,"running":1,"pending":0},
     "flows":[{"index":0,"id":"flow-000","name":"18-long-wait","dataFile":"flows/flow-000.json","assetsDir":"assets/flow-000",
       "status":"running","commands":{"total":2,"passed":1,"failed":0,"skipped":0,"running":1,"pending":0,"current":1}}]}
    """

    static let runningFlow = """
    {"id":"flow-000","name":"18-long-wait","commands":[
     {"id":"cmd-000","index":0,"type":"launchApp","yaml":"launchApp","status":"passed","duration":1976},
     {"id":"cmd-001","index":1,"type":"extendedWaitUntil","yaml":"extendedWaitUntil: visible text=\\"This never appears\\"","status":"running"}]}
    """

    static let runningJUnit = """
    <?xml version="1.0" encoding="UTF-8"?>
    <testsuites tests="1" failures="0" skipped="0" errors="0" time="0.000">
      <testsuite name="maestro-runner" tests="1" failures="0" skipped="0" errors="0" time="0.000">
        <testcase name="18-long-wait" classname="18-long-wait" time="0.000">
          <properties>
            <property name="file" value=".maestro/coverage/18-long-wait.yaml"/>
          </properties>
        </testcase>
      </testsuite>
    </testsuites>
    """

    // MARK: - Helpers

    private func collect(requestedFlow: String = "01-browse.yaml") throws -> [ScreenCapture] {
        try RunnerArtifactCollector.collect(
            reportDir: reportDir.path, outputDir: outputDir.path,
            requestedFlowPaths: [requestedFlow], stagedPathMap: ["/staged/01-browse.yaml": requestedFlow]
        )
    }

    private func writeFlowReport(name: String, status: String, commands: String) throws {
        try write("""
        {"status":"\(status)","flows":[{"index":0,"id":"flow-000","name":"\(name)","sourceFile":"/staged/01-browse.yaml",
         "assetsDir":"assets/flow-000","dataFile":"flows/flow-000.json","status":"\(status)"}]}
        """, to: "report.json")
        try write("{\"id\":\"flow-000\",\"commands\":\(commands)}", to: "flows/flow-000.json")
    }

    private func write(_ text: String, to relative: String) throws {
        let url = reportDir.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    private func json(_ relative: String) throws -> [String: Any] {
        let data = try Data(contentsOf: reportDir.appendingPathComponent(relative))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
