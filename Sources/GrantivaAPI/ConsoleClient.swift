import Foundation
import GrantivaCore

// MARK: - ConsoleClient

/// API client for the `grantiva console` command family (feature flags and
/// flag environments). Sibling of `RangeClient`: a closure struct with a
/// `.live`-style convenience init and a `.failing` double for tests.
public struct ConsoleClient: Sendable {
    // Flags (org endpoints)
    public var listFlags: @Sendable (_ appId: String?, _ environment: String?) async throws -> OrgFlagListResponse
    public var createFlag: @Sendable (CreateOrgFlagRequest) async throws -> OrgFlagDetail
    public var getFlag: @Sendable (_ flagRef: String) async throws -> OrgFlagDetail
    public var updateFlag: @Sendable (_ flagRef: String, UpdateOrgFlagRequest) async throws -> OrgFlagDetail
    public var deleteFlag: @Sendable (_ flagRef: String) async throws -> Void
    public var toggleFlag: @Sendable (_ flagRef: String, ToggleOrgFlagRequest) async throws -> OrgFlagDetail
    public var flagHistory: @Sendable (_ flagRef: String, _ limit: Int?, _ offset: Int?) async throws -> FlagHistoryResponse

    // Overrides (org endpoints)
    public var listOverrides: @Sendable (_ flagRef: String) async throws -> OrgFlagOverrideListResponse
    public var createOverride: @Sendable (_ flagRef: String, CreateFlagOverrideRequest) async throws -> OrgFlagOverride
    public var deleteOverride: @Sendable (_ flagRef: String, _ overrideId: String) async throws -> Void

    // Environments (org endpoints)
    public var listEnvironments: @Sendable () async throws -> [OrgFlagEnvironment]
    public var createEnvironment: @Sendable (CreateFlagEnvironmentRequest) async throws -> OrgFlagEnvironment
    public var updateEnvironment: @Sendable (_ envId: String, UpdateFlagEnvironmentRequest) async throws -> OrgFlagEnvironment
    public var deleteEnvironment: @Sendable (_ envId: String) async throws -> Void

    // Rules (existing SDK endpoints, addressed by flag UUID)
    public var listRules: @Sendable (_ flagId: String) async throws -> [FlagRuleResponse]
    public var createRule: @Sendable (_ flagId: String, CreateFlagRuleRequest) async throws -> FlagRuleResponse
    public var updateRule: @Sendable (_ flagId: String, _ ruleId: String, UpdateFlagRuleRequest) async throws -> FlagRuleResponse
    public var deleteRule: @Sendable (_ flagId: String, _ ruleId: String) async throws -> Void
    public var reorderRules: @Sendable (_ flagId: String, ReorderFlagRulesRequest) async throws -> [FlagRuleResponse]

    // Evaluation + stream (existing SDK endpoints)
    public var evaluateFlag: @Sendable (_ flagId: String, FlagEvaluationRequest) async throws -> FlagEvaluationResponse
    /// Opens the SSE stream and yields one event per server push until the
    /// stream ends or the task is cancelled.
    public var streamFlags: @Sendable (_ environment: String?) async throws -> AsyncThrowingStream<FlagStreamEvent, Error>

