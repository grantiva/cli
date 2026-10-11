import XCTest
@testable import GrantivaCore

final class WDAClientTests: XCTestCase {
    func testElementIDSupportsLegacyAndW3CKeys() {
        XCTAssertEqual(DriverClient.elementID(from: ["ELEMENT": "legacy-id"]), "legacy-id")
        XCTAssertEqual(
            DriverClient.elementID(from: [
                "element-6066-11e4-a52e-4f735466cecf": "w3c-id",
                "label": "must-not-be-used",
            ]),
            "w3c-id"
        )
    }

    func testElementIDDoesNotUseAnArbitraryStringValue() {
        XCTAssertNil(DriverClient.elementID(from: ["label": "not-an-element-id"]))
    }

    func testHierarchyParserThrowsForMalformedXML() {
        let parser = WDAHierarchyXMLParser(xml: "<XCUIElementTypeApplication><broken>")
        XCTAssertThrowsError(try parser.parse())
    }

    func testHierarchyParserBuildsNestedJSONSerializableTree() throws {
        let xml = #"<XCUIElementTypeApplication label="App &amp; More" enabled="true" visible="false" x="0" y="1" width="390" height="844"><XCUIElementTypeButton name="continue" identifier="next" value="Go" enabled="false"/></XCUIElementTypeApplication>"#
        let root = try WDAHierarchyXMLParser(xml: xml).parse()
        XCTAssertEqual(root["type"] as? String, "XCUIElementTypeApplication")
        XCTAssertEqual(root["label"] as? String, "App & More")
        XCTAssertEqual(root["enabled"] as? Bool, true)
        XCTAssertEqual(root["visible"] as? Bool, false)
        // K99/MCP-017: frame values are numbers.
        let frame = try XCTUnwrap(root["frame"] as? [String: Any])
        XCTAssertEqual(frame["height"] as? Int, 844)
        XCTAssertEqual(frame["y"] as? Int, 1)
        XCTAssertFalse(frame["height"] is String)
        let children = try XCTUnwrap(root["children"] as? [[String: Any]])
        XCTAssertEqual(children.first?["identifier"] as? String, "next")
        XCTAssertEqual(children.first?["enabled"] as? Bool, false)
        XCTAssertNoThrow(try JSONSerialization.data(withJSONObject: root))
    }

