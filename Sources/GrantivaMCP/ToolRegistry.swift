import Foundation
import GrantivaCore
import MCP

/// Central registry that holds references to all dependencies and dispatches
/// tool calls and resource reads to the appropriate handler.
@available(macOS 15, *)
struct ToolRegistry: Sendable {
    let driver: DriverClient
    let platform: Platform
    let device: any DevicePlatform
    let config: GrantivaConfig?
    let session: RunnerSessionInfo
    let simulatorManager: SimulatorManager
    let buildRunner: XcodeBuildRunner
    let emulators: EmulatorToolDependencies?

    // MARK: - Tool Definitions

    func allTools() -> [Tool] {
        UITools.definitions
            + BuildTools.definitions
            + SimTools.definitions
            + EmulatorTools.definitions
            + [ContextTool.definition]
            + ScriptTools.definitions
            + VRTTools.definitions
    }

    // MARK: - Resource Definitions

    func allResources() -> [Resource] {
        [
            Resource(
                name: "hierarchy",
                uri: "grantiva://hierarchy",
                description: "Current view hierarchy as JSON tree",
                mimeType: "application/json"
            ),
            Resource(
                name: "screenshot",
                uri: "grantiva://screenshot",
                description: "Current screenshot as base64 PNG",
                mimeType: "image/png"
            ),
        ]
    }

    // MARK: - Tool Dispatch

    func call(
        name: String,
        arguments: [String: Value],
        server: Server
    ) async throws -> CallTool.Result {
        let result: CallTool.Result

        switch name {
        // UI Tools
        case "grantiva_screenshot":
            result = try await UITools.screenshot(driver: driver, device: device, session: session, arguments: arguments)
        case "grantiva_tap":
            result = try await UITools.tap(driver: driver, arguments: arguments)
        case "grantiva_swipe":
            result = try await UITools.swipe(driver: driver, arguments: arguments)
        case "grantiva_type":
            result = try await UITools.type(driver: driver, arguments: arguments)
        case "grantiva_a11y_tree":
            result = try await UITools.a11yTree(driver: driver)
        case "grantiva_a11y_check":
            result = try await UITools.a11yCheck(driver: driver, config: config, platform: platform)

        // Build Tools
        case "grantiva_build":
            result = try await BuildTools.build(device: device, platform: platform, config: config, arguments: arguments)
        case "grantiva_run":
            result = try await BuildTools.run(device: device, platform: platform, config: config, arguments: arguments)
        case "grantiva_test":
            result = try await BuildTools.test(runner: buildRunner, platform: platform, config: config, simManager: simulatorManager, arguments: arguments)

        // Sim Tools
        case "grantiva_sim_list":
            result = try await SimTools.list(simManager: simulatorManager, arguments: arguments)
        case "grantiva_sim_boot":
            result = try await SimTools.boot(simManager: simulatorManager, arguments: arguments)
        case "grantiva_sim_ensure":
            result = try await SimTools.ensure(simManager: simulatorManager, arguments: arguments)
        case "grantiva_sim_delete":
            result = try await SimTools.delete(simManager: simulatorManager, arguments: arguments)

        // Emulator Tools
        case "grantiva_emulator_list":
            result = try await EmulatorTools.list(deps: emulators, arguments: arguments)
        case "grantiva_emulator_boot":
            result = try await EmulatorTools.boot(deps: emulators, config: config, arguments: arguments)
        case "grantiva_emulator_ensure":
            result = try await EmulatorTools.ensure(deps: emulators, arguments: arguments)
        case "grantiva_emulator_delete":
            result = try await EmulatorTools.delete(deps: emulators, arguments: arguments)

        // Context
        case "grantiva_context":
            result = try await ContextTool.context(config: config, platform: platform, device: device, simManager: simulatorManager)

        // Script
        case "grantiva_script":
            result = try await ScriptTools.script(driver: driver, arguments: arguments)

        // VRT Tools
        case "grantiva_vrt_capture":
            result = try await VRTTools.capture(platform: platform, arguments: arguments)
        case "grantiva_vrt_compare":
            result = try await VRTTools.compare(platform: platform, arguments: arguments)
        case "grantiva_vrt_approve":
            result = try await VRTTools.approve(platform: platform, arguments: arguments)

        default:
            return CallTool.Result(
                content: [.text(text: "Unknown tool: \(name)", annotations: nil, _meta: nil)],
                isError: true
            )
        }

        // After UI-mutating actions, notify resource subscribers about hierarchy change
        let uiMutatingTools = ["grantiva_tap", "grantiva_swipe", "grantiva_type", "grantiva_script"]
        if uiMutatingTools.contains(name) {
            try? await notifyHierarchyUpdate(server: server)
        }

        return result
    }

    // MARK: - Resource Read

    func readResource(uri: String) async throws -> [Resource.Content] {
        switch uri {
        case "grantiva://hierarchy":
            let tree = try await driver.hierarchy()
            let jsonData = try JSONSerialization.data(
                withJSONObject: tree, options: [.prettyPrinted, .sortedKeys]
            )
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            return [.text(jsonString, uri: uri, mimeType: "application/json")]

        case "grantiva://screenshot":
            let imageData = try await driver.screenshot()
            return [.binary(imageData, uri: uri, mimeType: "image/png")]

        default:
            throw MCPError.invalidRequest("Unknown resource URI: \(uri)")
        }
    }

    // MARK: - Notifications

    private func notifyHierarchyUpdate(server: Server) async throws {
        let notification = ResourceUpdatedNotification.message(
            .init(uri: "grantiva://hierarchy")
        )
        try await server.notify(notification)
    }
}
