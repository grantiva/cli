import Foundation

// MARK: - Path Encoding

private func encodedSegment(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowedWithoutSlash) ?? value
}

private extension CharacterSet {
    static let urlPathAllowedWithoutSlash: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove("/")
        return set
    }()
}

// MARK: - Org Flag Endpoints (console contract §7a — snake_case wire)

enum OrgFlagEndpoints {
    private static let prefix = "api/v1/org/flags"

    /// `GET /api/v1/org/flags?app_id=&environment=`
    static func list(appId: String?, environment: String?) -> Endpoint<EmptyBody, [OrgFlag]> {
        var query: [URLQueryItem] = []
        if let appId { query.append(URLQueryItem(name: "app_id", value: appId)) }
        if let environment { query.append(URLQueryItem(name: "environment", value: environment)) }
        return Endpoint(path: prefix, method: .get, queryItems: query.isEmpty ? nil : query)
    }

    /// `POST /api/v1/org/flags`
    static func create(body: CreateOrgFlagRequest) -> Endpoint<CreateOrgFlagRequest, OrgFlagDetail> {
        Endpoint(path: prefix, method: .post, body: body)
    }

    /// `GET /api/v1/org/flags/:flagRef` — flagRef is a UUID or a flag_key.
    static func detail(flagRef: String) -> Endpoint<EmptyBody, OrgFlagDetail> {
        Endpoint(path: "\(prefix)/\(encodedSegment(flagRef))", method: .get)
    }

    /// `PUT /api/v1/org/flags/:flagRef`
    static func update(flagRef: String, body: UpdateOrgFlagRequest) -> Endpoint<UpdateOrgFlagRequest, OrgFlagDetail> {
        Endpoint(path: "\(prefix)/\(encodedSegment(flagRef))", method: .put, body: body)
    }

    /// `DELETE /api/v1/org/flags/:flagRef`
    static func delete(flagRef: String) -> Endpoint<EmptyBody, EmptyResponse> {
        Endpoint(path: "\(prefix)/\(encodedSegment(flagRef))", method: .delete)
    }

    /// `POST /api/v1/org/flags/:flagRef/toggle`
    static func toggle(flagRef: String, body: ToggleOrgFlagRequest) -> Endpoint<ToggleOrgFlagRequest, OrgFlagToggleResponse> {
        Endpoint(path: "\(prefix)/\(encodedSegment(flagRef))/toggle", method: .post, body: body)
    }

    /// `GET /api/v1/org/flags/:flagRef/history?limit=&offset=`
    static func history(flagRef: String, limit: Int?, offset: Int?) -> Endpoint<EmptyBody, [FlagHistoryEntry]> {
        var query: [URLQueryItem] = []
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let offset { query.append(URLQueryItem(name: "offset", value: String(offset))) }
        return Endpoint(
            path: "\(prefix)/\(encodedSegment(flagRef))/history",
            method: .get,
            queryItems: query.isEmpty ? nil : query
        )
    }

    /// `GET /api/v1/org/flags/:flagRef/overrides`
    static func listOverrides(flagRef: String) -> Endpoint<EmptyBody, [OrgFlagOverride]> {
        Endpoint(path: "\(prefix)/\(encodedSegment(flagRef))/overrides", method: .get)
    }

    /// `POST /api/v1/org/flags/:flagRef/overrides`
    static func createOverride(flagRef: String, body: CreateFlagOverrideRequest) -> Endpoint<CreateFlagOverrideRequest, OrgFlagOverride> {
        Endpoint(path: "\(prefix)/\(encodedSegment(flagRef))/overrides", method: .post, body: body)
    }

    /// `DELETE /api/v1/org/flags/:flagRef/overrides/:overrideId`
    static func deleteOverride(flagRef: String, overrideId: String) -> Endpoint<EmptyBody, EmptyResponse> {
        Endpoint(
            path: "\(prefix)/\(encodedSegment(flagRef))/overrides/\(encodedSegment(overrideId))",
            method: .delete
        )
    }
}