    func testHierarchyParserKeepsFractionalFramesAndEmitsJSONNumbers() throws {
        let root = try WDAHierarchyXMLParser(xml: #"<Button x="10.5" y="0" width="44" height="43.75"/>"#).parse()
        let frame = try XCTUnwrap(root["frame"] as? [String: Any])
        XCTAssertEqual(frame["x"] as? Double, 10.5)
        XCTAssertEqual(frame["height"] as? Double, 43.75)
        let json = String(decoding: try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]), as: UTF8.self)
        XCTAssertTrue(json.contains(#""frame":{"height":43.75,"width":44,"x":10.5,"y":0}"#), json)
    }

    func testHierarchyParserOmitsEmptyAttributesAndIncompleteFrames() throws {
        let root = try WDAHierarchyXMLParser(xml: #"<Button label="" name="" x="1" y="2" width="3"/>"#).parse()
        XCTAssertNil(root["label"])
        XCTAssertNil(root["name"])
        XCTAssertNil(root["frame"])
    }

    /// Text selectors read the placeholder, so the tree carries it.
    func testHierarchyParserKeepsThePlaceholderValue() throws {
        let xml = #"<XCUIElementTypeApplication><XCUIElementTypeTextField placeholderValue="Search"/><XCUIElementTypeTextField placeholderValue=""/></XCUIElementTypeApplication>"#
        let children = try XCTUnwrap(try WDAHierarchyXMLParser(xml: xml).parse()["children"] as? [[String: Any]])
        XCTAssertEqual(children[0]["placeholderValue"] as? String, "Search")
        XCTAssertNil(children[1]["placeholderValue"])
    }

    func testHierarchyParserRejectsEmptyXML() {
        XCTAssertThrowsError(try WDAHierarchyXMLParser(xml: "").parse())
    }

    // MARK: - Live client against a stub transport (I05, I06)

    private let status = #"{"sessionId":"S1","value":{"ready":true}}"#
    private let oneElement = #"{"value":[{"ELEMENT":"E1"}]}"#
    private let noElements = #"{"value":[]}"#
    private let focused = #"{"value":{"ELEMENT":"F1"}}"#

    func testTapByLabelFindsByAccessibilityLabelPredicate() async throws {
        let transport = ScriptedTransport([(status, 200), (oneElement, 200), ("{}", 200)])
        try await DriverClient.wda(port: 8100, transport: transport.transport).tapByLabel("Favorites")
        let calls = transport.calls
        XCTAssertEqual(calls.map(\.path), ["/status", "/session/S1/elements", "/session/S1/element/E1/click"])
        let find = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(calls[1].body.utf8)) as? [String: String])
        XCTAssertEqual(find["using"], "predicate string")
        XCTAssertEqual(find["value"], #"label == "Favorites" AND type != "XCUIElementTypeApplication""#)
    }

    func testTapByLabelFallsBackToTheNameWhenNoLabelMatches() async throws {
        let transport = ScriptedTransport([(status, 200), (noElements, 200), (oneElement, 200), ("{}", 200)])
        try await DriverClient.wda(port: 8100, transport: transport.transport).tapByLabel("heart")
        let finds = transport.calls.filter { $0.path.hasSuffix("/elements") }
        let values = try finds.map { try XCTUnwrap(JSONSerialization.jsonObject(with: Data($0.body.utf8)) as? [String: String])["value"] }
        XCTAssertEqual(values, [
            #"label == "heart" AND type != "XCUIElementTypeApplication""#,
            #"name == "heart" AND type != "XCUIElementTypeApplication""#,
        ])
        XCTAssertEqual(transport.calls.last?.path, "/session/S1/element/E1/click")
    }

    func testTapByLabelEscapesQuotesAndBackslashesInThePredicate() async throws {
        let transport = ScriptedTransport([(status, 200), (oneElement, 200), ("{}", 200)])
        try await DriverClient.wda(port: 8100, transport: transport.transport).tapByLabel(#"Say "hi" \o/"#)
        let find = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(transport.calls[1].body.utf8)) as? [String: String])
        XCTAssertEqual(find["value"], #"label == "Say \"hi\" \\o/" AND type != "XCUIElementTypeApplication""#)
        XCTAssertEqual(DriverClient.predicateLiteral(#"a"b"#), #""a\"b""#)
    }

    func testTapByLabelThrowsElementNotFoundWhenNeitherLabelNorNameMatches() async {
        let transport = ScriptedTransport([(status, 200), (noElements, 200), (noElements, 200)])
        do {
            try await DriverClient.wda(port: 8100, transport: transport.transport).tapByLabel("Missing")
            XCTFail("expected elementNotFound")
        } catch let error as GrantivaError {
            guard case .elementNotFound("Missing") = error else { return XCTFail("\(error)") }
        } catch {
            XCTFail("\(error)")
        }
        XCTAssertFalse(transport.calls.contains { $0.path.hasSuffix("/click") })
    }

    func testTypeTextPostsCharactersToWDAKeys() async throws {
        let transport = ScriptedTransport([(status, 200), (focused, 200), ("{}", 200)])
        try await DriverClient.wda(port: 8100, transport: transport.transport).typeText("Hi!")
        XCTAssertEqual(transport.calls.map(\.path), ["/status", "/session/S1/element/active", "/session/S1/wda/keys"])
        XCTAssertEqual(transport.calls[2].method, "POST")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(transport.calls[2].body.utf8)) as? [String: [String]])
        XCTAssertEqual(body["value"], ["H", "i", "!"])
    }

    func testTypeTextFallsBackToKeysOnlyAfterA404() async throws {
        let transport = ScriptedTransport([(status, 200), (focused, 200), ("{}", 404), ("{}", 200)])
        try await DriverClient.wda(port: 8100, transport: transport.transport).typeText("x")
        XCTAssertEqual(transport.calls.map(\.path), ["/status", "/session/S1/element/active", "/session/S1/wda/keys", "/session/S1/keys"])
    }

    func testTypeTextFailureNamesTheHTTPStatus() async {
        let transport = ScriptedTransport([(status, 200), (focused, 200), ("{}", 500)])
        do {
            try await DriverClient.wda(port: 8100, transport: transport.transport).typeText("x")
            XCTFail("expected an error")
        } catch {
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("500"), message)
            XCTAssertTrue(message.contains("Failed to type text"), message)
            XCTAssertFalse(message.contains("exited with code"), message)
        }
        XCTAssertEqual(transport.calls.count, 3, "a non-404 failure must not retry /keys")
    }

