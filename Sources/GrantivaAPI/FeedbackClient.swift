import Foundation
import GrantivaCore

// MARK: - Staff feedback + support wire formats (§10 — snake_case)

public struct OrgFeatureRequest: Codable, Sendable, Equatable {
    public let id: String
    public let appId: String?
    public let title: String
    public let description: String
    public let status: String
    public let submitterId: String
    public let voteCount: Int
    public let commentCount: Int
    public let createdAt: String?
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, status
        case appId = "app_id"
        case submitterId = "submitter_id"
        case voteCount = "vote_count"
        case commentCount = "comment_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: String, appId: String? = nil, title: String, description: String, status: String, submitterId: String,
        voteCount: Int, commentCount: Int, createdAt: String? = nil, updatedAt: String? = nil
    ) {
        self.id = id
        self.appId = appId
        self.title = title
        self.description = description
        self.status = status
        self.submitterId = submitterId
        self.voteCount = voteCount
        self.commentCount = commentCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct OrgFeedbackComment: Codable, Sendable, Equatable {
    public let id: String
    public let authorId: String
    /// `user` or `admin`.
    public let authorType: String
    public let body: String
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, body
        case authorId = "author_id"
        case authorType = "author_type"
        case createdAt = "created_at"
    }

    public init(id: String, authorId: String, authorType: String, body: String, createdAt: String? = nil) {
        self.id = id
        self.authorId = authorId
        self.authorType = authorType
        self.body = body
        self.createdAt = createdAt
    }
}

public struct OrgFeatureRequestDetail: Codable, Sendable, Equatable {
    public let feature: OrgFeatureRequest
    public let comments: [OrgFeedbackComment]

    public init(feature: OrgFeatureRequest, comments: [OrgFeedbackComment]) {
        self.feature = feature
        self.comments = comments
    }
}

public struct OrgPage<Item: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public let items: [Item]
    public let page: Int
    public let per: Int
    public let total: Int

    public init(items: [Item], page: Int, per: Int, total: Int) {
        self.items = items
        self.page = page
        self.per = per
        self.total = total
    }
}

