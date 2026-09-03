import Foundation

// MARK: - Path Encoding

private func orgSegment(_ value: String) -> String {
    EndpointPath.segment(value)
}

// MARK: - Org App Endpoints (§9b — snake_case wire)

enum OrgAppEndpoints {
    private static let prefix = "api/v1/org/apps"

    static func list() -> Endpoint<EmptyBody, [OrgApp]> {
        Endpoint(path: prefix, method: .get)
    }

    static func create(body: CreateOrgAppRequest) -> Endpoint<CreateOrgAppRequest, OrgApp> {
        Endpoint(path: prefix, method: .post, body: body)
    }

    /// `appRef` is a UUID or a bundle id.
    static func detail(appRef: String) -> Endpoint<EmptyBody, OrgApp> {
        Endpoint(path: "\(prefix)/\(orgSegment(appRef))", method: .get)
    }

    static func update(appRef: String, body: UpdateOrgAppRequest) -> Endpoint<UpdateOrgAppRequest, OrgApp> {
        Endpoint(path: "\(prefix)/\(orgSegment(appRef))", method: .put, body: body)
    }

    static func delete(appRef: String) -> Endpoint<EmptyBody, OrgDeleteResponse> {
        Endpoint(path: "\(prefix)/\(orgSegment(appRef))", method: .delete)
    }

    static func activate(appRef: String) -> Endpoint<EmptyBody, OrgApp> {
        Endpoint(path: "\(prefix)/\(orgSegment(appRef))/activate", method: .post)
    }

    static func deactivate(appRef: String) -> Endpoint<EmptyBody, OrgApp> {
        Endpoint(path: "\(prefix)/\(orgSegment(appRef))/deactivate", method: .post)
    }

    static func setPrimary(appRef: String) -> Endpoint<EmptyBody, OrgApp> {
        Endpoint(path: "\(prefix)/\(orgSegment(appRef))/set-primary", method: .post)
    }
}

// MARK: - Org Claim Endpoints (§9c — snake_case wire)

enum OrgClaimEndpoints {
    private static let prefix = "api/v1/org/claims"

    static func list() -> Endpoint<EmptyBody, [OrgClaim]> {
        Endpoint(path: prefix, method: .get)
    }

    static func create(body: OrgClaimDefinition) -> Endpoint<OrgClaimDefinition, OrgClaim> {
        Endpoint(path: prefix, method: .post, body: body)
    }

    /// `claimRef` is a UUID or a claim key.
    static func detail(claimRef: String) -> Endpoint<EmptyBody, OrgClaim> {
        Endpoint(path: "\(prefix)/\(orgSegment(claimRef))", method: .get)
    }

    static func update(claimRef: String, body: UpdateOrgClaimRequest) -> Endpoint<UpdateOrgClaimRequest, OrgClaim> {
        Endpoint(path: "\(prefix)/\(orgSegment(claimRef))", method: .put, body: body)
    }

    static func delete(claimRef: String) -> Endpoint<EmptyBody, OrgDeleteResponse> {
        Endpoint(path: "\(prefix)/\(orgSegment(claimRef))", method: .delete)
    }

    static func reorder(body: ReorderOrgClaimsRequest) -> Endpoint<ReorderOrgClaimsRequest, [OrgClaim]> {
        Endpoint(path: "\(prefix)/reorder", method: .put, body: body)
    }

    static func test(body: TestOrgClaimRequest) -> Endpoint<TestOrgClaimRequest, OrgClaimTestResponse> {
        Endpoint(path: "\(prefix)/test", method: .post, body: body)
    }

    static func preview(claimRef: String, body: PreviewOrgClaimRequest) -> Endpoint<PreviewOrgClaimRequest, OrgClaimTestResponse> {
        Endpoint(path: "\(prefix)/\(orgSegment(claimRef))/preview", method: .post, body: body)
    }
}

// MARK: - Org Device Endpoints (§9a — snake_case wire)

enum OrgDeviceEndpoints {
    private static let prefix = "api/v1/org/devices"

    static func list(_ query: OrgDeviceQuery) -> Endpoint<EmptyBody, OrgDeviceList> {
        var items: [URLQueryItem] = []
        if let page = query.page { items.append(URLQueryItem(name: "page", value: String(page))) }
        if let per = query.per { items.append(URLQueryItem(name: "per", value: String(per))) }
        if let riskMin = query.riskMin { items.append(URLQueryItem(name: "risk_min", value: String(riskMin))) }
        if let riskMax = query.riskMax { items.append(URLQueryItem(name: "risk_max", value: String(riskMax))) }
        if let jailbroken = query.jailbroken { items.append(URLQueryItem(name: "jailbroken", value: jailbroken ? "true" : "false")) }
        if let appId = query.appId { items.append(URLQueryItem(name: "app_id", value: appId)) }
        if let search = query.search { items.append(URLQueryItem(name: "search", value: search)) }
        return Endpoint(path: prefix, method: .get, queryItems: items.isEmpty ? nil : items)
    }

    static func detail(keyId: String) -> Endpoint<EmptyBody, OrgDeviceDetail> {
        Endpoint(path: "\(prefix)/\(orgSegment(keyId))", method: .get)
    }
}
