import Foundation
import GrantivaCore
import MCP
import XCTest
@testable import GrantivaMCP

/// L23: a capture through a runner session never reports a step as 0 s. The
/// launch-only screen's `Launch app` step carries the measured launch (the
/// first such screen) or `null` (a later one: the app was not relaunched).
@available(macOS 15, *)
final class SessionCaptureTests: XCTestCase {
    func testTheLaunchStepIsMeasuredOrNullNeverZero() async throws {
        let device = MCPFakeDevicePlatform(platform: .ios)
        device.launchDelay = 50_000_000
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-l23-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: output) }

        let captures = try await VRTTools.captureScreens(
            [GrantivaConfig.Screen(name: "Home", path: .launch), GrantivaConfig.Screen(name: "Again", path: .launch)],
            appID: "com.example", udid: "UDID-1", platform: .ios,
            driver: MCPTestSupport.fakeDriver(recorder: WDARecorder()), device: device,
            outputDir: output.path, pause: { _ in }
        )
        let home = try XCTUnwrap(captures.first?.steps.first)
        XCTAssertEqual(home.action, "Launch app")
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(home.duration), 0.05)
        let again = try XCTUnwrap(captures.last?.steps.first)
        XCTAssertNil(again.duration)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(again), as: UTF8.self)
        XCTAssertTrue(json.contains(#""duration":null"#), json)
        XCTAssertFalse(String(decoding: try encoder.encode(home), as: UTF8.self).contains(#""duration":0,"#))
    }
}
