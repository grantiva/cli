import Foundation
import XCTest
import Yams
@testable import GrantivaCore

/// `--env KEY=VALUE` rides the runner's existing `launchApp: environment:`
/// field. These tests check both the parsing and that the injected YAML is
/// still valid YAML with the values in the place the runner reads them.
final class FlowEnvironmentTests: XCTestCase {
    // MARK: - Parsing

    func testParsesKeyValuePairs() throws {
        let parsed = try FlowEnvironment.parse(["PORT=8080", "HOST=127.0.0.1"])
        XCTAssertEqual(parsed, ["PORT": "8080", "HOST": "127.0.0.1"])
    }

    func testValueMayBeEmptyOrContainEquals() throws {
        let parsed = try FlowEnvironment.parse(["EMPTY=", "URL=a=b=c"])
        XCTAssertEqual(parsed["EMPTY"], "")
        XCTAssertEqual(parsed["URL"], "a=b=c")
    }

    func testRejectsAPairWithoutSeparator() {
        XCTAssertThrowsError(try FlowEnvironment.parse(["PORT"])) { error in
            XCTAssertTrue(String(describing: error).contains("expected KEY=VALUE"), String(describing: error))
        }
    }

    func testRejectsAnEmptyKey() {
        XCTAssertThrowsError(try FlowEnvironment.parse(["=8080"])) { error in
            XCTAssertTrue(String(describing: error).contains("key before `=` is empty"), String(describing: error))
        }
    }

    func testRejectsAKeyWithWhitespace() {
        XCTAssertThrowsError(try FlowEnvironment.parse(["MY PORT=1"])) { error in
            XCTAssertTrue(String(describing: error).contains("must not contain whitespace"), String(describing: error))
        }
    }

    // MARK: - Injection

    private func launchEnvironment(in yaml: String, field: String = "environment") throws -> [String: String] {
        let body = yaml.components(separatedBy: "\n---\n").last ?? yaml
        let steps = try XCTUnwrap(Yams.load(yaml: body) as? [Any])
        for step in steps {
            guard let mapping = step as? [String: Any],
                  let launch = mapping["launchApp"] as? [String: Any],
                  let environment = launch[field] as? [String: Any]
            else { continue }
            return environment.mapValues { "\($0)" }
        }
        return [:]
    }

    func testInjectsIntoABareLaunchApp() throws {
        let flow = """
        appId: com.example.app
        ---
        - launchApp
        - tapOn: "Start"
        """
        let result = FlowEnvironment.inject(flow, environment: ["PORT": "51234"])
        XCTAssertTrue(result.injected)
        XCTAssertEqual(try launchEnvironment(in: result.yaml)["PORT"], "51234")
    }

    func testKeepsTheAppIdOfAScalarLaunchApp() throws {
        let flow = """
        appId: com.example.app
        ---
        - launchApp: com.example.other
        """
        let result = FlowEnvironment.inject(flow, environment: ["PORT": "51234"])
        let body = result.yaml.components(separatedBy: "\n---\n").last ?? ""
        let steps = try XCTUnwrap(Yams.load(yaml: body) as? [Any])
        let launch = try XCTUnwrap((steps.first as? [String: Any])?["launchApp"] as? [String: Any])
        XCTAssertEqual(launch["appId"] as? String, "com.example.other")
        XCTAssertEqual((launch["environment"] as? [String: Any])?["PORT"] as? String, "51234")
    }

    func testMergesIntoAMappingLaunchAppPreservingItsOtherKeys() throws {
        let flow = """
        appId: com.example.app
        ---
        - launchApp:
            clearState: true
        - tapOn: "Start"
        """
        let result = FlowEnvironment.inject(flow, environment: ["PORT": "51234"])
        let body = result.yaml.components(separatedBy: "\n---\n").last ?? ""
        let steps = try XCTUnwrap(Yams.load(yaml: body) as? [Any])
        let launch = try XCTUnwrap((steps.first as? [String: Any])?["launchApp"] as? [String: Any])
        XCTAssertEqual(launch["clearState"] as? Bool, true)
        XCTAssertEqual((launch["environment"] as? [String: Any])?["PORT"] as? String, "51234")
    }

    func testOverridesAnExistingEnvironmentKeyWithoutDuplicatingIt() throws {
        let flow = """
        appId: com.example.app
        ---
        - launchApp:
            environment:
              PORT: "1111"
              KEEP: "yes"
        """
        let result = FlowEnvironment.inject(flow, environment: ["PORT": "51234"])
        let environment = try launchEnvironment(in: result.yaml)
        XCTAssertEqual(environment["PORT"], "51234")
        XCTAssertEqual(environment["KEEP"], "yes")
    }

    func testReportsWhenTheFlowHasNoLaunchAppToCarryTheEnvironment() {
        let flow = """
        appId: com.example.app
        ---
        - tapOn: "Start"
        """
        let result = FlowEnvironment.inject(flow, environment: ["PORT": "1"])
        XCTAssertFalse(result.injected)
        XCTAssertEqual(result.yaml, flow)
    }

