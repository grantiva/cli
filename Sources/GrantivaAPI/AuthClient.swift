import Foundation
import GrantivaCore

public struct AuthProfile: Codable, Sendable, Equatable {
    public let email: String
    public let apiKeyPrefix: String

    enum CodingKeys: String, CodingKey {
        case email
        case apiKeyPrefix = "api_key_prefix"
    }

    public init(email: String, apiKeyPrefix: String) {
        self.email = email
        self.apiKeyPrefix = apiKeyPrefix
    }
}

public struct AuthSession: Codable, Sendable, Equatable {
    public let sessionId: String

    enum CodingKeys: String, CodingKey { case sessionId = "session_id" }

    public init(sessionId: String) { self.sessionId = sessionId }
}

public struct AuthSessionStatus: Codable, Sendable, Equatable {
    public let status: String
    public let apiKey: String?
    public let email: String?

    enum CodingKeys: String, CodingKey {
        case status
        case apiKey = "api_key"
        case email
    }

    public init(status: String, apiKey: String? = nil, email: String? = nil) {
        self.status = status
        self.apiKey = apiKey
        self.email = email
    }
}

enum AuthEndpoints {
    static func profile() -> Endpoint<EmptyBody, AuthProfile> {
        Endpoint(path: "api/v1/auth/me", method: .get)
    }

    static func createSession() -> Endpoint<EmptyBody, AuthSession> {
        Endpoint(path: "api/v1/auth/cli/sessions", method: .post)
    }

    static func session(_ id: String) -> Endpoint<EmptyBody, AuthSessionStatus> {
        Endpoint(path: "api/v1/auth/cli/sessions/\(EndpointPath.segment(id))", method: .get)
    }
}

public struct AuthClient: Sendable {
    public var profile: @Sendable (_ apiKey: String) async throws -> AuthProfile
    public var createSession: @Sendable () async throws -> AuthSession
    public var session: @Sendable (_ id: String) async throws -> AuthSessionStatus

    public init(
        profile: @escaping @Sendable (String) async throws -> AuthProfile,
        createSession: @escaping @Sendable () async throws -> AuthSession,
        session: @escaping @Sendable (String) async throws -> AuthSessionStatus
    ) {
        self.profile = profile
        self.createSession = createSession
        self.session = session
    }

    public init(baseURL: String) throws {
        let baseURL = try validatedAPIBaseURL(baseURL)
        let anonymous = NetworkClient.anonymous()
        self.init(
            profile: { apiKey in
                try await NetworkClient.authorized(apiKey: apiKey).execute(AuthEndpoints.profile(), baseURL: baseURL)
            },
            createSession: {
                try await anonymous.execute(AuthEndpoints.createSession(), baseURL: baseURL)
            },
            session: { id in
                try await anonymous.execute(AuthEndpoints.session(id), baseURL: baseURL)
            }
        )
    }

    public static let failing = AuthClient(
        profile: { _ in throw GrantivaError.notAuthenticated },
        createSession: { throw GrantivaError.notAuthenticated },
        session: { _ in throw GrantivaError.notAuthenticated }
    )
}
