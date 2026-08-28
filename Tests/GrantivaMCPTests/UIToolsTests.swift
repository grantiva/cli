import Foundation
import GrantivaCore
import MCP
import XCTest

@testable import GrantivaMCP

/// Handler-level tests for the UI tools. The WDA client is injected as a fake, so
/// nothing here boots a simulator or opens a socket.
final class UIToolsTests: XCTestCase {

    // MARK: - tap

    func testTapByLabelForwardsTheLabelAndReturnsTheUpdatedHierarchy() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.tap(
            wda: MCPTestSupport.fakeWDA(recorder: recorder, hierarchyJSON: #"{"type":"Root"}"#),
            arguments: ["label": .string("Sign In")]
        )
        XCTAssertNil(result.isError)
        XCTAssertEqual(recorder.calls, ["tapByLabel(Sign In)", "hierarchy"])
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains(#"Tapped on "Sign In""#), text)
        XCTAssertTrue(text.contains(#""type" : "Root""#), text)
    }

    func testTapByCoordinatesForwardsBothAxes() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.tap(
            wda: MCPTestSupport.fakeWDA(recorder: recorder),
            arguments: ["x": .double(120), "y": .double(240)]
        )
        XCTAssertNil(result.isError)
        XCTAssertEqual(recorder.calls.first, "tapByCoordinate(120.0,240.0)")
        XCTAssertTrue(try textContent(of: result).contains("Tapped at (120, 240)"))
    }

    func testTapAcceptsIntegerCoordinates() async throws {
        // JSON integer literals decode to `.int`, which is what an agent sending
        // {"x": 120, "y": 240} produces. This must not be rejected.
        let recorder = WDARecorder()
        let result = try await UITools.tap(
            wda: MCPTestSupport.fakeWDA(recorder: recorder),
            arguments: ["x": .int(120), "y": .int(240)]
        )
        let text = try textContent(of: result)
        XCTAssertNil(result.isError, text)
        XCTAssertEqual(recorder.calls.first, "tapByCoordinate(120.0,240.0)")
    }

    func testTapWithNoArgumentsReturnsAnErrorResultInsteadOfThrowing() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.tap(wda: MCPTestSupport.fakeWDA(recorder: recorder), arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("provide either 'label' or both 'x' and 'y'"))
        XCTAssertTrue(recorder.calls.isEmpty, "A rejected tap must not touch WDA")
    }

    func testTapWithOnlyOneCoordinateIsRejected() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.tap(wda: MCPTestSupport.fakeWDA(recorder: recorder), arguments: ["x": .double(10)])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(recorder.calls.isEmpty)
    }

    func testTapPrefersLabelOverCoordinatesWhenBothAreProvided() async throws {
        let recorder = WDARecorder()
        _ = try await UITools.tap(
            wda: MCPTestSupport.fakeWDA(recorder: recorder),
            arguments: ["label": .string("OK"), "x": .double(1), "y": .double(2)]
        )
        XCTAssertEqual(recorder.calls.first, "tapByLabel(OK)")
    }

