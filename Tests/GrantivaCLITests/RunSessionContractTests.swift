import ArgumentParser
import XCTest
@testable import GrantivaCLI
import GrantivaCore

/// `run`'s narration, its `--json` document and the checks it makes before
/// any device work (K11, K12, K13, K19, K20, K21, K22, K23, K44).
final class RunSessionContractTests: XCTestCase {
    override func tearDown() {
        RunnerNarration.isSilenced = false
        super.tearDown()
    }

    // MARK: - K11: Android narration names UIAutomator2

    func testTheSessionLineNamesEachPlatformsDriver() {
        let flows = [".maestro/01-browse.yaml", ".maestro/02-favorite.yaml"]
        XCTAssertEqual(
            RunCommand.sessionNarration(platform: .android, flows: flows, countGiven: false),
            "Running 2 flow(s) in one UIAutomator2 session: .maestro/01-browse.yaml, .maestro/02-favorite.yaml"
        )
        XCTAssertEqual(
            RunCommand.sessionNarration(platform: .ios, flows: flows, countGiven: false),
            "Running 2 flow(s) in one GrantivaAgent session: .maestro/01-browse.yaml, .maestro/02-favorite.yaml"
        )
        XCTAssertFalse(RunCommand.sessionNarration(platform: .android, flows: flows, countGiven: true).contains("GrantivaAgent"))
    }

    func testKeepAliveHelpNamesBothDrivers() {
        let help = RunCommand.helpMessage()
        XCTAssertTrue(help.contains("GrantivaAgent on iOS"), help)
        XCTAssertTrue(help.contains("UIAutomator2 on Android"), help)
    }

    // MARK: - K12: a running device is used, not booted

    func testBootNarrationForARunningTargetSaysUsing() {
        XCTAssertEqual(
            RunCommand.bootNarration(platform: .android, target: "cov-android (emulator-5554)", running: true),
            "Using emulator: cov-android (emulator-5554)"
        )
        XCTAssertEqual(RunCommand.bootNarration(platform: .ios, target: "qa-ios-1"), "Booting simulator: qa-ios-1")
    }

    func testDeviceFlagResolvesThroughTheAttachedDevicePathAndNeverBoots() async throws {
        let fake = FakeDevicePlatform(platform: .android)
        fake.bootedName = "cov-android"
        var lines: [String] = []
        let device = try await RunCommand.targetDevice(
            platform: .android, device: fake, target: "emulator-5554", serialFlag: "emulator-5554",
            log: { lines.append($0) }
        )
        XCTAssertEqual(device.udid, "emulator-5554")
        XCTAssertEqual(fake.calls.filter { $0.hasPrefix("bootDevice") }, [])
        XCTAssertTrue(fake.calls.contains("attachedDevice(emulator-5554)"), "\(fake.calls)")
        XCTAssertEqual(lines, ["Using emulator: cov-android (emulator-5554)"])
        XCTAssertFalse(lines.contains { $0.contains("Booting") })
    }

    func testAnAVDNameIsNotAnnouncedAsABootBeforeOneHappens() async throws {
        let fake = FakeDevicePlatform(platform: .android)
        fake.bootedName = "Pixel_8"
        var lines: [String] = []
        _ = try await RunCommand.targetDevice(
            platform: .android, device: fake, target: "Pixel_8", serialFlag: nil, log: { lines.append($0) }
        )
        XCTAssertEqual(lines, ["Using emulator: Pixel_8 (emulator-5598)"])
    }

    func testIOSNarrationIsUnchanged() async throws {
        let fake = FakeDevicePlatform(platform: .ios)
        fake.bootedName = "qa-ios-1"
        fake.bootedID = "UDID-1"
        var lines: [String] = []
        _ = try await RunCommand.targetDevice(platform: .ios, device: fake, target: "qa-ios-1", serialFlag: nil, log: { lines.append($0) })
        XCTAssertEqual(lines, ["Booting simulator: qa-ios-1", "Simulator booted: qa-ios-1 (UDID-1)"])
    }

    // MARK: - K13: screens and flows counted once each

    func testSuiteNarrationCountsScreensAndFlowsSeparately() {
        XCTAssertEqual(RunCommand.suiteNarration(screens: 5, flows: 12), "Capturing 5 screen(s), then running 12 flow(s)...")
        XCTAssertEqual(RunCommand.suiteNarration(screens: 5, flows: 0), "Capturing 5 screen(s)...")
        // Flows only: the session line carries the one count.
        XCTAssertNil(RunCommand.suiteNarration(screens: 0, flows: 12))
        XCTAssertTrue(RunCommand.sessionNarration(platform: .ios, flows: ["a.yaml"], countGiven: false).hasPrefix("Running 1 flow(s)"))
        XCTAssertFalse(RunCommand.sessionNarration(platform: .ios, flows: ["a.yaml"], countGiven: true).contains("flow(s)"))
    }

