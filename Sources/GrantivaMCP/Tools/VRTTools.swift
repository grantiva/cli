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

    /// The absolute path of the running Grantiva binary. The argv[0] fallback
    /// is resolved through PATH when it is a bare name, never against the
    /// working directory (MCPServer has changed it to the project dir).
    static var executable: String {
        if let path = Bundle.main.executablePath { return path }
        let argv0 = CommandLine.arguments[0]
        if !argv0.contains("/"), let found = which(argv0) { return found }
        return URL(fileURLWithPath: argv0).standardizedFileURL.path
    }

    static func captureCommand(platform: Platform, executable: String = VRTTools.executable) -> [String] {
        [executable, "diff", "capture", "--no-build", "--json", "--platform", platform.rawValue]
    }

    static func compareCommand(platform: Platform, executable: String = VRTTools.executable) -> [String] {
        [executable, "diff", "compare", "--json", "--platform", platform.rawValue]
    }

    /// Screen names are passed as they are, one argument each: no shell is
    /// involved, so nothing in them is interpreted.
    static func approveCommand(platform: Platform, screens: [String], executable: String = VRTTools.executable) -> [String] {
        [executable, "diff", "approve", "--json", "--platform", platform.rawValue] + screens
    }

    /// The one shape of a VRT failure: `Error: <message>`, with the CLI's
    /// own leading `Error: ` (one or more) folded into it.
    static func failure(_ message: String) -> CallTool.Result {
        var text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasPrefix("Error:") {
            text = String(text.dropFirst("Error:".count)).trimmingCharacters(in: .whitespaces)
        }
        return CallTool.Result(content: [.text(text: "Error: \(text)", annotations: nil, _meta: nil)], isError: true)
    }

    static func capture(
        platform: Platform, arguments: [String: Value],
        executable: String = VRTTools.executable, environment: [String: String]? = nil
    ) async throws -> CallTool.Result {
        do {
            let output = try await run(captureCommand(platform: platform, executable: executable), environment: environment)
            return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
        } catch GrantivaError.commandFailed(let message, _) {
            return failure(message)
        }
    }

    static func compare(
        platform: Platform, arguments: [String: Value],
        executable: String = VRTTools.executable, environment: [String: String]? = nil
    ) async throws -> CallTool.Result {
        do {
            let output = try await run(compareCommand(platform: platform, executable: executable), environment: environment)
            return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
        } catch GrantivaError.commandFailed(let message, _) {
            return compareFailureResult(message: message)
        }
    }

    /// A failed comparison's JSON verdict is a result, not an error; any
    /// other failure is a VRT failure.
    static func compareFailureResult(message: String) -> CallTool.Result {
        let data = Data(message.utf8)
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let isDiffVerdict = json?["passed"] as? Bool == false
            && json?["screens"] is [[String: Any]]
        guard isDiffVerdict else { return failure(message) }
        return CallTool.Result(content: [.text(text: message, annotations: nil, _meta: nil)])
    }

    static func approve(
        platform: Platform, arguments: [String: Value],
        executable: String = VRTTools.executable, environment: [String: String]? = nil
    ) async throws -> CallTool.Result {
        let screens = arguments["screens"]?.arrayValue?.compactMap(\.stringValue) ?? []
        do {
            let output = try await run(approveCommand(platform: platform, screens: screens, executable: executable), environment: environment)
            return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
        } catch GrantivaError.commandFailed(let message, _) {
            return failure(message)
        }
    }

    /// Runs `argv` directly (no shell) with a null stdin, so the child can
    /// never read the MCP server's input. Returns trimmed stdout; a non-zero
    /// exit throws `commandFailed` with stderr (or stdout), as `shell` does.
    static func run(_ argv: [String], environment: [String: String]? = nil) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: argv[0])
        process.arguments = Array(argv.dropFirst())
        if let environment {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = stdout
        process.standardError = stderr
        GrantivaLog.logger.debug("$ \(argv.map(shellQuoted).joined(separator: " "))")
        // The exit is observed through the termination handler: blocking in
        // waitUntilExit on a cooperative thread can miss it.
        let exited = AsyncStream<Void> { continuation in
            process.terminationHandler = { _ in
                continuation.yield()
                continuation.finish()
            }
        }
        try process.run()
        // Drain both pipes concurrently so neither fills and blocks the child.
        async let out = readAll(stdout.fileHandleForReading)
        async let err = readAll(stderr.fileHandleForReading)
        let (outData, errData) = await (out, err)
        for await _ in exited {}
        let output = String(decoding: outData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else {
            let errors = String(decoding: errData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            let message = errors.isEmpty
                ? (output.isEmpty ? "\(argv.joined(separator: " ")) exited with code \(process.terminationStatus)" : output)
                : errors
            throw GrantivaError.commandFailed(message, process.terminationStatus)
        }
        return output
    }

    private static func readAll(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: handle.readDataToEndOfFile())
            }
        }
    }
}
