import Foundation
import GrantivaCore
import MCP

/// The Grantiva MCP server. Exposes iOS simulator automation tools and resources
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
        let config = try? GrantivaConfig.load()

        let session = try Self.loadActiveSession(projectDirectory: projectDirectory)

        let wda = WDAClient.live(port: session.wdaPort)
        let simManager = SimulatorManager.live
        let buildRunner = XcodeBuildRunner()

        // Build the tool registry
        let tools = ToolRegistry(
            wda: wda,
            config: config,
            session: session,
            simulatorManager: simManager,
            buildRunner: buildRunner
        )

        let allTools = tools.allTools()
        let allResources = tools.allResources()

        // Create and configure MCP server
        let server = Server(
            name: "grantiva",
            version: grantivaVersion,
            instructions: """
                Grantiva MCP server for iOS simulator automation. \
                Use grantiva_* tools to interact with the iOS simulator: \
                tap, swipe, type, take screenshots, inspect the accessibility tree, \
                build and run apps, manage simulators, and run visual regression tests.
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
        guard FileManager.default.fileExists(atPath: resolved.appendingPathComponent("grantiva.yml").path) else {
            throw GrantivaError.invalidArgument("No grantiva.yml found in project directory: \(resolved.path)")
        }
        return resolved
    }

    static func loadActiveSession(projectDirectory: URL) throws -> RunnerSessionInfo {
        let sessionURL = projectDirectory.appendingPathComponent(RunnerSessionInfo.path)
        guard let data = try? Data(contentsOf: sessionURL),
              let session = try? JSONDecoder().decode(RunnerSessionInfo.self, from: data),
              session.isAlive else {
            throw GrantivaError.invalidArgument(
                "No active runner session at \(sessionURL.path). Start one with 'grantiva runner start'."
            )
        }
        _ = try SimulatorUDID.validate(session.udid, flag: "session UDID")
        return session
    }
}
