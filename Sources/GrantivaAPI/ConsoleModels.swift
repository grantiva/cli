import Foundation

// MARK: - Console Wire Formats
//
// Two wire conventions coexist here, both dictated by the backend:
//
// - The org console endpoints (`/api/v1/org/flags`, `/api/v1/org/flag-environments`)
//   speak snake_case, per the Phase 1 contract (§7a of the console parity plan).
// - The pre-existing SDK endpoints (`/api/v1/flags/:flagId/rules`,
//   `/api/v1/flags/:flagId/evaluate`) speak Vapor's default camelCase and are
//   consumed as-is.
//
// Models below carry explicit CodingKeys wherever the wire key differs from
// the property name, so the convention each type follows is visible at the
// declaration.

// MARK: - Flags (org endpoints, snake_case)

/// A flag's per-environment on/off values and active state, keyed by
/// environment slug in flag responses.
public struct OrgFlagEnvironmentValue: Codable, Sendable, Equatable {
    /// Raw value served while the flag is on in this environment.
    public let onValue: String
    /// Raw value served while the flag is off in this environment.
    public let offValue: String
    /// Whether the flag is on in this environment.
    public let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case onValue = "on_value"
        case offValue = "off_value"
        case isActive = "is_active"
    }

    public init(onValue: String, offValue: String, isActive: Bool) {
        self.onValue = onValue
        self.offValue = offValue
        self.isActive = isActive
    }

    /// The value this environment currently serves.
    public var effectiveValue: String { isActive ? onValue : offValue }
}

