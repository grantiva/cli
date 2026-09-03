import Foundation
import GrantivaCore

// MARK: - Org administration wire formats (§11 — camelCase, the dashboard's own)

public struct Webhook: Codable, Sendable, Equatable {
    public let id: String
    public let url: String
    public let events: [String]
    public let isActive: Bool
    public let description: String?
    public let createdAt: String?
    public let updatedAt: String?

    public init(id: String, url: String, events: [String], isActive: Bool, description: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.id = id; self.url = url; self.events = events; self.isActive = isActive
        self.description = description; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

public struct WebhookCreated: Codable, Sendable, Equatable {
    public let id: String
    public let url: String
    public let events: [String]
    public let isActive: Bool
    public let description: String?
    /// The signing secret. Returned only at creation time.
    public let secret: String
    public let createdAt: String?
}

public struct CreateWebhookRequest: Codable, Sendable, Equatable {
    public let url: String
    public let events: [String]
    public let description: String?
    public init(url: String, events: [String], description: String? = nil) { self.url = url; self.events = events; self.description = description }
}

public struct PatchWebhookRequest: Codable, Sendable, Equatable {
    public let isActive: Bool?
    public let events: [String]?
    public let description: String?
    public init(isActive: Bool? = nil, events: [String]? = nil, description: String? = nil) { self.isActive = isActive; self.events = events; self.description = description }
}

public struct WebhookTestResult: Codable, Sendable, Equatable {
    public let success: Bool
    public let httpStatus: Int?
    public let responseBody: String?
    public let latencyMs: Int
    public let error: String?
    public init(success: Bool, httpStatus: Int?, responseBody: String?, latencyMs: Int, error: String?) {
        self.success = success; self.httpStatus = httpStatus; self.responseBody = responseBody; self.latencyMs = latencyMs; self.error = error
    }
}

public struct WebhookDelivery: Codable, Sendable, Equatable {
    public let id: String
    public let webhookId: String
    public let eventType: String
    public let status: String
    public let httpStatus: Int?
    public let responseBody: String?
    public let error: String?
    public let attemptCount: Int
    public let nextRetryAt: String?
    public let deliveredAt: String?
    public let createdAt: String?
}

/// The event types the server delivers.
public enum WebhookEvent: String, CaseIterable, Sendable {
    case deviceHighRisk = "device.high_risk"
    case deviceAttestationFailed = "device.attestation_failed"
    case deviceNew = "device.new"
    case deviceAttestedFirst = "device.attested.first"
    case attestationAnomaly = "attestation.anomaly"
    case flagUpdated = "flag.updated"
    case flagCreated = "flag.created"
    case flagDeleted = "flag.deleted"
    case subscriptionChanged = "subscription.changed"
    case subscriptionExpired = "subscription.expired"
    case subscriptionRefunded = "subscription.refunded"
}

public struct RiskAlertRule: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let threshold: Int
    public let comparison: String
    public let webhookUrl: String
    public let isActive: Bool
    public let createdAt: String?
}

public struct CreateRiskAlertRuleRequest: Codable, Sendable, Equatable {
    public let name: String
    public let threshold: Int
    public let comparison: String
    public let webhookUrl: String
    public init(name: String, threshold: Int, comparison: String, webhookUrl: String) { self.name = name; self.threshold = threshold; self.comparison = comparison; self.webhookUrl = webhookUrl }
}

public struct PatchRiskAlertRuleRequest: Codable, Sendable, Equatable {
    public let name: String?
    public let threshold: Int?
    public let comparison: String?
    public let webhookUrl: String?
    public let isActive: Bool?
    public init(name: String? = nil, threshold: Int? = nil, comparison: String? = nil, webhookUrl: String? = nil, isActive: Bool? = nil) {
        self.name = name; self.threshold = threshold; self.comparison = comparison; self.webhookUrl = webhookUrl; self.isActive = isActive
    }
}

public struct RiskAlertDelivery: Codable, Sendable, Equatable {
    public let id: String
    public let ruleId: String
    public let deviceId: String
    public let riskScore: Int
    public let status: String
    public let attemptCount: Int
    public let httpStatus: Int?
    public let error: String?
    public let deliveredAt: String?
    public let createdAt: String?
}

public struct FailureRateAlert: Codable, Sendable, Equatable {
    public let id: String
    public let isEnabled: Bool
    public let threshold: Int
    public let minAttestationCount: Int
    public let lastAlertedAt: String?
    public let createdAt: String?
    public let updatedAt: String?
}

public struct PatchFailureRateAlertRequest: Codable, Sendable, Equatable {
    public let isEnabled: Bool?
    public let threshold: Int?
    public let minAttestationCount: Int?
    public init(isEnabled: Bool? = nil, threshold: Int? = nil, minAttestationCount: Int? = nil) { self.isEnabled = isEnabled; self.threshold = threshold; self.minAttestationCount = minAttestationCount }
}

public struct FailureRateAlertEvent: Codable, Sendable, Equatable {
    public let id: String
    public let failureRate: Double
    public let attestationCount: Int
    public let triggeredAt: String?
}

public struct NotificationPreferences: Codable, Sendable, Equatable {
    public let newFeatureRequest: Bool
    public let featureVoteThreshold: Bool
    public let featureVoteThresholdCount: Int
    public let featureStatusChange: Bool
    public let newSupportTicket: Bool
    public let ticketAdminReply: Bool
    public let ticketResolved: Bool
    public let ticketUserReply: Bool
    public let flagToggle: Bool
    public let teamInvite: Bool
    public let usageAlert: Bool

