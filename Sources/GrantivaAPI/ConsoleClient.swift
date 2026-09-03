import Foundation
import GrantivaCore

// MARK: - ConsoleClient

/// API client for the `grantiva console` command family (feature flags and
/// flag environments). Sibling of `RangeClient`: a closure struct with a
/// `.live`-style convenience init and a `.failing` double for tests.
public struct ConsoleClient: Sendable {
    // Flags (org endpoints)
    public var listFlags: @Sendable (_ appId: String?, _ environment: String?) async throws -> [OrgFlag]
    public var createFlag: @Sendable (CreateOrgFlagRequest) async throws -> OrgFlagDetail
    public var getFlag: @Sendable (_ flagRef: String) async throws -> OrgFlagDetail
    public var updateFlag: @Sendable (_ flagRef: String, UpdateOrgFlagRequest) async throws -> OrgFlagDetail
    public var deleteFlag: @Sendable (_ flagRef: String) async throws -> Void
    public var toggleFlag: @Sendable (_ flagRef: String, ToggleOrgFlagRequest) async throws -> OrgFlagToggleResponse
    public var flagHistory: @Sendable (_ flagRef: String, _ limit: Int?, _ offset: Int?) async throws -> [FlagHistoryEntry]

    // Overrides (org endpoints)
    public var listOverrides: @Sendable (_ flagRef: String) async throws -> [OrgFlagOverride]
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
        listFlags: @escaping @Sendable (String?, String?) async throws -> [OrgFlag],
        createFlag: @escaping @Sendable (CreateOrgFlagRequest) async throws -> OrgFlagDetail,
        getFlag: @escaping @Sendable (String) async throws -> OrgFlagDetail,
        updateFlag: @escaping @Sendable (String, UpdateOrgFlagRequest) async throws -> OrgFlagDetail,
        deleteFlag: @escaping @Sendable (String) async throws -> Void,
        toggleFlag: @escaping @Sendable (String, ToggleOrgFlagRequest) async throws -> OrgFlagToggleResponse,
        flagHistory: @escaping @Sendable (String, Int?, Int?) async throws -> [FlagHistoryEntry],
        listOverrides: @escaping @Sendable (String) async throws -> [OrgFlagOverride],
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
    public init(apiKey: String, baseURL: String) throws {
        let baseURL = try validatedAPIBaseURL(baseURL)
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
                try await client.execute(FlagRuleEndpoints.reorder(flagId: flagId, body: body), baseURL: baseURL)
            },
            evaluateFlag: { flagId, body in
                try await client.execute(FlagEvaluationEndpoints.evaluate(flagId: flagId, body: body), baseURL: baseURL)
            },
            streamFlags: { environment in
                let url = try FlagEvaluationEndpoints.stream(environment: environment).url(relativeTo: baseURL)
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
                        // NOT `bytes.lines`: that skips empty lines, and the
                        // blank line is exactly what dispatches an SSE event.
                        var parser = SSEParser()
                        var buffer: [UInt8] = []
                        func feed(_ lineBytes: [UInt8]) {
                            var lineBytes = lineBytes
                            if lineBytes.last == 0x0D { lineBytes.removeLast() } // trailing \r
                            let line = String(decoding: lineBytes, as: UTF8.self)
                            if let event = parser.feed(line: line) {
                                continuation.yield(event)
                            }
                        }
                        do {
                            for try await byte in bytes {
                                if byte == 0x0A { // \n
                                    feed(buffer)
                                    buffer.removeAll(keepingCapacity: true)
                                } else {
                                    buffer.append(byte)
                                }
                            }
                            if !buffer.isEmpty { feed(buffer) }
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
