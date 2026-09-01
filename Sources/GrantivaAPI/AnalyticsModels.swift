import Foundation

// MARK: - Analytics Wire Formats
//
// The analytics endpoints (`/api/v1/analytics/*`) are pre-existing SDK/server
// endpoints and speak Vapor's default camelCase, so property names here match
// the wire keys directly. Dates arrive as ISO 8601 strings without fractional
// seconds and are kept as strings: the CLI prints them, it never does date
// arithmetic on them.
//
// One exception is called out below: the device profile embedded in
// `/api/v1/analytics/devices/:keyId` is a raw Fluent model and serializes with
// its snake_case column names.

// MARK: - Events

/// One attestation lifecycle event. Shared by overview, events, risk and
/// device detail responses.
public struct AttestationEventResponse: Codable, Sendable, Equatable {
    public let id: String
    /// `challenge_generated`, `attestation_validated`, `attestation_failed`,
    /// `suspicious_activity`, or `token_issued`.
    public let eventType: String
    public let keyId: String
    public let deviceId: String?
    public let ipAddress: String
    public let success: Bool
    public let errorReason: String?
    public let riskScore: Int
    public let createdAt: String

    public init(
        id: String, eventType: String, keyId: String, deviceId: String? = nil, ipAddress: String,
        success: Bool, errorReason: String? = nil, riskScore: Int, createdAt: String
    ) {
        self.id = id
        self.eventType = eventType
        self.keyId = keyId
        self.deviceId = deviceId
        self.ipAddress = ipAddress
        self.success = success
        self.errorReason = errorReason
        self.riskScore = riskScore
        self.createdAt = createdAt
    }
}

/// The event types `/api/v1/analytics/events?eventType=` accepts. The server
/// silently ignores an unknown value, so the CLI validates before sending.
public enum AttestationEventType: String, CaseIterable, Sendable {
    case challengeGenerated = "challenge_generated"
    case attestationValidated = "attestation_validated"
    case attestationFailed = "attestation_failed"
    case suspiciousActivity = "suspicious_activity"
    case tokenIssued = "token_issued"
}

// MARK: - Overview

/// `GET /api/v1/analytics/overview`. Statistics are computed by the server
/// over the most recent 100 events in the window, not the full total.
public struct AttestationAnalytics: Codable, Sendable {
    public let totalAttestations: Int
    public let successfulAttestations: Int
    public let failedAttestations: Int
    /// Percentage, 0–100.
    public let successRate: Double
    public let uniqueDevices: Int
    public let averageRiskScore: Double
    public let suspiciousEvents: Int
    public let recentEvents: [AttestationEventResponse]

    public init(
        totalAttestations: Int, successfulAttestations: Int, failedAttestations: Int, successRate: Double,
        uniqueDevices: Int, averageRiskScore: Double, suspiciousEvents: Int, recentEvents: [AttestationEventResponse]
    ) {
        self.totalAttestations = totalAttestations
        self.successfulAttestations = successfulAttestations
        self.failedAttestations = failedAttestations
        self.successRate = successRate
        self.uniqueDevices = uniqueDevices
        self.averageRiskScore = averageRiskScore
        self.suspiciousEvents = suspiciousEvents
        self.recentEvents = recentEvents
    }
}

// MARK: - Events (paginated)

public struct PaginationMeta: Codable, Sendable, Equatable {
    public let page: Int
    public let perPage: Int
    public let total: Int
    public let totalPages: Int

    public init(page: Int, perPage: Int, total: Int, totalPages: Int) {
        self.page = page
        self.perPage = perPage
        self.total = total
        self.totalPages = totalPages
    }
}

/// `GET /api/v1/analytics/events` — enveloped as `{data, meta}`.
public struct PaginatedEventsResponse: Codable, Sendable {
    public let data: [AttestationEventResponse]
    public let meta: PaginationMeta

    public init(data: [AttestationEventResponse], meta: PaginationMeta) {
        self.data = data
        self.meta = meta
    }
}

