import Foundation
import GrantivaCore

// MARK: - Release Notes Wire Formats
//
// `/api/v1/org/release-notes` is the one org surface that speaks camelCase:
// the dashboard consumes it, so the backend kept its keys when it opened
// the routes to API keys. Property names match the wire directly.

public struct ReleaseNote: Codable, Sendable, Equatable {
    public let id: String
    public let appId: String
    public let version: String
    public let title: String
    public let body: String
    public let isPublished: Bool
    public let publishedAt: String?
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String, appId: String, version: String, title: String, body: String, isPublished: Bool,
        publishedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil
    ) {
        self.id = id
        self.appId = appId
        self.version = version
        self.title = title
        self.body = body
        self.isPublished = isPublished
        self.publishedAt = publishedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ReleaseNotePage: Codable, Sendable, Equatable {
    public struct Metadata: Codable, Sendable, Equatable {
        public let page: Int
        public let per: Int
        public let total: Int

        public init(page: Int, per: Int, total: Int) {
            self.page = page
            self.per = per
            self.total = total
        }
    }

    public let items: [ReleaseNote]
    public let metadata: Metadata

    public init(items: [ReleaseNote], metadata: Metadata) {
        self.items = items
        self.metadata = metadata
    }
}

public struct CreateReleaseNoteRequest: Codable, Sendable, Equatable {
    public let appId: String
    public let version: String
    public let title: String
    public let body: String
    public let isPublished: Bool?

    public init(appId: String, version: String, title: String, body: String, isPublished: Bool? = nil) {
        self.appId = appId
        self.version = version
        self.title = title
        self.body = body
        self.isPublished = isPublished
    }
}

public struct UpdateReleaseNoteRequest: Codable, Sendable, Equatable {
    public let version: String?
    public let title: String?
    public let body: String?

    public init(version: String? = nil, title: String? = nil, body: String? = nil) {
        self.version = version
        self.title = title
        self.body = body
    }
}

// MARK: - Endpoints

enum ReleaseNoteEndpoints {
    private static let prefix = "api/v1/org/release-notes"

    static func list(appId: String?, page: Int?, per: Int?) -> Endpoint<EmptyBody, ReleaseNotePage> {
        var items: [URLQueryItem] = []
        if let appId { items.append(URLQueryItem(name: "appId", value: appId)) }
        if let page { items.append(URLQueryItem(name: "page", value: String(page))) }
        if let per { items.append(URLQueryItem(name: "per", value: String(per))) }
        return Endpoint(path: prefix, method: .get, queryItems: items.isEmpty ? nil : items)
    }

    static func create(body: CreateReleaseNoteRequest) -> Endpoint<CreateReleaseNoteRequest, ReleaseNote> {
        Endpoint(path: prefix, method: .post, body: body)
    }

    static func detail(noteId: String) -> Endpoint<EmptyBody, ReleaseNote> {
        Endpoint(path: "\(prefix)/\(EndpointPath.segment(noteId))", method: .get)
    }

    /// PATCH — sent through the raw request path since `NetworkClient` routes
    /// `.patch` through PUT.
    static func update(noteId: String, body: UpdateReleaseNoteRequest) -> Endpoint<UpdateReleaseNoteRequest, ReleaseNote> {
        Endpoint(path: "\(prefix)/\(EndpointPath.segment(noteId))", method: .patch, body: body)
    }

    static func delete(noteId: String) -> Endpoint<EmptyBody, EmptyResponse> {
        Endpoint(path: "\(prefix)/\(EndpointPath.segment(noteId))", method: .delete)
    }

    static func publish(noteId: String) -> Endpoint<EmptyBody, ReleaseNote> {
        Endpoint(path: "\(prefix)/\(EndpointPath.segment(noteId))/publish", method: .post)
    }

    static func unpublish(noteId: String) -> Endpoint<EmptyBody, ReleaseNote> {
        Endpoint(path: "\(prefix)/\(EndpointPath.segment(noteId))/unpublish", method: .post)
    }
}

// MARK: - ReleaseNotesClient

/// API client for `grantiva console releases`.
public struct ReleaseNotesClient: Sendable {
    public var list: @Sendable (_ appId: String?, _ page: Int?, _ per: Int?) async throws -> ReleaseNotePage
    public var create: @Sendable (CreateReleaseNoteRequest) async throws -> ReleaseNote
    public var get: @Sendable (_ noteId: String) async throws -> ReleaseNote
    public var update: @Sendable (_ noteId: String, UpdateReleaseNoteRequest) async throws -> ReleaseNote
    public var delete: @Sendable (_ noteId: String) async throws -> Void
    public var publish: @Sendable (_ noteId: String) async throws -> ReleaseNote
    public var unpublish: @Sendable (_ noteId: String) async throws -> ReleaseNote

    public init(
        list: @escaping @Sendable (String?, Int?, Int?) async throws -> ReleaseNotePage,
        create: @escaping @Sendable (CreateReleaseNoteRequest) async throws -> ReleaseNote,
        get: @escaping @Sendable (String) async throws -> ReleaseNote,
        update: @escaping @Sendable (String, UpdateReleaseNoteRequest) async throws -> ReleaseNote,
        delete: @escaping @Sendable (String) async throws -> Void,
        publish: @escaping @Sendable (String) async throws -> ReleaseNote,
        unpublish: @escaping @Sendable (String) async throws -> ReleaseNote
    ) {
        self.list = list
        self.create = create
        self.get = get
        self.update = update
        self.delete = delete
        self.publish = publish
        self.unpublish = unpublish
    }

    public init(apiKey: String, baseURL: String) throws {
        let baseURL = try validatedAPIBaseURL(baseURL)
        let client = NetworkClient.authorized(apiKey: apiKey)
        self.init(
            list: { appId, page, per in
                try await client.execute(ReleaseNoteEndpoints.list(appId: appId, page: page, per: per), baseURL: baseURL)
            },
            create: { body in try await client.execute(ReleaseNoteEndpoints.create(body: body), baseURL: baseURL) },
            get: { noteId in try await client.execute(ReleaseNoteEndpoints.detail(noteId: noteId), baseURL: baseURL) },
            update: { noteId, body in
                try await client.execute(ReleaseNoteEndpoints.update(noteId: noteId, body: body), baseURL: baseURL)
            },
            delete: { noteId in _ = try await client.execute(ReleaseNoteEndpoints.delete(noteId: noteId), baseURL: baseURL) },
            publish: { noteId in try await client.execute(ReleaseNoteEndpoints.publish(noteId: noteId), baseURL: baseURL) },
            unpublish: { noteId in try await client.execute(ReleaseNoteEndpoints.unpublish(noteId: noteId), baseURL: baseURL) }
        )
    }

    public static let failing = ReleaseNotesClient(
        list: { _, _, _ in throw GrantivaError.notAuthenticated },
        create: { _ in throw GrantivaError.notAuthenticated },
        get: { _ in throw GrantivaError.notAuthenticated },
        update: { _, _ in throw GrantivaError.notAuthenticated },
        delete: { _ in throw GrantivaError.notAuthenticated },
        publish: { _ in throw GrantivaError.notAuthenticated },
        unpublish: { _ in throw GrantivaError.notAuthenticated }
    )
}
