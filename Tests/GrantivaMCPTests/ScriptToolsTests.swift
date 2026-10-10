import Foundation
import GrantivaCore
import MCP
import XCTest

@testable import GrantivaMCP

/// `grantiva_script` is the batch action interpreter. Its step decoding is pure logic
/// over the argument payload, so it is fully testable against a fake WDA client.
final class ScriptToolsTests: XCTestCase {

    func testStepsAreExecutedInOrderAcrossEveryActionKind() async throws {
        let recorder = WDARecorder()
        let result = try await ScriptTools.script(
            driver: MCPTestSupport.fakeDriver(recorder: recorder),
            arguments: [
                "steps": .array([
                    .object(["tap": .string("Login")]),
                    .object(["tap_xy": .object(["x": .double(10), "y": .double(20)])]),
                    .object(["swipe": .string("up")]),
                    .object(["type": .string("hunter2")]),
                    .object(["wait": .double(0.01)]),
                ])
            ]
        )
        XCTAssertNil(result.isError)
        XCTAssertEqual(
            recorder.calls,
            [
                "tapByLabel(Login)",
                "tapByCoordinate(10.0,20.0)",
                "swipe(up)",
                "typeText(hunter2)",
                "hierarchy",
            ]
        )
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains(#"Step 1: tapped "Login""#), text)
        XCTAssertTrue(text.contains("Step 2: tapped at (10, 20)"), text)
        XCTAssertTrue(text.contains("Step 3: swiped up"), text)
        XCTAssertTrue(text.contains(#"Step 4: typed "hunter2""#), text)
        XCTAssertTrue(text.contains("Step 5: waited 0.01s"), text)
        XCTAssertTrue(text.contains("Final hierarchy:"), text)
    }

    func testMissingStepsArrayIsReportedAsAToolErrorWithoutTouchingWDA() async throws {
        let recorder = WDARecorder()
        let result = try await ScriptTools.script(driver: MCPTestSupport.fakeDriver(recorder: recorder), arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("'steps' array is required"))
        XCTAssertTrue(recorder.calls.isEmpty)
    }

    func testStepsOfTheWrongTypeAreRejected() async throws {
        let recorder = WDARecorder()
        let result = try await ScriptTools.script(
            driver: MCPTestSupport.fakeDriver(recorder: recorder),
            arguments: ["steps": .string("tap Login")]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(recorder.calls.isEmpty)
    }

    func testAnEmptyStepListStillReturnsTheHierarchy() async throws {
        let recorder = WDARecorder()
        let result = try await ScriptTools.script(
            driver: MCPTestSupport.fakeDriver(recorder: recorder),
            arguments: ["steps": .array([])]
        )
        XCTAssertNil(result.isError)
        XCTAssertEqual(recorder.calls, ["hierarchy"])
        XCTAssertTrue(try textContent(of: result).contains("Final hierarchy:"))
    }

    /// C17: invalid steps are rejected before any step runs, as an error result.
    func testInvalidStepsAreRejectedAsAToolErrorBeforeAnyStepRuns() async throws {
        let recorder = WDARecorder()
        let result = try await ScriptTools.script(
            driver: MCPTestSupport.fakeDriver(recorder: recorder),
            arguments: ["steps": .array([.object(["bogus": .int(1)]), .int(5)])]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(recorder.calls.isEmpty, "No step may run, and no hierarchy is fetched: \(recorder.calls)")
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("Step 1: unknown action 'bogus'"), text)
        XCTAssertTrue(text.contains("Step 2: not an object"), text)
    }

    func testOneInvalidStepStopsTheValidOnesFromRunning() async throws {
        let recorder = WDARecorder()
        let result = try await ScriptTools.script(
            driver: MCPTestSupport.fakeDriver(recorder: recorder),
            arguments: ["steps": .array([.object(["swipe": .string("down")]), .string("tap")])]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(recorder.calls.isEmpty, "\(recorder.calls)")
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("Step 2: not an object"), text)
        XCTAssertFalse(text.contains("Step 1:"), text)
    }

    func testUnknownActionKeysAreRejected() async throws {
        let recorder = WDARecorder()
        let result = try await ScriptTools.script(
            driver: MCPTestSupport.fakeDriver(recorder: recorder),
            arguments: ["steps": .array([.object(["frobnicate": .string("x")])])]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(recorder.calls.isEmpty)
        XCTAssertTrue(try textContent(of: result).contains("Step 1: unknown action 'frobnicate'"))
    }

    func testTapXYMissingAnAxisIsRejectedRatherThanTappingWithGarbage() async throws {
        let recorder = WDARecorder()
        let result = try await ScriptTools.script(
            driver: MCPTestSupport.fakeDriver(recorder: recorder),
            arguments: ["steps": .array([.object(["tap_xy": .object(["x": .double(10)])])])]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(recorder.calls.isEmpty, "A half-specified tap_xy must not be sent to WDA")
        XCTAssertTrue(try textContent(of: result).contains("Step 1: tap_xy needs numeric x and y"))
    }

    func testNegativeWaitIsRejected() async throws {
        let recorder = WDARecorder()
        let result = try await ScriptTools.script(
            driver: MCPTestSupport.fakeDriver(recorder: recorder),
            arguments: ["steps": .array([.object(["wait": .double(-1)])])]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(recorder.calls.isEmpty)
    }

    func testTapXYAcceptsIntegerCoordinates() async throws {
        let recorder = WDARecorder()
        _ = try await ScriptTools.script(
            driver: MCPTestSupport.fakeDriver(recorder: recorder),
            arguments: ["steps": .array([.object(["tap_xy": .object(["x": .int(5), "y": .int(6)])])])]
        )
        XCTAssertEqual(recorder.calls.first, "tapByCoordinate(5.0,6.0)")
    }

    func testAStepWithSeveralActionsIsRejected() async throws {
        let recorder = WDARecorder()
        let result = try await ScriptTools.script(
            driver: MCPTestSupport.fakeDriver(recorder: recorder),
            arguments: ["steps": .array([.object(["tap": .string("A"), "swipe": .string("up"), "type": .string("B")])])]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(recorder.calls.isEmpty)
        XCTAssertTrue(try textContent(of: result).contains("Step 1: more than one action (tap, swipe, type)"))
    }

    func testANonStringTapIsRejectedByName() async throws {
        let recorder = WDARecorder()
        let result = try await ScriptTools.script(
            driver: MCPTestSupport.fakeDriver(recorder: recorder),
            arguments: ["steps": .array([.object(["tap": .int(5)])])]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(recorder.calls.isEmpty)
        XCTAssertTrue(try textContent(of: result).contains("Step 1: 'tap' must be a string"))
    }
}
