import XCTest
@testable import GrantivaCore

final class WDAClientTests: XCTestCase {
    func testElementIDSupportsLegacyAndW3CKeys() {
        XCTAssertEqual(WDAClient.elementID(from: ["ELEMENT": "legacy-id"]), "legacy-id")
        XCTAssertEqual(
            WDAClient.elementID(from: [
                "element-6066-11e4-a52e-4f735466cecf": "w3c-id",
                "label": "must-not-be-used",
            ]),
            "w3c-id"
        )
    }

    func testElementIDDoesNotUseAnArbitraryStringValue() {
        XCTAssertNil(WDAClient.elementID(from: ["label": "not-an-element-id"]))
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
}
