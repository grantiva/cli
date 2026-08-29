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
            description: "List available iOS simulators with their name, UDID, state, runtime, and availability.",
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
                        "description": .string("Simulator name or UDID to boot (default: 'iPhone 16')"),
                    ]),
                ]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_sim_ensure",
            description: "Create or idempotently reuse an exact named simulator, optionally booting it to readiness. Only 'name' is required: the device type is inferred from the name and the runtime defaults to the newest installed one.",
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
        var devices = try await simManager.listDevices()

        // Only show available devices
        devices = devices.filter { $0.isAvailable }

        switch filter {
        case "booted":
            devices = devices.filter { $0.isBooted }
        case "shutdown":
            devices = devices.filter { !$0.isBooted }
        default:
            break
        }

        var lines: [String] = []
        for device in devices {
            let state = device.isBooted ? "Booted" : "Shutdown"
            lines.append("\(device.name) | \(device.udid) | \(state) | \(device.runtime)")
        }

        let output = lines.isEmpty
            ? "No simulators found matching filter '\(filter)'."
            : "Name | UDID | State | Runtime\n" + lines.joined(separator: "\n")

        return CallTool.Result(
            content: [.text(text: output, annotations: nil, _meta: nil)]
        )
    }

    static func boot(
        simManager: SimulatorManager,
        arguments: [String: Value]
    ) async throws -> CallTool.Result {
        let name = arguments["name"]?.stringValue ?? "iPhone 16"
        let device = try await simManager.boot(nameOrUDID: name)

        return CallTool.Result(
            content: [
                .text(
                    text: "Simulator booted: \(device.name) (\(device.udid))\nRuntime: \(device.runtime)",
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
                content: [.text(text: "Error: 'name' is required.", annotations: nil, _meta: nil)],
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
                content: [.text(text: "Error: 'name' is required.", annotations: nil, _meta: nil)],
                isError: true
            )
        }
        let device = try await simManager.delete(name: name)
        let data = try JSONSerialization.data(withJSONObject: ["deleted": true, "name": device.name, "udid": device.udid], options: [.sortedKeys])
        return CallTool.Result(content: [.text(text: String(decoding: data, as: UTF8.self), annotations: nil, _meta: nil)])
    }
}