    public init(newFeatureRequest: Bool, featureVoteThreshold: Bool, featureVoteThresholdCount: Int, featureStatusChange: Bool, newSupportTicket: Bool, ticketAdminReply: Bool, ticketResolved: Bool, ticketUserReply: Bool, flagToggle: Bool, teamInvite: Bool, usageAlert: Bool) {
        self.newFeatureRequest = newFeatureRequest; self.featureVoteThreshold = featureVoteThreshold; self.featureVoteThresholdCount = featureVoteThresholdCount
        self.featureStatusChange = featureStatusChange; self.newSupportTicket = newSupportTicket; self.ticketAdminReply = ticketAdminReply
        self.ticketResolved = ticketResolved; self.ticketUserReply = ticketUserReply; self.flagToggle = flagToggle; self.teamInvite = teamInvite; self.usageAlert = usageAlert
    }
}

/// Partial update; every field optional. Encoded as a dictionary so the
/// CLI can set arbitrary preference keys by name.
public struct PatchNotificationPreferencesRequest: Codable, Sendable, Equatable {
    public let values: [String: JSONValue]
    public init(values: [String: JSONValue]) { self.values = values }
    public init(from decoder: Decoder) throws { values = try [String: JSONValue](from: decoder) }
    public func encode(to encoder: Encoder) throws { try values.encode(to: encoder) }
}

public struct APIKeySummary: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let keyPrefix: String
    public let scopes: [String]
    public let keyType: String?
    public let isActive: Bool
    public let lastUsedAt: String?
    public let expiresAt: String?
    public let createdAt: String?
}

public struct APIKeyCreated: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let keyPrefix: String
    /// Shown once.
    public let rawKey: String
    public let scopes: [String]
    public let keyType: String?
    public let isActive: Bool
    public let expiresAt: String?
    public let createdAt: String?
}

public struct CreateAPIKeyRequest: Codable, Sendable, Equatable {
    public let name: String
    public let scopes: [String]
    public let expiresAt: String?
    public init(name: String, scopes: [String], expiresAt: String? = nil) { self.name = name; self.scopes = scopes; self.expiresAt = expiresAt }
}

public struct RotateAPIKeyRequest: Codable, Sendable, Equatable {
    public let gracePeriodDays: Int?
    public init(gracePeriodDays: Int? = nil) { self.gracePeriodDays = gracePeriodDays }
}

public struct OrgMember: Codable, Sendable, Equatable {
    public let id: String
    public let userId: String
    public let email: String
    public let orgRole: String
    public let joinedAt: String
}

public struct OrgInvite: Codable, Sendable, Equatable {
    public let id: String
    public let email: String
    public let orgRole: String?
    public let status: String
    public let invitedBy: String?
    public let expiresAt: String
    public let createdAt: String?
}

public struct InviteRequest: Codable, Sendable, Equatable {
    public let email: String
    public let orgRole: String?
    public init(email: String, orgRole: String? = nil) { self.email = email; self.orgRole = orgRole }
}

public struct AuditEntry: Codable, Sendable, Equatable {
    public let id: String
    public let actorEmail: String
    public let action: String
    public let resourceType: String
    public let resourceId: String?
    public let metadata: [String: String]?
    public let ipAddress: String?
    public let createdAt: String?
    public init(id: String, actorEmail: String, action: String, resourceType: String, resourceId: String?, metadata: [String: String]?, ipAddress: String?, createdAt: String?) {
        self.id = id; self.actorEmail = actorEmail; self.action = action; self.resourceType = resourceType
        self.resourceId = resourceId; self.metadata = metadata; self.ipAddress = ipAddress; self.createdAt = createdAt
    }
}