/// Query for `/api/v1/analytics/events`. All fields optional; the server
/// defaults page to 1 and perPage to 50 (clamped 1…200).
public struct EventsQuery: Sendable, Equatable {
    public var page: Int?
    public var perPage: Int?
    /// ISO 8601 lower bound (inclusive).
    public var from: String?
    /// ISO 8601 upper bound (inclusive).
    public var to: String?
    public var deviceId: String?
    public var eventType: AttestationEventType?

    public init(
        page: Int? = nil, perPage: Int? = nil, from: String? = nil, to: String? = nil,
        deviceId: String? = nil, eventType: AttestationEventType? = nil
    ) {
        self.page = page
        self.perPage = perPage
        self.from = from
        self.to = to
        self.deviceId = deviceId
        self.eventType = eventType
    }
}

// MARK: - Time ranges

/// The windows the risk, compliance and export endpoints accept. The server
/// silently falls back on anything else, so the CLI validates first.
public enum AnalyticsTimeRange: String, CaseIterable, Sendable {
    case day = "1d"
    case week = "7d"
    case month = "30d"
    case quarter = "90d"
}

// MARK: - Risk

/// `GET /api/v1/analytics/risk`.
public struct RiskAssessmentReport: Codable, Sendable {
    public let tenantId: String
    /// A two-element `[start, end]` array of ISO 8601 timestamps — how Swift
    /// encodes `ClosedRange<Date>`.
    public let period: [String]
    public let totalDevices: Int
    public let averageRiskScore: Double
    /// Keys `low`, `medium`, `high`, `critical`; all four are always present.
    public let riskDistribution: [String: Int]
    /// Devices in the critical band (score ≥ 76).
    public let highRiskDevices: [HighRiskDevice]
    /// Up to 20 most recent `suspicious_activity` events in the window.
    public let recentSecurityEvents: [SecurityEventSummary]
    public let generatedAt: String

    public init(
        tenantId: String, period: [String], totalDevices: Int, averageRiskScore: Double,
        riskDistribution: [String: Int], highRiskDevices: [HighRiskDevice],
        recentSecurityEvents: [SecurityEventSummary], generatedAt: String
    ) {
        self.tenantId = tenantId
        self.period = period
        self.totalDevices = totalDevices
        self.averageRiskScore = averageRiskScore
        self.riskDistribution = riskDistribution
        self.highRiskDevices = highRiskDevices
        self.recentSecurityEvents = recentSecurityEvents
        self.generatedAt = generatedAt
    }
}

public struct HighRiskDevice: Codable, Sendable, Equatable {
    public let keyId: String
    public let deviceModel: String?
    public let riskScore: Int
    public let jailbreakDetected: Bool
    public let suspiciousEvents: Int
    public let lastAttestation: String

    public init(
        keyId: String, deviceModel: String? = nil, riskScore: Int, jailbreakDetected: Bool,
        suspiciousEvents: Int, lastAttestation: String
    ) {
        self.keyId = keyId
        self.deviceModel = deviceModel
        self.riskScore = riskScore
        self.jailbreakDetected = jailbreakDetected
        self.suspiciousEvents = suspiciousEvents
        self.lastAttestation = lastAttestation
    }
}

public struct SecurityEventSummary: Codable, Sendable, Equatable {
    public let eventType: String
    public let keyId: String
    public let riskScore: Int
    public let timestamp: String

    public init(eventType: String, keyId: String, riskScore: Int, timestamp: String) {
        self.eventType = eventType
        self.keyId = keyId
        self.riskScore = riskScore
        self.timestamp = timestamp
    }
}

// MARK: - Compliance

/// `GET /api/v1/analytics/compliance`. `deviceCompliance` carries one entry
/// per device in the org (server cap 10 000) — there is no pagination.
public struct ComplianceReport: Codable, Sendable {
    public let tenantId: String
    /// Echo of the `type` query parameter; does not change the report.
    public let reportType: String
    /// `[start, end]` ISO 8601 pair.
    public let period: [String]
    public let totalDevices: Int
    public let compliantDevices: Int
    public let nonCompliantDevices: Int
    /// Percentage, 0–100.
    public let complianceRate: Double
    /// Violation description → number of devices, e.g. `"jailbreakDetected": 3`.
    public let violationSummary: [String: Int]
    public let deviceCompliance: [DeviceComplianceStatus]
    public let generatedAt: String

