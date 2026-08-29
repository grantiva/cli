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

    private func launchEnvironment(in yaml: String) throws -> [String: String] {
        let body = yaml.components(separatedBy: "\n---\n").last ?? yaml
        let steps = try XCTUnwrap(Yams.load(yaml: body) as? [Any])
        for step in steps {
            guard let mapping = step as? [String: Any],
                  let launch = mapping["launchApp"] as? [String: Any],
                  let environment = launch["environment"] as? [String: Any]
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

    // MARK: - Generated flows

    func testGeneratedScreenFlowCarriesTheEnvironment() throws {
        let yaml = FlowGenerator.generate(
            screens: [GrantivaConfig.Screen(name: "Home", path: .launch)],
            bundleId: "com.example.app",
            environment: ["PORT": "51234"]
        )
        XCTAssertEqual(try launchEnvironment(in: yaml)["PORT"], "51234")
    }

    func testGeneratedScreenFlowIsUnchangedWithoutEnvironment() {
        let yaml = FlowGenerator.generate(
            screens: [GrantivaConfig.Screen(name: "Home", path: .launch)],
            bundleId: "com.example.app"
        )
        XCTAssertTrue(yaml.contains("- launchApp\n"))
    }
}
