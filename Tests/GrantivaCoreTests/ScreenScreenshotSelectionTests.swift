import XCTest
@testable import GrantivaCore

final class ScreenScreenshotSelectionTests: XCTestCase {
    func testOverlappingScreenNamesSelectTheirOwnArtifact() {
        let files = ["cmd-001-login-error.png", "cmd-003-login.png"]
        XCTAssertEqual(files.filter { RunnerSession.screenshotName(in: $0) == "login" }, ["cmd-003-login.png"])
        XCTAssertEqual(files.filter { RunnerSession.screenshotName(in: $0) == "login-error" }, ["cmd-001-login-error.png"])
    }

    func testMissingScreenshotIsNotReplacedByLongerName() {
        XCTAssertFalse(["cmd-001-login-error.png"].contains { RunnerSession.screenshotName(in: $0) == "login" })
    }

    func testNamesPreserveHyphensAndUnicodeAndRejectUnrelatedFiles() {
        XCTAssertEqual(RunnerSession.screenshotName(in: "cmd-012-account-設定.png"), "account-設定")
        for file in ["login.png", "cmd-abc-login.png", "cmd-001-login.xml", "cmd-001.png"] {
            XCTAssertNil(RunnerSession.screenshotName(in: file))
        }
    }
}
