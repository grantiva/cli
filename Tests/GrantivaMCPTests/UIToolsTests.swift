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
            driver: MCPTestSupport.fakeDriver(recorder: recorder, hierarchyJSON: #"{"type":"Root"}"#),
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
            driver: MCPTestSupport.fakeDriver(recorder: recorder),
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
            driver: MCPTestSupport.fakeDriver(recorder: recorder),
            arguments: ["x": .int(120), "y": .int(240)]
        )
        let text = try textContent(of: result)
        XCTAssertNil(result.isError, text)
        XCTAssertEqual(recorder.calls.first, "tapByCoordinate(120.0,240.0)")
    }

    func testTapWithNoArgumentsReturnsAnErrorResultInsteadOfThrowing() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.tap(driver: MCPTestSupport.fakeDriver(recorder: recorder), arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("provide either 'label' or both 'x' and 'y'"))
        XCTAssertTrue(recorder.calls.isEmpty, "A rejected tap must not touch WDA")
    }

    func testTapWithOnlyOneCoordinateIsRejected() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.tap(driver: MCPTestSupport.fakeDriver(recorder: recorder), arguments: ["x": .double(10)])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(recorder.calls.isEmpty)
    }

    func testTapPrefersLabelOverCoordinatesWhenBothAreProvided() async throws {
        let recorder = WDARecorder()
        _ = try await UITools.tap(
            driver: MCPTestSupport.fakeDriver(recorder: recorder),
            arguments: ["label": .string("OK"), "x": .double(1), "y": .double(2)]
        )
        XCTAssertEqual(recorder.calls.first, "tapByLabel(OK)")
    }

    func testTapRejectsAWrongTypedLabel() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.tap(driver: MCPTestSupport.fakeDriver(recorder: recorder), arguments: ["label": .int(7)])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(recorder.calls.isEmpty)
    }

    // MARK: - swipe

    func testSwipeForwardsTheDirection() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.swipe(
            driver: MCPTestSupport.fakeDriver(recorder: recorder),
            arguments: ["direction": .string("left")]
        )
        XCTAssertNil(result.isError)
        XCTAssertEqual(recorder.calls, ["swipe(left)", "hierarchy"])
        XCTAssertTrue(try textContent(of: result).hasPrefix("Swiped left."))
    }

    func testSwipeWithoutDirectionIsRejectedBeforeReachingWDA() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.swipe(driver: MCPTestSupport.fakeDriver(recorder: recorder), arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("'direction' is required"))
        XCTAssertTrue(recorder.calls.isEmpty)
    }

    func testSwipeWithANonStringDirectionIsRejected() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.swipe(driver: MCPTestSupport.fakeDriver(recorder: recorder), arguments: ["direction": .bool(true)])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(recorder.calls.isEmpty)
    }

    // MARK: - type

    func testTypeForwardsTheTextVerbatim() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.type(
            driver: MCPTestSupport.fakeDriver(recorder: recorder),
            arguments: ["text": .string("hello world")]
        )
        XCTAssertNil(result.isError)
        XCTAssertEqual(recorder.calls, ["typeText(hello world)", "hierarchy"])
        XCTAssertTrue(try textContent(of: result).contains(#"Typed "hello world""#))
    }

    func testTypeAcceptsAnEmptyString() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.type(driver: MCPTestSupport.fakeDriver(recorder: recorder), arguments: ["text": .string("")])
        XCTAssertNil(result.isError)
        XCTAssertEqual(recorder.calls.first, "typeText()")
    }

    func testTypeWithoutTextIsRejectedBeforeReachingWDA() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.type(driver: MCPTestSupport.fakeDriver(recorder: recorder), arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("'text' is required"))
        XCTAssertTrue(recorder.calls.isEmpty)
    }

    // MARK: - a11y_tree

    func testA11yTreeReturnsPrettyPrintedSortedJSON() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.a11yTree(
            driver: MCPTestSupport.fakeDriver(recorder: recorder, hierarchyJSON: #"{"z":1,"a":2}"#)
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
            driver: MCPTestSupport.fakeDriver(recorder: WDARecorder(), hierarchyJSON: Self.violationHierarchy),
            config: nil,
            platform: .ios
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
            driver: MCPTestSupport.fakeDriver(recorder: WDARecorder(), hierarchyJSON: nested),
            config: nil,
            platform: .ios
        )
        XCTAssertTrue(try textContent(of: result).contains("Found 1 accessibility violation(s)"))
    }

    func testA11yCheckHonoursTheConfiguredRuleSubset() async throws {
        let config = GrantivaConfig(a11y: .init(rules: ["missing_label"]))
        let result = try await UITools.a11yCheck(
            driver: MCPTestSupport.fakeDriver(recorder: WDARecorder(), hierarchyJSON: Self.violationHierarchy),
            config: config,
            platform: .ios
        )
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("Found 1 accessibility violation(s)"), text)
        XCTAssertFalse(text.contains("small_tap_target"), text)
    }

    func testA11yCheckWithNoRulesEnabledReportsNothing() async throws {
        let config = GrantivaConfig(a11y: .init(rules: []))
        let result = try await UITools.a11yCheck(
            driver: MCPTestSupport.fakeDriver(recorder: WDARecorder(), hierarchyJSON: Self.violationHierarchy),
            config: config,
            platform: .ios
        )
        XCTAssertEqual(try textContent(of: result), "No accessibility violations found.")
    }

    func testA11yCheckIgnoresDisabledElements() async throws {
        let hierarchy = #"{"type":"XCUIElementTypeButton","label":"","name":"","enabled":false}"#
        let result = try await UITools.a11yCheck(
            driver: MCPTestSupport.fakeDriver(recorder: WDARecorder(), hierarchyJSON: hierarchy),
            config: nil,
            platform: .ios
        )
        XCTAssertEqual(try textContent(of: result), "No accessibility violations found.")
    }

    func testA11yCheckAcceptsANameInPlaceOfALabel() async throws {
        let hierarchy = #"{"type":"XCUIElementTypeButton","label":"","name":"submit","enabled":true}"#
        let result = try await UITools.a11yCheck(
            driver: MCPTestSupport.fakeDriver(recorder: WDARecorder(), hierarchyJSON: hierarchy),
            config: nil,
            platform: .ios
        )
        XCTAssertEqual(try textContent(of: result), "No accessibility violations found.")
    }

    // MARK: - screenshot

    func testScreenshotReturnsBase64PNGImageContentByDefault() async throws {
        let recorder = WDARecorder()
        let result = try await UITools.screenshot(
            driver: MCPTestSupport.fakeDriver(recorder: recorder, screenshotBytes: [0x89, 0x50, 0x4E, 0x47]),
            device: MCPFakeDevicePlatform(platform: .ios),
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
            driver: MCPTestSupport.fakeDriver(recorder: WDARecorder()),
            device: MCPFakeDevicePlatform(platform: .ios),
            session: MCPTestSupport.sessionWithoutUDID(),
            arguments: ["format": .string("bogus")]
        )
        XCTAssertNoThrow(try imageContent(of: result))
    }

    func testScreenshotWithADeviceGoesThroughThePlatform() async throws {
        let recorder = WDARecorder()
        let device = MCPFakeDevicePlatform(platform: .android)
        let session = RunnerSessionInfo(pid: 0, wdaPort: 0, bundleId: "", udid: "emulator-5554", startedAt: Date())
        let result = try await UITools.screenshot(driver: MCPTestSupport.fakeDriver(recorder: recorder), device: device, session: session, arguments: [:])
        XCTAssertEqual(device.calls, ["screenshot(emulator-5554)"])
        XCTAssertTrue(recorder.calls.isEmpty, "the driver is not asked when a device is known")
        XCTAssertEqual(try imageContent(of: result).mimeType, "image/png")
    }

    func testA11yCheckFlagsAClickableAndroidNodeWithoutALabel() async throws {
        let tree = #"{"type":"hierarchy","platform":"android","children":[{"type":"android.view.View","clickable":true,"enabled":true,"frame":{"x":"0","y":"0","width":"100","height":"100"},"children":[]}]}"#
        let result = try await UITools.a11yCheck(driver: MCPTestSupport.fakeDriver(recorder: WDARecorder(), hierarchyJSON: tree), config: nil, platform: .android)
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("missing_label"), text)
        XCTAssertFalse(text.contains("small_tap_target"), text)
    }

    /// Compose and View layouts put the text of a clickable row in a child.
    func testA11yCheckDoesNotFlagAClickableContainerWhoseChildCarriesTheText() async throws {
        let tree = #"{"type":"hierarchy","platform":"android","children":[{"type":"android.view.View","clickable":true,"enabled":true,"frame":{"x":"0","y":"0","width":"100","height":"100"},"children":[{"type":"android.widget.TextView","label":"Details","enabled":true,"frame":{"x":"0","y":"0","width":"100","height":"100"},"children":[]}]}]}"#
        let result = try await UITools.a11yCheck(driver: MCPTestSupport.fakeDriver(recorder: WDARecorder(), hierarchyJSON: tree), config: nil, platform: .android)
        let text = try textContent(of: result)
        XCTAssertFalse(text.contains("missing_label"), text)
    }

    /// Known widget classes keep the strict own-label rule.
    func testA11yCheckStillFlagsAnUnlabelledAndroidWidgetWhoseChildCarriesText() async throws {
        let tree = #"{"type":"hierarchy","platform":"android","children":[{"type":"android.widget.Button","clickable":true,"enabled":true,"frame":{"x":"0","y":"0","width":"100","height":"100"},"children":[{"type":"android.widget.TextView","label":"Go","enabled":true,"frame":{"x":"0","y":"0","width":"100","height":"100"},"children":[]}]}]}"#
        let result = try await UITools.a11yCheck(driver: MCPTestSupport.fakeDriver(recorder: WDARecorder(), hierarchyJSON: tree), config: nil, platform: .android)
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("missing_label"), text)
    }

    func testA11yCheckUses48dpOnAndroidAnd44ptOnIOS() async throws {
        let android = #"{"type":"hierarchy","children":[{"type":"android.widget.Button","label":"Go","enabled":true,"frame":{"x":"0","y":"0","width":"46","height":"46"},"children":[]}]}"#
        let androidText = try textContent(of: try await UITools.a11yCheck(driver: MCPTestSupport.fakeDriver(recorder: WDARecorder(), hierarchyJSON: android), config: nil, platform: .android))
        XCTAssertTrue(androidText.contains("below the 48x48dp minimum"), androidText)
        let ios = #"{"type":"XCUIElementTypeApplication","children":[{"type":"XCUIElementTypeButton","label":"Go","enabled":true,"frame":{"x":"0","y":"0","width":"46","height":"46"},"children":[]}]}"#
        let iosText = try textContent(of: try await UITools.a11yCheck(driver: MCPTestSupport.fakeDriver(recorder: WDARecorder(), hierarchyJSON: ios), config: nil, platform: .ios))
        XCTAssertEqual(iosText, "No accessibility violations found.")
    }

    // MARK: - a11y_check: Compose merged labels (A11)

    /// Two Deep Links buttons as UIAutomator2 dumps them on a Pixel 8 (scale
    /// 2.625): a clickable `View` holding the text and an empty, non-clickable
    /// `android.widget.Button` stub. From AND-061/hierarchy-immediate.xml.
    private static let composeDeepLinksXML = """
        <hierarchy rotation="0">
          <android.widget.ScrollView class="android.widget.ScrollView" text="" clickable="false" enabled="true" focusable="false" bounds="[0,316][1080,2064]" displayed="true">
            <android.view.View class="android.view.View" text="" clickable="true" enabled="true" focusable="true" bounds="[42,359][1038,485]" displayed="true">
              <android.widget.TextView class="android.widget.TextView" text="Caching Demo" clickable="false" enabled="true" focusable="false" bounds="[421,395][659,448]" displayed="true" />
              <android.widget.Button class="android.widget.Button" text="" clickable="false" enabled="true" focusable="false" bounds="[42,369][1038,474]" displayed="true" />
            </android.view.View>
            <android.view.View class="android.view.View" text="" clickable="true" enabled="true" focusable="true" bounds="[42,506][1038,632]" displayed="true">
              <android.widget.TextView class="android.widget.TextView" text="Edit Landmark" clickable="false" enabled="true" focusable="false" bounds="[423,542][657,595]" displayed="true" />
              <android.widget.Button class="android.widget.Button" text="" clickable="false" enabled="true" focusable="false" bounds="[42,516][1038,621]" displayed="true" />
            </android.view.View>
          </android.widget.ScrollView>
        </hierarchy>
        """

    private func androidCheck(xml: String) async throws -> String {
        let tree = try UIAutomator2HierarchyXMLParser(xml: xml, scale: 2.625).parse()
        let json = String(decoding: try JSONSerialization.data(withJSONObject: tree), as: UTF8.self)
        return try textContent(of: try await UITools.a11yCheck(
            driver: MCPTestSupport.fakeDriver(recorder: WDARecorder(), hierarchyJSON: json), config: nil, platform: .android
        ))
    }

    func testA11yCheckSkipsTheComposeButtonStubInsideALabelledClickableParent() async throws {
        let text = try await androidCheck(xml: Self.composeDeepLinksXML)
        XCTAssertFalse(text.contains("missing_label"), text)
        // The focused node is the 48 dp parent, not the 40 dp stub.
        XCTAssertEqual(text, "No accessibility violations found.")
    }

    func testA11yCheckStillFlagsAClickableImageButtonWithNoLabelAnywhere() async throws {
        let xml = """
            <hierarchy rotation="0">
              <android.widget.ImageButton class="android.widget.ImageButton" text="" content-desc="" clickable="true" enabled="true" bounds="[0,0][300,300]" displayed="true" />
            </hierarchy>
            """
        let text = try await androidCheck(xml: xml)
        XCTAssertEqual(text.components(separatedBy: "\"missing_label\"").count - 1, 1, text)
    }

    func testA11yCheckStillFlagsAnEmptyButtonStubWhenTheClickableParentHasNoText() async throws {
        let xml = """
            <hierarchy rotation="0">
              <android.view.View class="android.view.View" text="" clickable="true" enabled="true" bounds="[0,0][300,300]" displayed="true">
                <android.widget.Button class="android.widget.Button" text="" clickable="false" enabled="true" bounds="[0,0][300,300]" displayed="true" />
              </android.view.View>
            </hierarchy>
            """
        let text = try await androidCheck(xml: xml)
        XCTAssertTrue(text.contains("missing_label"), text)
    }

    func testA11yCheckResetsTheFocusGroupAtANestedClickable() async throws {
        // The outer card is labelled, but the inner clickable has no text of its
        // own: its empty stub is not covered by the outer label.
        let xml = """
            <hierarchy rotation="0">
              <android.view.View class="android.view.View" text="" clickable="true" focusable="true" enabled="true" bounds="[0,0][600,600]" displayed="true">
                <android.widget.TextView class="android.widget.TextView" text="Card" clickable="false" focusable="false" enabled="true" bounds="[0,0][600,200]" displayed="true" />
                <android.view.View class="android.view.View" text="" clickable="true" focusable="true" enabled="true" bounds="[0,300][300,600]" displayed="true">
                  <android.widget.Button class="android.widget.Button" text="" clickable="false" focusable="false" enabled="true" bounds="[0,300][300,600]" displayed="true" />
                </android.view.View>
              </android.view.View>
            </hierarchy>
            """
        let text = try await androidCheck(xml: xml)
        XCTAssertTrue(text.contains(#""type" : "android.widget.Button""#), text)
        XCTAssertTrue(text.contains(#""type" : "android.view.View""#), text)
    }

    func testA11yCheckStillChecksAFocusableWidgetInsideALabelledGroup() async throws {
        let xml = """
            <hierarchy rotation="0">
              <android.view.View class="android.view.View" text="" clickable="true" enabled="true" bounds="[0,0][300,300]" displayed="true">
                <android.widget.TextView class="android.widget.TextView" text="Row" clickable="false" enabled="true" bounds="[0,0][300,100]" displayed="true" />
                <android.widget.Switch class="android.widget.Switch" text="" clickable="false" focusable="true" enabled="true" bounds="[0,100][300,300]" displayed="true" />
              </android.view.View>
            </hierarchy>
            """
        let text = try await androidCheck(xml: xml)
        XCTAssertTrue(text.contains("android.widget.Switch has no accessibility label"), text)
    }
}
