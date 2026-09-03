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
}
