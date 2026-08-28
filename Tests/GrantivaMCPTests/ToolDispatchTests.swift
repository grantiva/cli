import Foundation
import GrantivaCore
import MCP
import XCTest

@testable import GrantivaMCP

/// `ToolRegistry.call` is the switchboard between a tools/call request and a handler.
/// A miswired case sends an agent's request to the wrong tool, so the routing for every
/// side-effect-free path is asserted here.
final class ToolDispatchTests: XCTestCase {

    private func call(
        _ name: String,
        _ arguments: [String: Value] = [:],
        recorder: WDARecorder = WDARecorder(),
        hierarchyJSON: String = MCPTestSupport.emptyHierarchyJSON
    ) async throws -> CallTool.Result {
        let registry = MCPTestSupport.registry(
            wda: MCPTestSupport.fakeWDA(recorder: recorder, hierarchyJSON: hierarchyJSON)
        )
        return try await registry.call(
            name: name, arguments: arguments, server: MCPTestSupport.disconnectedServer()
        )
    }

    // MARK: - Unknown tools

    func testAnUnknownToolNameReturnsAnErrorResultRatherThanThrowing() async throws {
        let result = try await call("grantiva_teleport")
        XCTAssertEqual(result.isError, true)
        XCTAssertEqual(try textContent(of: result), "Unknown tool: grantiva_teleport")
    }

