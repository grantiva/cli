import Foundation
import XCTest
import Yams
@testable import GrantivaCore

/// The runner (grantiva-runner 1.1.18, pkg/driver/wda) decides WDA's
/// `defaultAlertAction` from a launchApp's permissions with
/// `resolveAlertAction`, and grants on the simulator only the `allow`/`deny`
/// entries. These helpers mirror both so the tests pin what the runner does
/// with the rewritten flow.
private func runnerAlertAction(_ permissions: [String: String]?) -> String {
    let permissions = (permissions?.isEmpty ?? true) ? ["all": "allow"] : permissions!
    if permissions.count == 1, let all = permissions["all"] {
        switch all.lowercased() {
        case "allow": return "accept"
        case "deny": return "dismiss"
        default: break
        }
    }
    let values = Set(permissions.values.map { $0.lowercased() })
    guard values.count == 1 else { return "" }
    switch values.first {
    case "allow": return "accept"
    case "deny": return "dismiss"
    default: return ""
    }
}

private func runnerGrants(_ permissions: [String: String]?) -> [String: String] {
    let permissions = (permissions?.isEmpty ?? true) ? ["all": "allow"] : permissions!
    return permissions.filter { ["allow", "deny"].contains($0.value.lowercased()) }
}

final class FlowAlertPolicyTests: XCTestCase {
    private func launchPermissions(in yaml: String) throws -> [[String: String]?] {
        let body = yaml.components(separatedBy: "\n---\n").last ?? yaml
        let steps = try XCTUnwrap(Yams.load(yaml: body) as? [Any])
        return steps.compactMap { step -> [String: String]?? in
            if let name = step as? String { return name == "launchApp" ? .some(nil) : nil }
            guard let mapping = step as? [String: Any], let launch = mapping["launchApp"] else { return nil }
            guard let launchMap = launch as? [String: Any],
                  let permissions = launchMap["permissions"] as? [String: Any] else { return .some(nil) }
            return .some(permissions.mapValues { "\($0)" })
        }
    }

    private func assertNoMonitorSameGrants(_ flow: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let before = try launchPermissions(in: flow)
        let rewritten = FlowAlertPolicy.disableAutoAccept(in: flow)
        let after = try launchPermissions(in: rewritten)
        XCTAssertEqual(before.count, after.count, rewritten, file: file, line: line)
        for (old, new) in zip(before, after) {
            XCTAssertEqual(runnerAlertAction(new), "", "alert monitor still registered:\n\(rewritten)", file: file, line: line)
            XCTAssertEqual(runnerGrants(new), runnerGrants(old), "grants changed:\n\(rewritten)", file: file, line: line)
        }
    }

    func testTheDemoDiscardFlowNoLongerAutoAcceptsItsAlert() throws {
        let flow = """
        appId: com.kylebrowning.Landmarks
        ---
        - launchApp
        - tapOn: "Cancel"
        - assertVisible: "You have unsaved changes that will be lost."
        - tapOn: "Keep Editing"
        """
        XCTAssertEqual(runnerAlertAction(try launchPermissions(in: flow)[0]), "accept")
        try assertNoMonitorSameGrants(flow)
    }

    func testScalarLaunchAppKeepsItsAppId() throws {
        let flow = "appId: a\n---\n- launchApp: com.example.other\n- tapOn: x"
        try assertNoMonitorSameGrants(flow)
        let body = FlowAlertPolicy.disableAutoAccept(in: flow).components(separatedBy: "\n---\n").last!
        let steps = try XCTUnwrap(Yams.load(yaml: body) as? [Any])
        let launch = try XCTUnwrap((steps.first as? [String: Any])?["launchApp"] as? [String: Any])
        XCTAssertEqual(launch["appId"] as? String, "com.example.other")
    }

    func testMappingLaunchAppWithoutPermissionsKeepsItsKeys() throws {
        let flow = "appId: a\n---\n- launchApp:\n    clearState: true\n    environment:\n      A: \"1\"\n- tapOn: x"
        try assertNoMonitorSameGrants(flow)
        XCTAssertTrue(FlowAlertPolicy.disableAutoAccept(in: flow).contains("clearState: true"))
    }

    func testExplicitBlockPermissionsKeepTheirGrants() throws {
        try assertNoMonitorSameGrants("appId: a\n---\n- launchApp:\n    permissions:\n        camera: allow\n        photos: allow\n    clearState: true")
        try assertNoMonitorSameGrants("appId: a\n---\n- launchApp:\n    permissions:\n      all: deny")
    }

    func testExplicitInlinePermissionsKeepTheirGrants() throws {
        try assertNoMonitorSameGrants("appId: a\n---\n- launchApp:\n    permissions: { all: allow }")
        try assertNoMonitorSameGrants("appId: a\n---\n- launchApp:\n    permissions: {}")
    }

    func testEmptyBlockPermissionsMeansTheDefaultGrant() throws {
        try assertNoMonitorSameGrants("appId: a\n---\n- launchApp:\n    permissions:\n    clearState: true")
        try assertNoMonitorSameGrants("appId: a\n---\n- launchApp:\n    permissions:")
    }

    func testEveryLaunchAppIsRewritten() throws {
        try assertNoMonitorSameGrants("appId: a\n---\n- launchApp\n- tapOn: x\n- launchApp:\n    clearState: true\n- launchApp")
    }

    func testFlowsWithoutLaunchAppAreUnchanged() {
        let flow = "appId: a\n---\n- tapOn: x\n- assertVisible: y"
        XCTAssertEqual(FlowAlertPolicy.disableAutoAccept(in: flow), flow)
    }

    func testTheRewriteComposesWithEnvironmentInjection() throws {
        let flow = FlowEnvironment.inject(
            FlowAlertPolicy.disableAutoAccept(in: "appId: a\n---\n- launchApp"),
            environment: ["PORT": "1"]
        ).yaml
        let body = flow.components(separatedBy: "\n---\n").last!
        let steps = try XCTUnwrap(Yams.load(yaml: body) as? [Any])
        let launch = try XCTUnwrap((steps.first as? [String: Any])?["launchApp"] as? [String: Any])
        XCTAssertEqual((launch["environment"] as? [String: Any])?["PORT"] as? String, "1")
        XCTAssertEqual(runnerAlertAction((launch["permissions"] as? [String: Any])?.mapValues { "\($0)" }), "")
    }

    func testThePolicyAppliesToIOSUnlessOptedBackIn() {
        XCTAssertTrue(RunnerSession.disablesAlertAutoAccept(platform: IOSPlatform(), autoAcceptAlerts: false))
        XCTAssertFalse(RunnerSession.disablesAlertAutoAccept(platform: IOSPlatform(), autoAcceptAlerts: true))
    }

    func testGeneratedScreenFlowsCarryThePolicy() throws {
        let path = try FlowGenerator.writeTemp(
            screens: [GrantivaConfig.Screen(name: "Home", path: .launch)],
            bundleId: "com.example", disableAlertAutoAccept: true
        )
        defer { try? FileManager.default.removeItem(atPath: (path as NSString).deletingLastPathComponent) }
        let yaml = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertEqual(runnerAlertAction(try launchPermissions(in: yaml)[0]), "")
    }
}