    // MARK: - K20: totals keep screens and flows apart

    func testTheSummaryCountsScreensAndFlowsSeparately() {
        let captures = [
            ScreenCapture(screenName: "Home", path: "/c/Home.png", sizeBytes: 1,
                          steps: [StepResult(action: "Launch app", status: .passed, duration: 1.2)]),
            ScreenCapture(screenName: "Broken", path: "", sizeBytes: 0,
                          steps: [StepResult(action: "Tap on \"No Such Element\"", status: .failed, duration: 12, message: "Element not found")]),
            ScreenCapture(screenName: "01-browse", path: "", sizeBytes: 0,
                          steps: [StepResult(action: "launchApp", status: .passed, duration: 1.9)],
                          kind: .flow, screenshots: [.init(name: "01-browse-cmd-003-Home", path: "/c/x.png"),
                                                     .init(name: "01-browse-cmd-007-Landmark Detail", path: "/c/y.png")]),
        ]
        XCTAssertEqual(RunCommand.summaryLines(captures: captures), [
            "  Screens: 2 total, 1 captured, 1 failed",
            "  Flows: 1 total, 1 passed, 0 failed",
        ])
    }

    // MARK: - K44: a missing flow file fails before any device work

    func testAMissingFlowFileFailsBeforeTheDeviceIsTouched() async throws {
        try await inProject(files: ["grantiva.yml": "bundle_id: com.example\nsimulator: qa-ios-1\n"]) { _ in
            let fake = FakeDevicePlatform(platform: .ios)
            var command = try RunCommand.parse(["--no-build", "--flow", "missing.yaml"])
            command.devicePlatform = InjectedDevicePlatform(fake)
            command.runnerManager = RunnerManager(
                ensureAvailable: {}, runnerPath: { "/usr/bin/false" }, runnerDir: { NSTemporaryDirectory() },
                leaseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("locks-\(UUID().uuidString)").path
            )
            do {
                try await command.run()
                XCTFail("expected an error")
            } catch {
                XCTAssertEqual(error.localizedDescription, "Invalid argument: Flow file not found: missing.yaml")
            }
            XCTAssertEqual(fake.calls, [], "nothing may be booted, built or installed: \(fake.calls)")
        }
    }