    func testAnEmptyEnvironmentLeavesTheFlowUntouched() {
        let flow = "appId: com.example.app\n---\n- launchApp\n"
        XCTAssertEqual(FlowEnvironment.inject(flow, environment: [:]).yaml, flow)
    }

    func testQuotesValuesThatWouldBreakYAML() throws {
        let flow = "appId: com.example.app\n---\n- launchApp\n"
        let result = FlowEnvironment.inject(flow, environment: ["JSON": "{\"a\": 1}"])
        XCTAssertEqual(try launchEnvironment(in: result.yaml)["JSON"], "{\"a\": 1}")
    }

    // MARK: - Platform delivery and header env

    private func launchApp(in yaml: String) throws -> [String: Any] {
        let body = yaml.components(separatedBy: "\n---\n").last ?? yaml
        let steps = try XCTUnwrap(Yams.load(yaml: body) as? [Any])
        return try XCTUnwrap((steps.first as? [String: Any])?["launchApp"] as? [String: Any])
    }

    func testAndroidDeliversEnvAsArgumentsIntoABareLaunchApp() throws {
        let flow = "appId: com.example.app\n---\n- launchApp\n- tapOn: \"Start\"\n"
        let result = FlowEnvironment.apply(to: flow, environment: ["NOTE": "a=b c"], platform: .android)
        XCTAssertTrue(result.injected)
        let launch = try launchApp(in: result.yaml)
        XCTAssertEqual(launch["arguments"] as? [String: String], ["NOTE": "a=b c"])
        XCTAssertNil(launch["environment"])
        XCTAssertTrue(result.yaml.contains("NOTE: \"a=b c\""), result.yaml)
    }

    func testAndroidDeliversEnvAsArgumentsIntoAScalarLaunchApp() throws {
        let flow = "appId: com.example.app\n---\n- launchApp: com.example.other\n"
        let result = FlowEnvironment.apply(to: flow, environment: ["NOTE": "a=b c"], platform: .android)
        let launch = try launchApp(in: result.yaml)
        XCTAssertEqual(launch["appId"] as? String, "com.example.other")
        XCTAssertEqual(launch["arguments"] as? [String: String], ["NOTE": "a=b c"])
    }

    func testAndroidMergesEnvIntoAnExistingArgumentsMap() throws {
        let flow = """
        appId: com.example.app
        ---
        - launchApp:
            clearState: true
            arguments:
              KEEP: "yes"
              SEED: "default"
        """
        let result = FlowEnvironment.apply(to: flow, environment: ["SEED": "empty", "NOTE": "a=b c"], platform: .android)
        let launch = try launchApp(in: result.yaml)
        XCTAssertEqual(launch["clearState"] as? Bool, true)
        XCTAssertEqual(launch["arguments"] as? [String: String], ["KEEP": "yes", "SEED": "empty", "NOTE": "a=b c"])
    }

    func testAndroidTurnsAFlowsOwnLaunchEnvironmentIntoArguments() throws {
        let flow = """
        appId: com.example.app
        ---
        - launchApp:
            environment:
              SEED: "many"
        """
        let result = FlowEnvironment.apply(to: flow, environment: [:], platform: .android)
        let launch = try launchApp(in: result.yaml)
        XCTAssertEqual(launch["arguments"] as? [String: String], ["SEED": "many"])
        XCTAssertNil(launch["environment"])
    }

    func testIOSKeepsDeliveringEnvAsEnvironment() throws {
        let flow = "appId: com.example.app\n---\n- launchApp\n"
        let result = FlowEnvironment.apply(to: flow, environment: ["NOTE": "x"], platform: .ios)
        XCTAssertEqual(try launchEnvironment(in: result.yaml), ["NOTE": "x"])
        XCTAssertNil(try launchApp(in: result.yaml)["arguments"])
    }

    func testHeaderEnvIsMergedIntoTheLaunchEnvironment() throws {
        let flow = "appId: com.example.app\nenv:\n  A: b\n  CRASH: \"1\"\n---\n- launchApp\n"
        let ios = FlowEnvironment.apply(to: flow, environment: [:], platform: .ios)
        XCTAssertEqual(try launchEnvironment(in: ios.yaml), ["A": "b", "CRASH": "1"])
        let android = FlowEnvironment.apply(to: flow, environment: [:], platform: .android)
        XCTAssertEqual(try launchEnvironment(in: android.yaml, field: "arguments"), ["A": "b", "CRASH": "1"])
    }

    func testCLIEnvWinsOverHeaderEnvAndAStepValueWinsOverHeaderEnv() throws {
        let flow = """
        appId: com.example.app
        env:
          SEED: empty
          NOTE: header
          OTHER: header
        ---
        - launchApp:
            environment:
              OTHER: step
        """
        let result = FlowEnvironment.apply(to: flow, environment: ["SEED": "many"], platform: .ios)
        XCTAssertEqual(try launchEnvironment(in: result.yaml), ["SEED": "many", "NOTE": "header", "OTHER": "step"])
    }