public struct PaginatedItems<Item: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public struct Metadata: Codable, Sendable, Equatable {
        public let page: Int
        public let per: Int
        public let total: Int
        public init(page: Int, per: Int, total: Int) { self.page = page; self.per = per; self.total = total }
    }
    public let items: [Item]
    public let metadata: Metadata
    public init(items: [Item], metadata: Metadata) { self.items = items; self.metadata = metadata }
}

public struct OrgSettings: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let slug: String
    public let serviceTier: String
    public let serviceTierRawValue: String
    public let billingEmail: String?
    public let createdAt: String?
    public let updatedAt: String?
}

public struct UpdateSettingsRequest: Codable, Sendable, Equatable {
    public let name: String?
    public init(name: String?) { self.name = name }
}

public struct OrgUsage: Codable, Sendable, Equatable {
    public let currentMAD: Int
    public let tierLimit: Int?
    public let tierName: String
    public let billingPeriodStart: String
    public let billingPeriodEnd: String
    public let usagePercent: Double?
    public let daysUntilReset: Int?
    public let resetDate: String
    public init(currentMAD: Int, tierLimit: Int?, tierName: String, billingPeriodStart: String, billingPeriodEnd: String, usagePercent: Double?, daysUntilReset: Int?, resetDate: String) {
        self.currentMAD = currentMAD; self.tierLimit = tierLimit; self.tierName = tierName; self.billingPeriodStart = billingPeriodStart
        self.billingPeriodEnd = billingPeriodEnd; self.usagePercent = usagePercent; self.daysUntilReset = daysUntilReset; self.resetDate = resetDate
    }
}

public struct OrgBilling: Codable, Sendable, Equatable {
    public let plan: String
    public let planRawValue: String
    public let madUsed: Int
    public let madLimit: Int?
    public let currentPeriodEnd: String?
    public let stripeCustomerId: String?
    public let stripeSubscriptionId: String?
}

// MARK: - Endpoints

enum OrgAdminEndpoints {
    private static let prefix = "api/v1/org"

    static func listWebhooks() -> Endpoint<EmptyBody, [Webhook]> { Endpoint(path: "\(prefix)/webhooks", method: .get) }
    static func createWebhook(_ body: CreateWebhookRequest) -> Endpoint<CreateWebhookRequest, WebhookCreated> { Endpoint(path: "\(prefix)/webhooks", method: .post, body: body) }
    static func patchWebhook(_ id: String, _ body: PatchWebhookRequest) -> Endpoint<PatchWebhookRequest, Webhook> { Endpoint(path: "\(prefix)/webhooks/\(EndpointPath.segment(id))", method: .patch, body: body) }
    static func deleteWebhook(_ id: String) -> Endpoint<EmptyBody, EmptyResponse> { Endpoint(path: "\(prefix)/webhooks/\(EndpointPath.segment(id))", method: .delete) }
    static func testWebhook(_ id: String) -> Endpoint<EmptyBody, WebhookTestResult> { Endpoint(path: "\(prefix)/webhooks/\(EndpointPath.segment(id))/test", method: .post) }
    static func deliveries(_ id: String) -> Endpoint<EmptyBody, [WebhookDelivery]> { Endpoint(path: "\(prefix)/webhooks/\(EndpointPath.segment(id))/deliveries", method: .get) }
    static func retry(_ id: String, _ deliveryId: String) -> Endpoint<EmptyBody, WebhookDelivery> { Endpoint(path: "\(prefix)/webhooks/\(EndpointPath.segment(id))/deliveries/\(EndpointPath.segment(deliveryId))/retry", method: .post) }

