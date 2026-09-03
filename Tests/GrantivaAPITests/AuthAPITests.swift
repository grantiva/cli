import XCTest
@testable import GrantivaAPI

final class AuthAPITests: XCTestCase {
    private let base = URL(string: "https://api.example.com")!

    func testAuthEndpoints() throws {
        let profile = AuthEndpoints.profile()
        XCTAssertEqual(profile.method, .get)
        XCTAssertEqual(try profile.url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/auth/me")

        let create = AuthEndpoints.createSession()
        XCTAssertEqual(create.method, .post)
        XCTAssertEqual(try create.url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/auth/cli/sessions")

        let poll = AuthEndpoints.session("session/with space")
        XCTAssertEqual(poll.method, .get)
        XCTAssertEqual(
            try poll.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/auth/cli/sessions/session%2Fwith%20space"
        )
    }

    func testAuthModelsDecodeWireKeys() throws {
        let decoder = JSONDecoder()
        XCTAssertEqual(
            try decoder.decode(AuthProfile.self, from: Data(#"{"email":"dev@example.com","api_key_prefix":"grantiva_ab"}"#.utf8)),
            AuthProfile(email: "dev@example.com", apiKeyPrefix: "grantiva_ab")
        )
        XCTAssertEqual(
            try decoder.decode(AuthSession.self, from: Data(#"{"session_id":"S1"}"#.utf8)),
            AuthSession(sessionId: "S1")
        )
        XCTAssertEqual(
            try decoder.decode(AuthSessionStatus.self, from: Data(#"{"status":"complete","api_key":"secret","email":"dev@example.com"}"#.utf8)),
            AuthSessionStatus(status: "complete", apiKey: "secret", email: "dev@example.com")
        )
    }

    func testFailingClientThrows() async {
        await XCTAssertThrowsErrorAsync { try await AuthClient.failing.createSession() }
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected an error", file: file, line: line)
    } catch {}
}