public struct OrgSupportTicket: Codable, Sendable, Equatable {
    public let id: String
    public let appId: String?
    public let subject: String
    public let status: String
    public let priority: String
    public let submitterId: String
    public let submitterEmail: String?
    public let messageCount: Int
    public let createdAt: String?
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, subject, status, priority
        case appId = "app_id"
        case submitterId = "submitter_id"
        case submitterEmail = "submitter_email"
        case messageCount = "message_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: String, appId: String? = nil, subject: String, status: String, priority: String, submitterId: String,
        submitterEmail: String? = nil, messageCount: Int, createdAt: String? = nil, updatedAt: String? = nil
    ) {
        self.id = id
        self.appId = appId
        self.subject = subject
        self.status = status
        self.priority = priority
        self.submitterId = submitterId
        self.submitterEmail = submitterEmail
        self.messageCount = messageCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public typealias OrgTicketMessage = OrgFeedbackComment

public struct OrgSupportTicketDetail: Codable, Sendable, Equatable {
    public let ticket: OrgSupportTicket
    public let messages: [OrgTicketMessage]

    public init(ticket: OrgSupportTicket, messages: [OrgTicketMessage]) {
        self.ticket = ticket
        self.messages = messages
    }
}

public struct OrgSetStatusRequest: Codable, Sendable, Equatable {
    public let status: String
    public init(status: String) { self.status = status }
}

public struct OrgSetPriorityRequest: Codable, Sendable, Equatable {
    public let priority: String
    public init(priority: String) { self.priority = priority }
}

public struct OrgMessageBodyRequest: Codable, Sendable, Equatable {
    public let body: String
    public init(body: String) { self.body = body }
}

public enum FeatureStatus: String, CaseIterable, Sendable {
    case pending, open, planned, inProgress = "in_progress", shipped, declined, duplicate
}

public enum TicketStatus: String, CaseIterable, Sendable {
    case open, awaitingReply = "awaiting_reply", resolved, closed
}

public enum TicketPriority: String, CaseIterable, Sendable {
    case low, normal, high, urgent
}

public enum FeedbackSort: String, CaseIterable, Sendable {
    case votes, newest, oldest
}

public struct FeedbackQuery: Sendable, Equatable {
    public var status: FeatureStatus?
    public var appId: String?
    public var search: String?
    public var sort: FeedbackSort?
    public var page: Int?
    public var per: Int?

    public init(status: FeatureStatus? = nil, appId: String? = nil, search: String? = nil, sort: FeedbackSort? = nil, page: Int? = nil, per: Int? = nil) {
        self.status = status
        self.appId = appId
        self.search = search
        self.sort = sort
        self.page = page
        self.per = per
    }
}

public struct SupportQuery: Sendable, Equatable {
    public var status: TicketStatus?
    public var priority: TicketPriority?
    public var appId: String?
    public var search: String?
    public var page: Int?
    public var per: Int?

    public init(status: TicketStatus? = nil, priority: TicketPriority? = nil, appId: String? = nil, search: String? = nil, page: Int? = nil, per: Int? = nil) {
        self.status = status
        self.priority = priority
        self.appId = appId
        self.search = search
        self.page = page
        self.per = per
    }
}

// MARK: - Endpoints

enum OrgFeedbackEndpoints {
    private static let feedback = "api/v1/org/feedback"
    private static let support = "api/v1/org/support"

    static func listFeatures(_ q: FeedbackQuery) -> Endpoint<EmptyBody, OrgPage<OrgFeatureRequest>> {
        var items: [URLQueryItem] = []
        if let status = q.status { items.append(URLQueryItem(name: "status", value: status.rawValue)) }
        if let appId = q.appId { items.append(URLQueryItem(name: "app_id", value: appId)) }
        if let search = q.search { items.append(URLQueryItem(name: "search", value: search)) }
        if let sort = q.sort { items.append(URLQueryItem(name: "sort", value: sort.rawValue)) }
        if let page = q.page { items.append(URLQueryItem(name: "page", value: String(page))) }
        if let per = q.per { items.append(URLQueryItem(name: "per", value: String(per))) }
        return Endpoint(path: feedback, method: .get, queryItems: items.isEmpty ? nil : items)
    }

    static func feature(_ id: String) -> Endpoint<EmptyBody, OrgFeatureRequestDetail> {
        Endpoint(path: "\(feedback)/\(EndpointPath.segment(id))", method: .get)
    }

    static func setFeatureStatus(_ id: String, body: OrgSetStatusRequest) -> Endpoint<OrgSetStatusRequest, OrgFeatureRequest> {
        Endpoint(path: "\(feedback)/\(EndpointPath.segment(id))/status", method: .post, body: body)
    }

    static func addFeatureComment(_ id: String, body: OrgMessageBodyRequest) -> Endpoint<OrgMessageBodyRequest, OrgFeedbackComment> {
        Endpoint(path: "\(feedback)/\(EndpointPath.segment(id))/comments", method: .post, body: body)
    }

    static func listTickets(_ q: SupportQuery) -> Endpoint<EmptyBody, OrgPage<OrgSupportTicket>> {
        var items: [URLQueryItem] = []
        if let status = q.status { items.append(URLQueryItem(name: "status", value: status.rawValue)) }
        if let priority = q.priority { items.append(URLQueryItem(name: "priority", value: priority.rawValue)) }
        if let appId = q.appId { items.append(URLQueryItem(name: "app_id", value: appId)) }
        if let search = q.search { items.append(URLQueryItem(name: "search", value: search)) }
        if let page = q.page { items.append(URLQueryItem(name: "page", value: String(page))) }
        if let per = q.per { items.append(URLQueryItem(name: "per", value: String(per))) }
        return Endpoint(path: support, method: .get, queryItems: items.isEmpty ? nil : items)
    }

    static func ticket(_ id: String) -> Endpoint<EmptyBody, OrgSupportTicketDetail> {
        Endpoint(path: "\(support)/\(EndpointPath.segment(id))", method: .get)
    }

    static func setTicketStatus(_ id: String, body: OrgSetStatusRequest) -> Endpoint<OrgSetStatusRequest, OrgSupportTicket> {
        Endpoint(path: "\(support)/\(EndpointPath.segment(id))/status", method: .post, body: body)
    }

    static func setTicketPriority(_ id: String, body: OrgSetPriorityRequest) -> Endpoint<OrgSetPriorityRequest, OrgSupportTicket> {
        Endpoint(path: "\(support)/\(EndpointPath.segment(id))/priority", method: .post, body: body)
    }

    static func addTicketMessage(_ id: String, body: OrgMessageBodyRequest) -> Endpoint<OrgMessageBodyRequest, OrgTicketMessage> {
        Endpoint(path: "\(support)/\(EndpointPath.segment(id))/messages", method: .post, body: body)
    }
}

// MARK: - FeedbackClient

/// API client for `grantiva console feedback` and `console support`.
public struct FeedbackClient: Sendable {
    public var listFeatures: @Sendable (FeedbackQuery) async throws -> OrgPage<OrgFeatureRequest>
    public var getFeature: @Sendable (_ id: String) async throws -> OrgFeatureRequestDetail
    public var setFeatureStatus: @Sendable (_ id: String, FeatureStatus) async throws -> OrgFeatureRequest
    public var addFeatureComment: @Sendable (_ id: String, _ body: String) async throws -> OrgFeedbackComment
    public var listTickets: @Sendable (SupportQuery) async throws -> OrgPage<OrgSupportTicket>
    public var getTicket: @Sendable (_ id: String) async throws -> OrgSupportTicketDetail
    public var setTicketStatus: @Sendable (_ id: String, TicketStatus) async throws -> OrgSupportTicket
    public var setTicketPriority: @Sendable (_ id: String, TicketPriority) async throws -> OrgSupportTicket
    public var addTicketMessage: @Sendable (_ id: String, _ body: String) async throws -> OrgTicketMessage

    public init(
        listFeatures: @escaping @Sendable (FeedbackQuery) async throws -> OrgPage<OrgFeatureRequest>,
        getFeature: @escaping @Sendable (String) async throws -> OrgFeatureRequestDetail,
        setFeatureStatus: @escaping @Sendable (String, FeatureStatus) async throws -> OrgFeatureRequest,
        addFeatureComment: @escaping @Sendable (String, String) async throws -> OrgFeedbackComment,
        listTickets: @escaping @Sendable (SupportQuery) async throws -> OrgPage<OrgSupportTicket>,
        getTicket: @escaping @Sendable (String) async throws -> OrgSupportTicketDetail,
        setTicketStatus: @escaping @Sendable (String, TicketStatus) async throws -> OrgSupportTicket,
        setTicketPriority: @escaping @Sendable (String, TicketPriority) async throws -> OrgSupportTicket,
        addTicketMessage: @escaping @Sendable (String, String) async throws -> OrgTicketMessage
    ) {
        self.listFeatures = listFeatures
        self.getFeature = getFeature
        self.setFeatureStatus = setFeatureStatus
        self.addFeatureComment = addFeatureComment
        self.listTickets = listTickets
        self.getTicket = getTicket
        self.setTicketStatus = setTicketStatus
        self.setTicketPriority = setTicketPriority
        self.addTicketMessage = addTicketMessage
    }

    public init(apiKey: String, baseURL: String) throws {
        let baseURL = try validatedAPIBaseURL(baseURL)
        let client = NetworkClient.authorized(apiKey: apiKey)
        self.init(
            listFeatures: { q in try await client.execute(OrgFeedbackEndpoints.listFeatures(q), baseURL: baseURL) },
            getFeature: { id in try await client.execute(OrgFeedbackEndpoints.feature(id), baseURL: baseURL) },
            setFeatureStatus: { id, status in
                try await client.execute(OrgFeedbackEndpoints.setFeatureStatus(id, body: OrgSetStatusRequest(status: status.rawValue)), baseURL: baseURL)
            },
            addFeatureComment: { id, body in
                try await client.execute(OrgFeedbackEndpoints.addFeatureComment(id, body: OrgMessageBodyRequest(body: body)), baseURL: baseURL)
            },
            listTickets: { q in try await client.execute(OrgFeedbackEndpoints.listTickets(q), baseURL: baseURL) },
            getTicket: { id in try await client.execute(OrgFeedbackEndpoints.ticket(id), baseURL: baseURL) },
            setTicketStatus: { id, status in
                try await client.execute(OrgFeedbackEndpoints.setTicketStatus(id, body: OrgSetStatusRequest(status: status.rawValue)), baseURL: baseURL)
            },
            setTicketPriority: { id, priority in
                try await client.execute(OrgFeedbackEndpoints.setTicketPriority(id, body: OrgSetPriorityRequest(priority: priority.rawValue)), baseURL: baseURL)
            },
            addTicketMessage: { id, body in
                try await client.execute(OrgFeedbackEndpoints.addTicketMessage(id, body: OrgMessageBodyRequest(body: body)), baseURL: baseURL)
            }
        )
    }

    public static let failing = FeedbackClient(
        listFeatures: { _ in throw GrantivaError.notAuthenticated },
        getFeature: { _ in throw GrantivaError.notAuthenticated },
        setFeatureStatus: { _, _ in throw GrantivaError.notAuthenticated },
        addFeatureComment: { _, _ in throw GrantivaError.notAuthenticated },
        listTickets: { _ in throw GrantivaError.notAuthenticated },
        getTicket: { _ in throw GrantivaError.notAuthenticated },
        setTicketStatus: { _, _ in throw GrantivaError.notAuthenticated },
        setTicketPriority: { _, _ in throw GrantivaError.notAuthenticated },
        addTicketMessage: { _, _ in throw GrantivaError.notAuthenticated }
    )
}
