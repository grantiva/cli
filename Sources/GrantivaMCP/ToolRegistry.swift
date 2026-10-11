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
    /// The project root: where the config file is looked for, and where
    /// captures are written.
    var projectDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    /// True when the platform came from the project directory, not from
    /// `--platform` or `GRANTIVA_PLATFORM`: a missing config is then either
    /// platform's file.
    var platformDetected = false
    /// Reads the config file again when there was none at start, so a file
    /// created while the server runs is used.
    var loadConfig: (@Sendable () throws -> GrantivaConfig?)? = nil
    /// The resources the client subscribed to; hierarchy updates go only to
    /// a subscriber.
    var subscriptions = ResourceSubscriptions()

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

    func call(
        name: String,
        arguments: [String: Value],
        server: Server
    ) async throws -> CallTool.Result {
        try await call(name: name, arguments: arguments, notify: { uri in
            try? await server.notify(ResourceUpdatedNotification.message(.init(uri: uri)))
        })
    }

    /// Every failure of every tool comes back as an `isError` result; only
    /// cancellation is thrown. `notify` sends `resources/updated` for a URI.
    func call(
        name: String,
        arguments: [String: Value],
        notify: @Sendable (String) async -> Void
    ) async throws -> CallTool.Result {
        if Self.sessionTools.contains(name) {
            let current: RunnerConnection.Current
            do {
                current = try await connection.current()
            } catch {
                return Self.errorResult(error)
            }
            let outcome: (result: CallTool.Result, mutated: Bool)
            do {
                outcome = try await callSessionTool(name: name, current: current, arguments: arguments)
            } catch let cancellation as CancellationError {
                throw cancellation
            } catch {
                // A thrown error would reach the client as a JSON-RPC
                // internal error; it is a tool result like any other failure.
                return Self.sessionToolError(error, session: current.session)
            }
            // Only a call that may have changed the UI, and only for a client
            // that subscribed: a rejected or failed call changed nothing.
            if outcome.mutated, await subscriptions.contains(Self.hierarchyURI) {
                await notify(Self.hierarchyURI)
            }
            return outcome.result
        }

        do {
            return try await callTool(name: name, arguments: arguments)
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            return Self.errorResult(error)
        }
    }

    private func callTool(name: String, arguments: [String: Value]) async throws -> CallTool.Result {
        let config: GrantivaConfig?
        if Self.configTools.contains(name) {
            config = try currentConfig()
        } else {
            config = self.config
        }
        let missingConfig = GrantivaConfig.missingFileMessage(platform: platform, directory: projectDirectory)

        switch name {
        // Build Tools
        case "grantiva_build":
            return try await BuildTools.build(device: device, platform: platform, config: config, arguments: arguments, missingConfig: missingConfig)
        case "grantiva_run":
            return try await BuildTools.run(
                device: device, platform: platform, config: config, arguments: arguments,
                missingConfig: missingConfig, projectDirectory: projectDirectory
            )
        case "grantiva_test":
            return try await BuildTools.test(runner: buildRunner, platform: platform, config: config, simManager: simulatorManager, arguments: arguments, missingConfig: missingConfig)

        // Sim Tools
        case "grantiva_sim_list":
            return try await SimTools.list(simManager: simulatorManager, arguments: arguments)
        case "grantiva_sim_boot":
            return try await SimTools.boot(simManager: simulatorManager, arguments: arguments)
        case "grantiva_sim_ensure":
            return try await SimTools.ensure(simManager: simulatorManager, arguments: arguments)
        case "grantiva_sim_delete":
            return try await SimTools.delete(simManager: simulatorManager, arguments: arguments)

        // Emulator Tools
        case "grantiva_emulator_list":
            return try await EmulatorTools.list(deps: emulators, arguments: arguments)
        case "grantiva_emulator_boot":
            return try await EmulatorTools.boot(deps: emulators, config: config, arguments: arguments)
        case "grantiva_emulator_ensure":
            return try await EmulatorTools.ensure(deps: emulators, arguments: arguments)
        case "grantiva_emulator_delete":
            return try await EmulatorTools.delete(deps: emulators, arguments: arguments)

        // Context
        case "grantiva_context":
            return try await ContextTool.context(
                config: config, platform: platform, session: await connection.session(),
                listSimulators: { [simulatorManager] in try await simulatorManager.listDevices() },
                emulators: emulators,
                configSource: Self.configSource(platform: platform, config: config, directory: projectDirectory),
                driverPort: await connection.attachedPort(),
                projectDirectory: projectDirectory, platformDetected: platformDetected
            )

        // VRT Tools
        case "grantiva_vrt_capture":
            // A live session holds the device: capture through it rather
            // than start a second runner that the device lease refuses.
            if let session = await connection.session() {
                return await VRTTools.captureThroughSession(
                    config: config, missingConfig: missingConfig, platform: platform, session: session,
                    driver: { [connection] in try await connection.current().driver },
                    device: device, projectDirectory: projectDirectory
                )
            } else if config == nil {
                // Say so here rather than start `diff capture` to find out.
                return VRTTools.failure(missingConfig)
            } else {
                return try await VRTTools.capture(platform: platform, arguments: arguments)
            }
        case "grantiva_vrt_compare":
            return try await VRTTools.compare(platform: platform, arguments: arguments)
        case "grantiva_vrt_approve":
            return try await VRTTools.approve(platform: platform, arguments: arguments)

        default:
            return CallTool.Result(
                content: [.text(text: "Error: Unknown tool: \(name)", annotations: nil, _meta: nil)],
                isError: true
            )
        }
    }

    static let hierarchyURI = "grantiva://hierarchy"

    /// Where the config `grantiva_context` shows came from: the file, the
    /// `.maestro/` fallback (iOS), or nil when there is none.
    static func configSource(platform: Platform, config: GrantivaConfig?, directory: URL) -> String? {
        guard config != nil else { return nil }
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent(platform.configFileName).path) {
            return platform.configFileName
        }
        return ".maestro/ (no \(platform.configFileName))"
    }

    /// Tools that read the config file.
    static let configTools: Set<String> = [
        "grantiva_build", "grantiva_run", "grantiva_test", "grantiva_emulator_boot", "grantiva_context",
        "grantiva_vrt_capture",
    ]

    /// The config loaded at start, or the file as it is now when there was
    /// none then.
    private func currentConfig() throws -> GrantivaConfig? {
        if let config { return config }
        return try loadConfig?()
    }

    static func errorResult(_ error: Error) -> CallTool.Result {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return CallTool.Result(content: [.text(text: "Error: \(message)", annotations: nil, _meta: nil)], isError: true)
    }

    /// A session tool's failure as a tool result.
    static func sessionToolError(_ error: Error, session: RunnerSessionInfo?) -> CallTool.Result {
        CallTool.Result(
            content: [.text(text: "Error: \(sessionFailureText(error, session: session))", annotations: nil, _meta: nil)],
            isError: true
        )
    }

    /// What a session tool says about `error`, without the `Error: ` prefix.
    /// A driver that refuses the connection is the moment before WDA
    /// listens, so it is named as such; an app that has exited gets the
    /// tools' own remedy.
    static func sessionFailureText(_ error: Error, session: RunnerSessionInfo?) -> String {
        if let exited = error as? AppNotRunningError {
            return "\(exited.app) is not running. Relaunch it (grantiva_run, or restart the session with grantiva runner stop and grantiva runner start)."
        }
        if let urlError = error as? URLError, unreachableCodes.contains(urlError.code) {
            let port = session.map(\.wdaPort) ?? 0
            let driver = port > 0 ? "The runner session's driver on port \(port)" : "The runner session's driver"
            return "\(driver) is not answering (\(urlError.localizedDescription)). "
                + "Retry in a few seconds if the session just started; otherwise restart it with grantiva runner stop and grantiva runner start."
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    static let unreachableCodes: Set<URLError.Code> = [.cannotConnectToHost, .networkConnectionLost, .timedOut, .cannotFindHost]

    /// The tool's result, and whether the call may have changed the UI.
    private func callSessionTool(
        name: String,
        current: RunnerConnection.Current,
        arguments: [String: Value]
    ) async throws -> (result: CallTool.Result, mutated: Bool) {
        let driver = current.driver
        func changed(_ result: CallTool.Result) -> (CallTool.Result, Bool) { (result, result.isError != true) }
        switch name {
        case "grantiva_screenshot":
            return (try await UITools.screenshot(driver: driver, device: device, session: current.session, arguments: arguments), false)
        case "grantiva_tap":
            return changed(try await UITools.tap(driver: driver, arguments: arguments))
        case "grantiva_swipe":
            return changed(try await UITools.swipe(driver: driver, arguments: arguments))
        case "grantiva_type":
            return changed(try await UITools.type(driver: driver, arguments: arguments))
        case "grantiva_a11y_tree":
            return (try await UITools.a11yTree(driver: driver), false)
        case "grantiva_a11y_check":
            return (try await UITools.a11yCheck(driver: driver, config: try? currentConfig(), platform: platform), false)
        default: // grantiva_script
            let outcome = try await ScriptTools.run(driver: driver, arguments: arguments, session: current.session)
            // A script whose first steps ran and a later step failed still
            // changed the UI.
            return (outcome.result, outcome.stepsRun > 0)
        }
    }

    // MARK: - Resource Read

    /// The JSON-RPC error code a resource read answers when there is no
    /// usable runner session (none, or one still starting). Documented in
    /// docs/mcp.md.
    static let noSessionResourceErrorCode = -32002

    /// `-32002` means "no usable runner session": none resolves, the driver
    /// cannot attach or is not answering yet, WDA has no session yet, or the
    /// app under test is not running. Any other failure while reading is a
    /// server fault (`-32603`) carrying its real text.
    func readResource(uri: String) async throws -> [Resource.Content] {
        guard uri == "grantiva://hierarchy" || uri == "grantiva://screenshot" else {
            throw MCPError.invalidRequest("Unknown resource URI: \(uri)")
        }
        let current: RunnerConnection.Current
        do {
            current = try await connection.current()
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            throw MCPError.serverError(code: Self.noSessionResourceErrorCode, message: Self.resourceErrorMessage(error))
        }
        do {
            if uri == "grantiva://screenshot" {
                let imageData = try await current.driver.screenshot()
                return [.binary(imageData, uri: uri, mimeType: "image/png")]
            }
            let tree = try await current.driver.hierarchy()
            let jsonData = try JSONSerialization.data(withJSONObject: tree, options: [.prettyPrinted, .sortedKeys])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            return [.text(jsonString, uri: uri, mimeType: "application/json")]
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch let error as MCPError {
            throw error
        } catch {
            if Self.isNoUsableSession(error) {
                throw MCPError.serverError(code: Self.noSessionResourceErrorCode, message: Self.resourceErrorMessage(error))
            }
            throw MCPError.internalError(Self.resourceErrorMessage(error))
        }
    }

    /// The session exists but cannot serve a read yet (or any more).
    static func isNoUsableSession(_ error: Error) -> Bool {
        if case GrantivaError.unavailable = error { return true }
        if error is AppNotRunningError { return true }
        if let urlError = error as? URLError, unreachableCodes.contains(urlError.code) { return true }
        return false
    }

    /// The session tools' text for the same failure, without the `Error: `
    /// prefix and without a usage label (`Invalid argument: `) on a
    /// condition no argument caused.
    static func resourceErrorMessage(_ error: Error) -> String {
        if let error = error as? GrantivaError { return error.usageMessage }
        return sessionFailureText(error, session: nil)
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

/// The resource URIs the client subscribed to with `resources/subscribe`.
actor ResourceSubscriptions {
    private var uris: Set<String> = []

    func subscribe(_ uri: String) { uris.insert(uri) }
    func unsubscribe(_ uri: String) { uris.remove(uri) }
    func contains(_ uri: String) -> Bool { uris.contains(uri) }
}
