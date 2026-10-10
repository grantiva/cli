import Foundation
import GrantivaCore
import MCP

/// Visual Regression Testing tools: capture, compare, and approve screenshots.
/// These run the `diff` subcommands of the Grantiva binary that is serving MCP,
/// by absolute path: a `grantiva` resolved from PATH may be another version
/// (or missing) and reject flags such as `--platform`.
@available(macOS 15, *)
enum VRTTools {

    // MARK: - Tool Definitions

    static let definitions: [Tool] = [
        Tool(
            name: "grantiva_vrt_capture",
            description: "Capture screenshots for all configured screens. Equivalent to 'grantiva diff capture --no-build --json'. Assumes the app is already running on the device.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_vrt_compare",
            description: "Compare current captures against baselines. Equivalent to 'grantiva diff compare --json'. Returns diff results per screen with pixel and perceptual metrics.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
            ]),
            // Not read-only: `grantiva diff compare` creates .grantiva/captures/diffs
            // and writes a *_diff.png for every screen that fails. Open world: when the
            // user is authenticated, baselines are loaded from the remote Range API.
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: true)
        ),
        Tool(
            name: "grantiva_vrt_approve",
            description: "Promote current captures to baselines. Equivalent to 'grantiva diff approve [screens] --json'. Approves all screens if none specified.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "screens": .object([
                        "type": .string("array"),
                        "items": .object(["type": .string("string")]),
                        "description": .string("Screen names to approve. If omitted, approves all."),
                    ]),
                ]),
            ]),
            // Open world: promoting baselines writes them to the remote Range API
            // when the user is authenticated.
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: true)
        ),
    ]

    // MARK: - Handlers

    /// The absolute path of the running Grantiva binary.
    static var executable: String {
        if let path = Bundle.main.executablePath { return path }
        let argv0 = CommandLine.arguments[0]
        return URL(fileURLWithPath: argv0).standardizedFileURL.path
    }

    static func captureCommand(platform: Platform, executable: String = VRTTools.executable) -> String {
        "\(shellQuoted(executable)) diff capture --no-build --json --platform \(platform.rawValue)"
    }

    static func compareCommand(platform: Platform, executable: String = VRTTools.executable) -> String {
        "\(shellQuoted(executable)) diff compare --json --platform \(platform.rawValue)"
    }

    static func approveCommand(platform: Platform, screens: [String], executable: String = VRTTools.executable) -> String {
        var cmd = "\(shellQuoted(executable)) diff approve --json --platform \(platform.rawValue)"
        if !screens.isEmpty {
            cmd += " " + screens.map(shellQuoted).joined(separator: " ")
        }
        return cmd
    }

    static func capture(platform: Platform, arguments: [String: Value], executable: String = VRTTools.executable) async throws -> CallTool.Result {
        do {
            let output = try await shell(captureCommand(platform: platform, executable: executable))
            return CallTool.Result(
                content: [.text(text: output, annotations: nil, _meta: nil)]
            )
        } catch let error as GrantivaError {
            if case .commandFailed(let msg, _) = error {
                return CallTool.Result(
                    content: [.text(text: "Capture failed:\n\(msg)", annotations: nil, _meta: nil)],
                    isError: true
                )
            }
            throw error
        }
    }

    static func compare(platform: Platform, arguments: [String: Value], executable: String = VRTTools.executable) async throws -> CallTool.Result {
        do {
            let output = try await shell(compareCommand(platform: platform, executable: executable))
            return CallTool.Result(
                content: [.text(text: output, annotations: nil, _meta: nil)]
            )
        } catch let error as GrantivaError {
            if case .commandFailed(let msg, _) = error {
                return compareFailureResult(message: msg)
            }
            throw error
        }
    }

    static func compareFailureResult(message: String) -> CallTool.Result {
        let data = Data(message.utf8)
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let isDiffVerdict = json?["passed"] as? Bool == false
            && json?["screens"] is [[String: Any]]
        return CallTool.Result(
            content: [.text(text: message, annotations: nil, _meta: nil)],
            isError: isDiffVerdict ? nil : true
        )
    }

    static func approve(platform: Platform, arguments: [String: Value], executable: String = VRTTools.executable) async throws -> CallTool.Result {
        let screens = arguments["screens"]?.arrayValue?.compactMap(\.stringValue) ?? []
        do {
            let output = try await shell(approveCommand(platform: platform, screens: screens, executable: executable))
            return CallTool.Result(
                content: [.text(text: output, annotations: nil, _meta: nil)]
            )
        } catch let error as GrantivaError {
            if case .commandFailed(let msg, _) = error {
                return CallTool.Result(
                    content: [.text(text: "Approve failed:\n\(msg)", annotations: nil, _meta: nil)],
                    isError: true
                )
            }
            throw error
        }
    }
}
