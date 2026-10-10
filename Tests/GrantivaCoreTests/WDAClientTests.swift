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
        XCTAssertEqual((root["frame"] as? [String: String])?["height"], "844")
        let children = try XCTUnwrap(root["children"] as? [[String: Any]])
        XCTAssertEqual(children.first?["identifier"] as? String, "next")
        XCTAssertEqual(children.first?["enabled"] as? Bool, false)
        XCTAssertNoThrow(try JSONSerialization.data(withJSONObject: root))
    }

    func testHierarchyParserOmitsEmptyAttributesAndIncompleteFrames() throws {
        let root = try WDAHierarchyXMLParser(xml: #"<Button label="" name="" x="1" y="2" width="3"/>"#).parse()
        XCTAssertNil(root["label"])
        XCTAssertNil(root["name"])
        XCTAssertNil(root["frame"])
    }

    func testHierarchyParserRejectsEmptyXML() {
        XCTAssertThrowsError(try WDAHierarchyXMLParser(xml: "").parse())
    }

    // MARK: - Live client against a stub transport (I05, I06)

    private let status = #"{"sessionId":"S1","value":{"ready":true}}"#
    private let oneElement = #"{"value":[{"ELEMENT":"E1"}]}"#
    private let noElements = #"{"value":[]}"#

    func testTapByLabelFindsByAccessibilityLabelPredicate() async throws {
        let transport = ScriptedTransport([(status, 200), (oneElement, 200), ("{}", 200)])
        try await DriverClient.wda(port: 8100, transport: transport.transport).tapByLabel("Favorites")
        let calls = transport.calls
        XCTAssertEqual(calls.map(\.path), ["/status", "/session/S1/elements", "/session/S1/element/E1/click"])
        let find = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(calls[1].body.utf8)) as? [String: String])
        XCTAssertEqual(find["using"], "predicate string")
        XCTAssertEqual(find["value"], #"label == "Favorites""#)
    }

    func testTapByLabelFallsBackToTheNameWhenNoLabelMatches() async throws {
        let transport = ScriptedTransport([(status, 200), (noElements, 200), (oneElement, 200), ("{}", 200)])
        try await DriverClient.wda(port: 8100, transport: transport.transport).tapByLabel("heart")
        let finds = transport.calls.filter { $0.path.hasSuffix("/elements") }
        let values = try finds.map { try XCTUnwrap(JSONSerialization.jsonObject(with: Data($0.body.utf8)) as? [String: String])["value"] }
        XCTAssertEqual(values, [#"label == "heart""#, #"name == "heart""#])
        XCTAssertEqual(transport.calls.last?.path, "/session/S1/element/E1/click")
    }

    func testTapByLabelEscapesQuotesAndBackslashesInThePredicate() async throws {
        let transport = ScriptedTransport([(status, 200), (oneElement, 200), ("{}", 200)])
        try await DriverClient.wda(port: 8100, transport: transport.transport).tapByLabel(#"Say "hi" \o/"#)
        let find = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(transport.calls[1].body.utf8)) as? [String: String])
        XCTAssertEqual(find["value"], #"label == "Say \"hi\" \\o/""#)
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
        let transport = ScriptedTransport([(status, 200), ("{}", 200)])
        try await DriverClient.wda(port: 8100, transport: transport.transport).typeText("Hi!")
        XCTAssertEqual(transport.calls.map(\.path), ["/status", "/session/S1/wda/keys"])
        XCTAssertEqual(transport.calls[1].method, "POST")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(transport.calls[1].body.utf8)) as? [String: [String]])
        XCTAssertEqual(body["value"], ["H", "i", "!"])
    }

    func testTypeTextFallsBackToKeysOnlyAfterA404() async throws {
        let transport = ScriptedTransport([(status, 200), ("{}", 404), ("{}", 200)])
        try await DriverClient.wda(port: 8100, transport: transport.transport).typeText("x")
        XCTAssertEqual(transport.calls.map(\.path), ["/status", "/session/S1/wda/keys", "/session/S1/keys"])
    }

    func testTypeTextFailureNamesTheHTTPStatus() async {
        let transport = ScriptedTransport([(status, 200), ("{}", 500)])
        do {
            try await DriverClient.wda(port: 8100, transport: transport.transport).typeText("x")
            XCTFail("expected an error")
        } catch {
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("500"), message)
            XCTAssertTrue(message.contains("Failed to type text"), message)
            XCTAssertFalse(message.contains("exited with code"), message)
        }
        XCTAssertEqual(transport.calls.count, 2, "a non-404 failure must not retry /keys")
    }
}
