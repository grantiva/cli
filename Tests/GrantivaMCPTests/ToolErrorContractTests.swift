import MCP
import XCTest
@testable import GrantivaCore
@testable import GrantivaMCP

/// Guards the MCP error contract: invalid input from the model must come back as a
/// `CallTool.Result` with `isError: true`, which the model can read and correct. A
/// thrown error becomes a JSON-RPC protocol error, which reads as a transport failure.
///
/// Each case here returns before touching the simulator, so no `simctl` process runs.
final class ToolErrorContractTests: XCTestCase {

    private let simManager = SimulatorManager()

    private func assertToolError(
        _ result: CallTool.Result,
        contains expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(result.isError, true, "expected an isError result", file: file, line: line)
        let text = result.content.compactMap { content -> String? in
            if case .text(let text, _, _) = content { return text }
            return nil
        }.joined(separator: "\n")
        XCTAssertTrue(text.contains(expected), "\(text) does not mention \(expected)", file: file, line: line)
    }

    func testSimEnsureMissingArgumentsReturnsToolError() async throws {
        let result = try await SimTools.ensure(simManager: simManager, arguments: [:])
        assertToolError(result, contains: "required")
    }

    func testSimEnsureMissingNameReturnsToolError() async throws {
        // Only `name` is required now: the device type is inferred from it and
        // the runtime defaults to the newest installed one.
        let result = try await SimTools.ensure(
            simManager: simManager,
            arguments: ["device_type": .string("iPhone 16"), "runtime": .string("latest")]
        )
        assertToolError(result, contains: "'name' is required")
    }

    func testSimEnsureWrongArgumentTypeReturnsToolError() async throws {
        let result = try await SimTools.ensure(
            simManager: simManager,
            arguments: ["name": .int(7), "device_type": .string("iPhone 16"), "runtime": .string("latest")]
        )
        assertToolError(result, contains: "required")
    }

    func testSimDeleteMissingNameReturnsToolError() async throws {
        let result = try await SimTools.delete(simManager: simManager, arguments: [:])
        assertToolError(result, contains: "'name' is required")
    }

    func testSimDeleteWrongArgumentTypeReturnsToolError() async throws {
        let result = try await SimTools.delete(simManager: simManager, arguments: ["name": .bool(true)])
        assertToolError(result, contains: "'name' is required")
    }

    /// The tools that already honored the contract, kept here so the shape stays uniform.
    func testUIToolsReturnToolErrorsForInvalidArguments() async throws {
        let driver = DriverClient.wda(port: 8100)
        assertToolError(try await UITools.tap(driver: driver, arguments: [:]), contains: "Error:")
        assertToolError(try await UITools.swipe(driver: driver, arguments: [:]), contains: "'direction' is required")
        assertToolError(try await UITools.type(driver: driver, arguments: [:]), contains: "'text' is required")
        assertToolError(try await ScriptTools.script(driver: driver, arguments: [:]), contains: "'steps' array is required")
    }

    /// A label that matches nothing is the model's mistake to correct, not a
    /// transport failure: it must come back as an isError result.
    func testTapByAMissingLabelReturnsToolError() async throws {
        var driver = MCPTestSupport.fakeDriver(recorder: WDARecorder())
        driver.tapByLabel = { label in throw GrantivaError.elementNotFound(label) }
        let result = try await UITools.tap(driver: driver, arguments: ["label": .string("No Such Label QA")])
        assertToolError(result, contains: "Element not found: \"No Such Label QA\". Run grantiva hierarchy")
    }

    func testEmulatorEnsureAndDeleteMissingNameReturnToolErrors() async throws {
        let deps = EmulatorToolDependencies(
            listAVDs: { [] }, listDevices: { [] }, avdName: { _ in "" },
            boot: { _ in BootedDevice(udid: "", name: "") },
            ensure: { _, _, _ in XCTFail("must not run"); return EmulatorProvisionResult(name: "", serial: nil, created: false, state: "") },
            delete: { _, _ in XCTFail("must not run") }
        )
        let ensure = try await EmulatorTools.ensure(deps: deps, arguments: [:])
        XCTAssertEqual(ensure.isError, true)
        let delete = try await EmulatorTools.delete(deps: deps, arguments: ["name": .int(3)])
        XCTAssertEqual(delete.isError, true)
    }

    // MARK: - K53: every tool failure is an isError result, from one place

    private func throwingEmulators(_ error: Error) -> EmulatorToolDependencies {
        EmulatorToolDependencies(
            listAVDs: { throw error },
            listDevices: { throw error },
            avdName: { _ in throw error },
            boot: { _ in throw error },
            ensure: { _, _, _ in throw error },
            delete: { _, _ in throw error }
        )
    }

    private func failingRegistry(platform: Platform, device: MCPFakeDevicePlatform, emulators: EmulatorToolDependencies?) -> ToolRegistry {
        ToolRegistry(
            connection: RunnerConnection(
                resolveSession: { throw GrantivaError.invalidArgument("No active runner session.") },
                attach: { _ in throw GrantivaError.invalidArgument("unreachable") }
            ),
            platform: platform, device: device,
            config: GrantivaConfig(scheme: "Demo", bundleId: "com.example.app"),
            simulatorManager: .live, buildRunner: XcodeBuildRunner(), emulators: emulators,
            projectDirectory: FileManager.default.temporaryDirectory
        )
    }