    static func listRules() -> Endpoint<EmptyBody, [RiskAlertRule]> { Endpoint(path: "\(prefix)/risk-alerts/rules", method: .get) }
    static func createRule(_ body: CreateRiskAlertRuleRequest) -> Endpoint<CreateRiskAlertRuleRequest, RiskAlertRule> { Endpoint(path: "\(prefix)/risk-alerts/rules", method: .post, body: body) }
    static func patchRule(_ id: String, _ body: PatchRiskAlertRuleRequest) -> Endpoint<PatchRiskAlertRuleRequest, RiskAlertRule> { Endpoint(path: "\(prefix)/risk-alerts/rules/\(EndpointPath.segment(id))", method: .patch, body: body) }
    static func deleteRule(_ id: String) -> Endpoint<EmptyBody, EmptyResponse> { Endpoint(path: "\(prefix)/risk-alerts/rules/\(EndpointPath.segment(id))", method: .delete) }
    static func ruleDeliveries() -> Endpoint<EmptyBody, [RiskAlertDelivery]> { Endpoint(path: "\(prefix)/risk-alerts/deliveries", method: .get) }
    static func failureRate() -> Endpoint<EmptyBody, FailureRateAlert> { Endpoint(path: "\(prefix)/alerts/failure-rate", method: .get) }
    static func patchFailureRate(_ body: PatchFailureRateAlertRequest) -> Endpoint<PatchFailureRateAlertRequest, FailureRateAlert> { Endpoint(path: "\(prefix)/alerts/failure-rate", method: .patch, body: body) }
    static func failureRateHistory() -> Endpoint<EmptyBody, [FailureRateAlertEvent]> { Endpoint(path: "\(prefix)/alerts/failure-rate/history", method: .get) }
    static func notificationPreferences() -> Endpoint<EmptyBody, NotificationPreferences> { Endpoint(path: "\(prefix)/notification-preferences", method: .get) }
    static func patchNotificationPreferences(_ body: PatchNotificationPreferencesRequest) -> Endpoint<PatchNotificationPreferencesRequest, NotificationPreferences> { Endpoint(path: "\(prefix)/notification-preferences", method: .patch, body: body) }

    static func listKeys() -> Endpoint<EmptyBody, [APIKeySummary]> { Endpoint(path: "\(prefix)/api-keys", method: .get) }
    static func createKey(_ body: CreateAPIKeyRequest) -> Endpoint<CreateAPIKeyRequest, APIKeyCreated> { Endpoint(path: "\(prefix)/api-keys", method: .post, body: body) }
    static func rotateKey(_ id: String, _ body: RotateAPIKeyRequest) -> Endpoint<RotateAPIKeyRequest, APIKeyCreated> { Endpoint(path: "\(prefix)/api-keys/\(EndpointPath.segment(id))/rotate", method: .post, body: body) }
    static func revokeKey(_ id: String) -> Endpoint<EmptyBody, EmptyResponse> { Endpoint(path: "\(prefix)/api-keys/\(EndpointPath.segment(id))/revoke", method: .post) }

    static func members() -> Endpoint<EmptyBody, [OrgMember]> { Endpoint(path: "\(prefix)/members", method: .get) }
    static func invites() -> Endpoint<EmptyBody, [OrgInvite]> { Endpoint(path: "\(prefix)/invites", method: .get) }
    static func invite(_ body: InviteRequest) -> Endpoint<InviteRequest, OrgInvite> { Endpoint(path: "\(prefix)/invite", method: .post, body: body) }
    static func revokeInvite(_ id: String) -> Endpoint<EmptyBody, EmptyResponse> { Endpoint(path: "\(prefix)/invites/\(EndpointPath.segment(id))", method: .delete) }
    static func removeMember(_ membershipId: String) -> Endpoint<EmptyBody, EmptyResponse> { Endpoint(path: "\(prefix)/members/\(EndpointPath.segment(membershipId))/remove", method: .post) }

    static func auditLog(page: Int?, per: Int?) -> Endpoint<EmptyBody, PaginatedItems<AuditEntry>> {
        var items: [URLQueryItem] = []
        if let page { items.append(URLQueryItem(name: "page", value: String(page))) }
        if let per { items.append(URLQueryItem(name: "per", value: String(per))) }
        return Endpoint(path: "\(prefix)/audit-log", method: .get, queryItems: items.isEmpty ? nil : items)
    }
    static func settings() -> Endpoint<EmptyBody, OrgSettings> { Endpoint(path: "\(prefix)/settings", method: .get) }
    static func updateSettings(_ body: UpdateSettingsRequest) -> Endpoint<UpdateSettingsRequest, OrgSettings> { Endpoint(path: "\(prefix)/settings", method: .put, body: body) }
    static func usage() -> Endpoint<EmptyBody, OrgUsage> { Endpoint(path: "\(prefix)/usage", method: .get) }
    static func billing() -> Endpoint<EmptyBody, OrgBilling> { Endpoint(path: "\(prefix)/billing", method: .get) }
}

// MARK: - OrgAdminClient

