import Foundation
import GrantivaCore
import MCP

/// Central registry that holds references to all dependencies and dispatches
/// tool calls and resource reads to the appropriate handler.
@available(macOS 15, *)
struct ToolRegistry: Sendable {
    let connection: RunnerConnection
    let platform: Platform
    let device: any DevicePlatform
    let config: GrantivaConfig?
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

    /// Tools that act on the runner session's device. They resolve the
    /// session (and attach the driver) per call; with no session they return
    /// a tool error instead of failing the server.
    static let sessionTools: Set<String> = [
        "grantiva_screenshot", "grantiva_tap", "grantiva_swipe", "grantiva_type",
        "grantiva_a11y_tree", "grantiva_a11y_check", "grantiva_script",
    ]
    static let uiMutatingTools: Set<String> = ["grantiva_tap", "grantiva_swipe", "grantiva_type", "grantiva_script"]

    func call(
        name: String,
        arguments: [String: Value],
        server: Server
    ) async throws -> CallTool.Result {
        let result: CallTool.Result

        if Self.sessionTools.contains(name) {
            let current: RunnerConnection.Current
            do {
                current = try await connection.current()
            } catch {
                return CallTool.Result(
                    content: [.text(text: "Error: \(error.localizedDescription)", annotations: nil, _meta: nil)],
                    isError: true
                )
            }
            result = try await callSessionTool(name: name, current: current, arguments: arguments)
            // After UI-mutating actions, notify resource subscribers about hierarchy change
            if Self.uiMutatingTools.contains(name) {
                try? await notifyHierarchyUpdate(server: server)
            }
            return result
        }

        switch name {
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
            result = try await ContextTool.context(
                config: config, platform: platform, session: await connection.session(),
                listSimulators: { [simulatorManager] in try await simulatorManager.listDevices() },
                emulators: emulators
            )

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

        return result
    }

    private func callSessionTool(
        name: String,
        current: RunnerConnection.Current,
        arguments: [String: Value]
    ) async throws -> CallTool.Result {
        let driver = current.driver
        switch name {
        case "grantiva_screenshot":
            return try await UITools.screenshot(driver: driver, device: device, session: current.session, arguments: arguments)
        case "grantiva_tap":
            return try await UITools.tap(driver: driver, arguments: arguments)
        case "grantiva_swipe":
            return try await UITools.swipe(driver: driver, arguments: arguments)
        case "grantiva_type":
            return try await UITools.type(driver: driver, arguments: arguments)
        case "grantiva_a11y_tree":
            return try await UITools.a11yTree(driver: driver)
        case "grantiva_a11y_check":
            return try await UITools.a11yCheck(driver: driver, config: config, platform: platform)
        default: // grantiva_script
            return try await ScriptTools.script(driver: driver, arguments: arguments)
        }
    }

    // MARK: - Resource Read

    func readResource(uri: String) async throws -> [Resource.Content] {
        switch uri {
        case "grantiva://hierarchy":
            let tree = try await connection.current().driver.hierarchy()
            let jsonData = try JSONSerialization.data(
                withJSONObject: tree, options: [.prettyPrinted, .sortedKeys]
            )
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            return [.text(jsonString, uri: uri, mimeType: "application/json")]

        case "grantiva://screenshot":
            let imageData = try await connection.current().driver.screenshot()
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

@available(macOS 15, *)
extension ToolRegistry {
    /// A registry bound to one fixed driver and session; for tests.
    init(
        driver: DriverClient,
        platform: Platform,
        device: any DevicePlatform,
        config: GrantivaConfig?,
        session: RunnerSessionInfo,
        simulatorManager: SimulatorManager,
        buildRunner: XcodeBuildRunner,
        emulators: EmulatorToolDependencies?
    ) {
        self.init(
            connection: .fixed(driver: driver, session: session),
            platform: platform, device: device, config: config,
            simulatorManager: simulatorManager, buildRunner: buildRunner, emulators: emulators
        )
    }
}
