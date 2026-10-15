import Foundation
import GrantivaCore
import MCP

/// The Grantiva MCP server. Exposes iOS simulator and Android emulator automation tools and resources
/// over the Model Context Protocol via stdio transport.
@available(macOS 15, *)
public struct GrantivaMCPServer: Sendable {
    private let projectDirectory: URL?
    private let platform: Platform?

    /// `platform` is the `--platform` flag; nil resolves it from the project
    /// directory (and fails when both config files are present).
    public init(projectDirectory: URL? = nil, platform: Platform? = nil) {
        self.projectDirectory = projectDirectory
        self.platform = platform
    }

    public func run() async throws {
        let (server, connection) = try await makeServer()
        // Detach on both paths: on Android the attachment owns an adb forward.
        let transport = ValidatingTransport(wrapping: StdioTransport())
        do {
            try await server.start(transport: transport)
            await server.waitUntilCompleted()
        } catch {
            await connection.detach()
            throw error
        }
        await connection.detach()
    }

    /// Builds the configured server. Nothing here needs a runner session or a
    /// config file: device tools attach to the session on first use and
    /// report a missing one as a tool error, so an agent can still list tools
    /// and provision a device.
    func makeServer(
        keepAliveSessions: KeepAliveSessionStore = KeepAliveSessionStore()
    ) async throws -> (Server, RunnerConnection) {
        let projectDirectory = try Self.resolveProjectDirectory(projectDirectory)
        guard FileManager.default.changeCurrentDirectoryPath(projectDirectory.path) else {
            throw GrantivaError.invalidArgument("Cannot use project directory: \(projectDirectory.path)")
        }

        // All relative tool paths now resolve from the selected project root.
        let platform = try PlatformResolver(directory: projectDirectory).resolveOrDefault(flag: self.platform)
        let config = try GrantivaConfig.loadIfPresent(platform: platform)
        let device = try DevicePlatformFactory.make(platform)
        let connection = RunnerConnection(
            resolveSession: {
                try Self.loadActiveSession(
                    projectDirectory: projectDirectory, platform: platform, keepAliveSessions: keepAliveSessions
                )
            },
            attach: { session in
                if platform == .android, session.udid.isEmpty {
                    throw GrantivaError.invalidArgument(
                        "The runner session does not record which Android device it holds. Start it with `grantiva runner start` or `grantiva run --keep-alive` from this version of Grantiva."
                    )
                }
                return try await device.attachDriver(deviceID: session.udid, port: Self.driverPort(for: session))
            }
        )

        let tools = ToolRegistry(
            connection: connection,
            platform: platform,
            device: device,
            config: config,
            simulatorManager: SimulatorManager.live,
            buildRunner: XcodeBuildRunner(),
            emulators: try? EmulatorToolDependencies.live(),
            projectDirectory: projectDirectory,
            platformDetected: self.platform == nil && (try? PlatformResolver().environmentPlatform()) == nil,
            loadConfig: { try GrantivaConfig.loadIfPresent(platform: platform, from: projectDirectory) }
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

        // Register tools/call handler; a cancelled call gets no response (L14).
        await Self.registerToolCalls(on: server) { name, arguments in
            try await tools.call(name: name, arguments: arguments, server: server)
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

        // resources/subscribe and unsubscribe: hierarchy updates are sent
        // only while the client is subscribed.
        await server.withMethodHandler(ResourceSubscribe.self) { params in
            await tools.subscriptions.subscribe(params.uri)
            return Empty()
        }
        await server.withMethodHandler(ResourceUnsubscribe.self) { params in
            await tools.subscriptions.unsubscribe(params.uri)
            return Empty()
        }

        return (server, connection)
    }

    /// The directory must exist; a config file is optional (tools that need
    /// one say so when called).
    static func resolveProjectDirectory(_ directory: URL?) throws -> URL {
        // realpath(3) spelling, as keep-alive owners record it: `/tmp/x`
        // resolves to `/private/tmp/x` (`standardizedFileURL` would strip the
        // `/private` instead).
        let requested = (directory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        let resolved = URL(fileURLWithPath: KeepAliveOwner.canonicalDirectory(requested.path), isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw GrantivaError.invalidArgument("Project directory does not exist: \(resolved.path)")
        }
        return resolved
    }

    /// The runner's keep-alive session file carries port 0 on Android (the
    /// runner does not proxy UIAutomator2); nil tells the platform to forward one.
    static func driverPort(for session: RunnerSessionInfo) -> UInt16? {
        session.wdaPort > 0 ? session.wdaPort : nil
    }

    /// A live `grantiva runner start` session in the project for this
    /// platform wins (one for the other platform, in a directory with both
    /// config files, is skipped). Otherwise
    /// a `grantiva run --keep-alive` (or `runner start`) session is used only
    /// when its owner sidecar records this project directory and platform;
    /// sessions started elsewhere, for the other platform, or by a Grantiva
    /// that did not record those fields are never attached to.
    static func loadActiveSession(
        projectDirectory: URL,
        platform: Platform,
        keepAliveSessions: KeepAliveSessionStore = KeepAliveSessionStore()
    ) throws -> RunnerSessionInfo {
        let sessionURL = projectDirectory.appendingPathComponent(RunnerSessionInfo.path)
        if let data = try? Data(contentsOf: sessionURL),
           let session = try? RunnerSessionInfo.decode(data),
           session.isAlive, session.drivesPlatform(platform) {
            _ = try DeviceID.validate(session.udid, flag: "session UDID")
            // Written at launch, before the driver answers (L38-a).
            guard session.isReady else { throw RunnerSessionInfo.startingError(platform: platform, port: session.wdaPort) }
            return session
        }
        let project = KeepAliveOwner.canonicalDirectory(projectDirectory.path)
        // The one lookup `runner stop`, teardown and `hierarchy` use (L52):
        // published sessions first, then runners still starting.
        let sessions = keepAliveSessions.sessions()
        if let keepAlive = sessions.first(where: { $0.projectDirectory == project && $0.platform == platform }) {
            // A runner of this project's is up but has not published its session.
            guard keepAlive.isPublished else { throw RunnerSessionInfo.startingError(platform: platform) }
            if let port = UInt16(exactly: keepAlive.port) {
                let udid = keepAlive.udid.flatMap { try? DeviceID.validate($0) } ?? ""
                return RunnerSessionInfo(
                    pid: keepAlive.pid, wdaPort: port, bundleId: keepAlive.appId ?? "", udid: udid, startedAt: Date()
                )
            }
        }
        let live = sessions.filter(\.isPublished)
        throw GrantivaError.noRunnerSession(
            sessionFile: sessionURL.path, directory: projectDirectory.path, ignored: live.count
        )
    }
}
