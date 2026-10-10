import Foundation
import XCTest
@testable import GrantivaCore

/// Drives `RunnerSession` with a shell-script stand-in for grantiva-runner that
/// writes the report files the real runner writes (report.json, flows/*.json,
/// junit-report.xml, maestro-runner.log) against the flow paths it is handed.
final class RunnerSessionReportTests: XCTestCase {
    private var scratch: URL!
    private var previousDirectory: String!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-report-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        previousDirectory = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(scratch.path)
    }

    override func tearDownWithError() throws {
        FileManager.default.changeCurrentDirectoryPath(previousDirectory)
        try? FileManager.default.removeItem(at: scratch)
    }

    // MARK: - I11: report files name the user's flow path

    func testRewriterReplacesStagedPathsAndKeepsJSONAndXMLValid() throws {
        let staged = "/var/folders/jv/T/grantiva-ABC/0/99-crash.yaml"
        let user = #".maestro/R&D <99> "q" \b.yaml"#
        let report = scratch.appendingPathComponent("report")
        try FileManager.default.createDirectory(at: report.appendingPathComponent("flows"), withIntermediateDirectories: true)
        try """
        {
          "flows": [
            {"index": 0, "name": "99-crash", "sourceFile": "\(staged)", "error": "failed in \(staged)"},
            {"index": 1, "sourceFile": "/private\(staged)"}
          ]
        }
        """.write(to: report.appendingPathComponent("report.json"), atomically: true, encoding: .utf8)
        try #"{"sourceFile": "\#(staged.replacingOccurrences(of: "/", with: "\\/"))"}"#
            .write(to: report.appendingPathComponent("flows/flow-000.json"), atomically: true, encoding: .utf8)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuites><testsuite><testcase name="99-crash">
        <properties><property name="file" value="\(staged)"/></properties>
        </testcase></testsuite></testsuites>
        """.write(to: report.appendingPathComponent("junit-report.xml"), atomically: true, encoding: .utf8)
        try "[INFO] Flow file: \(staged)\n".write(to: report.appendingPathComponent("maestro-runner.log"), atomically: true, encoding: .utf8)

        RunnerReportRewriter.rewrite(reportDir: report.path, stagedPathMap: [staged: user])

        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: report.appendingPathComponent("report.json"))) as? [String: Any]
        let flows = try XCTUnwrap(json?["flows"] as? [[String: Any]])
        XCTAssertEqual(flows[0]["sourceFile"] as? String, user)
        XCTAssertEqual(flows[0]["error"] as? String, "failed in \(user)")
        XCTAssertEqual(flows[1]["sourceFile"] as? String, user)
        let flowJSON = try JSONSerialization.jsonObject(with: Data(contentsOf: report.appendingPathComponent("flows/flow-000.json"))) as? [String: Any]
        XCTAssertEqual(flowJSON?["sourceFile"] as? String, user)

        let xmlData = try Data(contentsOf: report.appendingPathComponent("junit-report.xml"))
        let parser = PropertyCollector(data: xmlData)
        XCTAssertTrue(parser.parse(), "rewritten junit must stay valid XML")
        XCTAssertEqual(parser.properties["file"], user)

        for file in ["report.json", "flows/flow-000.json", "junit-report.xml", "maestro-runner.log"] {
            let text = try String(contentsOf: report.appendingPathComponent(file), encoding: .utf8)
            XCTAssertFalse(text.contains("grantiva-ABC"), "\(file) still names the staged copy: \(text)")
        }
    }

    func testPreservedFlowReportNamesTheUserPathOnSuccessAndFailure() async throws {
        for exitCode in [0, 1] {
            try writeFlow("flows/login.yaml")
            let runner = try makeRunner(exitCode: exitCode)
            let reportDir = "out-\(exitCode)"
            _ = try? await RunnerSession.runFlowFiles(
                at: ["flows/login.yaml"], bundleId: "com.example", udid: udid(), platform: StubPlatform(),
                runner: runner, outputDir: "captures", reportDir: reportDir, timeoutSeconds: 30
            )
            for file in ["report.json", "flows/flow-000.json", "junit-report.xml", "maestro-runner.log"] {
                let text = try String(contentsOfFile: "\(scratch.path)/\(reportDir)/\(file)", encoding: .utf8)
                XCTAssertFalse(text.contains("/0/login.yaml"), "exit \(exitCode): \(file) names a staged copy: \(text)")
                XCTAssertTrue(text.contains("flows/login.yaml"), "exit \(exitCode): \(file): \(text)")
            }
        }
    }

    // MARK: - I18: same-basename flows get distinct names

    func testCollidingBasenamesAreStagedWithDistinctFlowNames() {
        XCTAssertEqual(
            RunnerSession.uniqueFlowNames(for: ["qa/a/same.yaml", "qa/b/same.yaml", "smoke.yaml"]),
            ["qa/a/same", "qa/b/same", nil]
        )
        XCTAssertEqual(RunnerSession.uniqueFlowNames(for: ["a/Login.yaml", "b/login.yml"]), ["a/Login", "b/login"])
        XCTAssertEqual(RunnerSession.uniqueFlowNames(for: ["a/x.yaml", "a/x.yml"]), ["a/x.yaml", "a/x.yml"])
    }

    func testInjectFlowNameAddsANameToTheHeaderUnlessTheFlowHasOne() {
        XCTAssertEqual(
            RunnerSession.injectFlowName("appId: com.example\n---\n- launchApp\n", name: "qa/a/same"),
            "appId: com.example\nname: \"qa/a/same\"\n---\n- launchApp\n"
        )
        let named = "appId: com.example\nname: Mine\n---\n- launchApp\n"
        XCTAssertEqual(RunnerSession.injectFlowName(named, name: "qa/a/same"), named)
    }

    func testRunFlowFilesStagesSameNamedFlowsUnderTheirOwnNames() async throws {
        try writeFlow("qa/a/same.yaml")
        try writeFlow("qa/b/same.yaml")
        let runner = try makeRunner(exitCode: 1)
        _ = try? await RunnerSession.runFlowFiles(
            at: ["qa/a/same.yaml", "qa/b/same.yaml"], bundleId: "com.example", udid: udid(),
            platform: StubPlatform(), runner: runner, outputDir: "captures", timeoutSeconds: 30
        )
        let staged0 = try String(contentsOfFile: "\(scratch.path)/seen/flow-0.yaml", encoding: .utf8)
        let staged1 = try String(contentsOfFile: "\(scratch.path)/seen/flow-1.yaml", encoding: .utf8)
        XCTAssertTrue(staged0.contains("name: \"qa/a/same\""), staged0)
        XCTAssertTrue(staged1.contains("name: \"qa/b/same\""), staged1)
    }

    // MARK: - I03: a failed capture leaves no stale capture behind

    func testFailedScreensCaptureRemovesThePreviousCaptures() async throws {
        let captures = scratch.appendingPathComponent(".grantiva/captures")
        try FileManager.default.createDirectory(at: captures, withIntermediateDirectories: true)
        let stale = captures.appendingPathComponent(ScreenArtifact.fileName(for: "Deep Links"))
        let unrelated = captures.appendingPathComponent("notes.txt")
        try Data("old".utf8).write(to: stale)
        try Data("keep".utf8).write(to: unrelated)

        do {
            _ = try await RunnerSession.run(
                screens: [GrantivaConfig.Screen(name: "Deep Links", path: .launch)],
                bundleId: "com.example", udid: udid(), platform: StubPlatform(),
                runner: try makeRunner(exitCode: 1), outputDir: captures.path
            )
            XCTFail("expected the runner failure to be thrown")
        } catch {
            XCTAssertTrue(RunnerSession.isRunnerOutcomeFailure(error), "run --continue-on-failure keys on this: \(error)")
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path),
                       "diff compare would pass against last run's image")
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }

    // MARK: - C04: screens runs honour --report-dir, --timeout, --continue-on-failure

    func testScreensRunWritesToASuppliedReportDirAndKeepsIt() async throws {
        let runner = try makeRunner(exitCode: 1)
        _ = try? await RunnerSession.run(
            screens: [GrantivaConfig.Screen(name: "Home", path: .launch)],
            bundleId: "com.example", udid: udid(), platform: StubPlatform(),
            runner: runner, outputDir: "out/captures",
            failFast: true, reportDir: "out", timeoutSeconds: 30
        )
        let reportDir = "\(scratch.path)/out"
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(reportDir)/report.json"), "report dir must survive the run")
        let report = try String(contentsOfFile: "\(reportDir)/report.json", encoding: .utf8)
        XCTAssertFalse(report.contains("grantiva-flows-"), report)
        let argv = try String(contentsOfFile: "\(scratch.path)/seen/argv", encoding: .utf8)
            .split(separator: "\n").map(String.init)
        let output = try XCTUnwrap(argv.firstIndex(of: "--output"))
        XCTAssertEqual(
            URL(fileURLWithPath: argv[output + 1]).resolvingSymlinksInPath().path,
            URL(fileURLWithPath: reportDir).resolvingSymlinksInPath().path
        )
        XCTAssertTrue(argv.contains("--fail-fast"))
    }

    func testScreensRunIsKilledAtTheSuppliedTimeout() async throws {
        let runner = try makeRunner(exitCode: 0, sleepSeconds: 30)
        let start = Date()
        do {
            _ = try await RunnerSession.run(
                screens: [GrantivaConfig.Screen(name: "Home", path: .launch)],
                bundleId: "com.example", udid: udid(), platform: StubPlatform(),
                runner: runner, outputDir: "captures", timeoutSeconds: 1
            )
            XCTFail("expected a timeout")
        } catch {
            XCTAssertTrue("\(error)".contains("timed out after 1s"), "\(error)")
            XCTAssertTrue(RunnerSession.isRunnerOutcomeFailure(error))
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 20)
    }

    // MARK: - Helpers

    private func udid() -> String { "TEST-REPORT-\(UUID().uuidString)" }

    private func writeFlow(_ path: String) throws {
        let url = scratch.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "appId: placeholder\n---\n- launchApp\n".write(to: url, atomically: true, encoding: .utf8)
    }

    /// A runner stand-in: records argv and each flow it is handed under
    /// `seen/`, writes the runner's report files naming those flow paths, then
    /// exits with `exitCode`.
    private func makeRunner(exitCode: Int, sleepSeconds: Int = 0) throws -> RunnerManager {
        let seen = scratch.appendingPathComponent("seen").path
        let script = scratch.appendingPathComponent("runner-\(UUID().uuidString).sh")
        try """
        #!/bin/bash
        seen='\(seen)'
        mkdir -p "$seen"
        printf '%s\\n' "$@" > "$seen/argv"
        out=""; flows=()
        while [ $# -gt 0 ]; do
          case "$1" in
            --output) out="$2"; shift 2 ;;
            *.yaml|*.yml) flows+=("$1"); shift ;;
            *) shift ;;
          esac
        done
        mkdir -p "$out/flows"
        entries=""; cases=""
        for i in "${!flows[@]}"; do
          f="${flows[$i]}"
          cp "$f" "$seen/flow-$i.yaml"
          [ -n "$entries" ] && entries="$entries,"
          entries="$entries{\\"index\\": $i, \\"id\\": \\"flow-00$i\\", \\"name\\": \\"flow\\", \\"sourceFile\\": \\"$f\\", \\"assetsDir\\": \\"assets/flow-00$i\\", \\"status\\": \\"failed\\"}"
          printf '{"sourceFile": "%s"}\\n' "$f" > "$out/flows/flow-00$i.json"
          cases="$cases<testcase name=\\"flow\\"><properties><property name=\\"file\\" value=\\"$f\\"/></properties></testcase>"
          echo "[INFO] Flow file: $f" >> "$out/maestro-runner.log"
        done
        printf '{"status": "failed", "flows": [%s]}\\n' "$entries" > "$out/report.json"
        printf '<?xml version="1.0"?><testsuites><testsuite>%s</testsuite></testsuites>\\n' "$cases" > "$out/junit-report.xml"
        sleep \(sleepSeconds)
        exit \(exitCode)
        """.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let dir = scratch.path
        return RunnerManager(ensureAvailable: {}, runnerPath: { script.path }, runnerDir: { dir })
    }
}

private final class PropertyCollector: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    var properties: [String: String] = [:]

    init(data: Data) {
        parser = XMLParser(data: data)
        super.init()
        parser.delegate = self
    }

    func parse() -> Bool { parser.parse() }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "property", let name = attributeDict["name"] {
            properties[name] = attributeDict["value"]
        }
    }
}

/// A device platform with no device: every capture hook is a no-op.
private struct StubPlatform: DevicePlatform {
    let platform: Platform = .android

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
    func logStream(deviceID: String, appID: String?, filter: String?, level: String?) async throws -> LogStreamCommand { fatalError() }
    func runnerEnvironment(runnerHome: String) -> [String: String] { [:] }
    func cleanupOrphans(deviceID: String) async {}
    func attachDriver(deviceID: String, port: UInt16?) async throws -> DriverAttachment { fatalError() }
    func recordVideo(deviceID: String, to path: String, seconds: Double) async throws {}
}