    func testTapByLabelTriesTheNameAfterA404OnTheLabelQuery() async throws {
        let transport = ScriptedTransport([(status, 200), ("{}", 404), (oneElement, 200), ("{}", 200)])
        try await DriverClient.wda(port: 8100, transport: transport.transport).tapByLabel("heart")
        XCTAssertEqual(transport.calls.filter { $0.path.hasSuffix("/elements") }.count, 2)
        XCTAssertEqual(transport.calls.last?.path, "/session/S1/element/E1/click")
    }

    func testTapByLabelReportsAServerErrorInsteadOfElementNotFound() async {
        let transport = ScriptedTransport([(status, 200), (#"{"value":{"error":"invalid session id"}}"#, 500)])
        do {
            try await DriverClient.wda(port: 8100, transport: transport.transport).tapByLabel("Favorites")
            XCTFail("expected an error")
        } catch let error as GrantivaError {
            guard case .networkError(_, 500) = error else { return XCTFail("\(error)") }
            XCTAssertTrue(error.localizedDescription.contains("Favorites"), error.localizedDescription)
        } catch {
            XCTFail("\(error)")
        }
        XCTAssertEqual(transport.calls.filter { $0.path.hasSuffix("/elements") }.count, 1, "a 500 must not fall through to the name query")
    }

    // MARK: - K78: label first, then name (identifier), then placeholder; the match is reported

    private func wda(_ transport: ScriptedTransport) -> DriverClient {
        DriverClient.wda(port: 8100, transport: transport.transport, retryDelay: .zero)
    }

    private func findPredicates(_ transport: ScriptedTransport) throws -> [String?] {
        try transport.calls.filter { $0.path.hasSuffix("/elements") }.map {
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data($0.body.utf8)) as? [String: String])["value"]
        }
    }

    func testTapByLabelReportsALabelMatch() async throws {
        let transport = ScriptedTransport([(status, 200), (oneElement, 200), ("{}", 200)])
        let tap = try XCTUnwrap(wda(transport).tapByLabelMatch)
        let match = try await tap("Favorites")
        XCTAssertEqual(match, .label)
    }

    func testTapByLabelReportsAnIdentifierFallbackMatch() async throws {
        let transport = ScriptedTransport([(status, 200), (noElements, 200), (oneElement, 200), ("{}", 200)])
        let tap = try XCTUnwrap(wda(transport).tapByLabelMatch)
        let match = try await tap("heart")
        XCTAssertEqual(match, .identifier)
        XCTAssertEqual(transport.calls.last?.path, "/session/S1/element/E1/click")
    }

    /// IOS-OBS-06: a SwiftUI `TextField("Name", ...)` carries "Name" as its
    /// placeholder, not its label; the flow's `tapOn: "Name"` reaches it, so
    /// the MCP tap does too, after label and name.
    func testTapByLabelReachesATextFieldByItsPlaceholderAfterLabelAndName() async throws {
        let transport = ScriptedTransport([(status, 200), (noElements, 200), (noElements, 200), (oneElement, 200), ("{}", 200)])
        let tap = try XCTUnwrap(wda(transport).tapByLabelMatch)
        let match = try await tap("Name")
        XCTAssertEqual(match, .placeholder)
        XCTAssertEqual(try findPredicates(transport), [
            #"label == "Name" AND type != "XCUIElementTypeApplication""#,
            #"name == "Name" AND type != "XCUIElementTypeApplication""#,
            #"placeholderValue == "Name" AND type != "XCUIElementTypeApplication""#,
        ])
        XCTAssertEqual(transport.calls.last?.path, "/session/S1/element/E1/click")
    }

    // MARK: - K92: a 400 right after startup, and an app that is not running

    private let appNotRunning = #"{"value":{"error":"invalid element state","message":"The application under test with bundle id 'com.kylebrowning.Landmarks' is not running, possibly crashed","traceback":""}}"#

    func testTapByLabelRetriesTheLookupOnceAfterA400AndThenReportsNotFound() async {
        let transport = ScriptedTransport([
            (status, 200), (appNotRunning, 400), (status, 200), (noElements, 200), (noElements, 200), (noElements, 200),
        ])
        do {
            try await wda(transport).tapByLabel("No Such")
            XCTFail("expected elementNotFound")
        } catch let error as GrantivaError {
            guard case .elementNotFound("No Such") = error else { return XCTFail("\(error)") }
        } catch {
            XCTFail("\(error)")
        }
        XCTAssertEqual(transport.calls.filter { $0.path == "/status" }.count, 2, "the session is resolved again before the retry")
    }

    func testTapByLabelSaysTheAppIsNotRunningWhenThe400Persists() async {
        let transport = ScriptedTransport([(status, 200), (appNotRunning, 400), (status, 200), (appNotRunning, 400)])
        do {
            try await wda(transport).tapByLabel("Landmarks")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? AppNotRunningError, AppNotRunningError(appID: "com.kylebrowning.Landmarks"))
            let message = error.localizedDescription
            XCTAssertTrue(message.hasPrefix("com.kylebrowning.Landmarks is not running. Relaunch it"), message)
            XCTAssertFalse(message.contains("Network error"), message)
        }
        XCTAssertFalse(transport.calls.contains { $0.path.hasSuffix("/click") })
    }

