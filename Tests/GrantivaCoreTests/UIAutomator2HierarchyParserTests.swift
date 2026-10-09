import XCTest
@testable import GrantivaCore

final class UIAutomator2HierarchyParserTests: XCTestCase {
    private let sample = """
    <?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
    <hierarchy index="0" class="hierarchy" rotation="0" width="1080" height="2400">
      <android.widget.FrameLayout index="0" package="dev.grantiva.example" class="android.widget.FrameLayout" text="" resource-id="" clickable="false" enabled="true" bounds="[0,0][1080,2400]" displayed="true">
        <android.view.View index="0" package="dev.grantiva.example" class="android.view.View" text="Details" content-desc="" resource-id="" clickable="false" enabled="true" bounds="[42,236][270,310]" displayed="true" />
        <android.widget.Button index="1" package="dev.grantiva.example" class="android.widget.Button" text="Settings" content-desc="Open settings" resource-id="dev.grantiva.example:id/settings" clickable="true" enabled="false" bounds="[540,2200][1080,2300]" displayed="false" />
      </android.widget.FrameLayout>
    </hierarchy>
    """

    func testParseBoundsReadsTheTwoCorners() {
        let b = UIAutomator2HierarchyXMLParser.parseBounds("[42,236][270,310]")
        XCTAssertEqual(b?.x, 42); XCTAssertEqual(b?.y, 236); XCTAssertEqual(b?.width, 228); XCTAssertEqual(b?.height, 74)
        XCTAssertNil(UIAutomator2HierarchyXMLParser.parseBounds("nonsense"))
        XCTAssertNil(UIAutomator2HierarchyXMLParser.parseBounds(""))
    }

    func testRootIsTaggedAndroidAndNodesMapOntoTheSharedShape() throws {
        let root = try UIAutomator2HierarchyXMLParser(xml: sample, scale: 2.625).parse()
        XCTAssertEqual(root["type"] as? String, "hierarchy")
        XCTAssertEqual(root["platform"] as? String, "android")
        let frame = try XCTUnwrap((root["children"] as? [[String: Any]])?.first)
        XCTAssertEqual(frame["type"] as? String, "android.widget.FrameLayout")
        XCTAssertEqual(frame["package"] as? String, "dev.grantiva.example")
        XCTAssertNil(frame["label"], "an empty text and no content-desc give no label")
        let children = try XCTUnwrap(frame["children"] as? [[String: Any]])
        XCTAssertEqual(children.count, 2)

        let text = children[0]
        XCTAssertEqual(text["label"] as? String, "Details", "label falls back to text")
        XCTAssertNil(text["name"])
        XCTAssertEqual(text["value"] as? String, "Details")
        XCTAssertEqual(text["clickable"] as? Bool, false)
        XCTAssertEqual(text["visible"] as? Bool, true)
        XCTAssertEqual(text["frame"] as? [String: String], ["x": "16", "y": "90", "width": "87", "height": "28"], "pixels / 2.625, rounded")

        let button = children[1]
        XCTAssertEqual(button["label"] as? String, "Open settings", "content-desc wins over text")
        XCTAssertEqual(button["name"] as? String, "Open settings")
        XCTAssertEqual(button["identifier"] as? String, "dev.grantiva.example:id/settings")
        XCTAssertEqual(button["value"] as? String, "Settings")
        XCTAssertEqual(button["enabled"] as? Bool, false)
        XCTAssertEqual(button["visible"] as? Bool, false)
        XCTAssertEqual(button["clickable"] as? Bool, true)
        XCTAssertNoThrow(try JSONSerialization.data(withJSONObject: root))
    }

    func testScaleOneKeepsPixels() throws {
        let root = try UIAutomator2HierarchyXMLParser(xml: sample, scale: 1).parse()
        let text = try XCTUnwrap(((root["children"] as? [[String: Any]])?.first?["children"] as? [[String: Any]])?.first)
        XCTAssertEqual(text["frame"] as? [String: String], ["x": "42", "y": "236", "width": "228", "height": "74"])
    }

    func testMalformedXMLThrows() {
        XCTAssertThrowsError(try UIAutomator2HierarchyXMLParser(xml: "<hierarchy><broken>", scale: 1).parse())
    }

    func testNodeWithoutBoundsHasNoFrame() throws {
        let root = try UIAutomator2HierarchyXMLParser(xml: #"<hierarchy><android.view.View class="android.view.View" text="x"/></hierarchy>"#, scale: 1).parse()
        let child = try XCTUnwrap((root["children"] as? [[String: Any]])?.first)
        XCTAssertNil(child["frame"])
    }
}