    public init(
        listFlags: @escaping @Sendable (String?, String?) async throws -> OrgFlagListResponse,
        createFlag: @escaping @Sendable (CreateOrgFlagRequest) async throws -> OrgFlagDetail,
        getFlag: @escaping @Sendable (String) async throws -> OrgFlagDetail,
        updateFlag: @escaping @Sendable (String, UpdateOrgFlagRequest) async throws -> OrgFlagDetail,
        deleteFlag: @escaping @Sendable (String) async throws -> Void,
        toggleFlag: @escaping @Sendable (String, ToggleOrgFlagRequest) async throws -> OrgFlagDetail,
        flagHistory: @escaping @Sendable (String, Int?, Int?) async throws -> FlagHistoryResponse,
        listOverrides: @escaping @Sendable (String) async throws -> OrgFlagOverrideListResponse,
        createOverride: @escaping @Sendable (String, CreateFlagOverrideRequest) async throws -> OrgFlagOverride,
        deleteOverride: @escaping @Sendable (String, String) async throws -> Void,
        listEnvironments: @escaping @Sendable () async throws -> [OrgFlagEnvironment],
        createEnvironment: @escaping @Sendable (CreateFlagEnvironmentRequest) async throws -> OrgFlagEnvironment,
        updateEnvironment: @escaping @Sendable (String, UpdateFlagEnvironmentRequest) async throws -> OrgFlagEnvironment,
        deleteEnvironment: @escaping @Sendable (String) async throws -> Void,
        listRules: @escaping @Sendable (String) async throws -> [FlagRuleResponse],
        createRule: @escaping @Sendable (String, CreateFlagRuleRequest) async throws -> FlagRuleResponse,
        updateRule: @escaping @Sendable (String, String, UpdateFlagRuleRequest) async throws -> FlagRuleResponse,
        deleteRule: @escaping @Sendable (String, String) async throws -> Void,
        reorderRules: @escaping @Sendable (String, ReorderFlagRulesRequest) async throws -> [FlagRuleResponse],
        evaluateFlag: @escaping @Sendable (String, FlagEvaluationRequest) async throws -> FlagEvaluationResponse,
        streamFlags: @escaping @Sendable (String?) async throws -> AsyncThrowingStream<FlagStreamEvent, Error>
    ) {
        self.listFlags = listFlags
        self.createFlag = createFlag
        self.getFlag = getFlag
        self.updateFlag = updateFlag
        self.deleteFlag = deleteFlag
        self.toggleFlag = toggleFlag
        self.flagHistory = flagHistory
        self.listOverrides = listOverrides
        self.createOverride = createOverride
        self.deleteOverride = deleteOverride
        self.listEnvironments = listEnvironments
        self.createEnvironment = createEnvironment
        self.updateEnvironment = updateEnvironment
        self.deleteEnvironment = deleteEnvironment
        self.listRules = listRules
        self.createRule = createRule
        self.updateRule = updateRule
        self.deleteRule = deleteRule
        self.reorderRules = reorderRules
        self.evaluateFlag = evaluateFlag
        self.streamFlags = streamFlags
    }
}

// MARK: - Convenience Init (live)