    func testTapRejectsAWrongTypedLabel() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.tap(wda: MCPTestSupport.fakeWDA(recorder: recorder), arguments: ["label": .int(7)])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(recorder.calls.isEmpty)
    }

    // MARK: - swipe

    func testSwipeForwardsTheDirection() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.swipe(
            wda: MCPTestSupport.fakeWDA(recorder: recorder),
            arguments: ["direction": .string("left")]
        )
        XCTAssertNil(result.isError)
        XCTAssertEqual(recorder.calls, ["swipe(left)", "hierarchy"])
        XCTAssertTrue(try textContent(of: result).hasPrefix("Swiped left."))
    }

    func testSwipeWithoutDirectionIsRejectedBeforeReachingWDA() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.swipe(wda: MCPTestSupport.fakeWDA(recorder: recorder), arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("'direction' is required"))
        XCTAssertTrue(recorder.calls.isEmpty)
    }

    func testSwipeWithANonStringDirectionIsRejected() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.swipe(wda: MCPTestSupport.fakeWDA(recorder: recorder), arguments: ["direction": .bool(true)])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(recorder.calls.isEmpty)
    }

    // MARK: - type

    func testTypeForwardsTheTextVerbatim() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.type(
            wda: MCPTestSupport.fakeWDA(recorder: recorder),
            arguments: ["text": .string("hello world")]
        )
        XCTAssertNil(result.isError)
        XCTAssertEqual(recorder.calls, ["typeText(hello world)", "hierarchy"])
        XCTAssertTrue(try textContent(of: result).contains(#"Typed "hello world""#))
    }

    func testTypeAcceptsAnEmptyString() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.type(wda: MCPTestSupport.fakeWDA(recorder: recorder), arguments: ["text": .string("")])
        XCTAssertNil(result.isError)
        XCTAssertEqual(recorder.calls.first, "typeText()")
    }

    func testTypeWithoutTextIsRejectedBeforeReachingWDA() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.type(wda: MCPTestSupport.fakeWDA(recorder: recorder), arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("'text' is required"))
        XCTAssertTrue(recorder.calls.isEmpty)
    }

    // MARK: - a11y_tree

    func testA11yTreeReturnsPrettyPrintedSortedJSON() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.a11yTree(
            wda: MCPTestSupport.fakeWDA(recorder: recorder, hierarchyJSON: #"{"z":1,"a":2}"#)
        )
        let text = try textContent(of: result)
        XCTAssertNil(result.isError)
        // Keys are sorted, so "a" precedes "z".
        XCTAssertLessThan(try XCTUnwrap(text.range(of: #""a""#)).lowerBound, try XCTUnwrap(text.range(of: #""z""#)).lowerBound)
        XCTAssertTrue(text.contains("\n"), "Expected pretty-printed JSON")
    }

    // MARK: - a11y_check

    private static let violationHierarchy = """
        {
          "type": "XCUIElementTypeApplication",
          "children": [
            {"type": "XCUIElementTypeButton", "label": "", "name": "", "enabled": true,
             "frame": {"width": "100", "height": "50"}},
            {"type": "XCUIElementTypeButton", "label": "Close", "enabled": true,
             "frame": {"width": "20", "height": "20"}},
            {"type": "XCUIElementTypeStaticText", "label": "", "enabled": true,
             "frame": {"width": "10", "height": "10"}},
            {"type": "XCUIElementTypeOther", "children": [
               {"type": "XCUIElementTypeSwitch", "label": "Wi-Fi", "enabled": true,
                "frame": {"width": "60", "height": "60"}}
            ]}
          ]
        }
        """

    func testA11yCheckFlagsMissingLabelsAndSmallTapTargets() async throws {
        let result = try await UITools.a11yCheck(
            wda: MCPTestSupport.fakeWDA(recorder: WDARecorder(), hierarchyJSON: Self.violationHierarchy),
            config: nil
        )
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("Found 2 accessibility violation(s)"), text)
        XCTAssertTrue(text.contains("missing_label"), text)
        XCTAssertTrue(text.contains("small_tap_target"), text)
        XCTAssertTrue(text.contains("20x20"), text)
        // Non-interactive types and compliant elements are not reported.
        XCTAssertFalse(text.contains("XCUIElementTypeStaticText"), text)
        XCTAssertFalse(text.contains("Wi-Fi"), text)
    }

    func testA11yCheckRecursesIntoNestedChildren() async throws {
        let nested = """
            {"type": "XCUIElementTypeOther", "children": [
              {"type": "XCUIElementTypeOther", "children": [
                {"type": "XCUIElementTypeButton", "label": "", "name": "", "enabled": true}
              ]}
            ]}
            """
        let result = try await UITools.a11yCheck(
            wda: MCPTestSupport.fakeWDA(recorder: WDARecorder(), hierarchyJSON: nested),
            config: nil
        )
        XCTAssertTrue(try textContent(of: result).contains("Found 1 accessibility violation(s)"))
    }

    func testA11yCheckHonoursTheConfiguredRuleSubset() async throws {
        let config = GrantivaConfig(a11y: .init(rules: ["missing_label"]))
        let result = try await UITools.a11yCheck(
            wda: MCPTestSupport.fakeWDA(recorder: WDARecorder(), hierarchyJSON: Self.violationHierarchy),
            config: config
        )
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("Found 1 accessibility violation(s)"), text)
        XCTAssertFalse(text.contains("small_tap_target"), text)
    }

    func testA11yCheckWithNoRulesEnabledReportsNothing() async throws {
        let config = GrantivaConfig(a11y: .init(rules: []))
        let result = try await UITools.a11yCheck(
            wda: MCPTestSupport.fakeWDA(recorder: WDARecorder(), hierarchyJSON: Self.violationHierarchy),
            config: config
        )
        XCTAssertEqual(try textContent(of: result), "No accessibility violations found.")
    }

    func testA11yCheckIgnoresDisabledElements() async throws {
        let hierarchy = #"{"type":"XCUIElementTypeButton","label":"","name":"","enabled":false}"#
        let result = try await UITools.a11yCheck(
            wda: MCPTestSupport.fakeWDA(recorder: WDARecorder(), hierarchyJSON: hierarchy),
            config: nil
        )
        XCTAssertEqual(try textContent(of: result), "No accessibility violations found.")
    }

    func testA11yCheckAcceptsANameInPlaceOfALabel() async throws {
        let hierarchy = #"{"type":"XCUIElementTypeButton","label":"","name":"submit","enabled":true}"#
        let result = try await UITools.a11yCheck(
            wda: MCPTestSupport.fakeWDA(recorder: WDARecorder(), hierarchyJSON: hierarchy),
            config: nil
        )
        XCTAssertEqual(try textContent(of: result), "No accessibility violations found.")
    }

    // MARK: - screenshot

    func testScreenshotReturnsBase64PNGImageContentByDefault() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.screenshot(
            wda: MCPTestSupport.fakeWDA(recorder: recorder, screenshotBytes: [0x89, 0x50, 0x4E, 0x47]),
            session: MCPTestSupport.sessionWithoutUDID(),
            arguments: [:]
        )
        let image = try imageContent(of: result)
        XCTAssertEqual(image.mimeType, "image/png")
        XCTAssertEqual(Data(base64Encoded: image.data), Data([0x89, 0x50, 0x4E, 0x47]))
        XCTAssertEqual(recorder.calls, ["screenshot"])
    }

    func testScreenshotTreatsAnUnknownFormatAsBase64() async throws {
        let result = try await UITools.screenshot(
            wda: MCPTestSupport.fakeWDA(recorder: WDARecorder()),
            session: MCPTestSupport.sessionWithoutUDID(),
            arguments: ["format": .string("bogus")]
        )
        XCTAssertNoThrow(try imageContent(of: result))
    }
}