// MARK: - Org Flag Environment Endpoints (console contract §7a — snake_case wire)

enum FlagEnvironmentEndpoints {
    private static let prefix = "api/v1/org/flag-environments"

    /// `GET /api/v1/org/flag-environments`
    static func list() -> Endpoint<EmptyBody, [OrgFlagEnvironment]> {
        Endpoint(path: prefix, method: .get)
    }

    /// `POST /api/v1/org/flag-environments`
    static func create(body: CreateFlagEnvironmentRequest) -> Endpoint<CreateFlagEnvironmentRequest, OrgFlagEnvironment> {
        Endpoint(path: prefix, method: .post, body: body)
    }

    /// `PUT /api/v1/org/flag-environments/:envId` — also carries `{reorder: "up"|"down"}`.
    static func update(envId: String, body: UpdateFlagEnvironmentRequest) -> Endpoint<UpdateFlagEnvironmentRequest, OrgFlagEnvironment> {
        Endpoint(path: "\(prefix)/\(encodedSegment(envId))", method: .put, body: body)
    }

    /// `DELETE /api/v1/org/flag-environments/:envId`
    static func delete(envId: String) -> Endpoint<EmptyBody, EmptyResponse> {
        Endpoint(path: "\(prefix)/\(encodedSegment(envId))", method: .delete)
    }
}

// MARK: - Flag Rule Endpoints (existing SDK API — camelCase wire, UUID flag ids)

enum FlagRuleEndpoints {
    private static func prefix(_ flagId: String) -> String {
        "api/v1/flags/\(encodedSegment(flagId))/rules"
    }

    /// `GET /api/v1/flags/:flagId/rules`
    static func list(flagId: String) -> Endpoint<EmptyBody, [FlagRuleResponse]> {
        Endpoint(path: prefix(flagId), method: .get)
    }

    /// `POST /api/v1/flags/:flagId/rules`
    static func create(flagId: String, body: CreateFlagRuleRequest) -> Endpoint<CreateFlagRuleRequest, FlagRuleResponse> {
        Endpoint(path: prefix(flagId), method: .post, body: body)
    }

    /// `PUT /api/v1/flags/:flagId/rules/:ruleId`
    static func update(flagId: String, ruleId: String, body: UpdateFlagRuleRequest) -> Endpoint<UpdateFlagRuleRequest, FlagRuleResponse> {
        Endpoint(path: "\(prefix(flagId))/\(encodedSegment(ruleId))", method: .put, body: body)
    }

    /// `DELETE /api/v1/flags/:flagId/rules/:ruleId`
    static func delete(flagId: String, ruleId: String) -> Endpoint<EmptyBody, EmptyResponse> {
        Endpoint(path: "\(prefix(flagId))/\(encodedSegment(ruleId))", method: .delete)
    }

    /// `PATCH /api/v1/flags/:flagId/rules/reorder`
    static func reorder(flagId: String, body: ReorderFlagRulesRequest) -> Endpoint<ReorderFlagRulesRequest, [FlagRuleResponse]> {
        Endpoint(path: "\(prefix(flagId))/reorder", method: .patch, body: body)
    }
}

// MARK: - Flag Evaluation Endpoints (existing SDK API — camelCase wire)

enum FlagEvaluationEndpoints {
    /// `POST /api/v1/flags/:flagId/evaluate` — dry-run with full rule trace.
    static func evaluate(flagId: String, body: FlagEvaluationRequest) -> Endpoint<FlagEvaluationRequest, FlagEvaluationResponse> {
        Endpoint(path: "api/v1/flags/\(encodedSegment(flagId))/evaluate", method: .post, body: body)
    }

    /// `GET /api/v1/flags/stream?environment=` — SSE config stream.
    static func stream(environment: String?) -> Endpoint<EmptyBody, EmptyResponse> {
        Endpoint(
            path: "api/v1/flags/stream",
            method: .get,
            queryItems: environment.map { [URLQueryItem(name: "environment", value: $0)] }
        )
    }
}
