import Foundation

// MARK: - Org Wire Formats (apps, claims, devices)
//
// The `/api/v1/org/apps`, `/api/v1/org/claims` and `/api/v1/org/devices`
// endpoints speak snake_case at the top level (console parity plan §9).
// Claim rule and configuration objects nest in their stored camelCase
// schema and are carried as opaque JSON so the CLI never has to know their
// shape to round-trip them.

// MARK: - Opaque JSON

/// Any JSON value, preserved as-is. Used for nested claim configuration
/// (`conditional_rules`, `external_config`, `validation_rules`) whose schema
/// belongs to the server.
public indirect enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value):
            if value.rounded() == value, abs(value) < 1e15 {
                try container.encode(Int64(value))
            } else {
                try container.encode(value)
            }
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    /// Parses a JSON document into a value.
    public static func parse(_ text: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }
}

// MARK: - Apps

public struct OrgApp: Codable, Sendable, Equatable {
    public let id: String
    public let appName: String
    public let bundleId: String
    public let teamId: String
    public let description: String?
    public let isActive: Bool
    public let isPrimary: Bool
    public let analyticsEnabled: Bool
    public let webhookEnabled: Bool
    public let createdAt: String?
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case appName = "app_name"
        case bundleId = "bundle_id"
        case teamId = "team_id"
        case description
        case isActive = "is_active"
        case isPrimary = "is_primary"
        case analyticsEnabled = "analytics_enabled"
        case webhookEnabled = "webhook_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: String, appName: String, bundleId: String, teamId: String, description: String? = nil,
        isActive: Bool, isPrimary: Bool, analyticsEnabled: Bool = true, webhookEnabled: Bool = true,
        createdAt: String? = nil, updatedAt: String? = nil
    ) {
        self.id = id
        self.appName = appName
        self.bundleId = bundleId
        self.teamId = teamId
        self.description = description
        self.isActive = isActive
        self.isPrimary = isPrimary
        self.analyticsEnabled = analyticsEnabled
        self.webhookEnabled = webhookEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct CreateOrgAppRequest: Codable, Sendable, Equatable {
    public let appName: String
    public let bundleId: String
    public let teamId: String
    public let description: String?
    public let isPrimary: Bool?

    enum CodingKeys: String, CodingKey {
        case appName = "app_name"
        case bundleId = "bundle_id"
        case teamId = "team_id"
        case description
        case isPrimary = "is_primary"
    }

    public init(appName: String, bundleId: String, teamId: String, description: String? = nil, isPrimary: Bool? = nil) {
        self.appName = appName
        self.bundleId = bundleId
        self.teamId = teamId
        self.description = description
        self.isPrimary = isPrimary
    }
}

public struct UpdateOrgAppRequest: Codable, Sendable, Equatable {
    public let appName: String?
    public let description: String?
    public let analyticsEnabled: Bool?
    public let webhookEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case appName = "app_name"
        case description
        case analyticsEnabled = "analytics_enabled"
        case webhookEnabled = "webhook_enabled"
    }

    public init(appName: String? = nil, description: String? = nil, analyticsEnabled: Bool? = nil, webhookEnabled: Bool? = nil) {
        self.appName = appName
        self.description = description
        self.analyticsEnabled = analyticsEnabled
        self.webhookEnabled = webhookEnabled
    }

    public var isEmpty: Bool {
        appName == nil && description == nil && analyticsEnabled == nil && webhookEnabled == nil
    }
}

/// `{deleted: true, id}` — shared by every org delete.
public struct OrgDeleteResponse: Codable, Sendable, Equatable {
    public let deleted: Bool
    public let id: String

    public init(deleted: Bool, id: String) {
        self.deleted = deleted
        self.id = id
    }
}

// MARK: - Claims

