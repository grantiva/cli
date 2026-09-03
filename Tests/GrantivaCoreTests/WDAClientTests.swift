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
}
