import Foundation
import GrantivaCore
import MCP

/// The Grantiva MCP server. Exposes iOS simulator and Android emulator automation tools and resources
/// over the Model Context Protocol via stdio transport.
@available(macOS 15, *)
public struct GrantivaMCPServer: Sendable {
    private let projectDirectory: URL?

    public init(projectDirectory: URL? = nil) {
        self.projectDirectory = projectDirectory
    }

    public func run() async throws {
        let projectDirectory = try Self.resolveProjectDirectory(projectDirectory)
        guard FileManager.default.changeCurrentDirectoryPath(projectDirectory.path) else {
            throw GrantivaError.invalidArgument("Cannot use project directory: \(projectDirectory.path)")
        }

        // All relative tool paths now resolve from the selected project root.
        let platform = try PlatformResolver(directory: projectDirectory).resolveOrDefault(flag: nil)
        let config = try GrantivaConfig.loadIfPresent(platform: platform)
        let session = try Self.loadActiveSession(projectDirectory: projectDirectory)
        let device = try DevicePlatformFactory.make(platform)
        let attachment = try await device.attachDriver(deviceID: session.udid, port: Self.driverPort(for: session))

        let tools = ToolRegistry(
            driver: attachment.client,
            platform: platform,
            device: device,
            config: config,
            session: session,
            simulatorManager: SimulatorManager.live,
            buildRunner: XcodeBuildRunner(),
            emulators: try? EmulatorToolDependencies.live()
        )

        let allTools = tools.allTools()
        let allResources = tools.allResources()

        // Create and configure MCP server
        let server = Server(
            name: "grantiva",
            version: grantivaVersion,
            instructions: """
                Grantiva MCP server for iOS simulator and Android emulator automation. \
                Use grantiva_* tools to interact with the device: \
                tap, swipe, type, take screenshots, inspect the accessibility tree, \
                build and run apps, manage simulators and emulators, and run visual regression tests.
                """,
            capabilities: .init(
                resources: .init(subscribe: true, listChanged: false),
                tools: .init(listChanged: false)
            )
        )

        // Register tools/list handler
        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: allTools)
        }

        // Register tools/call handler
        await server.withMethodHandler(CallTool.self) { params in
            let result = try await tools.call(
                name: params.name,
                arguments: params.arguments ?? [:],
                server: server
            )
            return result
        }

        // Register resources/list handler
        await server.withMethodHandler(ListResources.self) { _ in
            ListResources.Result(resources: allResources)
        }

        // Register resources/read handler
        await server.withMethodHandler(ReadResource.self) { params in
            let contents = try await tools.readResource(uri: params.uri)
            return ReadResource.Result(contents: contents)
        }

        // Register resources/subscribe handler
        await server.withMethodHandler(ResourceSubscribe.self) { params in
            // Subscription tracking is handled by the MCP server actor internally.
            // We just acknowledge it here.
            return Empty()
        }

        // Register resources/unsubscribe handler
        await server.withMethodHandler(ResourceUnsubscribe.self) { params in
            return Empty()
        }

        // Start on stdio transport
        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }

    static func resolveProjectDirectory(_ directory: URL?) throws -> URL {
        let resolved = (directory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            .standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw GrantivaError.invalidArgument("Project directory does not exist: \(resolved.path)")
        }
        let hasConfig = Platform.allCases.contains {
            FileManager.default.fileExists(atPath: resolved.appendingPathComponent($0.configFileName).path)
        }
        guard hasConfig else {
            throw GrantivaError.invalidArgument("No grantiva.yml or grantiva-android.yml found in project directory: \(resolved.path)")
        }
        return resolved
    }

    /// The runner's keep-alive session file carries port 0 on Android (the
    /// runner does not proxy UIAutomator2); nil tells the platform to forward one.
    static func driverPort(for session: RunnerSessionInfo) -> UInt16? {
        session.wdaPort > 0 ? session.wdaPort : nil
    }

    /// A `grantiva runner start` session in the project wins; otherwise the
    /// newest `grantiva run --keep-alive` session (shared discovery with
    /// `grantiva hierarchy`) is adapted to the same shape.
    static func loadActiveSession(
        projectDirectory: URL,
        keepAliveSessions: KeepAliveSessionStore = KeepAliveSessionStore()
    ) throws -> RunnerSessionInfo {
        let sessionURL = projectDirectory.appendingPathComponent(RunnerSessionInfo.path)
        if let data = try? Data(contentsOf: sessionURL),
           let session = try? JSONDecoder().decode(RunnerSessionInfo.self, from: data),
           session.isAlive {
            _ = try DeviceID.validate(session.udid, flag: "session UDID")
            return session
        }
        if let keepAlive = try? keepAliveSessions.locate(), let port = UInt16(exactly: keepAlive.port) {
            let udid = keepAlive.udid.flatMap { try? DeviceID.validate($0) } ?? ""
            return RunnerSessionInfo(
                pid: keepAlive.pid, wdaPort: port, bundleId: "", udid: udid, startedAt: Date()
            )
        }
        throw GrantivaError.invalidArgument(
            "No active runner session at \(sessionURL.path). Start one with 'grantiva runner start' or `grantiva run --keep-alive`."
        )
    }
}