public struct OrgFlag: Codable, Sendable {
    public let id: String
    public let flagKey: String
    public let name: String
    public let description: String?
    public let appId: String?
    public let valueType: String
    public let isActive: Bool
    /// Environment slug → on/off values and per-environment active state.
    public let environmentValues: [String: OrgFlagEnvironmentValue]?
    public let ruleCount: Int?
    public let createdAt: String?
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case flagKey = "flag_key"
        case name
        case description
        case appId = "app_id"
        case valueType = "value_type"
        case isActive = "is_active"
        case environmentValues = "environment_values"
        case ruleCount = "rule_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: String, flagKey: String, name: String, description: String? = nil,
        appId: String? = nil, valueType: String, isActive: Bool,
        environmentValues: [String: OrgFlagEnvironmentValue]? = nil, ruleCount: Int? = nil,
        createdAt: String? = nil, updatedAt: String? = nil
    ) {
        self.id = id
        self.flagKey = flagKey
        self.name = name
        self.description = description
        self.appId = appId
        self.valueType = valueType
        self.isActive = isActive
        self.environmentValues = environmentValues
        self.ruleCount = ruleCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Detail response: the flag's fields plus rule and override summaries.
/// Also the response shape of create/update, which return the flag without
/// the summaries (both arrays are optional) but with `rule_count`.
public struct OrgFlagDetail: Codable, Sendable {
    public let id: String
    public let flagKey: String
    public let name: String
    public let description: String?
    public let appId: String?
    public let valueType: String
    public let isActive: Bool
    public let environmentValues: [String: OrgFlagEnvironmentValue]?
    public let ruleCount: Int?
    public let createdAt: String?
    public let updatedAt: String?
    public let rules: [OrgFlagRuleSummary]?
    public let overrides: [OrgFlagOverride]?

    enum CodingKeys: String, CodingKey {
        case id
        case flagKey = "flag_key"
        case name
        case description
        case appId = "app_id"
        case valueType = "value_type"
        case isActive = "is_active"
        case environmentValues = "environment_values"
        case ruleCount = "rule_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case rules
        case overrides
    }

    public init(
        id: String, flagKey: String, name: String, description: String? = nil,
        appId: String? = nil, valueType: String, isActive: Bool,
        environmentValues: [String: OrgFlagEnvironmentValue]? = nil, ruleCount: Int? = nil,
        createdAt: String? = nil, updatedAt: String? = nil, rules: [OrgFlagRuleSummary]? = nil,
        overrides: [OrgFlagOverride]? = nil
    ) {
        self.id = id
        self.flagKey = flagKey
        self.name = name
        self.description = description
        self.appId = appId
        self.valueType = valueType
        self.isActive = isActive
        self.environmentValues = environmentValues
        self.ruleCount = ruleCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.rules = rules
        self.overrides = overrides
    }

    /// The flag's summary fields, as an `OrgFlag`.
    public var summary: OrgFlag {
        OrgFlag(
            id: id, flagKey: flagKey, name: name, description: description,
            appId: appId, valueType: valueType, isActive: isActive,
            environmentValues: environmentValues, ruleCount: ruleCount,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

/// Response of `POST /api/v1/org/flags/:flagRef/toggle` — the flag's identity
/// and effective active state, not the full flag document.
public struct OrgFlagToggleResponse: Codable, Sendable {
    public let id: String
    public let flagKey: String
    /// Effective active state after the toggle (globally, or in `environment`).
    public let isActive: Bool
    /// The environment the toggle applied to, when scoped; nil for global.
    public let environment: String?

    enum CodingKeys: String, CodingKey {
        case id
        case flagKey = "flag_key"
        case isActive = "is_active"
        case environment
    }

    public init(id: String, flagKey: String, isActive: Bool, environment: String? = nil) {
        self.id = id
        self.flagKey = flagKey
        self.isActive = isActive
        self.environment = environment
    }
}

public struct OrgFlagRuleSummary: Codable, Sendable {
    public let id: String
    public let priority: Int
    public let name: String
    public let value: String
    public let rolloutPercentage: Int?
    public let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id, priority, name, value
        case rolloutPercentage = "rollout_percentage"
        case isActive = "is_active"
    }

    public init(id: String, priority: Int, name: String, value: String, rolloutPercentage: Int? = nil, isActive: Bool? = nil) {
        self.id = id
        self.priority = priority
        self.name = name
        self.value = value
        self.rolloutPercentage = rolloutPercentage
        self.isActive = isActive
    }
}

/// Per-environment value input for flag create/update, keyed by environment
/// slug. All fields optional — omitted fields keep their current value.
public struct OrgFlagEnvironmentValueInput: Encodable, Sendable, Equatable {
    public let onValue: String?
    public let offValue: String?
    public let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case onValue = "on_value"
        case offValue = "off_value"
        case isActive = "is_active"
    }

    public init(onValue: String? = nil, offValue: String? = nil, isActive: Bool? = nil) {
        self.onValue = onValue
        self.offValue = offValue
        self.isActive = isActive
    }
}

public struct CreateOrgFlagRequest: Encodable, Sendable {
    public let flagKey: String
    public let name: String
    public let description: String?
    public let appId: String?
    public let valueType: String
    public let environmentValues: [String: OrgFlagEnvironmentValueInput]?
    public let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case flagKey = "flag_key"
        case name
        case description
        case appId = "app_id"
        case valueType = "value_type"
        case environmentValues = "environment_values"
        case isActive = "is_active"
    }

    public init(
        flagKey: String, name: String, description: String? = nil,
        appId: String? = nil, valueType: String,
        environmentValues: [String: OrgFlagEnvironmentValueInput]? = nil, isActive: Bool? = nil
    ) {
        self.flagKey = flagKey
        self.name = name
        self.description = description
        self.appId = appId
        self.valueType = valueType
        self.environmentValues = environmentValues
        self.isActive = isActive
    }
}

public struct UpdateOrgFlagRequest: Encodable, Sendable {
    public let name: String?
    public let description: String?
    public let environmentValues: [String: OrgFlagEnvironmentValueInput]?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case environmentValues = "environment_values"
    }

    public init(
        name: String? = nil, description: String? = nil,
        environmentValues: [String: OrgFlagEnvironmentValueInput]? = nil
    ) {
        self.name = name
        self.description = description
        self.environmentValues = environmentValues
    }
}

public struct ToggleOrgFlagRequest: Encodable, Sendable {
    /// Omitted is_active flips the current state server-side.
    public let isActive: Bool?
    public let environment: String?

    enum CodingKeys: String, CodingKey {
        case isActive = "is_active"
        case environment
    }

    public init(isActive: Bool? = nil, environment: String? = nil) {
        self.isActive = isActive
        self.environment = environment
    }
}

// MARK: - Flag History (org endpoint, snake_case — a bare array on the wire)

public struct FlagHistoryEntry: Codable, Sendable {
    public let id: String
    public let flagId: String
    /// Who made the change: a user email, or the API key prefix for
    /// key-authored changes (e.g. "gpat_cli_tes...").
    public let actorEmail: String
    /// Change type, e.g. "flag.created", "flag.toggled", "flag.updated".
    public let changeType: String
    /// Human-readable one-line description of the change.
    public let summary: String
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case flagId = "flag_id"
        case actorEmail = "actor_email"
        case changeType = "change_type"
        case summary
        case createdAt = "created_at"
    }

    public init(
        id: String, flagId: String, actorEmail: String, changeType: String,
        summary: String, createdAt: String? = nil
    ) {
        self.id = id
        self.flagId = flagId
        self.actorEmail = actorEmail
        self.changeType = changeType
        self.summary = summary
        self.createdAt = createdAt
    }
}