    func testToolNameDispatchIsCaseSensitive() async throws {
        let result = try await call("GRANTIVA_TAP", ["label": .string("A")])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).hasPrefix("Unknown tool:"))
    }

    func testAnEmptyToolNameIsRejected() async throws {
        let result = try await call("")
        XCTAssertEqual(result.isError, true)
    }

    // MARK: - Routing

    func testTapRoutesToTheTapHandler() async throws {
        let recorder = WDARecorder()
        _ = try await call("grantiva_tap", ["label": .string("Continue")], recorder: recorder)
        XCTAssertEqual(recorder.calls.first, "tapByLabel(Continue)")
    }

    func testSwipeRoutesToTheSwipeHandler() async throws {
        let recorder = WDARecorder()
        _ = try await call("grantiva_swipe", ["direction": .string("right")], recorder: recorder)
        XCTAssertEqual(recorder.calls.first, "swipe(right)")
    }

    func testTypeRoutesToTheTypeHandler() async throws {
        let recorder = WDARecorder()
        _ = try await call("grantiva_type", ["text": .string("abc")], recorder: recorder)
        XCTAssertEqual(recorder.calls.first, "typeText(abc)")
    }

    func testScriptRoutesToTheScriptHandler() async throws {
        let recorder = WDARecorder()
        _ = try await call(
            "grantiva_script",
            ["steps": .array([.object(["swipe": .string("down")])])],
            recorder: recorder
        )
        XCTAssertEqual(recorder.calls.first, "swipe(down)")
    }

    func testA11yTreeRoutesToTheHierarchyFetch() async throws {
        let recorder = WDARecorder()
        let result = try await call("grantiva_a11y_tree", recorder: recorder, hierarchyJSON: #"{"marker":"tree"}"#)
        XCTAssertEqual(recorder.calls, ["hierarchy"])
        XCTAssertTrue(try textContent(of: result).contains("tree"))
    }

    func testA11yCheckRoutesToTheAuditHandler() async throws {
        let result = try await call(
            "grantiva_a11y_check",
            hierarchyJSON: #"{"type":"XCUIElementTypeButton","label":"","name":"","enabled":true}"#
        )
        XCTAssertTrue(try textContent(of: result).contains("missing_label"))
    }

    func testScreenshotRoutesToTheScreenshotHandler() async throws {
        let recorder = WDARecorder()
        let result = try await call("grantiva_screenshot", recorder: recorder)
        XCTAssertEqual(recorder.calls, ["screenshot"])
        XCTAssertEqual(try imageContent(of: result).mimeType, "image/png")
    }

    // MARK: - Errors surface through dispatch

    func testValidationErrorsAreReturnedThroughDispatchWithIsErrorSet() async throws {
        for (name, arguments) in [
            ("grantiva_tap", [:]),
            ("grantiva_swipe", [:]),
            ("grantiva_type", [:]),
            ("grantiva_script", [:]),
            ("grantiva_build", [:]),
        ] as [(String, [String: Value])] {
            let result = try await call(name, arguments)
            XCTAssertEqual(result.isError, true, "\(name) should report a tool error for empty arguments")
        }
    }

    func testAFailingUIMutationStillReturnsRatherThanHangingOnNotification() async throws {
        // The registry notifies resource subscribers after UI-mutating tools. With no
        // transport connected that notification fails; it must not surface to the caller.
        let result = try await call("grantiva_swipe", ["direction": .string("up")])
        XCTAssertNil(result.isError)
    }

    func testSimDeleteValidationErrorPropagatesAsAThrownError() async throws {
        // Unlike the UI tools, the sim tools throw rather than returning isError.
        do {
            _ = try await call("grantiva_sim_delete")
            XCTFail("Expected grantiva_sim_delete to throw without a name")
        } catch let error as GrantivaError {
            guard case .invalidArgument = error else {
                return XCTFail("Expected invalidArgument, got \(error)")
            }
        }
    }

    // MARK: - Resources

    func testHierarchyResourceReturnsSortedPrettyJSON() async throws {
        let registry = MCPTestSupport.registry(
            wda: MCPTestSupport.fakeWDA(recorder: WDARecorder(), hierarchyJSON: #"{"z":1,"a":2}"#)
        )
        let contents = try await registry.readResource(uri: "grantiva://hierarchy")
        let content = try XCTUnwrap(contents.first)
        let text = try XCTUnwrap(content.text, "Expected text content, got \(content)")
        XCTAssertNil(content.blob)
        XCTAssertEqual(content.uri, "grantiva://hierarchy")
        XCTAssertEqual(content.mimeType, "application/json")
        XCTAssertLessThan(
            try XCTUnwrap(text.range(of: #""a""#)).lowerBound,
            try XCTUnwrap(text.range(of: #""z""#)).lowerBound
        )
    }

    func testScreenshotResourceReturnsBinaryPNG() async throws {
        let registry = MCPTestSupport.registry(
            wda: MCPTestSupport.fakeWDA(recorder: WDARecorder(), screenshotBytes: [1, 2, 3])
        )
        let contents = try await registry.readResource(uri: "grantiva://screenshot")
        let content = try XCTUnwrap(contents.first)
        let blob = try XCTUnwrap(content.blob, "Expected binary content, got \(content)")
        XCTAssertNil(content.text)
        XCTAssertEqual(content.uri, "grantiva://screenshot")
        XCTAssertEqual(content.mimeType, "image/png")
        XCTAssertEqual(Data(base64Encoded: blob), Data([1, 2, 3]))
    }

    func testUnknownResourceURIThrowsAnInvalidRequest() async throws {
        let registry = MCPTestSupport.registry(wda: MCPTestSupport.fakeWDA(recorder: WDARecorder()))
        do {
            _ = try await registry.readResource(uri: "grantiva://nope")
            XCTFail("Expected an unknown URI to throw")
        } catch let error as MCPError {
            XCTAssertTrue(String(describing: error).contains("Unknown resource URI"), String(describing: error))
        }
    }

    func testEveryAdvertisedResourceURIIsReadable() async throws {
        let registry = MCPTestSupport.registry(wda: MCPTestSupport.fakeWDA(recorder: WDARecorder()))
        for resource in registry.allResources() {
            let contents = try await registry.readResource(uri: resource.uri)
            XCTAssertFalse(contents.isEmpty, "\(resource.uri) returned no content")
        }
    }
}
