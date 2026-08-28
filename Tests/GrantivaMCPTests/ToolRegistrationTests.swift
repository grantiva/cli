import Foundation
import GrantivaCore
import MCP
import XCTest

@testable import GrantivaMCP

/// The tool name is the public API an agent binds to. Renaming or dropping one is a
/// breaking change for every client, so the exact set is pinned here.
final class ToolRegistrationTests: XCTestCase {

    /// The advertised MCP tool surface. Update this list only alongside a deliberate,
    /// documented API change.
    static let expectedToolNames: Set<String> = [
        // UI
        "grantiva_screenshot",
        "grantiva_tap",
        "grantiva_swipe",
        "grantiva_type",
        "grantiva_a11y_tree",
        "grantiva_a11y_check",
        // Build
        "grantiva_build",
        "grantiva_run",
        "grantiva_test",
        // Simulator
        "grantiva_sim_list",
        "grantiva_sim_boot",
        "grantiva_sim_ensure",
        "grantiva_sim_delete",
        // Context
        "grantiva_context",
        // Script
        "grantiva_script",
        // Visual regression
        "grantiva_vrt_capture",
        "grantiva_vrt_compare",
        "grantiva_vrt_approve",
    ]

    private func allTools() -> [Tool] {
        MCPTestSupport.registry(wda: MCPTestSupport.fakeWDA(recorder: WDARecorder())).allTools()
    }

    func testRegistryExposesExactlyTheAdvertisedToolSet() {
        let names = Set(allTools().map(\.name))
        XCTAssertEqual(
            names, Self.expectedToolNames,
            "MCP tool surface changed. Missing: \(Self.expectedToolNames.subtracting(names).sorted()). "
                + "Unexpected: \(names.subtracting(Self.expectedToolNames).sorted())."
        )
    }

    func testRegistryExposesEighteenTools() {
        XCTAssertEqual(allTools().count, 18)
    }

    func testToolNamesAreUniqueAndNamespaced() {
        let names = allTools().map(\.name)
        XCTAssertEqual(names.count, Set(names).count, "Duplicate tool names: \(names)")
        for name in names {
            XCTAssertTrue(name.hasPrefix("grantiva_"), "\(name) is not namespaced")
            XCTAssertEqual(name, name.lowercased(), "\(name) is not lowercase snake_case")
            XCTAssertNil(name.rangeOfCharacter(from: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted), "\(name) has illegal characters")
        }
    }

    func testEveryToolHasANonEmptyDescription() {
        for tool in allTools() {
            let description = tool.description ?? ""
            XCTAssertFalse(description.isEmpty, "\(tool.name) has no description")
        }
    }

    func testToolListSurvivesJSONRoundTrip() throws {
        // tools/list is serialized to the client; a schema that cannot encode/decode
        // would break every agent at handshake time.
        let tools = allTools()
        let data = try JSONEncoder().encode(ListTools.Result(tools: tools))
        let decoded = try JSONDecoder().decode(ListTools.Result.self, from: data)
        XCTAssertEqual(decoded.tools.map(\.name), tools.map(\.name))
        XCTAssertEqual(decoded.tools, tools)
    }

    // MARK: - Resources

    func testRegistryExposesHierarchyAndScreenshotResources() {
        let resources = MCPTestSupport.registry(wda: MCPTestSupport.fakeWDA(recorder: WDARecorder())).allResources()
        XCTAssertEqual(resources.map(\.uri).sorted(), ["grantiva://hierarchy", "grantiva://screenshot"])
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: resources.map { ($0.uri, $0.mimeType) }),
            ["grantiva://hierarchy": "application/json", "grantiva://screenshot": "image/png"]
        )
    }

    // MARK: - Annotations

    func testReadOnlyToolsAreAnnotatedReadOnly() {
        let readOnly = [
            "grantiva_screenshot", "grantiva_a11y_tree", "grantiva_a11y_check",
            "grantiva_sim_list", "grantiva_context", "grantiva_vrt_compare",
        ]
        let byName = Dictionary(uniqueKeysWithValues: allTools().map { ($0.name, $0) })
        for name in readOnly {
            XCTAssertEqual(byName[name]?.annotations.readOnlyHint, true, "\(name) should be readOnlyHint: true")
        }
    }

    func testMutatingToolsAreNotAnnotatedReadOnly() {
        let mutating = ["grantiva_tap", "grantiva_swipe", "grantiva_type", "grantiva_script", "grantiva_sim_boot", "grantiva_sim_delete"]
        let byName = Dictionary(uniqueKeysWithValues: allTools().map { ($0.name, $0) })
        for name in mutating {
            XCTAssertNotEqual(byName[name]?.annotations.readOnlyHint, true, "\(name) must not claim readOnlyHint")
        }
    }

    func testOnlySimDeleteIsMarkedDestructive() {
        let destructive = allTools().filter { $0.annotations.destructiveHint == true }.map(\.name)
        XCTAssertEqual(destructive, ["grantiva_sim_delete"])
    }

    func testNoToolClaimsOpenWorldAccess() {
        // Every Grantiva tool acts on the local machine only.
        for tool in allTools() {
            XCTAssertNotEqual(tool.annotations.openWorldHint, true, "\(tool.name) claims open-world access")
        }
    }
}