// MARK: - Recorded Flag Evaluations (org endpoint, snake_case)

public struct OrgFlagEvaluationEntry: Codable, Sendable, Equatable {
    public let id: String
    public let deviceKeyId: String?
    public let value: String
    public let evaluatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case deviceKeyId = "device_key_id"
        case value
        case evaluatedAt = "evaluated_at"
    }

    public init(id: String, deviceKeyId: String? = nil, value: String, evaluatedAt: String? = nil) {
        self.id = id
        self.deviceKeyId = deviceKeyId
        self.value = value
        self.evaluatedAt = evaluatedAt
    }
}

public struct OrgFlagEvaluationsResponse: Codable, Sendable, Equatable {
    public let evaluations: [OrgFlagEvaluationEntry]

    public init(evaluations: [OrgFlagEvaluationEntry]) { self.evaluations = evaluations }
}

// MARK: - Flag Overrides (org endpoints, snake_case — list is a bare array)

public struct OrgFlagOverride: Codable, Sendable {
    public let id: String
    public let flagId: String?
    public let deviceKeyId: String
    public let forcedValue: String
    public let expiresAt: String?
    public let createdAt: String?
    /// Who created the override: a user email, or the API key prefix.
    public let createdBy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case flagId = "flag_id"
        case deviceKeyId = "device_key_id"
        case forcedValue = "forced_value"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case createdBy = "created_by"
    }

    public init(
        id: String, flagId: String? = nil, deviceKeyId: String, forcedValue: String,
        expiresAt: String? = nil, createdAt: String? = nil, createdBy: String? = nil
    ) {
        self.id = id
        self.flagId = flagId
        self.deviceKeyId = deviceKeyId
        self.forcedValue = forcedValue
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.createdBy = createdBy
    }
}

public struct CreateFlagOverrideRequest: Encodable, Sendable {
    public let deviceKeyId: String
    public let forcedValue: String
    public let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case deviceKeyId = "device_key_id"
        case forcedValue = "forced_value"
        case expiresAt = "expires_at"
    }

    public init(deviceKeyId: String, forcedValue: String, expiresAt: String? = nil) {
        self.deviceKeyId = deviceKeyId
        self.forcedValue = forcedValue
        self.expiresAt = expiresAt
    }
}

// MARK: - Flag Environments (org endpoints, snake_case)

