import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

/// K103: every `--json` document and the `--ready-file` file use camelCase
/// keys, so a consumer writes one decoder for all of them.
///
/// Each fixture encodes a representative value the way its command does.
/// Commands add theirs to `fixtures`. The only other keys allowed are the
/// snake_case aliases a document still writes next to its camelCase twin for
/// existing consumers (`LegacyJSONKeys.renamed`); each must have that twin.
/// `runner start`/`runner stop` join in a sibling change (K16).
final class JSONKeyCasingContractTests: XCTestCase {
    static func isCamelCase(_ key: String) -> Bool { key.wholeMatch(of: /[a-z][A-Za-z0-9]*/) != nil }

    /// Command name → the JSON it prints.
    static func fixtures() throws -> [(command: String, json: String)] {
        let date = Date(timeIntervalSince1970: 1_791_700_000)
        let flowEntry = ScreenCapture(
            screenName: "01-browse", path: "", sizeBytes: 0,
            steps: [StepResult(action: "launchApp", status: .passed, duration: 1.9)],
            kind: .flow, screenshots: [.init(name: "01-browse-cmd-003-Home", path: "/c/01-browse-cmd-003-Home.png")]
        )
        let failedEntry = ScreenCapture(
            screenName: "02-exact-negative", path: "", sizeBytes: 0,
            steps: [StepResult(action: "assertVisible: text=\"X\"", status: .failed, duration: 12.6, message: "Element not visible")],
            kind: .flow
        )
        let screen = ScreenCapture(
            screenName: "Home", path: "/c/Home.png", sizeBytes: 125_344, timestamp: date,
            steps: [StepResult(action: "Launch app", status: .passed, duration: 2)]
        )
        let session = ManagedSimulatorSession(
            udid: "A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF", name: "fix2-4-ios", sessionId: "fix2-4",
            ownerPID: 42, acquiredAt: date, state: .active, bootedByGrantiva: true, ephemeral: false
        )
        let readyFile = FileManager.default.temporaryDirectory.appendingPathComponent("casing-\(UUID().uuidString).ready")
        defer { try? FileManager.default.removeItem(at: readyFile) }
        try ReadyFile.write(
            RunReadyState(status: "failed", flows: [.init(name: "screens", status: "failed")], reportDir: "/ci/out", error: nil),
            to: readyFile.path
        )
        let geometry = SimulatorDisplayGeometry(points: [402, 874], pixels: [1206, 2622], scale: 3)

        return [
            ("run (pass)", try JSONOutput.string(RunCommand.RunResult(
                screens: [.init(screen), .init(flowEntry)], allPassed: true, reportDir: "/ci/out"
            ))),
            ("run (fail)", try JSONOutput.string(RunCommand.RunResult(
                screens: [.init(failedEntry)], allPassed: false, error: "Runner failed (exit 1): ...", reportDir: "/ci/out"
            ))),
            ("run --ready-file", try String(contentsOf: readyFile, encoding: .utf8)),
            ("diff capture", try JSONOutput.string(CaptureResult(
                screens: [screen], directory: ".grantiva/captures", duration: 11.6,
                simulator: CaptureSimulatorTarget(name: "fix2-4-ios", udid: session.udid, geometry: geometry)
            ))),
            ("diff compare", try JSONOutput.string(CompareResult(
                screens: [ScreenDiff(
                    screenName: "Home", status: .failed, pixelDiffPercent: 7.97, perceptualDistance: 6.4,
                    pixelThreshold: 0.02, perceptualThreshold: 5, baselinePath: "/b/Home.png",
                    capturePath: "/c/Home.png", diffImagePath: "/c/diffs/Home.png", message: "over threshold"
                )],
                passed: false, duration: 0.4
            ))),
            ("diff approve", try JSONOutput.string(ApproveResult(approvedScreens: ["Home"], baselineDirectory: ".grantiva/baselines"))),
            ("doctor", try JSONOutput.string([DoctorCheck(name: "Xcode", status: .ok, message: "26.0", fix: nil)])),
            ("simulator teardown", try JSONOutput.string([SimulatorTeardownOutcome(
                session: session, deleted: true, deviceHomesRemoved: ["/h/devices/x"]
            )])),
            ("simulator sessions", try JSONOutput.string([session])),
            ("emulator ensure", try JSONOutput.string(EmulatorProvisionResult(
                name: "fix2-4-android", serial: "emulator-5554", created: true, state: "booted"
            ))),
            ("emulator teardown", try JSONOutput.string([EmulatorTeardownOutcome(
                serial: "emulator-5554", avd: "fix2-4-android", killed: true, recorded: true
            )])),
            ("emulator delete", try EmulatorCommand.Delete.renderJSON(name: "fix2-4-android")),
            ("simulator ensure", try JSONOutput.string(SimulatorProvisionResult(
                name: "fix2-4-ios", udid: session.udid, deviceType: "iPhone 17", runtime: "iOS 26.0", created: true,
                state: "Booted", pointWidth: 402, pointHeight: 874, pixelWidth: 1206, pixelHeight: 2622, displayScale: 3
            ))),
            ("build install (iOS)", try JSONOutput.string(InstallResult(
                status: .installed, scheme: "Landmarks", bundleId: "com.kylebrowning.Landmarks",
                simulator: .init(name: "fix2-4-ios", udid: session.udid), appPath: "/b/Landmarks.app", dataContainerPath: "/d"
            ))),
            ("build install (Android)", try JSONOutput.string(AndroidInstallResult(
                status: .installed, applicationId: "com.kylebrowning.landmarks",
                device: .init(name: "fix2-4-android", serial: "emulator-5554"), appPath: "/b/app.apk"
            ))),
            ("runner start (iOS)", try JSONOutput.string(RunnerLifecycleDocument(
                status: "started", pid: 64253, port: 8235, appID: "com.kylebrowning.Landmarks",
                deviceID: session.udid, platform: .ios, log: "/tmp/grantiva-runner.log"
            ))),
            ("runner start (Android, already running)", try JSONOutput.string(RunnerLifecycleDocument(
                status: "already_running", pid: 7067, port: 57776, appID: "com.kylebrowning.landmarks",
                deviceID: "emulator-5554", platform: .android, log: nil
            ))),
            ("runner stop", try JSONOutput.string(RunnerStopCommand.document(
                .stopped(pid: 64253, udid: session.udid, killed: false)
            ))),
            ("runner stop (already exited)", try JSONOutput.string(RunnerStopCommand.document(
                .exited(pid: 64253, udid: "emulator-5554")
            ))),
            ("runner stop (keep-alive sessions)", try JSONOutput.string(RunnerStopCommand.document(.keepAlive([
                .released(grantivaPid: 4163, runnerPid: 4267, udid: session.udid),
                .terminated(runnerPid: 4300, udid: session.udid, killed: true),
            ])))),
            ("runner stop (nothing running)", try JSONOutput.string(RunnerStopCommand.document(.notRunning))),
            ("runner install", try JSONOutput.string(RunnerInstallCommand.Result(
                path: "/rh/versions/v/grantiva-runner", version: "1.1.28-grantiva.9", extracted: false
            ))),
            ("record", try JSONOutput.string(RecordReport(
                simulator: "fix2-4-ios", udid: session.udid, emulator: nil, serial: nil, video: "out.mp4",
                requestedDurationSeconds: 3, lastFrameMilliseconds: 2900, recordedMilliseconds: 3000,
                frames: [RecordFrame(requestedMilliseconds: 1000, actualMilliseconds: 1000, path: "out-1000ms.png")]
            ))),
        ]
    }

