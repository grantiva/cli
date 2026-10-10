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
}
