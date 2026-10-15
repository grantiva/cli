import XCTest
@testable import GrantivaCore

final class RunnerSessionInfoTests: XCTestCase {
    private let session = RunnerSessionInfo(
        pid: 4242,
        wdaPort: 8100,
        bundleId: "com.example.app",
        udid: "TEST-UDID",
        startedAt: Date()
    )

    func testRecognizesTheRecordedGrantivaRunner() {
        XCTAssertTrue(session.ownsRunnerProcess(
            in: " 4242 4242 /Users/me/.grantiva/runner/grantiva-runner --device TEST-UDID"
        ))
    }

    func testRejectsAReusedPIDBelongingToAnUnrelatedProcess() {
        XCTAssertFalse(session.ownsRunnerProcess(in: " 4242 4242 /bin/sleep 30"))
        XCTAssertFalse(session.ownsRunnerProcess(in: " 4242 4242 /usr/bin/grantiva runner version"))
    }

    // MARK: - L43: the session file names the app and port as `runner start --json` does

    private func object(_ info: RunnerSessionInfo) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: info.encoded()) as? [String: Any])
    }

    func testAnAndroidSessionFileUsesApplicationIdAndPort() throws {
        let json = try object(RunnerSessionInfo(
            pid: 63796, wdaPort: 52419, bundleId: "com.kylebrowning.landmarks", udid: "emulator-5554",
            startedAt: Date(timeIntervalSinceReferenceDate: 813_438_038.5), platform: .android
        ))
        XCTAssertEqual(json["applicationId"] as? String, "com.kylebrowning.landmarks")
        XCTAssertEqual(json["port"] as? Int, 52419)
        XCTAssertEqual(json["serial"] as? String, "emulator-5554")
        XCTAssertEqual(json["udid"] as? String, "emulator-5554")
        XCTAssertEqual(json["platform"] as? String, "android")
        XCTAssertEqual(json["state"] as? String, "ready")
        // 2.1.0's names stay beside them for one release (LegacyJSONKeys.sessionFileTwins).
        XCTAssertEqual(json["bundleId"] as? String, "com.kylebrowning.landmarks")
        XCTAssertEqual(json["wdaPort"] as? Int, 52419)
    }

    func testAnIOSSessionFileKeepsBundleIdAndAddsPort() throws {
        let json = try object(RunnerSessionInfo(
            pid: 1, wdaPort: 8987, bundleId: "com.kylebrowning.Landmarks", udid: "7E846901-F93F-4220-A153-7043061033D7",
            startedAt: Date(), platform: .ios
        ))
        XCTAssertEqual(json["bundleId"] as? String, "com.kylebrowning.Landmarks")
        XCTAssertNil(json["applicationId"])
        XCTAssertNil(json["serial"])
        XCTAssertEqual(json["port"] as? Int, 8987)
    }

    func testA210SessionFileStillDecodes() throws {
        let data = Data(#"{"pid":63796,"wdaPort":52419,"platform":"android","udid":"emulator-5554","startedAt":813438038.501549,"bundleId":"com.kylebrowning.landmarks"}"#.utf8)
        let info = try RunnerSessionInfo.decode(data)
        XCTAssertEqual(info.pid, 63796)
        XCTAssertEqual(info.wdaPort, 52419)
        XCTAssertEqual(info.bundleId, "com.kylebrowning.landmarks")
        XCTAssertEqual(info.udid, "emulator-5554")
        XCTAssertEqual(info.platform, .android)
        XCTAssertTrue(info.isReady)
    }

    func testANewSessionFileRoundTrips() throws {
        let original = RunnerSessionInfo(
            pid: 9, wdaPort: 62621, bundleId: "a.b", udid: "emulator-5556",
            startedAt: Date(timeIntervalSinceReferenceDate: 813_438_038), platform: .android
        )
        let decoded = try RunnerSessionInfo.decode(original.encoded())
        XCTAssertEqual(decoded.pid, 9)
        XCTAssertEqual(decoded.wdaPort, 62621)
        XCTAssertEqual(decoded.bundleId, "a.b")
        XCTAssertEqual(decoded.udid, "emulator-5556")
        XCTAssertEqual(decoded.startedAt, original.startedAt)
    }

    // MARK: - B4-EJ.2: startedAt is an ISO 8601 UTC string (README, docs/mcp.md)

    func testTheSessionFileWritesStartedAtAsAnISO8601String() throws {
        let json = try object(RunnerSessionInfo(
            pid: 3652, wdaPort: 8403, bundleId: "com.kylebrowning.Landmarks", udid: "5C109004-BC92-4128-A6C9-43F0BE1960FF",
            startedAt: Date(timeIntervalSince1970: 1_792_090_092), platform: .ios
        ))
        XCTAssertEqual(json["startedAt"] as? String, "2026-10-15T18:48:12Z")
        let starting = try object(RunnerSessionInfo.starting(
            pid: 5, bundleId: "a.b", udid: "emulator-5554", startedAt: Date(timeIntervalSince1970: 0), platform: .android
        ))
        XCTAssertEqual(starting["startedAt"] as? String, "1970-01-01T00:00:00Z")
    }

    func testAnISO8601StartedAtDecodes() throws {
        let data = Data(#"{"pid":1,"port":2,"bundleId":"a.b","udid":"U","startedAt":"2026-10-15T18:48:12Z","state":"ready"}"#.utf8)
        XCTAssertEqual(try RunnerSessionInfo.decode(data).startedAt, Date(timeIntervalSince1970: 1_792_090_092))
    }

    func testANumericStartedAtFromAnOlderFileStillDecodes() throws {
        let data = Data(#"{"pid":1,"port":2,"bundleId":"a.b","udid":"U","startedAt":813782892.5,"state":"ready"}"#.utf8)
        XCTAssertEqual(try RunnerSessionInfo.decode(data).startedAt, Date(timeIntervalSinceReferenceDate: 813_782_892.5))
    }

    // MARK: - L38-a: written at launch as `starting`

    func testAStartingSessionHasNoPortYet() throws {
        let starting = RunnerSessionInfo.starting(
            pid: 5, bundleId: "a.b", udid: "emulator-5554", startedAt: Date(), platform: .android
        )
        XCTAssertFalse(starting.isReady)
        let json = try object(starting)
        XCTAssertEqual(json["state"] as? String, "starting")
        XCTAssertNil(json["port"])
        XCTAssertNil(json["wdaPort"])
        let decoded = try RunnerSessionInfo.decode(starting.encoded())
        XCTAssertFalse(decoded.isReady)
        XCTAssertEqual(decoded.wdaPort, 0)
    }

    func testTheStartingErrorNamesEachPlatformsDriver() {
        XCTAssertEqual(
            RunnerSessionInfo.startingError(platform: .android).localizedDescription,
            "The runner session is starting (UIAutomator2 has no session yet). Retry in a few seconds."
        )
        XCTAssertEqual(
            RunnerSessionInfo.startingError(platform: .ios).localizedDescription,
            "The runner session is starting (WDA has no session yet). Retry in a few seconds."
        )
    }
}