extension ConsoleClient {
    public init(apiKey: String, baseURL: String) {
        let baseURL = URL(string: baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL)!
        let client = NetworkClient.authorized(apiKey: apiKey)

        self.init(
            listFlags: { appId, environment in
                try await client.execute(OrgFlagEndpoints.list(appId: appId, environment: environment), baseURL: baseURL)
            },
            createFlag: { body in
                try await client.execute(OrgFlagEndpoints.create(body: body), baseURL: baseURL)
            },
            getFlag: { flagRef in
                try await client.execute(OrgFlagEndpoints.detail(flagRef: flagRef), baseURL: baseURL)
            },
            updateFlag: { flagRef, body in
                try await client.execute(OrgFlagEndpoints.update(flagRef: flagRef, body: body), baseURL: baseURL)
            },
            deleteFlag: { flagRef in
                _ = try await client.execute(OrgFlagEndpoints.delete(flagRef: flagRef), baseURL: baseURL)
            },
            toggleFlag: { flagRef, body in
                try await client.execute(OrgFlagEndpoints.toggle(flagRef: flagRef, body: body), baseURL: baseURL)
            },
            flagHistory: { flagRef, limit, offset in
                try await client.execute(OrgFlagEndpoints.history(flagRef: flagRef, limit: limit, offset: offset), baseURL: baseURL)
            },
            listOverrides: { flagRef in
                try await client.execute(OrgFlagEndpoints.listOverrides(flagRef: flagRef), baseURL: baseURL)
            },
            createOverride: { flagRef, body in
                try await client.execute(OrgFlagEndpoints.createOverride(flagRef: flagRef, body: body), baseURL: baseURL)
            },
            deleteOverride: { flagRef, overrideId in
                _ = try await client.execute(OrgFlagEndpoints.deleteOverride(flagRef: flagRef, overrideId: overrideId), baseURL: baseURL)
            },
            listEnvironments: {
                try await client.execute(FlagEnvironmentEndpoints.list(), baseURL: baseURL)
            },
            createEnvironment: { body in
                try await client.execute(FlagEnvironmentEndpoints.create(body: body), baseURL: baseURL)
            },
            updateEnvironment: { envId, body in
                try await client.execute(FlagEnvironmentEndpoints.update(envId: envId, body: body), baseURL: baseURL)
            },
            deleteEnvironment: { envId in
                _ = try await client.execute(FlagEnvironmentEndpoints.delete(envId: envId), baseURL: baseURL)
            },
            listRules: { flagId in
                try await client.execute(FlagRuleEndpoints.list(flagId: flagId), baseURL: baseURL)
            },
            createRule: { flagId, body in
                try await client.execute(FlagRuleEndpoints.create(flagId: flagId, body: body), baseURL: baseURL)
            },
            updateRule: { flagId, ruleId, body in
                try await client.execute(FlagRuleEndpoints.update(flagId: flagId, ruleId: ruleId, body: body), baseURL: baseURL)
            },
            deleteRule: { flagId, ruleId in
                _ = try await client.execute(FlagRuleEndpoints.delete(flagId: flagId, ruleId: ruleId), baseURL: baseURL)
            },
            reorderRules: { flagId, body in
                // NetworkClient.execute sends .patch through the PUT closure,
                // so the PATCH verb goes through the sendRequest escape hatch.
                let endpoint = FlagRuleEndpoints.reorder(flagId: flagId, body: body)
                var request = URLRequest(url: endpoint.url(relativeTo: baseURL))
                request.httpMethod = "PATCH"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(body)
                let data = try await client.sendRequest(request)
                return try JSONDecoder().decode([FlagRuleResponse].self, from: data)
            },
            evaluateFlag: { flagId, body in
                try await client.execute(FlagEvaluationEndpoints.evaluate(flagId: flagId, body: body), baseURL: baseURL)
            },
            streamFlags: { environment in
                let url = FlagEvaluationEndpoints.stream(environment: environment).url(relativeTo: baseURL)
                var request = URLRequest(url: url)
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 86_400 // SSE stream stays open; keepalives defeat idle cutoffs

                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw GrantivaError.networkError("Invalid response", 0)
                }
                guard http.statusCode == 200 else {
                    if http.statusCode == 401 { throw GrantivaError.notAuthenticated }
                    throw GrantivaError.networkError("SSE stream rejected", http.statusCode)
                }

                return AsyncThrowingStream { continuation in
                    let task = Task {
                        var parser = SSEParser()
                        do {
                            for try await line in bytes.lines {
                                if let event = parser.feed(line: line) {
                                    continuation.yield(event)
                                }
                            }
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            }
        )
    }
}

// MARK: - Failing

extension ConsoleClient {
    public static let failing = ConsoleClient(
        listFlags: { _, _ in throw GrantivaError.notAuthenticated },
        createFlag: { _ in throw GrantivaError.notAuthenticated },
        getFlag: { _ in throw GrantivaError.notAuthenticated },
        updateFlag: { _, _ in throw GrantivaError.notAuthenticated },
        deleteFlag: { _ in throw GrantivaError.notAuthenticated },
        toggleFlag: { _, _ in throw GrantivaError.notAuthenticated },
        flagHistory: { _, _, _ in throw GrantivaError.notAuthenticated },
        listOverrides: { _ in throw GrantivaError.notAuthenticated },
        createOverride: { _, _ in throw GrantivaError.notAuthenticated },
        deleteOverride: { _, _ in throw GrantivaError.notAuthenticated },
        listEnvironments: { throw GrantivaError.notAuthenticated },
        createEnvironment: { _ in throw GrantivaError.notAuthenticated },
        updateEnvironment: { _, _ in throw GrantivaError.notAuthenticated },
        deleteEnvironment: { _ in throw GrantivaError.notAuthenticated },
        listRules: { _ in throw GrantivaError.notAuthenticated },
        createRule: { _, _ in throw GrantivaError.notAuthenticated },
        updateRule: { _, _, _ in throw GrantivaError.notAuthenticated },
        deleteRule: { _, _ in throw GrantivaError.notAuthenticated },
        reorderRules: { _, _ in throw GrantivaError.notAuthenticated },
        evaluateFlag: { _, _ in throw GrantivaError.notAuthenticated },
        streamFlags: { _ in throw GrantivaError.notAuthenticated }
    )
}
