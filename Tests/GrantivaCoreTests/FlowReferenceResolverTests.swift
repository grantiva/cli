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

    func testCyclePreflightRejectsExplicitAndScreensChainsWithoutDeviceWork() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cycle-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "appId: x\n---\n- runFlow: b.yaml\n".write(to: root.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8)
        try "appId: x\n---\n- runFlow: a.yaml\n".write(to: root.appendingPathComponent("b.yaml"), atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try FlowCycleValidator.validate(flowPaths: ["a.yaml"], screens: [], cwd: root.path)) {
            XCTAssertEqual($0.localizedDescription, "Invalid argument: circular dependency detected: a.yaml -> b.yaml -> a.yaml -> b.yaml")
        }
        let screen = GrantivaConfig.Screen(name: "S", path: .steps([.init(runFlow: "a.yaml")]))
        XCTAssertThrowsError(try FlowCycleValidator.validate(flowPaths: [], screens: [screen], cwd: root.path)) {
            XCTAssertEqual($0.localizedDescription, "Invalid argument: circular dependency detected: grantiva.yml -> a.yaml -> b.yaml -> a.yaml")
        }
    }

    func testCyclePreflightLeavesValidAndUnreadableReferencesForTheRunner() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("acyclic-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "appId: x\n---\n- runFlow: child.yaml\n".write(to: root.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8)
        try "appId: x\n---\n- tapOn: Done\n".write(to: root.appendingPathComponent("child.yaml"), atomically: true, encoding: .utf8)

        XCTAssertNoThrow(try FlowCycleValidator.validate(flowPaths: ["a.yaml", "missing.yaml"], screens: [], cwd: root.path))
    }

    func testCyclePreflightUsesResolvedSymlinkIdentity() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cycle-symlink-\(UUID().uuidString)")
        let flows = root.appendingPathComponent("flows")
        try FileManager.default.createDirectory(at: flows, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createSymbolicLink(
            at: flows.appendingPathComponent("root"), withDestinationURL: root
        )
        try "appId: x\n---\n- runFlow: root/flows/a.yaml\n".write(
            to: flows.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8
        )

        XCTAssertThrowsError(try FlowCycleValidator.validate(
            flowPaths: ["flows/a.yaml"], screens: [], cwd: root.path
        )) {
            XCTAssertEqual(
                $0.localizedDescription,
                "Invalid argument: circular dependency detected: flows/a.yaml -> flows/root/flows/a.yaml -> flows/root/flows/root/flows/a.yaml"
            )
        }
    }

    func testCyclePreflightFindsMapFileAndInlineCommandReferences() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cycle-map-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "appId: x\n---\n- runFlow:\n    file: b.yaml\n".write(
            to: root.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8
        )
        try "appId: x\n---\n- runFlow:\n    commands:\n      - runFlow: a.yaml\n".write(
            to: root.appendingPathComponent("b.yaml"), atomically: true, encoding: .utf8
        )

        XCTAssertThrowsError(try FlowCycleValidator.validate(
            flowPaths: ["a.yaml"], screens: [], cwd: root.path
        )) {
            XCTAssertEqual(
                $0.localizedDescription,
                "Invalid argument: circular dependency detected: a.yaml -> b.yaml -> a.yaml -> b.yaml"
            )
        }
    }

    func testCyclePreflightMatchesNativeStructuralTraversalForDormantBranches() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cycle-structural-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "appId: x\n---\n- runFlow:\n    file: b.yaml\n    when:\n      visible: Never\n".write(
            to: root.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8
        )
        try "appId: x\n---\n- repeat:\n    times: 0\n    commands:\n      - runFlow: a.yaml\n".write(
            to: root.appendingPathComponent("b.yaml"), atomically: true, encoding: .utf8
        )

        // The native validator traverses file-backed runFlow and nested
        // repeat commands structurally, before conditions/counts execute.
        XCTAssertThrowsError(try FlowCycleValidator.validate(
            flowPaths: ["a.yaml"], screens: [], cwd: root.path
        ))
    }

    func testCyclePreflightDoesNotTreatArbitraryMapKeysAsCommands() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cycle-map-key-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "appId: x\n---\n- launchApp:\n    arguments:\n      runFlow: a.yaml\n".write(
            to: root.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8
        )
        XCTAssertNoThrow(try FlowCycleValidator.validate(flowPaths: ["a.yaml"], screens: [], cwd: root.path))
    }

    func testCyclePreflightKeepsDeepRelativeChainReadable() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cycle-prefix-\(UUID().uuidString)")
        let deep = root.appendingPathComponent("flows/deep")
        let shared = root.appendingPathComponent("shared")
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "appId: x\n---\n- runFlow: ../../shared/b.yaml\n".write(
            to: deep.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8
        )
        try "appId: x\n---\n- runFlow: ../flows/deep/a.yaml\n".write(
            to: shared.appendingPathComponent("b.yaml"), atomically: true, encoding: .utf8
        )
        XCTAssertThrowsError(try FlowCycleValidator.validate(
            flowPaths: ["flows/deep/a.yaml"], screens: [], cwd: root.path
        )) {
            XCTAssertEqual(
                $0.localizedDescription,
                "Invalid argument: circular dependency detected: flows/deep/a.yaml -> shared/b.yaml -> flows/deep/a.yaml -> shared/b.yaml"
            )
        }
    }

    func testCyclePreflightResolvesChildrenBesideLogicalSymlinkPath() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cycle-logical-parent-\(UUID().uuidString)")
        let real = root.appendingPathComponent("real")
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: alias, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "appId: x\n---\n- runFlow: child.yaml\n".write(
            to: real.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8
        )
        try "appId: x\n---\n- runFlow: child.yaml\n".write(
            to: real.appendingPathComponent("child.yaml"), atomically: true, encoding: .utf8
        )
        try "appId: x\n---\n- tapOn: Done\n".write(
            to: alias.appendingPathComponent("child.yaml"), atomically: true, encoding: .utf8
        )
        try FileManager.default.createSymbolicLink(
            at: alias.appendingPathComponent("a.yaml"), withDestinationURL: real.appendingPathComponent("a.yaml")
        )

        XCTAssertNoThrow(try FlowCycleValidator.validate(
            flowPaths: ["alias/a.yaml"], screens: [], cwd: root.path
        ))
    }

    func testCyclePreflightMemoizesPhysicalFilePerLogicalIncludeContext() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cycle-alias-context-\(UUID().uuidString)")
        let real = root.appendingPathComponent("real")
        let first = root.appendingPathComponent("first")
        let second = root.appendingPathComponent("second")
        for directory in [real, first, second] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        defer { try? FileManager.default.removeItem(at: root) }
        try "appId: x\n---\n- runFlow: child.yaml\n".write(
            to: real.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8
        )
        try "appId: x\n---\n- tapOn: Done\n".write(
            to: first.appendingPathComponent("child.yaml"), atomically: true, encoding: .utf8
        )
        try "appId: x\n---\n- runFlow: a.yaml\n".write(
            to: second.appendingPathComponent("child.yaml"), atomically: true, encoding: .utf8
        )
        for directory in [first, second] {
            try FileManager.default.createSymbolicLink(
                at: directory.appendingPathComponent("a.yaml"), withDestinationURL: real.appendingPathComponent("a.yaml")
            )
        }

        XCTAssertThrowsError(try FlowCycleValidator.validate(
            flowPaths: ["first/a.yaml", "second/a.yaml"], screens: [], cwd: root.path
        )) {
            XCTAssertTrue($0.localizedDescription.contains("second/a.yaml -> second/child.yaml -> second/a.yaml"), "\($0)")
        }
    }

    func testCyclePreflightAllowsSamePhysicalFileInDistinctAcyclicIncludeContexts() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cycle-alias-reentry-\(UUID().uuidString)")
        let real = root.appendingPathComponent("real")
        let first = root.appendingPathComponent("first")
        let next = first.appendingPathComponent("next")
        for directory in [real, first, next] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        defer { try? FileManager.default.removeItem(at: root) }
        try "appId: x\n---\n- runFlow: next/a.yaml\n".write(
            to: real.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8
        )
        for path in [first.appendingPathComponent("a.yaml"), next.appendingPathComponent("a.yaml")] {
            try FileManager.default.createSymbolicLink(
                at: path, withDestinationURL: real.appendingPathComponent("a.yaml")
            )
        }

        XCTAssertNoThrow(try FlowCycleValidator.validate(
            flowPaths: ["first/a.yaml"], screens: [], cwd: root.path
        ))
    }

    func testCyclePreflightPreservesAcyclicPrefixInDiagnostic() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cycle-prefix-node-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "appId: x\n---\n- runFlow: a.yaml\n".write(
            to: root.appendingPathComponent("root.yaml"), atomically: true, encoding: .utf8
        )
        try "appId: x\n---\n- runFlow: b.yaml\n".write(
            to: root.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8
        )
        try "appId: x\n---\n- runFlow: a.yaml\n".write(
            to: root.appendingPathComponent("b.yaml"), atomically: true, encoding: .utf8
        )
        XCTAssertThrowsError(try FlowCycleValidator.validate(
            flowPaths: ["root.yaml"], screens: [], cwd: root.path
        )) {
            XCTAssertEqual(
                $0.localizedDescription,
                "Invalid argument: circular dependency detected: root.yaml -> a.yaml -> b.yaml -> a.yaml"
            )
        }
    }

    func testCyclePreflightAbsoluteRootPreservesItsAliasAndFourWrittenHops() throws {
        let name = "cycle-absolute-root-\(UUID().uuidString)"
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(name)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "appId: x\n---\n- runFlow: b.yaml\n".write(
            to: root.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8
        )
        try "appId: x\n---\n- runFlow: a.yaml\n".write(
            to: root.appendingPathComponent("b.yaml"), atomically: true, encoding: .utf8
        )
        for suppliedRoot in [root.path, "/tmp/\(name)"] {
            let supplied = "\(suppliedRoot)/a.yaml"
            XCTAssertThrowsError(try FlowCycleValidator.validate(
                flowPaths: [supplied], screens: [], cwd: root.path
            )) {
                XCTAssertEqual(
                    $0.localizedDescription,
                    "Invalid argument: circular dependency detected: \(supplied) -> b.yaml -> a.yaml -> b.yaml"
                )
            }
        }
    }

    func testCyclePreflightKeepsOutsideCwdOperandsAsWritten() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cycle-outside-cwd-\(UUID().uuidString)")
        let project = root.appendingPathComponent("project")
        let shared = root.appendingPathComponent("shared")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "appId: x\n---\n- runFlow: b.yaml\n".write(
            to: shared.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8
        )
        try "appId: x\n---\n- runFlow: a.yaml\n".write(
            to: shared.appendingPathComponent("b.yaml"), atomically: true, encoding: .utf8
        )
        XCTAssertThrowsError(try FlowCycleValidator.validate(
            flowPaths: ["../shared/a.yaml"], screens: [], cwd: project.path
        )) {
            XCTAssertEqual(
                $0.localizedDescription,
                "Invalid argument: circular dependency detected: ../shared/a.yaml -> b.yaml -> a.yaml -> b.yaml"
            )
        }
    }

    func testCyclePreflightTraversesLifecycleHooks() throws {
        for hook in ["onFlowStart", "onFlowComplete"] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("cycle-hook-\(hook)-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            try "appId: x\n\(hook):\n  - runFlow: b.yaml\n---\n- tapOn: Done\n".write(
                to: root.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8
            )
            try "appId: x\n---\n- runFlow: a.yaml\n".write(
                to: root.appendingPathComponent("b.yaml"), atomically: true, encoding: .utf8
            )
            XCTAssertThrowsError(try FlowCycleValidator.validate(
                flowPaths: ["a.yaml"], screens: [], cwd: root.path
            ), hook)
        }
    }

    func testCyclePreflightTraversesRetryFileAndCommands() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cycle-retry-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "appId: x\n---\n- retry:\n    file: b.yaml\n    commands:\n      - runFlow: unused.yaml\n".write(
            to: root.appendingPathComponent("a.yaml"), atomically: true, encoding: .utf8
        )
        try "appId: x\n---\n- runFlow: a.yaml\n".write(
            to: root.appendingPathComponent("b.yaml"), atomically: true, encoding: .utf8
        )
        XCTAssertThrowsError(try FlowCycleValidator.validate(
            flowPaths: ["a.yaml"], screens: [], cwd: root.path
        ))
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