    func testAFlowPathThatIsADirectoryFailsTheSameWay() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("flows-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertThrowsError(try RunCommand.checkFlowFiles([dir.path])) { error in
            XCTAssertTrue(error.localizedDescription.contains(dir.path), "\(error)")
        }
    }

    // MARK: - K22: no failure screenshot for an error raised before the runner

    func testAUsageErrorTakesNoFailureScreenshot() {
        let report = RunnerFailureReport()
        XCTAssertFalse(RunCommand.wantsFailureScreenshot(
            error: GrantivaError.invalidArgument("Invalid runFlow command: ..."), report: report
        ))
        XCTAssertTrue(RunCommand.wantsFailureScreenshot(
            error: GrantivaError.commandFailed("Runner failed (exit 1)", 1), report: report
        ))
    }

    // MARK: - K23-a / K23-b: app ID order

    func testAndroidUsesTheFlowHeaderWhenNothingElseNamesTheApp() throws {
        let resolved = ResolvedProject(bundleId: "com.kylebrowning.landmarks", simulator: "emulator-5554")
        let bare = try TargetOptions.parse([])
        XCTAssertEqual(
            bare.installedAppID(platform: .android, config: nil, resolved: resolved, binaryID: nil, warn: { _ in }),
            "com.kylebrowning.landmarks"
        )
        let flagged = try TargetOptions.parse(["--application-id", "com.flag"])
        XCTAssertEqual(
            flagged.installedAppID(platform: .android, config: nil, resolved: resolved, binaryID: nil, warn: { _ in }),
            "com.flag"
        )
    }

    func testNoBuildWithoutAnIOSBundleIDSaysDetectionNeedsABuild() {
        XCTAssertEqual(
            TargetOptions.appIDMessage(for: .ios, noBuild: true),
            "Bundle ID is required to run flows. Project detection runs only when building, and --no-build skips it.\n"
                + "Pass --bundle-id or set appId (the flow header) or bundle_id in grantiva.yml."
        )
        XCTAssertEqual(
            TargetOptions.appIDMessage(for: .ios),
            "Bundle ID is required to run flows. Pass --bundle-id or set bundle_id in grantiva.yml."
        )
    }

    func testAnAndroidFlowRunWithNoConfigUsesTheHeaderEndToEnd() async throws {
        try await inProject(files: [
            "settings.gradle.kts": "rootProject.name = \"x\"\n",
            "perm.yaml": "appId: com.kylebrowning.landmarks\n---\n- launchApp\n",
        ]) { dir in
            let runner = try Self.runner(in: dir, passing: true)
            var command = try RunCommand.parse(["--platform", "android", "--no-build", "--flow", "perm.yaml", "--device", Self.fakeSerial()])
            command.devicePlatform = InjectedDevicePlatform(FakeDevicePlatform(platform: .android))
            command.runnerManager = runner
            command.resultOutput = ResultOutput { _ in }
            try await command.run()
            let argv = try String(contentsOf: dir.appendingPathComponent("argv"), encoding: .utf8)
            let staged = try String(contentsOf: dir.appendingPathComponent("staged.yaml"), encoding: .utf8)
            XCTAssertTrue(argv.contains("perm.yaml"), argv)
            XCTAssertTrue(staged.contains("appId: com.kylebrowning.landmarks"), staged)
        }
    }

    // MARK: - K19 / K21: the --json document

    func testAJSONFailureNamesTheFailedStepAndNeverPointsAtSuppressedOutput() async throws {
        let json = try await runJSON(passing: false, reportDir: "rep")
        let error = try XCTUnwrap(json["error"] as? String)
        XCTAssertTrue(error.contains("smoke: tapOn: text=\"Remove\": Element not found: text='Remove'"), error)
        XCTAssertFalse(error.contains("see the runner output above"), error)
        XCTAssertTrue(error.contains("Run grantiva hierarchy"), error)
    }

    func testAPassingDocumentCarriesReportDirLikeAFailingOne() async throws {
        let pass = try await runJSON(passing: true, reportDir: "rep")
        let fail = try await runJSON(passing: false, reportDir: "rep")
        let passDir = try XCTUnwrap(pass["reportDir"] as? String)
        let failDir = try XCTUnwrap(fail["reportDir"] as? String)
        XCTAssertTrue(passDir.hasPrefix("/") && passDir.hasSuffix("/rep"), passDir)
        XCTAssertTrue(failDir.hasPrefix("/") && failDir.hasSuffix("/rep"), failDir)
        XCTAssertNil(pass["error"])

        let none = try await runJSON(passing: true, reportDir: nil)
        XCTAssertNil(none["reportDir"])
    }

    func testPassingAndFailingDocumentsHaveTheSameShape() async throws {
        let pass = try await runJSON(passing: true, reportDir: "rep")
        let fail = try await runJSON(passing: false, reportDir: "rep")
        XCTAssertEqual(Set(pass.keys).union(["error"]), Set(fail.keys))
        let passEntry = try XCTUnwrap((pass["screens"] as? [[String: Any]])?.first)
        let failEntry = try XCTUnwrap((fail["screens"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(passEntry.keys), Set(failEntry.keys))
        XCTAssertEqual(Set(passEntry.keys), ["name", "kind", "passed", "steps", "screenshots"])
        XCTAssertEqual(passEntry["name"] as? String, "smoke")
        XCTAssertEqual(failEntry["name"] as? String, "smoke")
        XCTAssertEqual(passEntry["kind"] as? String, "flow")
        XCTAssertEqual(failEntry["kind"] as? String, "flow")
        let passSteps = try XCTUnwrap(passEntry["steps"] as? [[String: Any]])
        XCTAssertEqual(passSteps.map { $0["action"] as? String }, ["launchApp", "takeScreenshot"])
        XCTAssertEqual(passSteps.first?["duration"] as? Double, 1.8)
        let failSteps = try XCTUnwrap(failEntry["steps"] as? [[String: Any]])
        XCTAssertEqual(failSteps.last?["duration"] as? Double, 12.0)
        let shots = try XCTUnwrap(passEntry["screenshots"] as? [[String: Any]])
        XCTAssertEqual(shots.map { $0["name"] as? String }, ["smoke-cmd-001-Home"])
    }

    // MARK: - Helpers

    private func runJSON(passing: Bool, reportDir: String?) async throws -> [String: Any] {
        var document: [String: Any] = [:]
        try await inProject(files: [
            "grantiva-android.yml": "module: app\nflows:\n  - smoke.yaml\n",
            "smoke.yaml": "appId: com.placeholder\n---\n- launchApp\n- takeScreenshot: Home\n",
        ]) { dir in
            let runner = try Self.runner(in: dir, passing: passing)
            var arguments = ["--json", "--no-build", "--application-id", "com.fake", "--device", Self.fakeSerial()]
            if let reportDir { arguments += ["--report-dir", reportDir] }
            var command = try RunCommand.parse(arguments)
            command.devicePlatform = InjectedDevicePlatform(FakeDevicePlatform(platform: .android))
            command.runnerManager = runner
            let stdout = Lines()
            command.resultOutput = ResultOutput { stdout.append($0) }
            _ = try? await command.run()
            XCTAssertEqual(stdout.values.count, 1, "\(stdout.values)")
            document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(stdout.values.joined().utf8)) as? [String: Any])
        }
        return document
    }

    /// A runner stand-in that writes a report like the real one: a flow with
    /// a launch and a named screenshot, or a launch and a failed tap.
    static func runner(in dir: URL, passing: Bool) throws -> RunnerManager {
        let runner = dir.appendingPathComponent("fake-runner").path
        let report = passing
            ? #"{"status":"passed","flows":[{"index":0,"id":"flow-000","name":"smoke","sourceFile":"@FLOW@","assetsDir":"assets/flow-000","dataFile":"flows/flow-000.json","status":"passed"}]}"#
            : #"{"status":"failed","flows":[{"index":0,"id":"flow-000","name":"smoke","sourceFile":"@FLOW@","assetsDir":"assets/flow-000","dataFile":"flows/flow-000.json","status":"failed","error":"Element not found: text='Remove'"}]}"#
        let flowData = passing
            ? #"{"commands":[{"index":0,"type":"launchApp","yaml":"launchApp","status":"passed","duration":1800},{"index":1,"type":"takeScreenshot","yaml":"takeScreenshot","status":"passed","duration":120,"artifacts":{"screenshotAfter":"assets/flow-000/cmd-001-Home.png"}}]}"#
            : #"{"commands":[{"index":0,"type":"launchApp","yaml":"launchApp","status":"passed","duration":1800},{"index":1,"type":"tapOn","yaml":"tapOn: text=\"Remove\"","status":"failed","duration":12000,"error":{"type":"element_not_found","message":"Element not found: text='Remove'"}}]}"#
        try report.write(to: dir.appendingPathComponent("report.tmpl"), atomically: true, encoding: .utf8)
        try flowData.write(to: dir.appendingPathComponent("flow.json"), atomically: true, encoding: .utf8)
        try """
        #!/bin/sh
        printf '%s\\n' "$@" > '\(dir.path)/argv'
        while [ $# -gt 0 ]; do
          if [ "$1" = "--output" ]; then out="$2"; shift; fi
          flow="$1"
          shift
        done
        cp "$flow" '\(dir.path)/staged.yaml'
        mkdir -p "$out/flows" "$out/assets/flow-000"
        printf 'png' > "$out/assets/flow-000/cmd-001-Home.png"
        printf 'png' > "$out/assets/flow-000/cmd-000-before.png"
        sed "s|@FLOW@|$flow|" '\(dir.path)/report.tmpl' > "$out/report.json"
        cp '\(dir.path)/flow.json' "$out/flows/flow-000.json"
        echo "  grantiva-runner test - by Grantiva"
        exit \(passing ? 0 : 1)
        """.write(toFile: runner, atomically: true, encoding: .utf8)
        chmod(runner, 0o755)
        return RunnerManager(
            ensureAvailable: {}, runnerPath: { runner }, runnerDir: { dir.path },
            leaseDirectory: dir.appendingPathComponent("locks").path
        )
    }

    /// A serial no real device has, so a test lease can never meet another
    /// run's.
    static func fakeSerial() -> String { "emulator-test-\(UUID().uuidString)" }

    private func inProject(files: [String: String], _ body: (URL) async throws -> Void) async throws {
        let fileManager = FileManager.default
        let dir = fileManager.temporaryDirectory.appendingPathComponent("grantiva-run-contract-\(UUID().uuidString)")
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        for (name, contents) in files {
            try contents.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        let previous = fileManager.currentDirectoryPath
        defer {
            fileManager.changeCurrentDirectoryPath(previous)
            try? fileManager.removeItem(at: dir)
        }
        fileManager.changeCurrentDirectoryPath(dir.path)
        unsetenv("GRANTIVA_PLATFORM")
        try await body(dir)
    }
}

private final class Lines: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    func append(_ line: String) { lock.withLock { storage.append(line) } }
    var values: [String] { lock.withLock { storage } }
}
