import XCTest

@testable import GrantivaMCP

/// The bundled grantiva-runner's selector rules (1.1.28-grantiva.11), as a
/// capture through a session uses them.
final class SelectorMatchTests: XCTestCase {
    /// Text is the same rule on both platforms.
    func testTextIsAWholeValueRegexIgnoringCase() {
        XCTAssertTrue(SelectorMatch.text("Open", "open"))
        XCTAssertFalse(SelectorMatch.text("Open", "Talk · Open"), "tap: Open does not match Talk · Open")
        XCTAssertFalse(SelectorMatch.text("Example", "Examples"))
        XCTAssertTrue(SelectorMatch.text(".*Open.*", "Talk · Open now"))
    }

    func testTextAlsoMatchesLiterallyAcrossLineBreaksAndAccentForms() {
        XCTAssertTrue(SelectorMatch.text("$7.50", "$7.50"), "equal to the pattern although $ anchors")
        XCTAssertTrue(SelectorMatch.text("Plan Visit", "Plan\nVisit"))
        XCTAssertTrue(SelectorMatch.text("(", "("), "an invalid regex matches literally")
        XCTAssertTrue(SelectorMatch.text("Caf\u{E9}", "Cafe\u{301}"), "NFC on both sides")
    }

    func testExactIsTheWholeValueAsWritten() {
        XCTAssertTrue(SelectorMatch.exactText("Not advertising", "Not advertising"))
        XCTAssertFalse(SelectorMatch.exactText("not advertising", "Not advertising"))
        XCTAssertFalse(SelectorMatch.exactText("Advertising", "Not advertising"))
        XCTAssertFalse(SelectorMatch.exactText(".*", "anything"), "never a regex")
    }

    func testIOSIdIsTheWholeIdentifierIgnoringCase() {
        XCTAssertTrue(SelectorMatch.iosID("loginButton", "LoginButton"))
        XCTAssertFalse(SelectorMatch.iosID("login", "com.app/login"), "no last-component rule on iOS")
        XCTAssertFalse(SelectorMatch.iosID("login", "login_button"))
        XCTAssertTrue(SelectorMatch.iosID("cell_[0-9]+", "CELL_12"), "a regex id matches the whole identifier")
        XCTAssertTrue(SelectorMatch.iosID("$total", "$TOTAL"), "an id equal to the identifier matches")
        XCTAssertFalse(SelectorMatch.iosID("General", ""), "no identifier, no match")
    }

    func testAndroidIdMatchesTheWholeResourceIdOrItsLastComponent() {
        XCTAssertTrue(SelectorMatch.androidID("login", "com.app:id/login"))
        XCTAssertFalse(SelectorMatch.androidID("login", "com.app:id/login_button"))
        XCTAssertTrue(SelectorMatch.androidID("LOGIN", "login"))
    }
}