    public init(
        tenantId: String, reportType: String, period: [String], totalDevices: Int, compliantDevices: Int,
        nonCompliantDevices: Int, complianceRate: Double, violationSummary: [String: Int],
        deviceCompliance: [DeviceComplianceStatus], generatedAt: String
    ) {
        self.tenantId = tenantId
        self.reportType = reportType
        self.period = period
        self.totalDevices = totalDevices
        self.compliantDevices = compliantDevices
        self.nonCompliantDevices = nonCompliantDevices
        self.complianceRate = complianceRate
        self.violationSummary = violationSummary
        self.deviceCompliance = deviceCompliance
        self.generatedAt = generatedAt
    }
}

public struct DeviceComplianceStatus: Codable, Sendable, Equatable {
    public let keyId: String
    public let deviceModel: String?
    public let osVersion: String?
    public let isCompliant: Bool
    public let complianceScore: Int
    /// Violation descriptions as the server renders them, e.g.
    /// `jailbreakDetected`, `outdatedOS("16.0")`.
    public let violations: [String]
    public let lastChecked: String

    public init(
        keyId: String, deviceModel: String? = nil, osVersion: String? = nil, isCompliant: Bool,
        complianceScore: Int, violations: [String], lastChecked: String
    ) {
        self.keyId = keyId
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.isCompliant = isCompliant
        self.complianceScore = complianceScore
        self.violations = violations
        self.lastChecked = lastChecked
    }
}

// MARK: - Export

/// The datasets `/api/v1/analytics/export?data=` can produce. Output is
/// always CSV.
public enum AnalyticsExportData: String, CaseIterable, Sendable {
    case devices
    case events
}

// MARK: - Device detail

/// `GET /api/v1/analytics/devices/:keyId`.
public struct DeviceDetailsResponse: Codable, Sendable {
    public let keyId: String
    public let deviceProfile: DeviceProfile
    /// Up to 50 most recent events for this key.
    public let recentEvents: [AttestationEventResponse]
    public let complianceStatus: ComplianceResult
    public let lastUpdated: String

    public init(
        keyId: String, deviceProfile: DeviceProfile, recentEvents: [AttestationEventResponse],
        complianceStatus: ComplianceResult, lastUpdated: String
    ) {
        self.keyId = keyId
        self.deviceProfile = deviceProfile
        self.recentEvents = recentEvents
        self.complianceStatus = complianceStatus
        self.lastUpdated = lastUpdated
    }
}

