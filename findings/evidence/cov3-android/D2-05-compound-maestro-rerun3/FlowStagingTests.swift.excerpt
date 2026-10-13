import Foundation
import XCTest
@testable import GrantivaCore

/// How flows and Maestro-format configs are staged for the runner: inline
/// `runFlow` (K22), sub-flow screenshots (K83), wait timeouts and scrolls
/// (K109), and the Maestro form of `grantiva-android.yml` (K24).
final class FlowStagingTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-staging-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    // MARK: - K22: inline runFlow commands

    func testInlineRunFlowCommandsPassThroughUnchanged() throws {
        let staged = try FlowReferenceResolver.resolve(in: """
        appId: com.kylebrowning.landmarks
        ---
        - launchApp
        - runFlow:
            commands:
              - tapOn: "Favorites"
              - assertVisible: "Landmarks you favorite will appear here."
        """, relativeTo: "/project")
        XCTAssertTrue(staged.contains("tapOn: Favorites"), staged)
        XCTAssertTrue(staged.contains("assertVisible: Landmarks you favorite will appear here."), staged)
    }

    func testARunFlowInsideAnInlineBlockIsResolvedAgainstTheParentFlow() throws {
        var asWritten: [String: String] = [:]
        let staged = try FlowReferenceResolver.resolve(in: """
        appId: com.example
        ---
        - runFlow:
            when:
              visible: "Login"
            commands:
              - runFlow: sub.yaml
        """, relativeTo: "/project/.maestro", asWritten: &asWritten)
        XCTAssertTrue(staged.contains("/project/.maestro/sub.yaml"), staged)
        XCTAssertTrue(staged.contains("when:"), staged)
        XCTAssertEqual(asWritten["/project/.maestro/sub.yaml"], "sub.yaml")
    }

    func testFileFormWithAConditionStillWorks() throws {
        let staged = try FlowReferenceResolver.resolve(in: """
        appId: com.example
        ---
        - runFlow:
            file: sub.yaml
            when:
              platform: iOS
        """, relativeTo: "/project")
        XCTAssertTrue(staged.contains("file: /project/sub.yaml"), staged)
    }

    func testAnEmptyRunFlowObjectNamesBothAcceptedForms() {
        XCTAssertThrowsError(try FlowReferenceResolver.resolve(in: "appId: x\n---\n- runFlow: {}\n", relativeTo: "/p")) { error in
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("runFlow: {file: <file>}"), message)
            XCTAssertTrue(message.contains("runFlow: {commands: [...]}"), message)
        }
    }

    // MARK: - K83: a sub-flow's takeScreenshot is a screen

    func testASubFlowScreenshotIsACapturePointInBothRunFlowForms() throws {
        try "appId: com.kylebrowning.Landmarks\n---\n- tapOn: \"Landmarks\"\n- takeScreenshot: \"FromSub\"\n"
            .write(to: scratch.appendingPathComponent("sub.yaml"), atomically: true, encoding: .utf8)
        for runFlow in ["- runFlow: sub.yaml", "- runFlow:\n    file: sub.yaml"] {
            let config = try MaestroFlowParser.parse(
                "appId: com.kylebrowning.Landmarks\n---\n- launchApp\n\(runFlow)\n- takeScreenshot: \"Main\"\n",
                sourceName: "grantiva.yml", baseDirectory: scratch
            )
            XCTAssertEqual(config.screens.map(\.name), ["FromSub", "Main"], runFlow)
            guard case .steps(let steps) = config.screens[0].path else { return XCTFail("FromSub has steps") }
            XCTAssertEqual(steps.first?.tap, "Landmarks")
        }
    }

    func testASubFlowWithoutAScreenshotStaysOneRunFlowStep() throws {
        try "appId: x\n---\n- tapOn: \"Landmarks\"\n"
            .write(to: scratch.appendingPathComponent("plain.yaml"), atomically: true, encoding: .utf8)
        let config = try MaestroFlowParser.parse(
            "appId: x\n---\n- launchApp\n- runFlow: plain.yaml\n- takeScreenshot: \"Main\"\n",
            sourceName: "grantiva.yml", baseDirectory: scratch
        )
        XCTAssertEqual(config.screens.map(\.name), ["Main"])
        guard case .steps(let steps) = config.screens[0].path else { return XCTFail("Main has steps") }
        XCTAssertEqual(steps.map(\.runFlow), ["plain.yaml"])
    }

    func testAMissingOrCyclicSubFlowIsLeftForTheRunnerToReport() throws {
        try "appId: x\n---\n- runFlow: a.yaml\n- takeScreenshot: \"InA\"\n"
            .write(to: scratch.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8)
        let config = try MaestroFlowParser.parse(
            "appId: x\n---\n- runFlow: missing.yaml\n- runFlow: a.yaml\n- takeScreenshot: \"Main\"\n",
            sourceName: "grantiva.yml", baseDirectory: scratch
        )
        // a.yaml is expanded once; its own runFlow back to a.yaml stays a step.
        XCTAssertEqual(config.screens.map(\.name), ["InA", "Main"])
        guard case .steps(let steps) = config.screens[0].path else { return XCTFail("InA has steps") }
        XCTAssertEqual(steps.compactMap(\.runFlow), ["missing.yaml", "a.yaml"])
    }

    func testAScreenNameTakenInBothParentAndSubFlowIsAnError() throws {
        try "appId: x\n---\n- takeScreenshot: \"Main\"\n"
            .write(to: scratch.appendingPathComponent("sub.yaml"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try MaestroFlowParser.parse(
            "appId: x\n---\n- runFlow: sub.yaml\n- tapOn: \"Go\"\n- takeScreenshot: \"Main\"\n",
            sourceName: "grantiva.yml", baseDirectory: scratch
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("\"Main\""), "\(error)")
        }
    }

    func testAConfigFileExpandsSubFlowsRelativeToItsDirectory() throws {
        try "appId: com.example\n---\n- launchApp\n- runFlow: sub.yaml\n- takeScreenshot: \"Main\"\n"
            .write(to: scratch.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
        try "appId: com.example\n---\n- takeScreenshot: \"FromSub\"\n"
            .write(to: scratch.appendingPathComponent("sub.yaml"), atomically: true, encoding: .utf8)
        let config = try XCTUnwrap(GrantivaConfig.loadIfPresent(platform: .ios, from: scratch))
        XCTAssertEqual(config.screens.map(\.name), ["FromSub", "Main"])
    }

    // MARK: - K109: extendedWaitUntil keeps its timeout; scrollUntilVisible scrolls

    func testExtendedWaitUntilKeepsItsTimeoutAndSelector() throws {
        let config = try MaestroFlowParser.parse("""
        appId: x
        ---
        - extendedWaitUntil:
            visible: "Cache Policy"
            timeout: 5000
        - extendedWaitUntil:
            notVisible:
              id: "spinner"
            timeout: 2000
        - extendedWaitUntil:
            visible:
              text: "Exact"
              exact: true
        - takeScreenshot: "S"
        """)
        guard case .steps(let steps) = config.screens[0].path else { return XCTFail("steps") }
        XCTAssertEqual(steps[0].assertVisible, "Cache Policy")
        XCTAssertEqual(steps[0].waitTimeout, 5000)
        XCTAssertEqual(steps[1].assertNotVisible, "spinner")
        XCTAssertTrue(steps[1].assertNotVisibleById)
        XCTAssertEqual(steps[1].waitTimeout, 2000)
        XCTAssertTrue(steps[2].assertVisibleExact)
        XCTAssertNil(steps[2].waitTimeout)

        let yaml = FlowGenerator.generate(screens: config.screens, bundleId: "x")
        XCTAssertTrue(yaml.contains("""
        - extendedWaitUntil:
            visible: "Cache Policy"
            timeout: 5000
        """), yaml)
        XCTAssertTrue(yaml.contains("""
        - extendedWaitUntil:
            notVisible:
              id: "spinner"
            timeout: 2000
        """), yaml)
        // Without a timeout the step is generated as before.
        XCTAssertTrue(yaml.contains("- assertVisible:\n    text: \"Exact\"\n    exact: true"), yaml)
    }

    func testScrollUntilVisibleStaysAScroll() throws {
        let config = try MaestroFlowParser.parse("""
        appId: x
        ---
        - scrollUntilVisible:
            element:
              id: "row-12"
            direction: DOWN
            timeout: 20000
        - takeScreenshot: "S"
        """)
        let yaml = FlowGenerator.generate(screens: config.screens, bundleId: "x")
        XCTAssertTrue(yaml.contains("""
        - scrollUntilVisible:
            element:
              id: "row-12"
            direction: DOWN
            timeout: 20000
        """), yaml)
        XCTAssertFalse(yaml.contains("- assertVisible"), yaml)
    }

    // MARK: - K24: Maestro-format grantiva-android.yml

    static let androidMaestroConfig = """
    appId: com.kylebrowning.landmarks
    ---
    - launchApp
    - swipe:
        direction: UP
    - waitForAnimationToEnd
    - takeScreenshot: "Home Swiped"
    - tapOn: "Deep Links"
    - tapOn: "Caching Demo"
    - extendedWaitUntil:
        visible: "Cache Policy"
        timeout: 5000
    - tapOn:
        id: "clock"
    - assertVisible:
        id: "clock"
    - takeScreenshot: "Caching Maestro"
    """

    func testAMaestroFormatAndroidConfigLoadsWithAndroidDefaults() throws {
        try Self.androidMaestroConfig.write(to: scratch.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        let config = try XCTUnwrap(GrantivaConfig.loadIfPresent(platform: .android, from: scratch))
        XCTAssertEqual(config.platform, .android)
        XCTAssertEqual(config.android?.applicationId, "com.kylebrowning.landmarks")
        XCTAssertEqual(config.android?.module, "app")
        XCTAssertEqual(config.android?.variant, "debug")
        XCTAssertEqual(config.screens.map(\.name), ["Home Swiped", "Caching Maestro"])
        guard case .steps(let steps) = config.screens[1].path else { return XCTFail("steps") }
        XCTAssertTrue(steps.contains { $0.tap == "clock" && $0.tapById })
        XCTAssertTrue(steps.contains { $0.assertVisible == "clock" && $0.assertVisibleById })

        let yaml = FlowGenerator.generate(screens: config.screens, bundleId: "com.kylebrowning.landmarks", platform: .android)
        XCTAssertTrue(yaml.contains("- tapOn:\n    id: \"clock\""), yaml)
        XCTAssertTrue(yaml.contains("- assertVisible:\n    id: \"clock\""), yaml)
    }

    func testAnAndroidFlagStillWinsOverTheMaestroAppId() throws {
        try Self.androidMaestroConfig.write(to: scratch.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        let config = try XCTUnwrap(GrantivaConfig.loadIfPresent(platform: .android, from: scratch))
        XCTAssertEqual(
            AndroidProject.applicationID(override: "com.flag", binary: nil, configured: config.android?.applicationId).id,
            "com.flag"
        )
    }
}
