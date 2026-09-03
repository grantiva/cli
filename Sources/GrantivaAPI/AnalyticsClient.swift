import Foundation
import GrantivaCore

// MARK: - AnalyticsClient

/// API client for `grantiva console analytics` and `console devices`. Same
/// closure-struct shape as `ConsoleClient`: a `.live`-style convenience init
/// and a `.failing` double for tests.
public struct AnalyticsClient: Sendable {
    public var overview: @Sendable (_ days: Int?) async throws -> AttestationAnalytics
    public var events: @Sendable (EventsQuery) async throws -> PaginatedEventsResponse
    public var risk: @Sendable (AnalyticsTimeRange?) async throws -> RiskAssessmentReport
    public var compliance: @Sendable (AnalyticsTimeRange?) async throws -> ComplianceReport
    /// Raw CSV bytes.
    public var export: @Sendable (AnalyticsExportData, AnalyticsTimeRange?) async throws -> Data
    public var device: @Sendable (_ keyId: String) async throws -> DeviceDetailsResponse

    public init(
        overview: @escaping @Sendable (Int?) async throws -> AttestationAnalytics,
        events: @escaping @Sendable (EventsQuery) async throws -> PaginatedEventsResponse,
        risk: @escaping @Sendable (AnalyticsTimeRange?) async throws -> RiskAssessmentReport,
        compliance: @escaping @Sendable (AnalyticsTimeRange?) async throws -> ComplianceReport,
        export: @escaping @Sendable (AnalyticsExportData, AnalyticsTimeRange?) async throws -> Data,
        device: @escaping @Sendable (String) async throws -> DeviceDetailsResponse
    ) {
        self.overview = overview
        self.events = events
        self.risk = risk
        self.compliance = compliance
        self.export = export
        self.device = device
    }
}

// MARK: - Convenience Init (live)

extension AnalyticsClient {
    public init(apiKey: String, baseURL: String) throws {
        let baseURL = try validatedAPIBaseURL(baseURL)
        let client = NetworkClient.authorized(apiKey: apiKey)

        self.init(
            overview: { days in
                try await client.execute(AnalyticsEndpoints.overview(days: days), baseURL: baseURL)
            },
            events: { query in
                try await client.execute(AnalyticsEndpoints.events(query), baseURL: baseURL)
            },
            risk: { range in
                try await client.execute(AnalyticsEndpoints.risk(range: range), baseURL: baseURL)
            },
            compliance: { period in
                try await client.execute(AnalyticsEndpoints.compliance(period: period), baseURL: baseURL)
            },
            export: { data, period in
                try await client.download(AnalyticsEndpoints.export(data: data, period: period), baseURL: baseURL)
            },
            device: { keyId in
                try await client.execute(AnalyticsEndpoints.device(keyId: keyId), baseURL: baseURL)
            }
        )
    }
}

// MARK: - Failing

extension AnalyticsClient {
    public static let failing = AnalyticsClient(
        overview: { _ in throw GrantivaError.notAuthenticated },
        events: { _ in throw GrantivaError.notAuthenticated },
        risk: { _ in throw GrantivaError.notAuthenticated },
        compliance: { _ in throw GrantivaError.notAuthenticated },
        export: { _, _ in throw GrantivaError.notAuthenticated },
        device: { _ in throw GrantivaError.notAuthenticated }
    )
}
