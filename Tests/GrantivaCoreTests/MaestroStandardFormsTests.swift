import XCTest
import Yams
@testable import GrantivaCore

/// Standard Maestro command forms (C07, C08, A02) in screens mode, and the
/// `run --flow` normaliser (C10, A02).
final class MaestroStandardFormsTests: XCTestCase {
    private func steps(_ yaml: String) throws -> [GrantivaConfig.Screen.Step] {
        let config = try MaestroFlowParser.parse(yaml)
        guard case .steps(let steps) = config.screens.first?.path else {
            XCTFail("Expected steps")
            return []
        }
        return steps
    }

    // MARK: C07

    func testSwipeDirectionForm() throws {
        let steps = try steps("""
        appId: com.example.app
        ---
        - swipe:
            direction: UP
        - takeScreenshot: "Swiped"
        """)
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps[0].swipe, "up")
        XCTAssertNil(steps[0].swipeFrom)
    }

    func testSwipePercentageCoordinates() throws {
        let steps = try steps("""
        - swipe:
            start: 60%, 17%
            end: 5%, 17%
        """)
        XCTAssertEqual(steps[0].swipe, "left")
    }

    func testSwipePercentagePointsAndDurationReachTheGeneratedFlow() throws {
        let steps = try steps("""
        - swipe:
            start: 60%, 17%
            end: 5%, 17%
            duration: 400
        - swipe:
            direction: LEFT
            duration: 250
        """)
        XCTAssertEqual(steps[0].swipeStart, "60%, 17%")
        XCTAssertEqual(steps[0].swipeEnd, "5%, 17%")
        XCTAssertEqual(steps[0].swipeDuration, 400)
        XCTAssertEqual(steps[1].swipeDuration, 250)

        let yaml = FlowGenerator.generate(screens: [.init(name: "S", path: .steps(steps))], bundleId: "a.b")
        XCTAssertTrue(yaml.contains("- swipe:\n    start: \"60%, 17%\"\n    end: \"5%, 17%\"\n    duration: 400\n"), yaml)
        XCTAssertTrue(yaml.contains("- swipe:\n    direction: LEFT\n    duration: 250\n"), yaml)
    }

    func testPixelSwipePointsFallBackToDirection() throws {
        let steps = try steps("""
        - swipe:
            start: 300, 200
            end: 100, 200
        """)
        XCTAssertEqual(steps[0].swipe, "left")
        XCTAssertNil(steps[0].swipeStart)
        XCTAssertNil(steps[0].swipeEnd)
        let yaml = FlowGenerator.generate(screens: [.init(name: "S", path: .steps(steps))], bundleId: "a.b")
        XCTAssertTrue(yaml.contains("- swipe:\n    direction: LEFT\n"), yaml)
        XCTAssertFalse(yaml.contains("start:"), yaml)
    }

    func testScrollDirectionIsCaseInsensitive() throws {
        let steps = try steps("""
        - scroll:
            direction: UP
        - scroll:
            direction: DOWN
        - scroll:
            direction: LEFT
        - scroll:
            direction: RIGHT
        """)
        XCTAssertEqual(steps.map(\.swipe), ["down", "up", "right", "left"])
    }

    func testSwipeWithUnknownDirectionIsRejected() {
        XCTAssertThrowsError(try MaestroFlowParser.parse("- swipe:\n    direction: SIDEWAYS", sourceName: "f.yaml")) {
            XCTAssertEqual($0.localizedDescription, "Invalid argument: f.yaml:1: unsupported Maestro command 'swipe'")
        }
    }

    func testExtendedWaitUntilVisibleBecomesAssertVisible() throws {
        let steps = try steps("""
        - extendedWaitUntil:
            visible: "Featured"
            timeout: 5000
        - extendedWaitUntil:
            visible:
              id: "hero"
        - extendedWaitUntil:
            notVisible: "Spinner"
        """)
        XCTAssertEqual(steps.count, 3)
        XCTAssertEqual(steps[0].assertVisible, "Featured")
        XCTAssertFalse(steps[0].assertVisibleById)
        XCTAssertEqual(steps[1].assertVisible, "hero")
        XCTAssertTrue(steps[1].assertVisibleById)
        XCTAssertEqual(steps[2].assertNotVisible, "Spinner")
    }

    func testBareWaitForAnimationToEndIsASettleStep() throws {
        let steps = try steps("""
        - waitForAnimationToEnd
        - takeScreenshot: "Settled"
        """)
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps[0].settle, MaestroFlowParser.defaultSettleSeconds)
        XCTAssertNil(steps[0].wait)
    }

    func testWaitForAnimationToEndGeneratesASettleNotASleep() {
        let yaml = FlowGenerator.generate(
            screens: [.init(name: "S", path: .steps([.init(settle: 3)]))], bundleId: "com.example.app"
        )
        XCTAssertTrue(yaml.contains("- waitForAnimationToEnd:\n    timeout: 3000\n"), yaml)
    }

    func testUnsupportedCommandErrorNamesFileAndLine() {
        let yaml = """
        appId: com.example.app
        ---
        - launchApp
        - tapOn: "Go"
        - back
        """
        XCTAssertThrowsError(try GrantivaConfig.parse(yaml, platform: .ios, fileName: "grantiva.yml")) {
            XCTAssertEqual($0.localizedDescription, "Invalid argument: grantiva.yml:5: unsupported Maestro command 'back'")
        }
    }

    func testFlowRunSkipsUnrelatedMaestroDirectory() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let maestro = dir.appendingPathComponent(".maestro")
        try FileManager.default.createDirectory(at: maestro, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "appId: a\n---\n- back\n".write(to: maestro.appendingPathComponent("bad.yaml"), atomically: true, encoding: .utf8)
        try "appId: a\n---\n- launchApp\n".write(to: maestro.appendingPathComponent("good.yaml"), atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try GrantivaConfig.loadIfPresent(platform: .ios, from: dir))
        XCTAssertNil(try GrantivaConfig.loadIfPresent(platform: .ios, from: dir, includeMaestroDirectory: false))
    }

    // MARK: C08

    func testIdSelectorsAreCarriedForEveryCommand() throws {
        let steps = try steps("""
        - tapOn:
            id: "clock"
        - assertVisible:
            id: "title"
        - assertNotVisible:
            id: "spinner"
        - scrollUntilVisible:
            element:
              id: "row30"
        - extendedWaitUntil:
            visible:
              id: "loaded"
        """)
        XCTAssertEqual(steps.map(\.tap), ["clock", nil, nil, nil, nil])
        XCTAssertTrue(steps[0].tapById)
        XCTAssertEqual(steps[1].assertVisible, "title")
        XCTAssertTrue(steps[1].assertVisibleById)
        XCTAssertEqual(steps[2].assertNotVisible, "spinner")
        XCTAssertTrue(steps[2].assertNotVisibleById)
        XCTAssertEqual(steps[3].assertVisible, "row30")
        XCTAssertTrue(steps[3].assertVisibleById)
        XCTAssertEqual(steps[4].assertVisible, "loaded")
        XCTAssertTrue(steps[4].assertVisibleById)
    }

    func testFlowGeneratorEmitsIdSelectors() throws {
        let yaml = FlowGenerator.generate(screens: [.init(name: "S", path: .steps([
            .init(tap: "General", tapById: true),
            .init(tap: "About"),
            .init(assertVisible: "title", assertVisibleById: true),
            .init(assertNotVisible: "spinner", assertNotVisibleById: true),
        ]))], bundleId: "com.apple.Preferences")
        XCTAssertTrue(yaml.contains("- tapOn:\n    id: \"General\"\n"), yaml)
        XCTAssertTrue(yaml.contains("- tapOn: \"About\"\n"), yaml)
        XCTAssertTrue(yaml.contains("- assertVisible:\n    id: \"title\"\n"), yaml)
        XCTAssertTrue(yaml.contains("- assertNotVisible:\n    id: \"spinner\"\n"), yaml)
        XCTAssertEqual(try Array(Yams.compose_all(yaml: yaml)).count, 2)
    }

    // MARK: A02

    func testSwipeFromIsKept() throws {
        let steps = try steps("""
        - swipe:
            direction: LEFT
            from: "Lake Tahoe"
        - swipe:
            direction: RIGHT
            from:
              id: "row"
        """)
        XCTAssertEqual(steps[0].swipe, "left")
        XCTAssertEqual(steps[0].swipeFrom, "Lake Tahoe")
        XCTAssertFalse(steps[0].swipeFromById)
        XCTAssertEqual(steps[1].swipeFrom, "row")
        XCTAssertTrue(steps[1].swipeFromById)
    }

    func testGeneratedSwipeFromReachesTheRunnerAsASelector() throws {
        let path = try FlowGenerator.writeTemp(screens: [.init(name: "S", path: .steps([
            .init(swipe: "left", swipeFrom: "Lake Tahoe"),
            .init(swipe: "right", swipeFrom: "row", swipeFromById: true),
        ]))], bundleId: "com.example.app")
        defer { try? FileManager.default.removeItem(atPath: (path as NSString).deletingLastPathComponent) }
        let commands = try runnerCommands(String(contentsOfFile: path, encoding: .utf8))
        let swipes = commands.compactMap { ($0 as? [String: Any])?["swipe"] as? [String: Any] }
        XCTAssertEqual(swipes.count, 2)
        XCTAssertEqual(swipes[0]["selector"] as? String, "Lake Tahoe")
        XCTAssertNil(swipes[0]["from"])
        XCTAssertEqual((swipes[1]["selector"] as? [String: Any])?["id"] as? String, "row")
    }

    // MARK: C10 / A02: the `run --flow` normaliser

    private func runnerCommands(_ yaml: String) throws -> [Any] {
        let commands = try XCTUnwrap(MaestroFlowParser.splitDocuments(yaml).commands)
        return try XCTUnwrap(Yams.load(yaml: commands) as? [Any])
    }

    func testNormaliserDefaultsBareScrollToDown() throws {
        let staged = try FlowReferenceResolver.resolve(
            in: "appId: com.example.app\n---\n- scroll\n- scroll:\n    direction: UP\n", relativeTo: "/p"
        )
        let commands = try runnerCommands(staged)
        XCTAssertEqual(((commands[0] as? [String: Any])?["scroll"] as? [String: Any])?["direction"] as? String, "DOWN")
        XCTAssertEqual(((commands[1] as? [String: Any])?["scroll"] as? [String: Any])?["direction"] as? String, "UP")
    }

    func testNormaliserGivesSetPermissionsTheHeaderAppId() throws {
        let staged = try FlowReferenceResolver.resolve(in: """
        appId: com.kylebrowning.Landmarks
        ---
        - setPermissions:
            permissions:
              notifications: allow
        - setPermissions:
            appId: com.other.app
            permissions:
              camera: deny
        - repeat:
            times: 1
            commands:
              - scroll
        """, relativeTo: "/p")
        let commands = try runnerCommands(staged)
        let first = try XCTUnwrap((commands[0] as? [String: Any])?["setPermissions"] as? [String: Any])
        XCTAssertEqual(first["appId"] as? String, "com.kylebrowning.Landmarks")
        XCTAssertEqual((first["permissions"] as? [String: Any])?["notifications"] as? String, "allow")
        let second = try XCTUnwrap((commands[1] as? [String: Any])?["setPermissions"] as? [String: Any])
        XCTAssertEqual(second["appId"] as? String, "com.other.app")
        let nested = try XCTUnwrap(((commands[2] as? [String: Any])?["repeat"] as? [String: Any])?["commands"] as? [Any])
        XCTAssertEqual(((nested[0] as? [String: Any])?["scroll"] as? [String: Any])?["direction"] as? String, "DOWN")
    }

    func testNormaliserMapsSwipeFromToSelector() throws {
        let staged = try FlowReferenceResolver.resolve(
            in: "appId: a.b\n---\n- swipe:\n    direction: LEFT\n    from: \"Lake Tahoe\"\n", relativeTo: "/p"
        )
        let swipe = try XCTUnwrap((try runnerCommands(staged)[0] as? [String: Any])?["swipe"] as? [String: Any])
        XCTAssertEqual(swipe["selector"] as? String, "Lake Tahoe")
        XCTAssertEqual(swipe["direction"] as? String, "LEFT")
        XCTAssertNil(swipe["from"])
    }

    func testGoldenMaestroFileToGeneratedFlow() throws {
        let config = try MaestroFlowParser.parse("""
        appId: com.kylebrowning.Landmarks
        ---
        - launchApp
        - tapOn:
            id: "landmark-row"
        - waitForAnimationToEnd
        - extendedWaitUntil:
            visible: "Featured"
            timeout: 5000
        - takeScreenshot: "Detail"
        - swipe:
            direction: LEFT
            from: "Lake Tahoe"
        - scroll
        - assertNotVisible:
            id: "spinner"
        - takeScreenshot: "After"
        """)
        let yaml = FlowGenerator.generate(screens: config.screens, bundleId: try XCTUnwrap(config.bundleId))
        // The generator settles after each interaction and before each
        // screenshot (A04); the source's own waitForAnimationToEnd replaces
        // the generated settle after the tap rather than doubling it.
        XCTAssertEqual(yaml, """
        appId: "com.kylebrowning.Landmarks"
        ---
        - launchApp
        - tapOn:
            id: "landmark-row"
        - waitForAnimationToEnd:
            timeout: 5000
        - assertVisible: "Featured"
        - waitForAnimationToEnd:
            timeout: 5000
        - takeScreenshot: "Detail"
        - swipe:
            direction: LEFT
            from: "Lake Tahoe"
        - waitForAnimationToEnd:
            timeout: 5000
        - swipe:
            direction: UP
        - waitForAnimationToEnd:
            timeout: 5000
        - assertNotVisible:
            id: "spinner"
        - waitForAnimationToEnd:
            timeout: 5000
        - takeScreenshot: "After"

        """)
    }

    func testFlowHeaderAppId() {
        XCTAssertEqual(MaestroFlowParser.appId(in: "appId: com.example.app\n---\n- launchApp"), "com.example.app")
        XCTAssertNil(MaestroFlowParser.appId(in: "- launchApp"))
    }
}
