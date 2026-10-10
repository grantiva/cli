import XCTest
import Yams
@testable import GrantivaCore

final class FlowGeneratorTests: XCTestCase {
    func testEachGeneratedFlowGetsItsOwnDirectory() throws {
        let first = try FlowGenerator.writeTemp(screens: [], bundleId: "com.example.a")
        let second = try FlowGenerator.writeTemp(screens: [], bundleId: "com.example.b")
        defer {
            for path in [first, second] {
                try? FileManager.default.removeItem(atPath: (path as NSString).deletingLastPathComponent)
            }
        }

        XCTAssertNotEqual(first, second)
        XCTAssertEqual((first as NSString).lastPathComponent, "flow.yaml")
        XCTAssertTrue(try String(contentsOfFile: first, encoding: .utf8).contains(#"appId: "com.example.a""#))
        XCTAssertTrue(try String(contentsOfFile: second, encoding: .utf8).contains(#"appId: "com.example.b""#))
    }

    func testGeneratedStringsAreValidEscapedYAML() throws {
        let screens = [GrantivaConfig.Screen(
            name: "Result: \"final\"",
            path: .steps([.init(
                tap: "Say \"hello\": now",
                type: "line one\nline two",
                assertVisible: "Value: \\quoted\"",
                assertNotVisible: "Missing: \"item\"",
                runFlow: "flows/\"child\".yaml"
            )])
        )]

        let yaml = FlowGenerator.generate(screens: screens, bundleId: "com.example:\"app\"")
        let documents = try Array(Yams.compose_all(yaml: yaml))

        XCTAssertEqual(documents.count, 2)
        XCTAssertTrue(yaml.contains(#"tapOn: "Say \"hello\": now""#))
        XCTAssertTrue(yaml.contains(#"inputText: "line one\nline two""#))
        XCTAssertTrue(yaml.contains(#"takeScreenshot: "Result: \"final\"""#))
    }

    func testAndroidScreensFlowDeliversEnvironmentAsLaunchArguments() throws {
        let yaml = FlowGenerator.generate(
            screens: [GrantivaConfig.Screen(name: "Home", path: .launch)],
            bundleId: "com.example.app",
            environment: ["LANDMARKS_NOTE": "a=b c", "LANDMARKS_SEED": "empty"],
            platform: .android
        )
        let body = try XCTUnwrap(yaml.components(separatedBy: "\n---\n").last)
        let steps = try XCTUnwrap(Yams.load(yaml: body) as? [Any])
        let launch = try XCTUnwrap((steps.first as? [String: Any])?["launchApp"] as? [String: Any])
        XCTAssertEqual(launch["arguments"] as? [String: String], ["LANDMARKS_NOTE": "a=b c", "LANDMARKS_SEED": "empty"])
        XCTAssertNil(launch["environment"])
    }

    private let settle = "- waitForAnimationToEnd:\n    timeout: 5000"

    // C09: `wait: N` sleeps N seconds; waitForAnimationToEnd is only an upper bound.
    func testWaitStepSleepsUnconditionally() throws {
        let screens = [GrantivaConfig.Screen(name: "Waited", path: .steps([.init(wait: 3)]))]
        let yaml = FlowGenerator.generate(screens: screens, bundleId: "com.example")

        XCTAssertTrue(
            yaml.contains("""
                - evalScript:
                    script: "${var grantivaWaitUntil = Date.now() + 3000; while (Date.now() < grantivaWaitUntil) {}}"
                    label: "Wait 3s"
                """),
            yaml
        )
        XCTAssertFalse(yaml.contains("timeout: 3000"), yaml)
        let steps = try XCTUnwrap(Array(Yams.compose_all(yaml: yaml)).last?.sequence)
        let eval = try XCTUnwrap(steps.compactMap { $0.mapping?["evalScript"]?.mapping }.first)
        let script = try XCTUnwrap(eval["script"]?.string)
        XCTAssertTrue(script.hasPrefix("${") && script.hasSuffix("}"), script)
        XCTAssertEqual(eval["label"]?.string, "Wait 3s")
    }

    func testFractionalWaitIsInMilliseconds() {
        XCTAssertTrue(FlowGenerator.sleepScript(seconds: 1.5).contains("Date.now() + 1500;"))
        XCTAssertEqual(FlowGenerator.waitLabel(seconds: 1.5), "Wait 1.5s")
    }

    // Golden: against the 2.0.1 output for this config, the only differences
    // are the settle lines and the wait step.
    func testLegacyMultiScreenConfigGeneratesExpectedFlow() {
        let screens = [
            GrantivaConfig.Screen(name: "Home", path: .launch),
            GrantivaConfig.Screen(name: "Profile", path: .steps([
                .init(tap: "Profile"),
                .init(swipe: "up"),
                .init(type: "abc"),
                .init(assertVisible: "Name"),
                .init(assertNotVisible: "Error"),
                .init(runFlow: "flows/extra.yaml"),
            ])),
            GrantivaConfig.Screen(name: "Waited", path: .steps([.init(wait: 2)])),
        ]
        let expected = """
            appId: "com.example"
            ---
            - launchApp
            - waitForAnimationToEnd:
                timeout: 5000
            - takeScreenshot: "Home"
            - tapOn: "Profile"
            - waitForAnimationToEnd:
                timeout: 5000
            - swipe:
                direction: UP
            - waitForAnimationToEnd:
                timeout: 5000
            - inputText: "abc"
            - waitForAnimationToEnd:
                timeout: 5000
            - assertVisible: "Name"
            - assertNotVisible: "Error"
            - runFlow: "flows/extra.yaml"
            - waitForAnimationToEnd:
                timeout: 5000
            - takeScreenshot: "Profile"
            - evalScript:
                script: "${var grantivaWaitUntil = Date.now() + 2000; while (Date.now() < grantivaWaitUntil) {}}"
                label: "Wait 2s"
            - waitForAnimationToEnd:
                timeout: 5000
            - takeScreenshot: "Waited"

            """
        XCTAssertEqual(FlowGenerator.generate(screens: screens, bundleId: "com.example"), expected)
    }

    // A04: a settle wait between each interaction and the next screenshot.
    func testTapIsFollowedBySettleBeforeScreenshot() {
        let screens = [GrantivaConfig.Screen(name: "Deep Links", path: .steps([.init(tap: "Deep Links")]))]
        let yaml = FlowGenerator.generate(screens: screens, bundleId: "com.example")

        XCTAssertTrue(
            yaml.hasSuffix("- tapOn: \"Deep Links\"\n\(settle)\n- takeScreenshot: \"Deep Links\"\n"),
            yaml
        )
    }

    func testSwipeAndTypeAreFollowedBySettle() {
        let screens = [GrantivaConfig.Screen(name: "S", path: .steps([
            .init(swipe: "Up"), .init(type: "abc"), .init(assertVisible: "Done"),
        ]))]
        let yaml = FlowGenerator.generate(screens: screens, bundleId: "com.example")

        XCTAssertTrue(yaml.contains("- swipe:\n    direction: UP\n\(settle)\n- inputText: \"abc\"\n\(settle)\n- assertVisible"), yaml)
        XCTAssertTrue(yaml.hasSuffix("- assertVisible: \"Done\"\n\(settle)\n- takeScreenshot: \"S\"\n"), yaml)
    }

    func testEveryScreenshotIsPrecededByOneSettle() {
        let screens = [
            GrantivaConfig.Screen(name: "Home", path: .launch),
            GrantivaConfig.Screen(name: "Fav", path: .steps([.init(tap: "Favorites")])),
        ]
        let yaml = FlowGenerator.generate(screens: screens, bundleId: "com.example")

        XCTAssertTrue(yaml.contains("- launchApp\n\(settle)\n- takeScreenshot: \"Home\""), yaml)
        XCTAssertEqual(yaml.components(separatedBy: "waitForAnimationToEnd").count - 1, 2, yaml)
    }

    // A13: the mapping form emits a selector with `exact: true`.
    func testExactLabelsEmitExactSelectors() throws {
        let screens = [GrantivaConfig.Screen(name: "Tab", path: .steps([
            .init(tap: "Landmarks", assertVisible: "Lakes", assertNotVisible: "Back", tapExact: true,
                  assertVisibleExact: true, assertNotVisibleExact: true),
            .init(tap: "Lakes"),
        ]))]
        let yaml = FlowGenerator.generate(screens: screens, bundleId: "com.example")

        XCTAssertTrue(yaml.contains("- tapOn:\n    text: \"Landmarks\"\n    exact: true\n"), yaml)
        XCTAssertTrue(yaml.contains("- assertVisible:\n    text: \"Lakes\"\n    exact: true\n"), yaml)
        XCTAssertTrue(yaml.contains("- assertNotVisible:\n    text: \"Back\"\n    exact: true\n"), yaml)
        XCTAssertTrue(yaml.contains("- tapOn: \"Lakes\"\n"), yaml)
        XCTAssertEqual(try Array(Yams.compose_all(yaml: yaml)).count, 2)
    }
}