/// The server's stored profile for one attested key. This is the one
/// snake_case object on the analytics surface: it is a raw database model
/// and serializes with its column names.
public struct DeviceProfile: Codable, Sendable {
    public let id: String
    public let keyId: String
    public let firstSeen: String
    public let lastAttestation: String
    public let attestationCount: Int
    public let riskScore: Int
    public let deviceModel: String?
    public let osVersion: String?
    public let appVersion: String?
    public let firstAppVersion: String?
    public let jailbreakDetected: Bool
    public let isDevelopmentBuild: Bool?
    public let appStoreReceipt: Bool?
    public let permissions: [String]?
    public let lastCountry: String?
    public let suspiciousEvents: Int
    public let lastSuspiciousEventAt: String?
    public let consecutiveCleanAttestations: Int?
    public let deviceFingerprint: String?
    public let subjectId: String?
    public let createdAt: String?
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case keyId = "key_id"
        case firstSeen = "first_seen"
        case lastAttestation = "last_attestation"
        case attestationCount = "attestation_count"
        case riskScore = "risk_score"
        case deviceModel = "device_model"
        case osVersion = "os_version"
        case appVersion = "app_version"
        case firstAppVersion = "first_app_version"
        case jailbreakDetected = "jailbreak_detected"
        case isDevelopmentBuild = "is_development_build"
        case appStoreReceipt = "app_store_receipt"
        case permissions
        case lastCountry = "last_country"
        case suspiciousEvents = "suspicious_events"
        case lastSuspiciousEventAt = "last_suspicious_event_at"
        case consecutiveCleanAttestations = "consecutive_clean_attestations"
        case deviceFingerprint = "device_fingerprint"
        case subjectId = "subject_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: String, keyId: String, firstSeen: String, lastAttestation: String, attestationCount: Int,
        riskScore: Int, deviceModel: String? = nil, osVersion: String? = nil, appVersion: String? = nil,
        firstAppVersion: String? = nil, jailbreakDetected: Bool, isDevelopmentBuild: Bool? = nil,
        appStoreReceipt: Bool? = nil, permissions: [String]? = nil, lastCountry: String? = nil,
        suspiciousEvents: Int, lastSuspiciousEventAt: String? = nil, consecutiveCleanAttestations: Int? = nil,
        deviceFingerprint: String? = nil, subjectId: String? = nil, createdAt: String? = nil, updatedAt: String? = nil
    ) {
        self.id = id
        self.keyId = keyId
        self.firstSeen = firstSeen
        self.lastAttestation = lastAttestation
        self.attestationCount = attestationCount
        self.riskScore = riskScore
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.firstAppVersion = firstAppVersion
        self.jailbreakDetected = jailbreakDetected
        self.isDevelopmentBuild = isDevelopmentBuild
        self.appStoreReceipt = appStoreReceipt
        self.permissions = permissions
        self.lastCountry = lastCountry
        self.suspiciousEvents = suspiciousEvents
        self.lastSuspiciousEventAt = lastSuspiciousEventAt
        self.consecutiveCleanAttestations = consecutiveCleanAttestations
        self.deviceFingerprint = deviceFingerprint
        self.subjectId = subjectId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ComplianceResult: Codable, Sendable {
    public let isCompliant: Bool
    public let score: Int
    public let violations: [ComplianceViolation]
    public let lastChecked: String

    public init(isCompliant: Bool, score: Int, violations: [ComplianceViolation], lastChecked: String) {
        self.isCompliant = isCompliant
        self.score = score
        self.violations = violations
        self.lastChecked = lastChecked
    }
}

/// A compliance violation as Swift's synthesized enum encoding renders it:
/// `{"jailbreakDetected":{}}` or `{"outdatedOS":{"_0":"16.0"}}`. Decoded into
/// the case name plus its optional payload, and re-encoded in the same
/// shape so `--json` round-trips the wire format.
public struct ComplianceViolation: Codable, Sendable, Equatable {
    public let kind: String
    public let detail: String?

    public init(kind: String, detail: String? = nil) {
        self.kind = kind
        self.detail = detail
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        guard let key = container.allKeys.first else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "empty violation object")
            )
        }
        kind = key.stringValue
        let payload = try container.nestedContainer(keyedBy: DynamicKey.self, forKey: key)
        let payloadKey = DynamicKey(stringValue: "_0")
        if let text = try? payload.decode(String.self, forKey: payloadKey) {
            detail = text
        } else if let number = try? payload.decode(Int.self, forKey: payloadKey) {
            detail = String(number)
        } else {
            detail = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        var payload = container.nestedContainer(keyedBy: DynamicKey.self, forKey: DynamicKey(stringValue: kind))
        if let detail {
            if let number = Int(detail) {
                try payload.encode(number, forKey: DynamicKey(stringValue: "_0"))
            } else {
                try payload.encode(detail, forKey: DynamicKey(stringValue: "_0"))
            }
        }
    }

    /// `outdatedOS("16.0")`-style rendering, matching the compliance report's
    /// string form.
    public var description: String {
        guard let detail else { return kind }
        if Int(detail) != nil { return "\(kind)(\(detail))" }
        return "\(kind)(\"\(detail)\")"
    }
}