public struct OrgFlagEnvironment: Codable, Sendable {
    public let id: String
    public let name: String
    public let slug: String
    public let color: String?
    public let isDefault: Bool?
    public let sortOrder: Int?
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, color
        case isDefault = "is_default"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }

    public init(
        id: String, name: String, slug: String, color: String? = nil,
        isDefault: Bool? = nil, sortOrder: Int? = nil, createdAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.color = color
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

public struct CreateFlagEnvironmentRequest: Encodable, Sendable {
    public let name: String
    public let color: String?

    public init(name: String, color: String? = nil) {
        self.name = name
        self.color = color
    }
}

public struct UpdateFlagEnvironmentRequest: Encodable, Sendable {
    public let name: String?
    public let color: String?
    /// "up" or "down" — moves the environment one slot in the sort order.
    public let reorder: String?

    public init(name: String? = nil, color: String? = nil, reorder: String? = nil) {
        self.name = name
        self.color = color
        self.reorder = reorder
    }
}

// MARK: - Rule Conditions (shared shape, string-or-array values)

/// A condition value is a single string or an array of strings on the wire.
public enum ConditionValue: Codable, Equatable, Sendable {
    case string(String)
    case array([String])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let arr = try? container.decode([String].self) {
            self = .array(arr)
        } else if let str = try? container.decode(String.self) {
            self = .string(str)
        } else {
            throw DecodingError.typeMismatch(
                ConditionValue.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected String or [String]")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .array(let arr): try container.encode(arr)
        }
    }

    public var displayValue: String {
        switch self {
        case .string(let s): return s
        case .array(let arr): return arr.joined(separator: ",")
        }
    }
}

public struct RuleCondition: Codable, Equatable, Sendable {
    public let attribute: String
    public let `operator`: String
    public let value: ConditionValue

    public init(attribute: String, operator: String, value: ConditionValue) {
        self.attribute = attribute
        self.operator = `operator`
        self.value = value
    }
}

// MARK: - Flag Rules (existing SDK endpoints, camelCase)

public struct FlagRuleResponse: Codable, Sendable {
    public let id: String
    public let flagId: String
    public let priority: Int
    public let name: String
    public let conditions: [RuleCondition]
    public let value: String
    public let rolloutPercentage: Int
    public let isActive: Bool
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String, flagId: String, priority: Int, name: String,
        conditions: [RuleCondition], value: String, rolloutPercentage: Int,
        isActive: Bool, createdAt: String? = nil, updatedAt: String? = nil
    ) {
        self.id = id
        self.flagId = flagId
        self.priority = priority
        self.name = name
        self.conditions = conditions
        self.value = value
        self.rolloutPercentage = rolloutPercentage
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct CreateFlagRuleRequest: Encodable, Sendable {
    public let name: String
    public let conditions: [RuleCondition]
    public let value: String
    public let rolloutPercentage: Int?
    public let isActive: Bool?

    public init(name: String, conditions: [RuleCondition], value: String, rolloutPercentage: Int? = nil, isActive: Bool? = nil) {
        self.name = name
        self.conditions = conditions
        self.value = value
        self.rolloutPercentage = rolloutPercentage
        self.isActive = isActive
    }
}

public struct UpdateFlagRuleRequest: Encodable, Sendable {
    public let name: String?
    public let conditions: [RuleCondition]?
    public let value: String?
    public let rolloutPercentage: Int?
    public let isActive: Bool?
    public let priority: Int?

    public init(
        name: String? = nil, conditions: [RuleCondition]? = nil, value: String? = nil,
        rolloutPercentage: Int? = nil, isActive: Bool? = nil, priority: Int? = nil
    ) {
        self.name = name
        self.conditions = conditions
        self.value = value
        self.rolloutPercentage = rolloutPercentage
        self.isActive = isActive
        self.priority = priority
    }
}

public struct ReorderFlagRulesRequest: Encodable, Sendable {
    /// Ordered rule IDs; array index becomes the new priority.
    public let ruleIds: [String]

    public init(ruleIds: [String]) {
        self.ruleIds = ruleIds
    }
}

// MARK: - Flag Evaluation (existing SDK endpoint, camelCase)

public struct FlagEvaluationRequest: Encodable, Sendable {
    public let deviceModel: String?
    public let osVersion: String?
    public let appVersion: String?
    public let deviceId: String?
    public let riskScore: Int?
    public let locale: String?
    public let country: String?
    public let userId: String?
    public let attestationStatus: String?
    public let custom: [String: String]?
    public let environment: String?

    public init(
        deviceModel: String? = nil, osVersion: String? = nil, appVersion: String? = nil,
        deviceId: String? = nil, riskScore: Int? = nil, locale: String? = nil,
        country: String? = nil, userId: String? = nil, attestationStatus: String? = nil,
        custom: [String: String]? = nil, environment: String? = nil
    ) {
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.deviceId = deviceId
        self.riskScore = riskScore
        self.locale = locale
        self.country = country
        self.userId = userId
        self.attestationStatus = attestationStatus
        self.custom = custom
        self.environment = environment
    }
}

public struct FlagEvaluationResponse: Codable, Sendable {
    public let flagKey: String
    public let flagId: String
    public let environment: String
    public let resolvedValue: String
    public let valueType: String
    public let matchedRule: String?
    public let isDefault: Bool
    public let trace: [FlagEvaluationTraceEntry]

    public init(
        flagKey: String, flagId: String, environment: String, resolvedValue: String,
        valueType: String, matchedRule: String?, isDefault: Bool,
        trace: [FlagEvaluationTraceEntry]
    ) {
        self.flagKey = flagKey
        self.flagId = flagId
        self.environment = environment
        self.resolvedValue = resolvedValue
        self.valueType = valueType
        self.matchedRule = matchedRule
        self.isDefault = isDefault
        self.trace = trace
    }
}

public struct FlagEvaluationTraceEntry: Codable, Sendable {
    public let ruleName: String
    public let ruleId: String
    public let priority: Int
    public let matched: Bool
    public let rolloutPercentage: Int
    public let passedRollout: Bool
    public let conditions: [ConditionTraceEntry]
    public let value: String

    public init(
        ruleName: String, ruleId: String, priority: Int, matched: Bool,
        rolloutPercentage: Int, passedRollout: Bool, conditions: [ConditionTraceEntry],
        value: String
    ) {
        self.ruleName = ruleName
        self.ruleId = ruleId
        self.priority = priority
        self.matched = matched
        self.rolloutPercentage = rolloutPercentage
        self.passedRollout = passedRollout
        self.conditions = conditions
        self.value = value
    }
}

public struct ConditionTraceEntry: Codable, Sendable {
    public let attribute: String
    public let `operator`: String
    public let expected: String
    public let actual: String?
    public let passed: Bool

    public init(attribute: String, operator: String, expected: String, actual: String?, passed: Bool) {
        self.attribute = attribute
        self.operator = `operator`
        self.expected = expected
        self.actual = actual
        self.passed = passed
    }
}

// MARK: - SSE Events (flags stream)

public struct FlagStreamEvent: Codable, Sendable, Equatable {
    /// SSE event name (e.g. "flags"), or "message" when the server sends none.
    public let event: String
    /// Raw data payload — a JSON document for "flags" events.
    public let data: String

    public init(event: String, data: String) {
        self.event = event
        self.data = data
    }
}

/// Incremental parser for a Server-Sent-Events byte stream, fed line by line.
///
/// Handles the subset the flags stream emits: `event:` / `data:` fields,
/// comment lines (`: keepalive`) which are ignored, and blank-line dispatch.
public struct SSEParser: Sendable {
    private var eventName: String?
    private var dataLines: [String] = []

    public init() {}

    /// Feeds one line (without its trailing newline). Returns a completed
    /// event when the line was the blank dispatch line, else nil.
    public mutating func feed(line: String) -> FlagStreamEvent? {
        if line.isEmpty {
            defer {
                eventName = nil
                dataLines = []
            }
            guard !dataLines.isEmpty else { return nil }
            let dispatchedName = eventName.flatMap { $0.isEmpty ? nil : $0 } ?? "message"
            return FlagStreamEvent(event: dispatchedName, data: dataLines.joined(separator: "\n"))
        }
        if line.hasPrefix(":") { return nil } // comment / keepalive

        let separator = line.firstIndex(of: ":")
        let field = separator.map { String(line[..<$0]) } ?? line
        var value = separator.map { String(line[line.index(after: $0)...]) } ?? ""
        // The SSE grammar strips exactly one leading ASCII space from a field
        // value. Other leading and trailing whitespace is significant.
        if value.first == " " { value.removeFirst() }

        if field == "event" {
            eventName = value
        } else if field == "data" {
            dataLines.append(value)
        }
        return nil
    }
}

enum SSEByteDecoderError: Error, Equatable, LocalizedError {
    case lineTooLong(maximumBytes: Int)

    var errorDescription: String? {
        switch self {
        case .lineTooLong(let maximumBytes):
            return "SSE line exceeds the \(maximumBytes)-byte limit"
        }
    }
}

/// Splits an SSE byte stream into physical lines without relying on
/// `AsyncBytes.lines`, which does not expose the blank dispatch lines.
struct SSEByteDecoder: Sendable {
    static let defaultMaximumLineBytes = 64 * 1024

    private var parser = SSEParser()
    private var line: [UInt8] = []
    private var previousByteWasCR = false
    private var isFirstLine = true
    private let maximumLineBytes: Int

    init(maximumLineBytes: Int = defaultMaximumLineBytes) {
        self.maximumLineBytes = maximumLineBytes
    }

    mutating func feed(byte: UInt8) throws -> FlagStreamEvent? {
        if previousByteWasCR {
            previousByteWasCR = false
            if byte == 0x0A { return nil } // CRLF is one line ending.
        }

        if byte == 0x0D {
            previousByteWasCR = true
            return dispatchLine()
        }
        if byte == 0x0A {
            return dispatchLine()
        }
        guard line.count < maximumLineBytes else {
            throw SSEByteDecoderError.lineTooLong(maximumBytes: maximumLineBytes)
        }
        line.append(byte)
        return nil
    }

    /// An unterminated final line and any pending event are discarded per SSE.
    mutating func finish() {
        line.removeAll(keepingCapacity: false)
        parser = SSEParser()
        previousByteWasCR = false
    }

    private mutating func dispatchLine() -> FlagStreamEvent? {
        if isFirstLine {
            isFirstLine = false
            if line.starts(with: [0xEF, 0xBB, 0xBF]) {
                line.removeFirst(3)
            }
        }
        let decoded = String(decoding: line, as: UTF8.self)
        line.removeAll(keepingCapacity: true)
        return parser.feed(line: decoded)
    }
}
