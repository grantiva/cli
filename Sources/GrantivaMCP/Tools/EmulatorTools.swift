import Foundation
import GrantivaCore
import MCP

/// What the emulator tools need from the Android layer, as closures so the
/// handlers are testable without an SDK. `nil` in the registry means the SDK
/// is not installed on this Mac.
struct EmulatorToolDependencies: Sendable {
    var listAVDs: @Sendable () async throws -> [String]
    var listDevices: @Sendable () async throws -> [ADBDevice]
    var avdName: @Sendable (String) async throws -> String
    var boot: @Sendable (String) async throws -> BootedDevice
    var ensure: @Sendable (String, String?, Bool) async throws -> EmulatorProvisionResult
    var delete: @Sendable (String, Bool) async throws -> Void

    static func live() throws -> EmulatorToolDependencies {
        let platform = try AndroidPlatform.live()
        return EmulatorToolDependencies(
            listAVDs: { try await platform.emulators.listAVDs() },
            listDevices: { try await platform.adb.devices() },
            avdName: { try await platform.adb.avdName(serial: $0) },
            boot: { try await platform.bootDevice(named: $0) },
            ensure: { try await platform.emulators.ensure(avd: $0, systemImage: $1, boot: $2) },
            delete: { try await platform.emulators.deleteAVD(name: $0, force: $1) }
        )
    }
}

/// Android emulator management: the `grantiva_sim_*` twins.
@available(macOS 15, *)
enum EmulatorTools {
    static let definitions: [Tool] = [
        Tool(
            name: "grantiva_emulator_list",
            description: "List Android Virtual Devices with the serial of each one that is running.",
            inputSchema: .object(["type": .string("object"), "properties": .object([:])]),
            annotations: .init(readOnlyHint: true, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_emulator_boot",
            description: "Boot an Android emulator by AVD name, or use it if it is already running. Defaults to emulator in grantiva-android.yml.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "name": .object(["type": .string("string"), "description": .string("AVD name (default: emulator in grantiva-android.yml)")]),
                ]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_emulator_ensure",
            description: "Create an AVD when missing (installing its system image first) and optionally boot it. Only 'name' is required.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "name": .object(["type": .string("string")]),
                    "system_image": .object(["type": .string("string"), "description": .string("System image package, e.g. system-images;android-35;google_apis;arm64-v8a")]),
                    "boot": .object(["type": .string("boolean")]),
                ]),
                "required": .array([.string("name")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_emulator_delete",
            description: "Delete an AVD Grantiva created. Pass force to delete one it did not create. A running AVD is never deleted.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "name": .object(["type": .string("string")]),
                    "force": .object(["type": .string("boolean")]),
                ]),
                "required": .array([.string("name")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false)
        ),
    ]

    static func unavailable() -> CallTool.Result {
        CallTool.Result(content: [.text(text: "Error: \(AndroidSDK.missingMessage)", annotations: nil, _meta: nil)], isError: true)
    }

    private static func toolError(_ message: String) -> CallTool.Result {
        CallTool.Result(content: [.text(text: "Error: \(message)", annotations: nil, _meta: nil)], isError: true)
    }

    static func list(deps: EmulatorToolDependencies?, arguments: [String: Value]) async throws -> CallTool.Result {
        guard let deps else { return unavailable() }
        let avds = try await deps.listAVDs()
        var running: [String: String] = [:]
        for device in try await deps.listDevices() where device.isEmulator && device.isUsable {
            if let name = try? await deps.avdName(device.serial) { running[name] = device.serial }
        }
        let lines = avds.map { "\($0) | \(running[$0] ?? "-") | \(running[$0] == nil ? "Shutdown" : "Booted")" }
        let output = lines.isEmpty ? "No AVDs found. Create one with grantiva_emulator_ensure." : "Name | Serial | State\n" + lines.joined(separator: "\n")
        return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
    }

    static func boot(deps: EmulatorToolDependencies?, config: GrantivaConfig?, arguments: [String: Value]) async throws -> CallTool.Result {
        guard let deps else { return unavailable() }
        let name = arguments["name"]?.stringValue ?? config?.android?.emulator ?? ""
        let device = try await deps.boot(name)
        return CallTool.Result(content: [.text(text: "Emulator booted: \(device.name) (\(device.udid))", annotations: nil, _meta: nil)])
    }

    static func ensure(deps: EmulatorToolDependencies?, arguments: [String: Value]) async throws -> CallTool.Result {
        guard let deps else { return unavailable() }
        guard let name = arguments["name"]?.stringValue else { return toolError("'name' is required.") }
        let result = try await deps.ensure(name, arguments["system_image"]?.stringValue, arguments["boot"]?.boolValue ?? false)
        return CallTool.Result(content: [.text(text: try JSONOutput.string(result), annotations: nil, _meta: nil)])
    }

    static func delete(deps: EmulatorToolDependencies?, arguments: [String: Value]) async throws -> CallTool.Result {
        guard let deps else { return unavailable() }
        guard let name = arguments["name"]?.stringValue else { return toolError("'name' is required.") }
        try await deps.delete(name, arguments["force"]?.boolValue ?? false)
        let data = try JSONSerialization.data(withJSONObject: ["deleted": true, "name": name], options: [.sortedKeys])
        return CallTool.Result(content: [.text(text: String(decoding: data, as: UTF8.self), annotations: nil, _meta: nil)])
    }
}