public struct OrgClaim: Codable, Sendable, Equatable {
    public let id: String
    public let claimKey: String
    public let claimName: String
    /// `static`, `conditional`, `dynamic`, or `external`.
    public let claimType: String
    /// `string`, `number`, `boolean`, `array`, `object`, or `date`.
    public let dataType: String
    public let description: String?
    public let isActive: Bool
    public let priority: Int
    public let staticValue: String?
    public let conditionalRules: JSONValue?
    public let dynamicExpression: String?
    public let externalConfig: JSONValue?
    public let validationRules: JSONValue?
    public let createdAt: String?
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case claimKey = "claim_key"
        case claimName = "claim_name"
        case claimType = "claim_type"
        case dataType = "data_type"
        case description
        case isActive = "is_active"
        case priority
        case staticValue = "static_value"
        case conditionalRules = "conditional_rules"
        case dynamicExpression = "dynamic_expression"
        case externalConfig = "external_config"
        case validationRules = "validation_rules"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: String, claimKey: String, claimName: String, claimType: String, dataType: String,
        description: String? = nil, isActive: Bool, priority: Int, staticValue: String? = nil,
        conditionalRules: JSONValue? = nil, dynamicExpression: String? = nil, externalConfig: JSONValue? = nil,
        validationRules: JSONValue? = nil, createdAt: String? = nil, updatedAt: String? = nil
    ) {
        self.id = id
        self.claimKey = claimKey
        self.claimName = claimName
        self.claimType = claimType
        self.dataType = dataType
        self.description = description
        self.isActive = isActive
        self.priority = priority
        self.staticValue = staticValue
        self.conditionalRules = conditionalRules
        self.dynamicExpression = dynamicExpression
        self.externalConfig = externalConfig
        self.validationRules = validationRules
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// The definition body for create and for `test` (unsaved).
public struct OrgClaimDefinition: Codable, Sendable, Equatable {
    public let claimKey: String
    public let claimName: String
    public let claimType: String
    public let dataType: String
    public let description: String?
    public let priority: Int?
    public let isActive: Bool?
    public let staticValue: String?
    public let conditionalRules: JSONValue?
    public let dynamicExpression: String?
    public let externalConfig: JSONValue?
    public let validationRules: JSONValue?

    enum CodingKeys: String, CodingKey {
        case claimKey = "claim_key"
        case claimName = "claim_name"
        case claimType = "claim_type"
        case dataType = "data_type"
        case description
        case priority
        case isActive = "is_active"
        case staticValue = "static_value"
        case conditionalRules = "conditional_rules"
        case dynamicExpression = "dynamic_expression"
        case externalConfig = "external_config"
        case validationRules = "validation_rules"
    }

    public init(
        claimKey: String, claimName: String, claimType: String, dataType: String, description: String? = nil,
        priority: Int? = nil, isActive: Bool? = nil, staticValue: String? = nil, conditionalRules: JSONValue? = nil,
        dynamicExpression: String? = nil, externalConfig: JSONValue? = nil, validationRules: JSONValue? = nil
    ) {
        self.claimKey = claimKey
        self.claimName = claimName
        self.claimType = claimType
        self.dataType = dataType
        self.description = description
        self.priority = priority
        self.isActive = isActive
        self.staticValue = staticValue
        self.conditionalRules = conditionalRules
        self.dynamicExpression = dynamicExpression
        self.externalConfig = externalConfig
        self.validationRules = validationRules
    }
}

public struct UpdateOrgClaimRequest: Codable, Sendable, Equatable {
    public let claimName: String?
    public let description: String?
    public let isActive: Bool?
    public let priority: Int?
    public let staticValue: String?
    public let conditionalRules: JSONValue?
    public let dynamicExpression: String?
    public let externalConfig: JSONValue?
    public let validationRules: JSONValue?

    enum CodingKeys: String, CodingKey {
        case claimName = "claim_name"
        case description
        case isActive = "is_active"
        case priority
        case staticValue = "static_value"
        case conditionalRules = "conditional_rules"
        case dynamicExpression = "dynamic_expression"
        case externalConfig = "external_config"
        case validationRules = "validation_rules"
    }

    public init(
        claimName: String? = nil, description: String? = nil, isActive: Bool? = nil, priority: Int? = nil,
        staticValue: String? = nil, conditionalRules: JSONValue? = nil, dynamicExpression: String? = nil,
        externalConfig: JSONValue? = nil, validationRules: JSONValue? = nil
    ) {
        self.claimName = claimName
        self.description = description
        self.isActive = isActive
        self.priority = priority
        self.staticValue = staticValue
        self.conditionalRules = conditionalRules
        self.dynamicExpression = dynamicExpression
        self.externalConfig = externalConfig
        self.validationRules = validationRules
    }

    public var isEmpty: Bool {
        claimName == nil && description == nil && isActive == nil && priority == nil && staticValue == nil
            && conditionalRules == nil && dynamicExpression == nil && externalConfig == nil && validationRules == nil
    }
}

public struct ReorderOrgClaimsRequest: Codable, Sendable, Equatable {
    public let claimRefs: [String]

    enum CodingKeys: String, CodingKey {
        case claimRefs = "claim_refs"
    }

    public init(claimRefs: [String]) {
        self.claimRefs = claimRefs
    }
}

/// A simulated device for `test` / `preview`; every field optional.
public struct OrgClaimTestDevice: Codable, Sendable, Equatable {
    public var keyId: String?
    public var deviceModel: String?
    public var osVersion: String?
    public var appVersion: String?
    public var riskScore: Int?
    public var attestationCount: Int?
    public var jailbreakDetected: Bool?
    public var country: String?

    enum CodingKeys: String, CodingKey {
        case keyId = "key_id"
        case deviceModel = "device_model"
        case osVersion = "os_version"
        case appVersion = "app_version"
        case riskScore = "risk_score"
        case attestationCount = "attestation_count"
        case jailbreakDetected = "jailbreak_detected"
        case country
    }

    public init(
        keyId: String? = nil, deviceModel: String? = nil, osVersion: String? = nil, appVersion: String? = nil,
        riskScore: Int? = nil, attestationCount: Int? = nil, jailbreakDetected: Bool? = nil, country: String? = nil
    ) {
        self.keyId = keyId
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.riskScore = riskScore
        self.attestationCount = attestationCount
        self.jailbreakDetected = jailbreakDetected
        self.country = country
    }

    public var isEmpty: Bool {
        keyId == nil && deviceModel == nil && osVersion == nil && appVersion == nil && riskScore == nil
            && attestationCount == nil && jailbreakDetected == nil && country == nil
    }
}

public struct OrgClaimTestContext: Codable, Sendable, Equatable {
    public let device: OrgClaimTestDevice?
    public let additionalData: [String: String]?

    enum CodingKeys: String, CodingKey {
        case device
        case additionalData = "additional_data"
    }

    public init(device: OrgClaimTestDevice? = nil, additionalData: [String: String]? = nil) {
        self.device = device
        self.additionalData = additionalData
    }
}

public struct TestOrgClaimRequest: Codable, Sendable, Equatable {
    public let claim: OrgClaimDefinition
    public let context: OrgClaimTestContext?

    public init(claim: OrgClaimDefinition, context: OrgClaimTestContext? = nil) {
        self.claim = claim
        self.context = context
    }
}

public struct PreviewOrgClaimRequest: Codable, Sendable, Equatable {
    public let context: OrgClaimTestContext?

    public init(context: OrgClaimTestContext? = nil) {
        self.context = context
    }
}

public struct OrgClaimTestResponse: Codable, Sendable, Equatable {
    public let claimKey: String
    public let evaluatedValue: String?
    public let dataType: String
    public let evaluationTimeMs: Double
    public let errors: [String]?

    enum CodingKeys: String, CodingKey {
        case claimKey = "claim_key"
        case evaluatedValue = "evaluated_value"
        case dataType = "data_type"
        case evaluationTimeMs = "evaluation_time_ms"
        case errors
    }

    public init(claimKey: String, evaluatedValue: String?, dataType: String, evaluationTimeMs: Double, errors: [String]? = nil) {
        self.claimKey = claimKey
        self.evaluatedValue = evaluatedValue
        self.dataType = dataType
        self.evaluationTimeMs = evaluationTimeMs
        self.errors = errors
    }
}

// MARK: - Devices

public struct OrgDevice: Codable, Sendable, Equatable {
    public let id: String
    public let keyId: String
    public let appId: String?
    public let appName: String?
    public let deviceModel: String?
    public let osVersion: String?
    public let appVersion: String?
    public let riskScore: Int
    public let jailbreakDetected: Bool
    public let isDevelopmentBuild: Bool?
    public let appStoreReceipt: Bool?
    public let attestationCount: Int
    public let suspiciousEvents: Int
    public let lastCountry: String?
    public let firstSeen: String
    public let lastAttestation: String

    enum CodingKeys: String, CodingKey {
        case id
        case keyId = "key_id"
        case appId = "app_id"
        case appName = "app_name"
        case deviceModel = "device_model"
        case osVersion = "os_version"
        case appVersion = "app_version"
        case riskScore = "risk_score"
        case jailbreakDetected = "jailbreak_detected"
        case isDevelopmentBuild = "is_development_build"
        case appStoreReceipt = "app_store_receipt"
        case attestationCount = "attestation_count"
        case suspiciousEvents = "suspicious_events"
        case lastCountry = "last_country"
        case firstSeen = "first_seen"
        case lastAttestation = "last_attestation"
    }

    public init(
        id: String, keyId: String, appId: String? = nil, appName: String? = nil, deviceModel: String? = nil,
        osVersion: String? = nil, appVersion: String? = nil, riskScore: Int, jailbreakDetected: Bool,
        isDevelopmentBuild: Bool? = nil, appStoreReceipt: Bool? = nil, attestationCount: Int, suspiciousEvents: Int,
        lastCountry: String? = nil, firstSeen: String, lastAttestation: String
    ) {
        self.id = id
        self.keyId = keyId
        self.appId = appId
        self.appName = appName
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.riskScore = riskScore
        self.jailbreakDetected = jailbreakDetected
        self.isDevelopmentBuild = isDevelopmentBuild
        self.appStoreReceipt = appStoreReceipt
        self.attestationCount = attestationCount
        self.suspiciousEvents = suspiciousEvents
        self.lastCountry = lastCountry
        self.firstSeen = firstSeen
        self.lastAttestation = lastAttestation
    }
}

public typealias OrgDeviceList = OrgPage<OrgDevice>

public struct OrgDeviceEvent: Codable, Sendable, Equatable {
    public let id: String
    public let eventType: String
    public let keyId: String
    public let deviceId: String?
    public let ipAddress: String
    public let success: Bool
    public let errorReason: String?
    public let riskScore: Int
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case eventType = "event_type"
        case keyId = "key_id"
        case deviceId = "device_id"
        case ipAddress = "ip_address"
        case success
        case errorReason = "error_reason"
        case riskScore = "risk_score"
        case createdAt = "created_at"
    }

    public init(
        id: String, eventType: String, keyId: String, deviceId: String? = nil, ipAddress: String, success: Bool,
        errorReason: String? = nil, riskScore: Int, createdAt: String? = nil
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

public struct OrgDeviceDetail: Codable, Sendable, Equatable {
    public let id: String
    public let keyId: String
    public let appId: String?
    public let appName: String?
    public let deviceModel: String?
    public let osVersion: String?
    public let appVersion: String?
    public let firstAppVersion: String?
    public let riskScore: Int
    public let jailbreakDetected: Bool
    public let isDevelopmentBuild: Bool?
    public let appStoreReceipt: Bool?
    public let attestationCount: Int
    public let suspiciousEvents: Int
    public let lastSuspiciousEventAt: String?
    public let consecutiveCleanAttestations: Int?
    public let permissions: [String]?
    public let lastCountry: String?
    public let subjectId: String?
    public let firstSeen: String
    public let lastAttestation: String
    public let createdAt: String?
    public let updatedAt: String?
    public let recentEvents: [OrgDeviceEvent]

    enum CodingKeys: String, CodingKey {
        case id
        case keyId = "key_id"
        case appId = "app_id"
        case appName = "app_name"
        case deviceModel = "device_model"
        case osVersion = "os_version"
        case appVersion = "app_version"
        case firstAppVersion = "first_app_version"
        case riskScore = "risk_score"
        case jailbreakDetected = "jailbreak_detected"
        case isDevelopmentBuild = "is_development_build"
        case appStoreReceipt = "app_store_receipt"
        case attestationCount = "attestation_count"
        case suspiciousEvents = "suspicious_events"
        case lastSuspiciousEventAt = "last_suspicious_event_at"
        case consecutiveCleanAttestations = "consecutive_clean_attestations"
        case permissions
        case lastCountry = "last_country"
        case subjectId = "subject_id"
        case firstSeen = "first_seen"
        case lastAttestation = "last_attestation"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case recentEvents = "recent_events"
    }
}

/// Query for `GET /api/v1/org/devices`.
public struct OrgDeviceQuery: Sendable, Equatable {
    public var page: Int?
    public var per: Int?
    public var riskMin: Int?
    public var riskMax: Int?
    public var jailbroken: Bool?
    public var appId: String?
    public var search: String?

    public init(
        page: Int? = nil, per: Int? = nil, riskMin: Int? = nil, riskMax: Int? = nil,
        jailbroken: Bool? = nil, appId: String? = nil, search: String? = nil
    ) {
        self.page = page
        self.per = per
        self.riskMin = riskMin
        self.riskMax = riskMax
        self.jailbroken = jailbroken
        self.appId = appId
        self.search = search
    }
}