/// API client for `console webhooks|alerts|keys|team|audit|org`.
public struct OrgAdminClient: Sendable {
    public var listWebhooks: @Sendable () async throws -> [Webhook]
    public var createWebhook: @Sendable (CreateWebhookRequest) async throws -> WebhookCreated
    public var patchWebhook: @Sendable (String, PatchWebhookRequest) async throws -> Webhook
    public var deleteWebhook: @Sendable (String) async throws -> Void
    public var testWebhook: @Sendable (String) async throws -> WebhookTestResult
    public var deliveries: @Sendable (String) async throws -> [WebhookDelivery]
    public var retryDelivery: @Sendable (String, String) async throws -> WebhookDelivery

    public var listRules: @Sendable () async throws -> [RiskAlertRule]
    public var createRule: @Sendable (CreateRiskAlertRuleRequest) async throws -> RiskAlertRule
    public var patchRule: @Sendable (String, PatchRiskAlertRuleRequest) async throws -> RiskAlertRule
    public var deleteRule: @Sendable (String) async throws -> Void
    public var ruleDeliveries: @Sendable () async throws -> [RiskAlertDelivery]
    public var failureRate: @Sendable () async throws -> FailureRateAlert
    public var patchFailureRate: @Sendable (PatchFailureRateAlertRequest) async throws -> FailureRateAlert
    public var failureRateHistory: @Sendable () async throws -> [FailureRateAlertEvent]
    public var notificationPreferences: @Sendable () async throws -> NotificationPreferences
    public var patchNotificationPreferences: @Sendable (PatchNotificationPreferencesRequest) async throws -> NotificationPreferences

    public var listKeys: @Sendable () async throws -> [APIKeySummary]
    public var createKey: @Sendable (CreateAPIKeyRequest) async throws -> APIKeyCreated
    public var rotateKey: @Sendable (String, RotateAPIKeyRequest) async throws -> APIKeyCreated
    public var revokeKey: @Sendable (String) async throws -> Void

    public var members: @Sendable () async throws -> [OrgMember]
    public var invites: @Sendable () async throws -> [OrgInvite]
    public var invite: @Sendable (InviteRequest) async throws -> OrgInvite
    public var revokeInvite: @Sendable (String) async throws -> Void
    public var removeMember: @Sendable (String) async throws -> Void

    public var auditLog: @Sendable (Int?, Int?) async throws -> PaginatedItems<AuditEntry>
    public var settings: @Sendable () async throws -> OrgSettings
    public var updateSettings: @Sendable (UpdateSettingsRequest) async throws -> OrgSettings
    public var usage: @Sendable () async throws -> OrgUsage
    public var billing: @Sendable () async throws -> OrgBilling

