import XCTest
@testable import GrantivaCLI
import GrantivaAPI
import GrantivaCore
import Synchronization

@available(macOS 15, *)
final class AuthCommandTests: XCTestCase {
    func testCompletedBrowserSessionUsesActiveStatus() throws {
        let response = try JSONDecoder().decode(
            AuthSessionStatus.self,
            from: Data(#"{"status":"active","api_key":"gpat_test","email":"user@example.com"}"#.utf8)
        )

        XCTAssertEqual(response.status, "active")
        XCTAssertEqual(response.apiKey, "gpat_test")
        XCTAssertEqual(response.email, "user@example.com")
    }

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

    func testAPIKeyLoginUsesAuthClientAndSavesCredentials() async throws {
        var command = try AuthCommand.LoginCommand.parse([
            "--api-key", "grantiva_secret", "--base-url", "https://api.example.com", "--json",
        ])
        let saved = Mutex<AuthCredentials?>(nil)
        command.authStore = AuthStore(
            load: { nil },
            save: { credentials in saved.withLock { $0 = credentials } },
            delete: { false }
        )
        let client = AuthClient(
            profile: { key in
                XCTAssertEqual(key, "grantiva_secret")
                return AuthProfile(email: "dev@example.com", apiKeyPrefix: "grantiva_se")
            },
            createSession: { XCTFail("Unexpected browser flow"); return AuthSession(sessionId: "") },
            session: { _ in XCTFail("Unexpected browser flow"); return AuthSessionStatus(status: "pending") }
        )

        try await command.run(client: client)

        let credentials = saved.withLock { $0 }
        XCTAssertEqual(credentials?.apiKey, "grantiva_secret")
        XCTAssertEqual(credentials?.baseURL, "https://api.example.com")
        XCTAssertEqual(credentials?.email, "dev@example.com")
    }

    // MARK: - Logout

    private func logoutLine(removed: Bool, json: Bool) throws -> String {
        var command = try AuthCommand.LogoutCommand.parse(json ? ["--json"] : [])
        command.authStore = AuthStore(load: { nil }, save: { _ in }, delete: { removed })
        return try command.logout()
    }

    func testLogoutWithNoStoredCredentialsSaysNotLoggedIn() throws {
        XCTAssertEqual(
            try logoutLine(removed: false, json: false),
            "Not logged in; no credentials at ~/.grantiva/auth.json."
        )
        let json = try JSONSerialization.jsonObject(with: Data(try logoutLine(removed: false, json: true).utf8)) as? [String: Any]
        XCTAssertEqual(json?["success"] as? Bool, true)
        XCTAssertEqual(json?["removed"] as? Bool, false)
        XCTAssertEqual(json?["message"] as? String, "No stored credentials")
    }

    func testLogoutWithStoredCredentialsReportsRemoval() throws {
        XCTAssertEqual(
            try logoutLine(removed: true, json: false),
            "Logged out. Credentials removed from ~/.grantiva/auth.json"
        )
        let json = try JSONSerialization.jsonObject(with: Data(try logoutLine(removed: true, json: true).utf8)) as? [String: Any]
        XCTAssertEqual(json?["removed"] as? Bool, true)
        XCTAssertEqual(json?["message"] as? String, "Credentials removed")
    }
}
