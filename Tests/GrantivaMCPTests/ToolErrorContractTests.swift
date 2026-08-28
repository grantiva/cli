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

    func testSimEnsureMissingRuntimeReturnsToolError() async throws {
        let result = try await SimTools.ensure(
            simManager: simManager,
            arguments: ["name": .string("APP-302 iPhone"), "device_type": .string("iPhone 16")]
        )
        assertToolError(result, contains: "runtime")
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
        let wda = WDAClient.live(port: 8100)
        assertToolError(try await UITools.tap(wda: wda, arguments: [:]), contains: "Error:")
        assertToolError(try await UITools.swipe(wda: wda, arguments: [:]), contains: "'direction' is required")
        assertToolError(try await UITools.type(wda: wda, arguments: [:]), contains: "'text' is required")
        assertToolError(try await ScriptTools.script(wda: wda, arguments: [:]), contains: "'steps' array is required")
    }
}