    public init(apiKey: String, baseURL: String) {
        let baseURL = URL(string: baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL)!
        let client = NetworkClient.authorized(apiKey: apiKey)
        listWebhooks = { try await client.execute(OrgAdminEndpoints.listWebhooks(), baseURL: baseURL) }
        createWebhook = { try await client.execute(OrgAdminEndpoints.createWebhook($0), baseURL: baseURL) }
        patchWebhook = { id, body in try await client.execute(OrgAdminEndpoints.patchWebhook(id, body), baseURL: baseURL) }
        deleteWebhook = { _ = try await client.execute(OrgAdminEndpoints.deleteWebhook($0), baseURL: baseURL) }
        testWebhook = { try await client.execute(OrgAdminEndpoints.testWebhook($0), baseURL: baseURL) }
        deliveries = { try await client.execute(OrgAdminEndpoints.deliveries($0), baseURL: baseURL) }
        retryDelivery = { id, d in try await client.execute(OrgAdminEndpoints.retry(id, d), baseURL: baseURL) }
        listRules = { try await client.execute(OrgAdminEndpoints.listRules(), baseURL: baseURL) }
        createRule = { try await client.execute(OrgAdminEndpoints.createRule($0), baseURL: baseURL) }
        patchRule = { id, body in try await client.execute(OrgAdminEndpoints.patchRule(id, body), baseURL: baseURL) }
        deleteRule = { _ = try await client.execute(OrgAdminEndpoints.deleteRule($0), baseURL: baseURL) }
        ruleDeliveries = { try await client.execute(OrgAdminEndpoints.ruleDeliveries(), baseURL: baseURL) }
        failureRate = { try await client.execute(OrgAdminEndpoints.failureRate(), baseURL: baseURL) }
        patchFailureRate = { try await client.execute(OrgAdminEndpoints.patchFailureRate($0), baseURL: baseURL) }
        failureRateHistory = { try await client.execute(OrgAdminEndpoints.failureRateHistory(), baseURL: baseURL) }
        notificationPreferences = { try await client.execute(OrgAdminEndpoints.notificationPreferences(), baseURL: baseURL) }
        patchNotificationPreferences = { try await client.execute(OrgAdminEndpoints.patchNotificationPreferences($0), baseURL: baseURL) }
        listKeys = { try await client.execute(OrgAdminEndpoints.listKeys(), baseURL: baseURL) }
        createKey = { try await client.execute(OrgAdminEndpoints.createKey($0), baseURL: baseURL) }
        rotateKey = { id, body in try await client.execute(OrgAdminEndpoints.rotateKey(id, body), baseURL: baseURL) }
        revokeKey = { _ = try await client.execute(OrgAdminEndpoints.revokeKey($0), baseURL: baseURL) }
        members = { try await client.execute(OrgAdminEndpoints.members(), baseURL: baseURL) }
        invites = { try await client.execute(OrgAdminEndpoints.invites(), baseURL: baseURL) }
        invite = { try await client.execute(OrgAdminEndpoints.invite($0), baseURL: baseURL) }
        revokeInvite = { _ = try await client.execute(OrgAdminEndpoints.revokeInvite($0), baseURL: baseURL) }
        removeMember = { _ = try await client.execute(OrgAdminEndpoints.removeMember($0), baseURL: baseURL) }
        auditLog = { page, per in try await client.execute(OrgAdminEndpoints.auditLog(page: page, per: per), baseURL: baseURL) }
        settings = { try await client.execute(OrgAdminEndpoints.settings(), baseURL: baseURL) }
        updateSettings = { try await client.execute(OrgAdminEndpoints.updateSettings($0), baseURL: baseURL) }
        usage = { try await client.execute(OrgAdminEndpoints.usage(), baseURL: baseURL) }
        billing = { try await client.execute(OrgAdminEndpoints.billing(), baseURL: baseURL) }
    }

    /// Every call throws `notAuthenticated`; tests override the members they need.
    public static var failing: OrgAdminClient { OrgAdminClient(apiKey: "", baseURL: "https://failing.invalid", failing: true) }

    private init(apiKey: String, baseURL: String, failing: Bool) {
        listWebhooks = { throw GrantivaError.notAuthenticated }
        createWebhook = { _ in throw GrantivaError.notAuthenticated }
        patchWebhook = { _, _ in throw GrantivaError.notAuthenticated }
        deleteWebhook = { _ in throw GrantivaError.notAuthenticated }
        testWebhook = { _ in throw GrantivaError.notAuthenticated }
        deliveries = { _ in throw GrantivaError.notAuthenticated }
        retryDelivery = { _, _ in throw GrantivaError.notAuthenticated }
        listRules = { throw GrantivaError.notAuthenticated }
        createRule = { _ in throw GrantivaError.notAuthenticated }
        patchRule = { _, _ in throw GrantivaError.notAuthenticated }
        deleteRule = { _ in throw GrantivaError.notAuthenticated }
        ruleDeliveries = { throw GrantivaError.notAuthenticated }
        failureRate = { throw GrantivaError.notAuthenticated }
        patchFailureRate = { _ in throw GrantivaError.notAuthenticated }
        failureRateHistory = { throw GrantivaError.notAuthenticated }
        notificationPreferences = { throw GrantivaError.notAuthenticated }
        patchNotificationPreferences = { _ in throw GrantivaError.notAuthenticated }
        listKeys = { throw GrantivaError.notAuthenticated }
        createKey = { _ in throw GrantivaError.notAuthenticated }
        rotateKey = { _, _ in throw GrantivaError.notAuthenticated }
        revokeKey = { _ in throw GrantivaError.notAuthenticated }
        members = { throw GrantivaError.notAuthenticated }
        invites = { throw GrantivaError.notAuthenticated }
        invite = { _ in throw GrantivaError.notAuthenticated }
        revokeInvite = { _ in throw GrantivaError.notAuthenticated }
        removeMember = { _ in throw GrantivaError.notAuthenticated }
        auditLog = { _, _ in throw GrantivaError.notAuthenticated }
        settings = { throw GrantivaError.notAuthenticated }
        updateSettings = { _ in throw GrantivaError.notAuthenticated }
        usage = { throw GrantivaError.notAuthenticated }
        billing = { throw GrantivaError.notAuthenticated }
    }
}