    func testAFlowWithoutHeaderEnvOrCLIEnvIsUntouched() {
        let flow = "appId: com.example.app\n---\n- launchApp\n"
        XCTAssertEqual(FlowEnvironment.apply(to: flow, environment: [:], platform: .ios).yaml, flow)
        XCTAssertEqual(FlowEnvironment.apply(to: flow, environment: [:], platform: .android).yaml, flow)
    }

    func testHeaderEnvReadsOnlyTheHeader() {
        XCTAssertEqual(FlowEnvironment.headerEnvironment("appId: x\nenv:\n  A: b\n---\n- launchApp\n"), ["A": "b"])
        XCTAssertEqual(FlowEnvironment.headerEnvironment("- launchApp\n- inputText: \"env: x\"\n"), [:])
    }

    func testHeaderEnvSurvivesALeadingDocumentMarker() {
        let flow = "---\nappId: x\nenv:\n  A: b\n---\n- launchApp\n"
        XCTAssertEqual(FlowEnvironment.headerEnvironment(flow), ["A": "b"])
    }

    func testHeaderEnvNullBecomesEmptyString() {
        let flow = "appId: x\nenv:\n  EMPTY:\n  TILDE: ~\n---\n- launchApp\n"
        XCTAssertEqual(FlowEnvironment.headerEnvironment(flow), ["EMPTY": "", "TILDE": ""])
    }

    func testHeaderEnvDropsKeysThatAreNotValidLaunchKeys() {
        let flow = "appId: x\nenv:\n  OK_1.x: a\n  \"BAD;rm\": b\n---\n- launchApp\n"
        XCTAssertEqual(FlowEnvironment.headerEnvironment(flow), ["OK_1.x": "a"])
    }

    func testRejectsKeysOutsideTheLaunchKeyAlphabet() {
        for argument in ["1ABC=x", "A;B=x", "A-B=x", "A'B=x", "A$B=x"] {
            XCTAssertThrowsError(try FlowEnvironment.parse([argument]), argument) { error in
                XCTAssertTrue(String(describing: error).contains("must start with a letter or `_`"), String(describing: error))
            }
        }
        XCTAssertEqual(try FlowEnvironment.parse(["_A.b9=1"]), ["_A.b9": "1"])
    }

    func testAndroidMergesAStepsEnvironmentIntoItsArguments() throws {
        let flow = """
        appId: com.example.app
        ---
        - launchApp:
            arguments:
              KEEP: "args"
            environment:
              KEEP: "env"
              SEED: "many"
            clearState: true
        - tapOn: "Start"
        """
        let result = FlowEnvironment.apply(to: flow, environment: ["NOTE": "n"], platform: .android)
        let launch = try launchApp(in: result.yaml)
        XCTAssertEqual(launch["arguments"] as? [String: String], ["KEEP": "args", "SEED": "many", "NOTE": "n"])
        XCTAssertNil(launch["environment"])
        XCTAssertEqual(launch["clearState"] as? Bool, true)
    }

    func testAndroidMergesEnvironmentThatPrecedesArguments() throws {
        let flow = """
        appId: com.example.app
        ---
        - launchApp:
            environment:
              SEED: "many"
            arguments:
              KEEP: "args"
        """
        let launch = try launchApp(in: FlowEnvironment.apply(to: flow, environment: [:], platform: .android).yaml)
        XCTAssertEqual(launch["arguments"] as? [String: String], ["KEEP": "args", "SEED": "many"])
        XCTAssertNil(launch["environment"])
    }

    func testOverrideMatchesQuotedExistingKeys() throws {
        let flow = """
        appId: com.example.app
        ---
        - launchApp:
            environment:
              "PORT": "1111"
        """
        let result = FlowEnvironment.inject(flow, environment: ["PORT": "2"])
        XCTAssertEqual(result.yaml.components(separatedBy: "PORT").count - 1, 1, result.yaml)
        XCTAssertEqual(try launchEnvironment(in: result.yaml), ["PORT": "2"])
    }

    // MARK: - Generated flows

    func testGeneratedScreenFlowCarriesTheEnvironment() throws {
        let yaml = FlowGenerator.generate(
            screens: [GrantivaConfig.Screen(name: "Home", path: .launch)],
            bundleId: "com.example.app",
            environment: ["PORT": "51234"]
        )
        XCTAssertEqual(try launchEnvironment(in: yaml)["PORT"], "51234")
    }

    func testGeneratedScreenFlowCarriesTheEnvironmentAsArgumentsOnAndroid() throws {
        let yaml = FlowGenerator.generate(
            screens: [GrantivaConfig.Screen(name: "Home", path: .launch)],
            bundleId: "com.example.app",
            environment: ["NOTE": "a=b c"],
            platform: .android
        )
        XCTAssertEqual(try launchEnvironment(in: yaml, field: "arguments"), ["NOTE": "a=b c"])
        XCTAssertEqual(try launchEnvironment(in: yaml), [:])
    }

    func testGeneratedScreenFlowIsUnchangedWithoutEnvironment() {
        let yaml = FlowGenerator.generate(
            screens: [GrantivaConfig.Screen(name: "Home", path: .launch)],
            bundleId: "com.example.app"
        )
        XCTAssertTrue(yaml.contains("- launchApp\n"))
    }
}
