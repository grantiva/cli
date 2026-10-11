import Foundation
import GrantivaCore
import MCP
import XCTest

@testable import GrantivaMCP

/// The runner session's lifecycle as the MCP tools see it: the window after
/// `runner start --detach` returns while WDA has no session yet (R05), a
/// project without a config file (R04), and `grantiva_vrt_capture` while a
/// session holds the device.
@available(macOS 15, *)
final class SessionLifecycleTests: XCTestCase {
    private let udid = "921A0945-7157-4533-BA1F-21E8132D3E40"
    private let port: UInt16 = 8581

    // MARK: - Fixtures

    /// WDA as it answers while the runner is still opening its session:
    /// `/status` is up but carries no `sessionId`.
    private static func startingWDA() -> UIAutomator2Transport {
        UIAutomator2Transport { request in
            if request.url?.path == "/status" {
                return (Data(#"{"value":{"ready":true,"state":"success"}}"#.utf8), 200)
            }
            return (Data(#"{"value":{"error":"invalid session id"}}"#.utf8), 404)
        }
    }

    /// WDA not listening yet.
    private static func refusingWDA() -> UIAutomator2Transport {
        UIAutomator2Transport { _ in throw URLError(.cannotConnectToHost) }
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp-lifecycle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }

    /// A project with a config file and the session file `runner start` writes.
    private func projectWithSessionFile() throws -> URL {
        let directory = try temporaryDirectory()
        try Data().write(to: directory.appendingPathComponent("grantiva.yml"))
        let session = RunnerSessionInfo(
            pid: getpid(), wdaPort: port, bundleId: "com.example.app", udid: udid, startedAt: Date(), platform: .ios
        )
        let sessionURL = directory.appendingPathComponent(RunnerSessionInfo.path)
        try FileManager.default.createDirectory(at: sessionURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(session).write(to: sessionURL)
        return directory
    }

    private func emptyKeepAliveStore() -> KeepAliveSessionStore {
        KeepAliveSessionStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path,
            isProcessAlive: { _ in false }
        )
    }

    /// A registry wired like the server: the session is read from the
    /// project's session file and the driver is the real WDA client over
    /// `transport`.
    private func registry(
        projectDirectory: URL,
        transport: UIAutomator2Transport,
        device: any DevicePlatform = MCPFakeDevicePlatform(platform: .ios)
    ) -> ToolRegistry {
        let store = emptyKeepAliveStore()
        let connection = RunnerConnection(
            resolveSession: {
                try GrantivaMCPServer.loadActiveSession(
                    projectDirectory: projectDirectory, platform: .ios, keepAliveSessions: store
                )
            },
            attach: { session in
                DriverAttachment(
                    client: .wda(port: session.wdaPort, transport: transport), port: Int(session.wdaPort), detach: {}
                )
            }
        )
        return ToolRegistry(
            connection: connection, platform: .ios, device: device, config: GrantivaConfig(),
            simulatorManager: .live, buildRunner: XcodeBuildRunner(), emulators: nil,
            projectDirectory: projectDirectory
        )
    }

    /// The session tools that go through the driver. `grantiva_screenshot`
    /// with a known device uses the platform screenshot instead (below).
    private static let driverTools: [(String, [String: Value])] = [
        ("grantiva_tap", ["label": .string("Continue")]),
        ("grantiva_tap", ["x": .double(10), "y": .double(20)]),
        ("grantiva_swipe", ["direction": .string("up")]),
        ("grantiva_type", ["text": .string("hello")]),
        ("grantiva_a11y_tree", [:]),
        ("grantiva_a11y_check", [:]),
        ("grantiva_script", ["steps": .array([.object(["tap": .string("Continue")])])]),
    ]

    // MARK: - R05: WDA startup window

    func testSessionToolsReturnAnErrorResultWhileWDAHasNoSessionYet() async throws {
        let directory = try projectWithSessionFile()
        let registry = registry(projectDirectory: directory, transport: Self.startingWDA())
        for (name, arguments) in Self.driverTools {
            let result: CallTool.Result
            do {
                result = try await registry.call(name: name, arguments: arguments, server: MCPTestSupport.disconnectedServer())
            } catch {
                XCTFail("\(name) threw (a JSON-RPC error for the client) instead of returning isError: \(error)")
                continue
            }
            XCTAssertEqual(result.isError, true, name)
            let text = try textContent(of: result)
            XCTAssertTrue(text.contains("runner session is starting"), "\(name): \(text)")
            XCTAssertTrue(text.contains("port \(port)"), "\(name): \(text)")
            XCTAssertTrue(text.contains("Retry in a few seconds"), "\(name): \(text)")
        }
    }

    /// Without a device ID the screenshot comes from the driver, so it hits
    /// the same startup window.
    func testScreenshotThroughTheDriverReturnsAnErrorResultWhileWDAHasNoSessionYet() async throws {
        let session = RunnerSessionInfo(pid: getpid(), wdaPort: port, bundleId: "", udid: "", startedAt: Date())
        let transport = Self.startingWDA()
        let connection = RunnerConnection(
            resolveSession: { session },
            attach: { session in
                DriverAttachment(client: .wda(port: session.wdaPort, transport: transport), port: Int(session.wdaPort), detach: {})
            }
        )
        let registry = ToolRegistry(
            connection: connection, platform: .ios, device: MCPFakeDevicePlatform(platform: .ios), config: nil,
            simulatorManager: .live, buildRunner: XcodeBuildRunner(), emulators: nil
        )
        let result = try await registry.call(name: "grantiva_screenshot", arguments: [:], server: MCPTestSupport.disconnectedServer())
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("runner session is starting"))
    }

    /// Before WDA listens at all the HTTP request is refused; that is the
    /// same startup state and gets the same kind of answer.
    func testSessionToolsReturnAnErrorResultWhileWDAIsNotListeningYet() async throws {
        let directory = try projectWithSessionFile()
        let registry = registry(projectDirectory: directory, transport: Self.refusingWDA())
        for (name, arguments) in Self.driverTools {
            let result: CallTool.Result
            do {
                result = try await registry.call(name: name, arguments: arguments, server: MCPTestSupport.disconnectedServer())
            } catch {
                XCTFail("\(name) threw instead of returning isError: \(error)")
                continue
            }
            XCTAssertEqual(result.isError, true, name)
            let text = try textContent(of: result)
            XCTAssertTrue(text.contains("port \(port)"), "\(name): \(text)")
            XCTAssertTrue(text.contains("Retry in a few seconds"), "\(name): \(text)")
        }
    }

    /// The no-session answer is unchanged.
    func testWithoutASessionFileTheToolsStillSayThereIsNoSession() async throws {
        let directory = try temporaryDirectory()
        let registry = registry(projectDirectory: directory, transport: Self.startingWDA())
        let result = try await registry.call(name: "grantiva_a11y_tree", arguments: [:], server: MCPTestSupport.disconnectedServer())
        XCTAssertEqual(result.isError, true)
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("No active runner session"), text)
        XCTAssertTrue(text.contains("grantiva runner start"), text)
    }

    // MARK: - R04: missing config file

    private func configlessRegistry(
        directory: URL, platform: Platform = .ios, device: MCPFakeDevicePlatform
    ) -> ToolRegistry {
        ToolRegistry(
            connection: RunnerConnection(
                resolveSession: { throw GrantivaError.invalidArgument("No active runner session at x.") },
                attach: { _ in throw GrantivaError.invalidArgument("unreachable") }
            ),
            platform: platform, device: device, config: nil,
            simulatorManager: .live, buildRunner: XcodeBuildRunner(), emulators: nil,
            projectDirectory: directory
        )
    }

    func testBuildRunAndTestNameTheMissingConfigFile() async throws {
        let directory = try temporaryDirectory()
        let device = MCPFakeDevicePlatform(platform: .ios)
        let registry = configlessRegistry(directory: directory, device: device)
        let expected = "grantiva.yml not found at \(directory.appendingPathComponent("grantiva.yml").path)"
        for name in ["grantiva_build", "grantiva_run", "grantiva_test"] {
            let result = try await registry.call(name: name, arguments: [:], server: MCPTestSupport.disconnectedServer())
            XCTAssertEqual(result.isError, true, name)
            let text = try textContent(of: result)
            XCTAssertTrue(text.contains(expected), "\(name): \(text)")
            XCTAssertTrue(text.contains("grantiva init"), "\(name): \(text)")
        }
        XCTAssertTrue(device.calls.isEmpty, "\(device.calls)")
    }

    func testAndroidBuildNamesTheMissingAndroidConfigFile() async throws {
        let directory = try temporaryDirectory()
        let device = MCPFakeDevicePlatform(platform: .android)
        let registry = configlessRegistry(directory: directory, platform: .android, device: device)
        let result = try await registry.call(name: "grantiva_build", arguments: [:], server: MCPTestSupport.disconnectedServer())
        XCTAssertEqual(result.isError, true)
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("grantiva-android.yml not found at \(directory.path)/grantiva-android.yml"), text)
        XCTAssertTrue(text.contains("grantiva init --platform android"), text)
        XCTAssertTrue(device.calls.isEmpty, "\(device.calls)")
    }

    /// Arguments still stand in for the config file.
    func testBuildWithASchemeArgumentStillBuildsWithoutAConfigFile() async throws {
        let directory = try temporaryDirectory()
        let device = MCPFakeDevicePlatform(platform: .ios)
        let registry = configlessRegistry(directory: directory, device: device)
        let result = try await registry.call(
            name: "grantiva_build", arguments: ["scheme": .string("Demo")], server: MCPTestSupport.disconnectedServer()
        )
        XCTAssertNil(result.isError)
        XCTAssertTrue(device.calls.contains { $0.hasPrefix("build(scheme=Demo") }, "\(device.calls)")
    }

    /// A config file created after the server started is picked up.
    func testAConfigFileCreatedAfterStartIsRead() async throws {
        let directory = try temporaryDirectory()
        let device = MCPFakeDevicePlatform(platform: .ios)
        var registry = configlessRegistry(directory: directory, device: device)
        registry.loadConfig = { try GrantivaConfig.loadIfPresent(platform: .ios, from: directory) }
        try "scheme: Demo\n".write(to: directory.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
        let result = try await registry.call(name: "grantiva_build", arguments: [:], server: MCPTestSupport.disconnectedServer())
        let text = try textContent(of: result)
        XCTAssertNil(result.isError, text)
        XCTAssertTrue(device.calls.contains { $0.hasPrefix("build(scheme=Demo") }, "\(device.calls)")
    }

    // MARK: - vrt_capture with a live session

    private func screensConfig(_ screens: [GrantivaConfig.Screen]) -> GrantivaConfig {
        var config = GrantivaConfig(bundleId: "com.example.app")
        config.screens = screens
        return config
    }

    private func liveRegistry(
        directory: URL, config: GrantivaConfig?, driver: DriverClient, device: MCPFakeDevicePlatform
    ) -> ToolRegistry {
        let session = RunnerSessionInfo(pid: getpid(), wdaPort: port, bundleId: "com.example.app", udid: udid, startedAt: Date(), platform: .ios)
        return ToolRegistry(
            connection: .fixed(driver: driver, session: session), platform: .ios, device: device, config: config,
            simulatorManager: .live, buildRunner: XcodeBuildRunner(), emulators: nil,
            projectDirectory: directory
        )
    }

    private static let plannedHierarchy = #"""
        {"type":"XCUIElementTypeApplication","label":"Landmarks","children":[
          {"type":"XCUIElementTypeButton","label":"Landmarks","frame":{"x":"20","y":"800","width":"60","height":"40"},"children":[]},
          {"type":"XCUIElementTypeButton","label":"Plan Visit","frame":{"x":"0","y":"0","width":"10","height":"10"},"children":[]}
        ]}
        """#

    func testVRTCaptureRunsThroughTheLiveSessionInsteadOfStartingAnotherRunner() async throws {
        let directory = try temporaryDirectory()
        let recorder = WDARecorder()
        let device = MCPFakeDevicePlatform(platform: .ios)
        device.bootedID = udid
        let config = screensConfig([
            .init(name: "Home", path: .launch),
            .init(name: "Detail", path: .steps([.init(tap: "Landmarks"), .init(assertVisible: "Plan Visit")])),
        ])
        let registry = liveRegistry(
            directory: directory, config: config,
            driver: MCPTestSupport.fakeDriver(recorder: recorder, hierarchyJSON: Self.plannedHierarchy), device: device
        )

        let result = try await registry.call(name: "grantiva_vrt_capture", arguments: [:], server: MCPTestSupport.disconnectedServer())
        let text = try textContent(of: result)
        XCTAssertNil(result.isError, text)
        XCTAssertFalse(text.contains("already owned"), text)

        // The app is relaunched on the session's device; the steps and the
        // screenshots go through the session's driver, as the runner's do.
        XCTAssertEqual(device.calls.filter { !$0.hasPrefix("displayGeometry") }, [
            "bootDevice(\(udid))", "prepare", "terminate(com.example.app)", "launch(com.example.app)", "restore",
        ])
        XCTAssertTrue(recorder.calls.contains("screenshot"), "\(recorder.calls)")
        // The tab, at its frame's center; not the application element that shares its label.
        XCTAssertTrue(recorder.calls.contains("tapByCoordinate(50.0,820.0)"), "\(recorder.calls)")
        let captures = directory.appendingPathComponent(".grantiva/captures")
        for name in ["Home", "Detail"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: captures.appendingPathComponent("\(name).png").path), name)
        }

        // The result has the shape of `grantiva diff capture --json`.
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        let screens = try XCTUnwrap(json["screens"] as? [[String: Any]])
        XCTAssertEqual(screens.compactMap { $0["screen_name"] as? String }, ["Home", "Detail"])
        XCTAssertEqual((json["simulator"] as? [String: Any])?["udid"] as? String, udid)
        // Relative to the project, as `diff capture --json` reports them.
        XCTAssertEqual(json["directory"] as? String, ".grantiva/captures")
        XCTAssertEqual(screens.compactMap { $0["path"] as? String }, [".grantiva/captures/Home.png", ".grantiva/captures/Detail.png"])
    }

    func testVRTCaptureThroughTheSessionReportsTheFailingStepAndRestoresTheStatusBar() async throws {
        let directory = try temporaryDirectory()
        let driver = MCPTestSupport.fakeDriver(recorder: WDARecorder())
        let device = MCPFakeDevicePlatform(platform: .ios)
        let config = screensConfig([
            .init(name: "Home", path: .launch),
            .init(name: "Detail", path: .steps([.init(tap: "Nowhere")])),
        ])
        let registry = liveRegistry(directory: directory, config: config, driver: driver, device: device)

        let result = try await registry.call(name: "grantiva_vrt_capture", arguments: [:], server: MCPTestSupport.disconnectedServer())
        XCTAssertEqual(result.isError, true)
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("Detail"), text)
        XCTAssertTrue(text.contains("Element not found: \"Nowhere\""), text)
        XCTAssertEqual(device.calls.last, "restore")
    }

    func testVRTCaptureThroughTheSessionRefusesStepsTheDriverCannotRunBeforeTouchingTheDevice() async throws {
        let directory = try temporaryDirectory()
        let device = MCPFakeDevicePlatform(platform: .ios)
        let config = screensConfig([.init(name: "Login", path: .steps([.init(runFlow: "login.yaml")]))])
        let registry = liveRegistry(directory: directory, config: config, driver: MCPTestSupport.fakeDriver(recorder: WDARecorder()), device: device)

        let result = try await registry.call(name: "grantiva_vrt_capture", arguments: [:], server: MCPTestSupport.disconnectedServer())
        XCTAssertEqual(result.isError, true)
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("Login"), text)
        XCTAssertTrue(text.contains("runFlow"), text)
        XCTAssertTrue(text.contains("grantiva runner stop"), text)
        XCTAssertTrue(device.calls.isEmpty, "\(device.calls)")
    }

    // MARK: - Selectors in a capture through the session

    /// One screen whose single step is `step`, captured through a session
    /// whose hierarchy is `hierarchy`; returns the result and the driver calls.
    private func captureOneStep(
        _ step: GrantivaConfig.Screen.Step, hierarchy: String
    ) async throws -> (CallTool.Result, [String]) {
        let directory = try temporaryDirectory()
        let recorder = WDARecorder()
        let registry = liveRegistry(
            directory: directory, config: screensConfig([.init(name: "Screen", path: .steps([step]))]),
            driver: MCPTestSupport.fakeDriver(recorder: recorder, hierarchyJSON: hierarchy),
            device: MCPFakeDevicePlatform(platform: .ios)
        )
        let result = try await registry.call(name: "grantiva_vrt_capture", arguments: [:], server: MCPTestSupport.disconnectedServer())
        return (result, recorder.calls)
    }

    private func assertSucceeded(_ result: CallTool.Result, file: StaticString = #filePath, line: UInt = #line) throws {
        let text = try textContent(of: result, file: file, line: line)
        XCTAssertNil(result.isError, text, file: file, line: line)
    }

    private static let loginHierarchy = #"""
        {"type":"XCUIElementTypeApplication","children":[
          {"type":"XCUIElementTypeOther","identifier":"com.app:id/login_button","frame":{"x":0,"y":0,"width":10,"height":10},"children":[]},
          {"type":"XCUIElementTypeButton","identifier":"com.app:id/login","label":"Sign in","frame":{"x":100,"y":200,"width":40,"height":20},"children":[]},
          {"type":"XCUIElementTypeStaticText","label":"Not advertising","frame":{"x":0,"y":300,"width":200,"height":20},"children":[]}
        ]}
        """#

    func testTapByIdMatchesTheWholeIdentifierNotALabel() async throws {
        var byId = GrantivaConfig.Screen.Step(tap: "login")
        byId.tapById = true
        let (result, calls) = try await captureOneStep(byId, hierarchy: Self.loginHierarchy)
        try assertSucceeded(result)
        XCTAssertTrue(calls.contains("tapByCoordinate(120.0,210.0)"), "\(calls)")

        // The same text without `id:` looks at labels, where "login" is not.
        let (byText, _) = try await captureOneStep(.init(tap: "login"), hierarchy: Self.loginHierarchy)
        XCTAssertEqual(byText.isError, true)
        XCTAssertTrue(try textContent(of: byText).contains("Element not found: \"login\""))
    }

    func testTextTapMatchesTheWholeValueIgnoringCaseLikeTheRunner() async throws {
        let (caseless, calls) = try await captureOneStep(.init(tap: "sign IN"), hierarchy: Self.loginHierarchy)
        try assertSucceeded(caseless)
        XCTAssertTrue(calls.contains("tapByCoordinate(120.0,210.0)"), "\(calls)")

        // Plain text is not a substring match: "advertising" is not "Not advertising".
        let (partial, _) = try await captureOneStep(.init(tap: "advertising"), hierarchy: Self.loginHierarchy)
        XCTAssertEqual(partial.isError, true)
        let (regex, regexCalls) = try await captureOneStep(.init(tap: ".*advertising"), hierarchy: Self.loginHierarchy)
        try assertSucceeded(regex)
        XCTAssertTrue(regexCalls.contains("tapByCoordinate(100.0,310.0)"), "\(regexCalls)")
    }

    func testExactTapNeedsTheWholeValueInItsOwnCase() async throws {
        var exact = GrantivaConfig.Screen.Step(tap: "Not advertising")
        exact.tapExact = true
        let (match, _) = try await captureOneStep(exact, hierarchy: Self.loginHierarchy)
        try assertSucceeded(match)

        var otherCase = GrantivaConfig.Screen.Step(tap: "not advertising")
        otherCase.tapExact = true
        let (miss, _) = try await captureOneStep(otherCase, hierarchy: Self.loginHierarchy)
        XCTAssertEqual(miss.isError, true)
    }

    func testAssertionsUseTheSameSelectorRules() async throws {
        let (partial, _) = try await captureOneStep(.init(assertVisible: "advertising"), hierarchy: Self.loginHierarchy)
        XCTAssertEqual(partial.isError, true)
        XCTAssertTrue(try textContent(of: partial).contains("is not visible"))
        var byId = GrantivaConfig.Screen.Step(assertVisible: "login")
        byId.assertVisibleById = true
        let (found, _) = try await captureOneStep(byId, hierarchy: Self.loginHierarchy)
        try assertSucceeded(found)
        let (absent, _) = try await captureOneStep(.init(assertNotVisible: "Sign out"), hierarchy: Self.loginHierarchy)
        try assertSucceeded(absent)
    }

    func testASwipeWithADurationIsRefusedBeforeTouchingTheDevice() async throws {
        let directory = try temporaryDirectory()
        let device = MCPFakeDevicePlatform(platform: .ios)
        var step = GrantivaConfig.Screen.Step(swipe: "up")
        step.swipeDuration = 400
        let registry = liveRegistry(
            directory: directory, config: screensConfig([.init(name: "Feed", path: .steps([step]))]),
            driver: MCPTestSupport.fakeDriver(recorder: WDARecorder()), device: device
        )
        let result = try await registry.call(name: "grantiva_vrt_capture", arguments: [:], server: MCPTestSupport.disconnectedServer())
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("a swipe with a duration"))
        XCTAssertTrue(device.calls.isEmpty, "\(device.calls)")
    }

    /// R04 repro: an empty directory and no session.
    func testVRTCaptureWithoutASessionOrConfigNamesTheMissingFile() async throws {
        let directory = try temporaryDirectory()
        let device = MCPFakeDevicePlatform(platform: .ios)
        let registry = configlessRegistry(directory: directory, device: device)
        let result = try await registry.call(name: "grantiva_vrt_capture", arguments: [:], server: MCPTestSupport.disconnectedServer())
        XCTAssertEqual(result.isError, true)
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("grantiva.yml not found at \(directory.path)/grantiva.yml"), text)
        XCTAssertTrue(text.contains("grantiva init"), text)
        XCTAssertTrue(device.calls.isEmpty, "\(device.calls)")
    }

    func testVRTCaptureWithALiveSessionNamesTheMissingConfigFile() async throws {
        let directory = try temporaryDirectory()
        let device = MCPFakeDevicePlatform(platform: .ios)
        let registry = liveRegistry(directory: directory, config: nil, driver: MCPTestSupport.fakeDriver(recorder: WDARecorder()), device: device)
        let result = try await registry.call(name: "grantiva_vrt_capture", arguments: [:], server: MCPTestSupport.disconnectedServer())
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("grantiva.yml not found at \(directory.path)/grantiva.yml"))
        XCTAssertTrue(device.calls.isEmpty, "\(device.calls)")
    }

    func testVRTCaptureWithALiveSessionAndNoScreensSaysSo() async throws {
        let directory = try temporaryDirectory()
        let device = MCPFakeDevicePlatform(platform: .ios)
        let registry = liveRegistry(
            directory: directory, config: screensConfig([]), driver: MCPTestSupport.fakeDriver(recorder: WDARecorder()), device: device
        )
        let result = try await registry.call(name: "grantiva_vrt_capture", arguments: [:], server: MCPTestSupport.disconnectedServer())
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("No screens configured in grantiva.yml"))
    }
}
