import XCTest
@testable import GrantivaCLI
import GrantivaCore

@available(macOS 15, *)
final class AuthCommandTests: XCTestCase {
    func testMalformedBaseURLThrowsInvalidArgument() {
        XCTAssertThrowsError(try AuthCommand.LoginCommand.validatedBaseURL("http://[")) { error in
            guard case GrantivaError.invalidArgument(let message) = error else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
            XCTAssertEqual(message, "--base-url must be a valid http or https URL")
        }
    }

    func testBaseURLRequiresHTTPOrHTTPSAndAHost() {
        for value in ["not a URL", "file:///tmp/grantiva", "https:///missing-host"] {
            XCTAssertThrowsError(try AuthCommand.LoginCommand.validatedBaseURL(value), value)
        }
    }

    func testValidBaseURLIsPreserved() throws {
        let url = try AuthCommand.LoginCommand.validatedBaseURL("https://example.com/custom/")
        XCTAssertEqual(url.absoluteString, "https://example.com/custom/")
    }
}
