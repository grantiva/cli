import Foundation

// MARK: - Analytics Endpoints (existing server API — camelCase wire)

enum AnalyticsEndpoints {
    private static let prefix = "api/v1/analytics"

    /// `GET /api/v1/analytics/overview?days=`
    static func overview(days: Int?) -> Endpoint<EmptyBody, AttestationAnalytics> {
        Endpoint(
            path: "\(prefix)/overview",
            method: .get,
            queryItems: days.map { [URLQueryItem(name: "days", value: String($0))] }
        )
    }

    /// `GET /api/v1/analytics/events?page=&perPage=&from=&to=&deviceId=&eventType=`
    static func events(_ query: EventsQuery) -> Endpoint<EmptyBody, PaginatedEventsResponse> {
        var items: [URLQueryItem] = []
        if let page = query.page { items.append(URLQueryItem(name: "page", value: String(page))) }
        if let perPage = query.perPage { items.append(URLQueryItem(name: "perPage", value: String(perPage))) }
        if let from = query.from { items.append(URLQueryItem(name: "from", value: from)) }
        if let to = query.to { items.append(URLQueryItem(name: "to", value: to)) }
        if let deviceId = query.deviceId { items.append(URLQueryItem(name: "deviceId", value: deviceId)) }
        if let eventType = query.eventType { items.append(URLQueryItem(name: "eventType", value: eventType.rawValue)) }
        return Endpoint(path: "\(prefix)/events", method: .get, queryItems: items.isEmpty ? nil : items)
    }

    /// `GET /api/v1/analytics/risk?timeRange=`
    static func risk(range: AnalyticsTimeRange?) -> Endpoint<EmptyBody, RiskAssessmentReport> {
        Endpoint(
            path: "\(prefix)/risk",
            method: .get,
            queryItems: range.map { [URLQueryItem(name: "timeRange", value: $0.rawValue)] }
        )
    }

    /// `GET /api/v1/analytics/compliance?period=`
    static func compliance(period: AnalyticsTimeRange?) -> Endpoint<EmptyBody, ComplianceReport> {
        Endpoint(
            path: "\(prefix)/compliance",
            method: .get,
            queryItems: period.map { [URLQueryItem(name: "period", value: $0.rawValue)] }
        )
    }

    /// `GET /api/v1/analytics/export?data=&period=` — always CSV.
    static func export(data: AnalyticsExportData, period: AnalyticsTimeRange?) -> Endpoint<EmptyBody, EmptyResponse> {
        var items = [URLQueryItem(name: "data", value: data.rawValue)]
        if let period { items.append(URLQueryItem(name: "period", value: period.rawValue)) }
        return Endpoint(path: "\(prefix)/export", method: .get, queryItems: items)
    }

    /// `GET /api/v1/analytics/devices/:keyId`
    static func device(keyId: String) -> Endpoint<EmptyBody, DeviceDetailsResponse> {
        let encoded = EndpointPath.segment(keyId)
        return Endpoint(path: "\(prefix)/devices/\(encoded)", method: .get)
    }
}