    func testAnUnrecognised400KeepsWDAsReason() async {
        let odd = #"{"value":{"error":"invalid argument","message":"Something odd happened"}}"#
        let transport = ScriptedTransport([(status, 200), (odd, 400), (status, 200), (odd, 400)])
        do {
            try await wda(transport).tapByLabel("Landmarks")
            XCTFail("expected an error")
        } catch {
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("Something odd happened"), message)
            XCTAssertTrue(message.contains("Landmarks"), message)
        }
    }

    func testSwipeAndHierarchySayTheAppIsNotRunning() async {
        let size = #"{"value":{"width":390,"height":844}}"#
        let swipe = ScriptedTransport([(status, 200), (size, 200), (appNotRunning, 400)])
        do {
            try await wda(swipe).swipe("up")
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("is not running"), error.localizedDescription)
        }
        let source = ScriptedTransport([(status, 200), (appNotRunning, 400)])
        do {
            _ = try await wda(source).hierarchy()
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("is not running"), error.localizedDescription)
        }
    }

    // MARK: - K102: typing needs a focused field

    func testTypeTextWithoutAFocusedElementSendsNoKeys() async {
        let none = #"{"value":{"error":"no such element","message":"unable to find an element"}}"#
        let transport = ScriptedTransport([(status, 200), (none, 404)])
        do {
            try await wda(transport).typeText("x")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error.localizedDescription, #"No focused text field: tap a field before typing "x"."#)
        }
        XCTAssertEqual(transport.calls.map(\.path), ["/status", "/session/S1/element/active"])
    }
}
