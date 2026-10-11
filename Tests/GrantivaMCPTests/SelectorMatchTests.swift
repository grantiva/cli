import XCTest

@testable import GrantivaMCP

/// The runner's selector text rules, as the capture through a session uses them.
final class SelectorMatchTests: XCTestCase {
    func testTextIsAWholeValueRegexIgnoringCase() {
        XCTAssertTrue(SelectorMatch.text("Open", "open"))
        XCTAssertFalse(SelectorMatch.text("Open", "Talk · Open"))
        XCTAssertFalse(SelectorMatch.text("Example", "Examples"))
        XCTAssertTrue(SelectorMatch.text(".*Open.*", "Talk · Open now"))
    }

    func testTextAlsoMatchesLiterallyAndAcrossLineBreaks() {
        XCTAssertTrue(SelectorMatch.text("$7.50", "$7.50"), "equal to the pattern although $ anchors")
        XCTAssertTrue(SelectorMatch.text("Plan Visit", "Plan\nVisit"))
        XCTAssertTrue(SelectorMatch.text("(", "("), "an invalid regex matches literally")
    }

    func testExactIsTheWholeValueInItsOwnCase() {
        XCTAssertTrue(SelectorMatch.exactText("Not advertising", "Not advertising"))
        XCTAssertFalse(SelectorMatch.exactText("not advertising", "Not advertising"))
        XCTAssertFalse(SelectorMatch.exactText("Advertising", "Not advertising"))
    }

    func testIDMatchesTheWholeIdentifierOrItsLastComponent() {
        XCTAssertTrue(SelectorMatch.id("login", "com.app:id/login"))
        XCTAssertFalse(SelectorMatch.id("login", "com.app:id/login_button"))
        XCTAssertTrue(SelectorMatch.id("LOGIN", "login"))
    }
}
