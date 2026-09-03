import XCTest
import Yams
@testable import GrantivaCore

final class FlowReferenceResolverTests: XCTestCase {
    func testResolvesQuotedUnquotedAndSpacedScalarPaths() throws {
        let yaml = """
        appId: com.example
        ---
        - runFlow: child.yaml
        - runFlow: "flows/login flow.yaml"
        - runFlow: 'flows/logout flow.yaml'
        """

        let rewritten = try FlowReferenceResolver.resolve(in: yaml, relativeTo: "/project/tests")
        XCTAssertEqual(
            try runFlowPaths(rewritten),
            [
                "/project/tests/child.yaml",
                "/project/tests/flows/login flow.yaml",
                "/project/tests/flows/logout flow.yaml",
            ]
        )
    }

    func testPreservesAbsolutePathAndResolvesObjectFile() throws {
        let yaml = """
        appId: com.example
        ---
        - runFlow: /shared/absolute.yaml
        - runFlow:
            file: ../shared/relative.yaml
            env:
              ROLE: admin
        """

        let rewritten = try FlowReferenceResolver.resolve(in: yaml, relativeTo: "/project/tests/smoke")
        XCTAssertEqual(
            try runFlowPaths(rewritten),
            ["/shared/absolute.yaml", "/project/tests/shared/relative.yaml"]
        )
    }

    func testNestedRunFlowCommandsAreResolved() throws {
        let yaml = """
        appId: com.example
        ---
        - repeat:
            times: 2
            commands:
              - runFlow: nested/child.yaml
        """

        let rewritten = try FlowReferenceResolver.resolve(in: yaml, relativeTo: "/project")
        XCTAssertTrue(rewritten.contains("/project/nested/child.yaml"), rewritten)
    }

    func testEnvironmentValueNamedRunFlowIsNotTreatedAsACommand() throws {
        let yaml = """
        appId: com.example
        ---
        - launchApp:
            environment:
              runFlow: literal-value
        """

        let rewritten = try FlowReferenceResolver.resolve(in: yaml, relativeTo: "/project")
        XCTAssertTrue(rewritten.contains("runFlow: literal-value"), rewritten)
        XCTAssertFalse(rewritten.contains("/project/literal-value"), rewritten)
    }

    func testRejectsInvalidRunFlowFormsExplicitly() {
        for command in ["- runFlow: 42", "- runFlow: []", "- runFlow:\n    env: { ROLE: admin }", "- runFlow: '   '"] {
            XCTAssertThrowsError(
                try FlowReferenceResolver.resolve(
                    in: "appId: com.example\n---\n\(command)\n",
                    relativeTo: "/project"
                ),
                command
            ) { error in
                XCTAssertTrue(error.localizedDescription.contains("Invalid runFlow command"), "\(error)")
            }
        }
    }

    func testGeneratedFlowsResolveReferencesAgainstInvocationDirectory() throws {
        let screen = GrantivaConfig.Screen(
            name: "done",
            path: .steps([.init(runFlow: "flows/child.yaml")])
        )
        let path = try FlowGenerator.writeTemp(
            screens: [screen], bundleId: "com.example", runFlowBaseDirectory: "/checkout"
        )
        defer { try? FileManager.default.removeItem(atPath: (path as NSString).deletingLastPathComponent) }

        let content = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertEqual(try runFlowPaths(content), ["/checkout/flows/child.yaml"])
    }

    func testDuplicateTopLevelBasenamesRetainIndependentReferenceBases() throws {
        let first = try FlowReferenceResolver.resolve(
            in: "appId: a\n---\n- runFlow: child.yaml\n", relativeTo: "/flows/smoke"
        )
        let second = try FlowReferenceResolver.resolve(
            in: "appId: a\n---\n- runFlow: child.yaml\n", relativeTo: "/flows/regression"
        )
        XCTAssertEqual(try runFlowPaths(first), ["/flows/smoke/child.yaml"])
        XCTAssertEqual(try runFlowPaths(second), ["/flows/regression/child.yaml"])
    }

    private func runFlowPaths(_ yaml: String) throws -> [String] {
        let commands = try XCTUnwrap(MaestroFlowParser.splitDocuments(yaml).commands)
        let value = try XCTUnwrap(try Yams.load(yaml: commands))
        return try collectRunFlowPaths(value)
    }

    private func collectRunFlowPaths(_ value: Any) throws -> [String] {
        if let values = value as? [Any] {
            return try values.flatMap(collectRunFlowPaths)
        }
        guard let dictionary = value as? [String: Any] else { return [] }
        var result: [String] = []
        for (key, child) in dictionary {
            if key == "runFlow" {
                if let path = child as? String {
                    result.append(path)
                } else {
                    let options = try XCTUnwrap(child as? [String: Any])
                    result.append(try XCTUnwrap(options["file"] as? String))
                }
            } else {
                result.append(contentsOf: try collectRunFlowPaths(child))
            }
        }
        return result
    }
}