    func testEveryJSONDocumentUsesCamelCaseKeys() throws {
        for fixture in try Self.fixtures() {
            let object = try JSONSerialization.jsonObject(with: Data(fixture.json.utf8))
            for problem in Self.casingProblems(in: object, path: "$") {
                XCTFail("\(fixture.command): \(problem)")
            }
        }
    }

    func testTheCheckCatchesASnakeCaseKey() throws {
        let object = try JSONSerialization.jsonObject(with: Data(#"{"bundle_id": "x", "ok": {"report_dir": 1}}"#.utf8))
        XCTAssertEqual(Self.casingProblems(in: object, path: "$").count, 2)
    }

    /// The README paragraph lists every key still written in both spellings,
    /// with its replacement; the encoders and this test read the same table.
    func testTheReadmeListsEveryLegacyAlias() throws {
        let readme = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("README.md")
        let text = try String(contentsOf: readme, encoding: .utf8)
        for entry in LegacyJSONKeys.renamed {
            XCTAssertTrue(text.contains("`\(entry.snake)` → `\(entry.camel)`"), "README misses \(entry.snake)")
        }
    }

    func testAStepWithoutAMeasuredDurationWritesNull() throws {
        let json = try JSONOutput.string(StepResult(action: "Launch app", status: .passed, duration: nil))
        XCTAssertTrue(json.contains("\"duration\" : null"), json)
        let run = try JSONOutput.string(RunCommand.RunResult.ScreenResult(ScreenCapture(
            screenName: "S", path: "", sizeBytes: 0, steps: [StepResult(action: "a", status: .passed, duration: nil)]
        )))
        XCTAssertTrue(run.contains("\"duration\" : null"), run)
    }

    func testScreenshotPathsAreRelativeUnderTheWorkingDirectory() {
        XCTAssertEqual(RunCommand.displayPath("/p/proj/.grantiva/run-captures/a.png", cwd: "/p/proj"), ".grantiva/run-captures/a.png")
        XCTAssertEqual(RunCommand.displayPath("/elsewhere/out/captures/a.png", cwd: "/p/proj"), "/elsewhere/out/captures/a.png")
        XCTAssertEqual(RunCommand.displayPath(".grantiva/run-captures/a.png", cwd: "/p/proj"), ".grantiva/run-captures/a.png")
    }

    func testRunJSONNamesTheReportDirectoryInCamelCase() throws {
        let json = try JSONOutput.string(RunCommand.RunResult(screens: [], allPassed: true, reportDir: "/ci/out"))
        XCTAssertTrue(json.contains("\"reportDir\""), json)
    }

    /// Keys that are not camelCase, skipping documented aliases whose
    /// camelCase twin is present beside them.
    static func casingProblems(in value: Any, path: String) -> [String] {
        if let list = value as? [Any] {
            return list.enumerated().flatMap { casingProblems(in: $1, path: "\(path)[\($0)]") }
        }
        guard let object = value as? [String: Any] else { return [] }
        var problems: [String] = []
        for (key, child) in object {
            if !isCamelCase(key) {
                if let twin = LegacyJSONKeys.aliases[key] {
                    let twins = [twin] + (LegacyJSONKeys.platformTwins[key] ?? [])
                    if !twins.contains(where: { object[$0] != nil }) {
                        problems.append("\(path).\(key) has no camelCase twin \(twin)")
                    }
                } else {
                    problems.append("\(path).\(key) is not camelCase")
                }
            }
            problems += casingProblems(in: child, path: "\(path).\(key)")
        }
        return problems
    }
}
