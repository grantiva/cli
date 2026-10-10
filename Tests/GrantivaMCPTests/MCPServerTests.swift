import Foundation
import GrantivaCore
@testable import GrantivaMCP
import MCP
import XCTest

@available(macOS 15, *)
final class MCPServerTests: XCTestCase {
    /// C11: a project directory without a config file still starts the server.
    func testProjectDirectoryDoesNotRequireAConfigFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertEqual(
            try GrantivaMCPServer.resolveProjectDirectory(directory).standardizedFileURL,
            directory.standardizedFileURL
        )
    }

    func testProjectDirectoryMustExist() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertThrowsError(try GrantivaMCPServer.resolveProjectDirectory(missing)) { error in
            XCTAssertTrue(String(describing: error).contains("does not exist"))
        }
    }

    func testSessionIsLoadedRelativeToExplicitProjectDirectory() throws {
        let directory = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = RunnerSessionInfo(
            pid: getpid(),
            wdaPort: 8201,
            bundleId: "com.example.app",
            udid: "921A0945-7157-4533-BA1F-21E8132D3E40",
            startedAt: Date()
        )
        let sessionURL = directory.appendingPathComponent(RunnerSessionInfo.path)
        try FileManager.default.createDirectory(
            at: sessionURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(session).write(to: sessionURL)

        let loaded = try GrantivaMCPServer.loadActiveSession(projectDirectory: directory, platform: .ios, keepAliveSessions: emptyKeepAliveStore())

        XCTAssertEqual(loaded.wdaPort, 8201)
        XCTAssertEqual(loaded.bundleId, "com.example.app")
    }

    func testSessionRejectsMalformedUDIDBeforeToolsConsumeIt() throws {
        let directory = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = RunnerSessionInfo(
            pid: getpid(),
            wdaPort: 8201,
            bundleId: "com.example.app",
            udid: "$(touch /tmp/grantiva-mcp-injected)",
            startedAt: Date()
        )
        let sessionURL = directory.appendingPathComponent(RunnerSessionInfo.path)
        try FileManager.default.createDirectory(
            at: sessionURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(session).write(to: sessionURL)

        XCTAssertThrowsError(try GrantivaMCPServer.loadActiveSession(projectDirectory: directory, platform: .ios, keepAliveSessions: emptyKeepAliveStore())) { error in
            XCTAssertTrue(String(describing: error).contains("session UDID"))
        }
    }

    func testMissingSessionFailsLoudly() throws {
        let directory = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertThrowsError(
            try GrantivaMCPServer.loadActiveSession(projectDirectory: directory, platform: .ios, keepAliveSessions: emptyKeepAliveStore())
        ) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("No active runner session"))
            XCTAssertTrue(message.contains("grantiva runner start"))
            XCTAssertTrue(message.contains("grantiva run --keep-alive"))
        }
    }

    func testFallsBackToALiveKeepAliveSessionStartedFromTheSameProject() throws {
        let directory = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let udid = "921A0945-7157-4533-BA1F-21E8132D3E40"
        let store = try keepAliveStore(in: directory, owners: [(4242, udid, directory.path, .ios)])

        let loaded = try GrantivaMCPServer.loadActiveSession(projectDirectory: directory, platform: .ios, keepAliveSessions: store)
        XCTAssertEqual(loaded.pid, 4242)
        XCTAssertEqual(loaded.wdaPort, 8577)
        XCTAssertEqual(loaded.udid, udid)
    }

    /// C03: another project's keep-alive session is never attached to.
    func testIgnoresAKeepAliveSessionFromAnotherProjectDirectory() throws {
        let directory = try makeProjectDirectory()
        let other = try makeProjectDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: other)
        }
        let store = try keepAliveStore(in: directory, owners: [(4242, "921A0945-7157-4533-BA1F-21E8132D3E40", other.path, .ios)])

        XCTAssertThrowsError(
            try GrantivaMCPServer.loadActiveSession(projectDirectory: directory, platform: .ios, keepAliveSessions: store)
        ) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("No active runner session"), message)
            XCTAssertTrue(message.contains("1 keep-alive session(s) started from another project directory"), message)
        }
    }

    /// C03: a keep-alive session for the other platform is never attached to.
    func testIgnoresAKeepAliveSessionForAnotherPlatform() throws {
        let directory = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try keepAliveStore(in: directory, owners: [(4242, "921A0945-7157-4533-BA1F-21E8132D3E40", directory.path, .ios)])

        XCTAssertThrowsError(
            try GrantivaMCPServer.loadActiveSession(projectDirectory: directory, platform: .android, keepAliveSessions: store)
        )
    }

    /// Sidecars written before the project directory was recorded are ignored.
    func testIgnoresAKeepAliveSessionWithoutARecordedProjectDirectory() throws {
        let directory = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sessions = directory.appendingPathComponent("sessions")
        let store = try keepAliveStore(in: directory, owners: [])
        let legacy = #"{"udid":"921A0945-7157-4533-BA1F-21E8132D3E40","runnerPid":4242,"grantivaPid":1,"createdAt":"2026-10-01T00:00:00Z"}"#
        try Data(legacy.utf8).write(to: sessions.appendingPathComponent("4242.owner.json"))
        XCTAssertEqual(store.liveSessions().first?.udid, "921A0945-7157-4533-BA1F-21E8132D3E40")

        XCTAssertThrowsError(
            try GrantivaMCPServer.loadActiveSession(projectDirectory: directory, platform: .ios, keepAliveSessions: store)
        )
    }

    /// The newest session from the same project and platform wins over a newer
    /// one from elsewhere.
    func testPicksTheMatchingSessionAmongSeveral() throws {
        let directory = try makeProjectDirectory()
        let other = try makeProjectDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: other)
        }
        let store = try keepAliveStore(in: directory, owners: [
            (4242, "921A0945-7157-4533-BA1F-21E8132D3E40", directory.path, .ios),
            (4343, "11111111-2222-3333-4444-555555555555", other.path, .ios),
        ])
        let loaded = try GrantivaMCPServer.loadActiveSession(projectDirectory: directory, platform: .ios, keepAliveSessions: store)
        XCTAssertEqual(loaded.pid, 4242)
    }

    /// Writes a runner session file for each pid (later pids are newer) and
    /// an owner sidecar for each entry in `owners`.
    private func keepAliveStore(
        in directory: URL,
        owners: [(pid: Int32, udid: String, project: String, platform: Platform)]
    ) throws -> KeepAliveSessionStore {
        let sessions = directory.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let pids = Set(owners.map(\.pid)).union([4242])
        let store = KeepAliveSessionStore(directory: sessions.path, isProcessAlive: { pids.contains($0) })
        for (index, pid) in pids.sorted().enumerated() {
            let runnerFile: [String: Any] = ["version": 1, "sessionId": "s\(pid)", "pid": pid, "port": 8577, "outputDir": "/o"]
            try JSONSerialization.data(withJSONObject: runnerFile)
                .write(to: sessions.appendingPathComponent("\(pid)-179134047889082500\(index).grantiva"))
        }
        for owner in owners {
            store.recordOwner(udid: owner.udid, runnerPid: owner.pid, projectDirectory: owner.project, platform: owner.platform)
        }
        return store
    }

    private func emptyKeepAliveStore() -> KeepAliveSessionStore {
        KeepAliveSessionStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path,
            isProcessAlive: { _ in false }
        )
    }

    private func makeProjectDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data().write(to: directory.appendingPathComponent("grantiva.yml"))
        return directory
    }

    /// Review Focus 5.
    func testProjectDirectoryAcceptsAnAndroidOnlyProject() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "platform: android\nmodule: app\n".write(to: directory.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        XCTAssertEqual(try GrantivaMCPServer.resolveProjectDirectory(directory).standardizedFileURL, directory.standardizedFileURL)
    }

    /// Review Focus 5.
    func testLoadActiveSessionAcceptsAnADBSerial() throws {
        let directory = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = RunnerSessionInfo(pid: getpid(), wdaPort: 61211, bundleId: "dev.grantiva.example", udid: "emulator-5554", startedAt: Date())
        let sessionURL = directory.appendingPathComponent(RunnerSessionInfo.path)
        try FileManager.default.createDirectory(at: sessionURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(session).write(to: sessionURL)
        let loaded = try GrantivaMCPServer.loadActiveSession(projectDirectory: directory, platform: .android, keepAliveSessions: emptyKeepAliveStore())
        XCTAssertEqual(loaded.udid, "emulator-5554")
        XCTAssertEqual(loaded.wdaPort, 61211)
    }

    func testDriverPortIsNilForAKeepAliveSessionWithPortZero() {
        XCTAssertNil(GrantivaMCPServer.driverPort(for: RunnerSessionInfo(pid: 1, wdaPort: 0, bundleId: "", udid: "emulator-5554", startedAt: Date())))
        XCTAssertEqual(GrantivaMCPServer.driverPort(for: RunnerSessionInfo(pid: 1, wdaPort: 8100, bundleId: "", udid: "", startedAt: Date())), 8100)
    }

    /// A directory with both config files is ambiguous on its own; the
    /// server's `--platform` flag settles it.
    func testExplicitPlatformWinsOverADualConfigDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "scheme: Example\n".write(to: directory.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
        try "platform: android\nmodule: app\n".write(to: directory.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        let resolver = PlatformResolver(directory: directory)
        XCTAssertThrowsError(try resolver.resolveOrDefault(flag: nil))
        XCTAssertEqual(try resolver.resolveOrDefault(flag: .android), .android)
    }

    // MARK: - Startup without a session (C11)

    /// Runs `body` against a server built for `directory`, connected over an
    /// in-memory transport, with no keep-alive sessions on the machine.
    private func withServer(
        directory: URL,
        _ body: (Client) async throws -> Void
    ) async throws {
        let previous = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(previous) }
        let (server, connection) = try await GrantivaMCPServer(projectDirectory: directory, platform: .ios)
            .makeServer(keepAliveSessions: emptyKeepAliveStore())
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: serverTransport)
        let client = Client(name: "test", version: "0.0.0")
        _ = try await client.connect(transport: clientTransport)
        do {
            try await body(client)
        } catch {
            await client.disconnect()
            await server.stop()
            await connection.detach()
            throw error
        }
        await client.disconnect()
        await server.stop()
        await connection.detach()
    }

    func testServerStartsWithoutASessionAndDeviceToolsReturnAToolError() async throws {
        let directory = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await withServer(directory: directory) { client in
            let tools = try await client.listTools().tools.map(\.name)
            XCTAssertTrue(tools.contains("grantiva_tap"), "\(tools)")
            XCTAssertTrue(tools.contains("grantiva_sim_list"), "\(tools)")

            for (name, arguments) in [
                ("grantiva_tap", ["label": Value.string("General")]),
                ("grantiva_swipe", ["direction": .string("up")]),
                ("grantiva_type", ["text": .string("x")]),
                ("grantiva_screenshot", [:]),
                ("grantiva_a11y_tree", [:]),
                ("grantiva_a11y_check", [:]),
                ("grantiva_script", ["steps": .array([])]),
            ] {
                let result = try await client.callTool(name: name, arguments: arguments)
                XCTAssertEqual(result.isError, true, name)
                let text = result.content.compactMap { if case .text(let t, _, _) = $0 { return t } else { return nil } }.joined()
                XCTAssertTrue(text.contains("No active runner session"), "\(name): \(text)")
                XCTAssertTrue(text.contains("grantiva runner start"), "\(name): \(text)")
            }
        }
    }

    func testServerStartsInADirectoryWithoutAConfigFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try await withServer(directory: directory) { client in
            let tools = try await client.listTools().tools
            XCTAssertFalse(tools.isEmpty)
            let result = try await client.callTool(name: "grantiva_build", arguments: [:])
            XCTAssertEqual(result.isError, true)
            let text = result.content.compactMap { if case .text(let t, _, _) = $0 { return t } else { return nil } }.joined()
            XCTAssertTrue(text.contains("grantiva.yml"), text)
        }
    }

    // MARK: - Lazy attachment (C11)

    /// Concurrent first calls share one attach; nothing is left attached
    /// after detach.
    func testConcurrentFirstCallsAttachOnce() async throws {
        final class Counter: @unchecked Sendable {
            let lock = NSLock()
            var attaches = 0
            var detaches = 0
        }
        let counter = Counter()
        let session = RunnerSessionInfo(pid: 10, wdaPort: 8100, bundleId: "", udid: "emulator-5554", startedAt: Date())
        let connection = RunnerConnection(
            resolveSession: { session },
            attach: { _ in
                counter.lock.withLock { counter.attaches += 1 }
                try await Task.sleep(nanoseconds: 50_000_000)
                return DriverAttachment(client: .failing, port: 8100, detach: {
                    counter.lock.withLock { counter.detaches += 1 }
                })
            }
        )
        async let first = connection.current()
        async let second = connection.current()
        async let third = connection.current()
        _ = try await (first, second, third)
        XCTAssertEqual(counter.attaches, 1)
        await connection.detach()
        XCTAssertEqual(counter.detaches, 1)
    }

    /// C03 review: in a directory with both config files, a session.json
    /// written for the other platform is skipped.
    func testSessionFileForTheOtherPlatformIsSkipped() throws {
        let directory = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sessionURL = directory.appendingPathComponent(RunnerSessionInfo.path)
        try FileManager.default.createDirectory(at: sessionURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let recorded = RunnerSessionInfo(pid: getpid(), wdaPort: 8201, bundleId: "a", udid: "921A0945-7157-4533-BA1F-21E8132D3E40", startedAt: Date(), platform: .ios)
        try JSONEncoder().encode(recorded).write(to: sessionURL)
        XCTAssertThrowsError(try GrantivaMCPServer.loadActiveSession(projectDirectory: directory, platform: .android, keepAliveSessions: emptyKeepAliveStore()))
        XCTAssertEqual(try GrantivaMCPServer.loadActiveSession(projectDirectory: directory, platform: .ios, keepAliveSessions: emptyKeepAliveStore()).wdaPort, 8201)

        // A file from an earlier version (no platform) is judged by the device ID's shape.
        let legacy = #"{"pid":\#(getpid()),"wdaPort":8201,"bundleId":"a","udid":"emulator-5554","startedAt":0}"#
        try Data(legacy.utf8).write(to: sessionURL)
        XCTAssertThrowsError(try GrantivaMCPServer.loadActiveSession(projectDirectory: directory, platform: .ios, keepAliveSessions: emptyKeepAliveStore()))
        XCTAssertEqual(try GrantivaMCPServer.loadActiveSession(projectDirectory: directory, platform: .android, keepAliveSessions: emptyKeepAliveStore()).udid, "emulator-5554")
    }

    func testConnectionAttachesOnFirstUseAndPicksUpASessionStartedLater() async throws {
        final class State: @unchecked Sendable {
            let lock = NSLock()
            var session: RunnerSessionInfo?
            var attaches: [String] = []
            var detaches = 0
        }
        let state = State()
        let connection = RunnerConnection(
            resolveSession: {
                guard let session = state.lock.withLock({ state.session }) else {
                    throw GrantivaError.invalidArgument("No active runner session at x. Start one with 'grantiva runner start'.")
                }
                return session
            },
            attach: { session in
                state.lock.withLock { state.attaches.append("\(session.pid):\(session.wdaPort)") }
                return DriverAttachment(client: .failing, port: Int(session.wdaPort), detach: {
                    state.lock.withLock { state.detaches += 1 }
                })
            }
        )

        do {
            _ = try await connection.current()
            XCTFail("expected no session")
        } catch {
            XCTAssertTrue(String(describing: error).contains("No active runner session"))
        }
        XCTAssertTrue(state.attaches.isEmpty)

        state.lock.withLock { state.session = RunnerSessionInfo(pid: 10, wdaPort: 8100, bundleId: "", udid: "921A0945-7157-4533-BA1F-21E8132D3E40", startedAt: Date()) }
        _ = try await connection.current()
        _ = try await connection.current()
        XCTAssertEqual(state.attaches, ["10:8100"], "The driver is attached once per session")

        state.lock.withLock { state.session = RunnerSessionInfo(pid: 11, wdaPort: 8200, bundleId: "", udid: "921A0945-7157-4533-BA1F-21E8132D3E40", startedAt: Date()) }
        let current = try await connection.current()
        XCTAssertEqual(current.session.pid, 11)
        XCTAssertEqual(state.attaches, ["10:8100", "11:8200"])
        XCTAssertEqual(state.detaches, 1, "The stale attachment is released")

        await connection.detach()
        XCTAssertEqual(state.detaches, 2)
    }
}
