import MCP
import XCTest
@testable import GrantivaMCP

/// Guards the MCP tool annotations. `readOnlyHint` is how a client decides whether a
/// tool is safe to invoke without confirmation, so a tool that mutates the machine must
/// never advertise itself as read-only.
final class ToolAnnotationsTests: XCTestCase {

    private var allTools: [Tool] {
        UITools.definitions
            + BuildTools.definitions
            + SimTools.definitions
            + [ContextTool.definition]
            + ScriptTools.definitions
            + VRTTools.definitions
    }

    private func tool(_ name: String) throws -> Tool {
        try XCTUnwrap(allTools.first { $0.name == name }, "No tool named \(name)")
    }

    func testAllToolsAreRegistered() {
        XCTAssertEqual(allTools.count, 18)
        XCTAssertEqual(Set(allTools.map(\.name)).count, 18, "Tool names must be unique")
    }

    /// `grantiva_test` runs `xcodebuild test`: it boots a simulator and writes build
    /// products. It was previously annotated `readOnlyHint: true`.
    func testGrantivaTestIsNotMarkedReadOnly() throws {
        XCTAssertEqual(try tool("grantiva_test").annotations.readOnlyHint, false)
    }

    func testMutatingToolsAreNotMarkedReadOnly() throws {
        let mutating = [
            "grantiva_screenshot", "grantiva_tap", "grantiva_swipe", "grantiva_type",
            "grantiva_build", "grantiva_run", "grantiva_test",
            "grantiva_sim_boot", "grantiva_sim_ensure", "grantiva_sim_delete",
            "grantiva_script",
            "grantiva_vrt_capture", "grantiva_vrt_compare", "grantiva_vrt_approve",
        ]
        for name in mutating {
            XCTAssertEqual(try tool(name).annotations.readOnlyHint, false, "\(name) mutates its environment")
        }
    }

    func testReadOnlyToolsAreMarkedReadOnly() throws {
        for name in ["grantiva_a11y_tree", "grantiva_a11y_check", "grantiva_sim_list", "grantiva_context"] {
            XCTAssertEqual(try tool(name).annotations.readOnlyHint, true, "\(name) only reads")
        }
    }

    /// The hints default to permissive values when unspecified, so every tool states them.
    func testEveryToolDeclaresReadOnlyAndOpenWorldHints() {
        for tool in allTools {
            XCTAssertNotNil(tool.annotations.readOnlyHint, "\(tool.name) has no readOnlyHint")
            XCTAssertNotNil(tool.annotations.openWorldHint, "\(tool.name) has no openWorldHint")
        }
    }

    func testSimDeleteIsMarkedDestructive() throws {
        let delete = try tool("grantiva_sim_delete")
        XCTAssertEqual(delete.annotations.readOnlyHint, false)
        XCTAssertEqual(delete.annotations.destructiveHint, true)
    }

    /// No other tool destroys state, so nothing else should carry the destructive hint.
    func testOnlySimDeleteIsDestructive() {
        let destructive = allTools.filter { $0.annotations.destructiveHint == true }.map(\.name)
        XCTAssertEqual(destructive, ["grantiva_sim_delete"])
    }

    /// The VRT tools reach the remote Range baseline API when the user is authenticated;
    /// every other tool is confined to the local machine and simulator.
    func testOnlyRemoteBaselineToolsAreOpenWorld() {
        let openWorld = Set(allTools.filter { $0.annotations.openWorldHint == true }.map(\.name))
        XCTAssertEqual(openWorld, ["grantiva_vrt_compare", "grantiva_vrt_approve"])
    }
}