    func testEveryNonSessionToolFailureIsAnIsErrorResult() async throws {
        let device = MCPFakeDevicePlatform(platform: .ios)
        device.bootFailure = GrantivaError.invalidArgument(#"Simulator not found: "no-such-sim""#)
        let registry = failingRegistry(
            platform: .ios, device: device,
            emulators: throwingEmulators(GrantivaError.invalidArgument(#"No attached device has the serial "no-such-avd"."#))
        )
        let missing = "grantiva-k53-no-such-\(UUID().uuidString)"
        let calls: [(String, [String: Value])] = [
            ("grantiva_build", ["simulator": .string("no-such-sim")]),
            ("grantiva_run", ["simulator": .string("no-such-sim")]),
            ("grantiva_sim_boot", ["name": .string(missing)]),
            ("grantiva_sim_delete", ["name": .string(missing)]),
            ("grantiva_emulator_boot", ["name": .string("no-such-avd")]),
            ("grantiva_emulator_delete", ["name": .string("no-such-avd")]),
            ("grantiva_emulator_ensure", ["name": .string("no-such-avd")]),
            ("grantiva_emulator_list", [:]),
        ]
        for (name, arguments) in calls {
            let result = try await registry.call(name: name, arguments: arguments, server: MCPTestSupport.disconnectedServer())
            XCTAssertEqual(result.isError, true, name)
            let text = try textContent(of: result)
            XCTAssertTrue(text.hasPrefix("Error: "), "\(name): \(text)")
            XCTAssertEqual(text.components(separatedBy: "Error:").count - 1, 1, "\(name): \(text)")
        }
    }

    func testTheEmulatorDeleteRefusalNamesTheToolsForceArgument() async throws {
        let refusal = GrantivaError.invalidArgument(
            #"AVD "fix-k53-hand" was not created by Grantiva (grantiva emulator ensure). Pass --force to delete it anyway."#
        )
        let registry = failingRegistry(platform: .android, device: MCPFakeDevicePlatform(platform: .android), emulators: throwingEmulators(refusal))
        let result = try await registry.call(
            name: "grantiva_emulator_delete", arguments: ["name": .string("fix-k53-hand")], server: MCPTestSupport.disconnectedServer()
        )
        XCTAssertEqual(result.isError, true)
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("Pass force: true to delete it anyway."), text)
        XCTAssertFalse(text.contains("--force"), text)
    }

    func testCancellationStillPropagatesAsCancellation() async throws {
        let registry = failingRegistry(platform: .android, device: MCPFakeDevicePlatform(platform: .android), emulators: throwingEmulators(CancellationError()))
        do {
            _ = try await registry.call(name: "grantiva_emulator_list", arguments: [:], server: MCPTestSupport.disconnectedServer())
            XCTFail("expected CancellationError")
        } catch is CancellationError {
        }
    }

    // MARK: - K100: resources/read without a session

    func testResourceReadWithoutASessionIsNotAnInternalError() async throws {
        let registry = failingRegistry(platform: .ios, device: MCPFakeDevicePlatform(platform: .ios), emulators: nil)
        for uri in ["grantiva://hierarchy", "grantiva://screenshot"] {
            do {
                _ = try await registry.readResource(uri: uri)
                XCTFail("expected an error for \(uri)")
            } catch let error as MCPError {
                XCTAssertEqual(error.code, ToolRegistry.noSessionResourceErrorCode, uri)
                XCTAssertNotEqual(error.code, -32603, uri)
                // What the client reads: the response as the transport sends it.
                let encodedError = try JSONSerialization.jsonObject(with: JSONEncoder().encode(error))
                let response = try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": 9, "error": encodedError])
                let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONRPCScreen.outgoing(response)) as? [String: Any])
                let message = try XCTUnwrap((sent["error"] as? [String: Any])?["message"] as? String)
                XCTAssertTrue(message.hasPrefix("No active runner session"), message)
                XCTAssertFalse(message.contains("Internal error"), message)
                XCTAssertFalse(message.contains("Invalid argument"), message)
            }
        }
    }

    func testResourceReadWhileTheSessionIsStartingSaysRetry() async throws {
        var driver = MCPTestSupport.fakeDriver(recorder: WDARecorder())
        driver.hierarchy = { throw GrantivaError.unavailable(DriverClient.sessionStartingMessage(port: 8100)) }
        let registry = MCPTestSupport.registry(driver: driver)
        do {
            _ = try await registry.readResource(uri: "grantiva://hierarchy")
            XCTFail("expected an error")
        } catch let error as MCPError {
            XCTAssertEqual(error.code, ToolRegistry.noSessionResourceErrorCode)
            XCTAssertTrue((error.errorDescription ?? "").contains("Retry in a few seconds"), error.errorDescription ?? "")
        }
    }
}
