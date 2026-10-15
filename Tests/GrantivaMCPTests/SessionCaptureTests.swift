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

    /// A relaunched app shows a still launch screen first; the capture waits
    /// for the app's first screen instead of settling on the launch screen
    /// (a blank Home through a session on iOS 27.0).
    func testALaunchOnlyScreenWaitsForTheAppPastItsLaunchScreen() async throws {
        let launchScreen = Data([0x89, 0x50, 0x4E, 0x47, 0x00])
        let home = Data([0x89, 0x50, 0x4E, 0x47, 0x01])
        let reads = LockedCounter()
        let driver = DriverClient(
            status: { WDAStatus(sessionId: "s", ready: true) },
            hierarchy: {
                // Three reads of the launch screen's tree, then the app's.
                guard reads.increment() > 3 else {
                    return ["type": "XCUIElementTypeApplication", "label": "Landmarks", "children": [["type": "XCUIElementTypeWindow"]]]
                }
                return ["type": "XCUIElementTypeApplication", "label": "Landmarks",
                        "children": [["type": "XCUIElementTypeStaticText", "label": "Landmarks"]]]
            },
            hierarchyXML: { "" },
            tapByLabel: { _ in }, tapByCoordinate: { _, _ in }, typeText: { _ in }, swipe: { _ in },
            screenshot: { reads.value > 3 ? home : launchScreen }
        )
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-launch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: output) }

        let captures = try await VRTTools.captureScreens(
            [GrantivaConfig.Screen(name: "Home", path: .launch)],
            appID: "com.example", udid: "UDID-1", platform: .ios,
            driver: driver, device: MCPFakeDevicePlatform(platform: .ios),
            outputDir: output.path, pause: { _ in }
        )
        let path = try XCTUnwrap(captures.first?.path)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: path)), home, "captured the launch screen")
    }

    /// The wait is bounded: an app whose tree never shows a labelled element
    /// is still captured.
    func testTheLaunchWaitEndsForAnAppWithNoLabelledElement() async throws {
        let recorder = WDARecorder()
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-launch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: output) }

        let captures = try await VRTTools.captureScreens(
            [GrantivaConfig.Screen(name: "Home", path: .launch)],
            appID: "com.example", udid: "UDID-1", platform: .ios,
            driver: MCPTestSupport.fakeDriver(recorder: recorder), device: MCPFakeDevicePlatform(platform: .ios),
            outputDir: output.path, pause: { _ in }
        )
        XCTAssertEqual(captures.count, 1)
        XCTAssertEqual(recorder.calls.filter { $0 == "hierarchy" }.count, Int(VRTTools.launchTimeout / 0.25))
    }

    func testOnlyALabelledElementOtherThanTheApplicationCounts() {
        XCTAssertFalse(VRTTools.hasLabelledElement(["type": "XCUIElementTypeApplication", "label": "Landmarks", "children": [["type": "XCUIElementTypeWindow", "label": ""]]]))
        XCTAssertTrue(VRTTools.hasLabelledElement(["type": "XCUIElementTypeApplication", "children": [["type": "XCUIElementTypeOther", "children": [["type": "XCUIElementTypeButton", "name": "Favorites"]]]]]))
        // UIAutomator2: text is `value`, content-desc `name`.
        XCTAssertTrue(VRTTools.hasLabelledElement(["type": "hierarchy", "children": [["type": "android.widget.TextView", "value": "Landmarks"]]]))
    }

    /// The config header's `env:` reaches the app the session relaunches,
    /// as it does through the runner's `launchApp`.
    func testTheRelaunchCarriesTheConfigHeaderEnvironment() async throws {
        let device = MCPFakeDevicePlatform(platform: .ios)
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-env-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: output) }

        _ = try await VRTTools.captureScreens(
            [GrantivaConfig.Screen(name: "Home", path: .launch)],
            appID: "com.example", udid: "UDID-1", platform: .ios,
            driver: MCPTestSupport.fakeDriver(recorder: WDARecorder()), device: device,
            outputDir: output.path, environment: ["LANDMARKS_SEED": "empty"], pause: { _ in }
        )
        XCTAssertTrue(device.calls.contains("launch(com.example,LANDMARKS_SEED=empty)"), "\(device.calls)")
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() -> Int { lock.withLock { count += 1; return count } }

}
