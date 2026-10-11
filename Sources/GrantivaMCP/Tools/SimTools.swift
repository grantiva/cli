import Foundation
import GrantivaCore
import MCP

/// Simulator management tools: list and boot simulators.
@available(macOS 15, *)
enum SimTools {

    // MARK: - Tool Definitions

    static let definitions: [Tool] = [
        Tool(
            name: "grantiva_sim_list",
            description: "List iOS simulators with their name, UDID, state (as simctl reports it), runtime (e.g. iOS 26.0), and availability (no when the simulator's runtime is not installed).",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "filter": .object([
                        "type": .string("string"),
                        "description": .string("Filter by state: 'booted', 'shutdown', or 'all' (default: 'all')"),
                        "enum": .array([.string("all"), .string("booted"), .string("shutdown")]),
                    ]),
                ]),
            ]),
            annotations: .init(readOnlyHint: true, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_sim_boot",
            description: "Boot an iOS simulator by name or UDID. Returns the booted device info.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "name": .object([
                        "type": .string("string"),
                        "description": .string("Simulator name or UDID to boot (default: \(DefaultSimulator.description))"),
                    ]),
                ]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_sim_ensure",
            description: "Create or idempotently reuse an exact named simulator, optionally booting it to readiness. Only 'name' is required: an existing simulator with that name is reused as-is. To create one, the name must contain a device model (\"iPhone 17\") or 'device_type' must be given; the runtime defaults to the newest installed one.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "name": .object(["type": .string("string")]),
                    "device_type": .object(["type": .string("string")]),
                    "runtime": .object(["type": .string("string"), "description": .string("Runtime name, version, identifier, or 'latest'")]),
                    "boot": .object(["type": .string("boolean")]),
                ]),
                "required": .array([.string("name")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_sim_delete",
            description: "Explicitly delete one simulator by its exact name or UDID.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object(["name": .object(["type": .string("string")])]),
                "required": .array([.string("name")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false)
        ),
    ]

    // MARK: - Handlers

    static func list(
        simManager: SimulatorManager,
        arguments: [String: Value]
    ) async throws -> CallTool.Result {
        let filter = arguments["filter"]?.stringValue ?? "all"
        let output = render(devices: try await simManager.listDevices(), filter: filter)
        return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
    }

    /// iOS simulators only (watchOS, tvOS and visionOS devices are left
    /// out), unavailable ones included and marked as such.
    static func render(devices: [SimulatorDevice], filter: String) -> String {
        let rows = devices
            .filter { $0.runtime.hasPrefix("iOS") }
            .filter { device in
                switch filter {
                case "booted": return device.isBooted
                case "shutdown": return device.state == "Shutdown"
                default: return true
                }
            }
            .map { "\($0.name) | \($0.udid) | \($0.state) | \(runtimeName($0.runtime)) | \($0.isAvailable ? "yes" : "no")" }
        guard !rows.isEmpty else { return "No iOS simulators found matching filter '\(filter)'." }
        return (["Name | UDID | State | Runtime | Available"] + rows).joined(separator: "\n")
    }

    /// simctl's runtime identifier fragment as people read it:
    /// `iOS-26-0` becomes `iOS 26.0`.
    static func runtimeName(_ runtime: String) -> String {
        SimulatorDevice.runtimeDisplayName(runtime)
    }

    static func boot(
        simManager: SimulatorManager,
        arguments: [String: Value]
    ) async throws -> CallTool.Result {
        // Unnamed, only a default-named simulator Grantiva created is booted (L08).
        let device = if let name = arguments["name"]?.stringValue {
            try await simManager.boot(nameOrUDID: name)
        } else {
            try await simManager.bootDefault(name: DefaultSimulator.name, override: "the 'name' argument")
        }

        return CallTool.Result(
            content: [
                .text(
                    text: "Simulator booted: \(device.name) (\(device.udid))\nRuntime: \(runtimeName(device.runtime))",
                    annotations: nil, _meta: nil
                ),
            ]
        )
    }

    static func ensure(simManager: SimulatorManager, arguments: [String: Value]) async throws -> CallTool.Result {
        guard let name = arguments["name"]?.stringValue else {
            // Invalid model input is a tool error the model can read and correct,
            // not a JSON-RPC protocol error that reads as a transport failure.
            return CallTool.Result(
                content: [.text(text: "Error: Invalid argument: 'name' is required.", annotations: nil, _meta: nil)],
                isError: true
            )
        }
        let result = try await simManager.ensure(
            name: name,
            deviceType: arguments["device_type"]?.stringValue,
            runtime: arguments["runtime"]?.stringValue,
            boot: arguments["boot"]?.boolValue ?? false
        )
        return CallTool.Result(content: [.text(text: try JSONOutput.string(result), annotations: nil, _meta: nil)])
    }

    static func delete(simManager: SimulatorManager, arguments: [String: Value]) async throws -> CallTool.Result {
        guard let name = arguments["name"]?.stringValue else {
            return CallTool.Result(
                content: [.text(text: "Error: Invalid argument: 'name' is required.", annotations: nil, _meta: nil)],
                isError: true
            )
        }
        let device = try await simManager.delete(name: name)
        let data = try JSONSerialization.data(withJSONObject: ["deleted": true, "name": device.name, "udid": device.udid], options: [.sortedKeys])
        return CallTool.Result(content: [.text(text: String(decoding: data, as: UTF8.self), annotations: nil, _meta: nil)])
    }
}
