import XCTest
@testable import GrantivaAPI
import GrantivaCore

final class AnalyticsAPITests: XCTestCase {
    private let base = URL(string: "https://api.example.com")!

    // MARK: - Endpoint shapes

    func testOverviewEndpoint() {
        XCTAssertEqual(
            AnalyticsEndpoints.overview(days: nil).url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/analytics/overview"
        )
        XCTAssertEqual(
            AnalyticsEndpoints.overview(days: 7).url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/analytics/overview?days=7"
        )
    }

    func testEventsEndpointCarriesEveryFilter() {
        let query = EventsQuery(
            page: 2, perPage: 25, from: "2026-09-01T00:00:00Z", to: "2026-09-02T00:00:00Z",
            deviceId: "dev-1", eventType: .attestationFailed
        )
        let url = AnalyticsEndpoints.events(query).url(relativeTo: base).absoluteString
        XCTAssertTrue(url.hasPrefix("https://api.example.com/api/v1/analytics/events?"), url)
        XCTAssertTrue(url.contains("page=2"), url)
        // The server reads `perPage` (camelCase) first; `per_page` is a fallback.
        XCTAssertTrue(url.contains("perPage=25"), url)
        XCTAssertTrue(url.contains("from=2026-09-01T00:00:00Z"), url)
        XCTAssertTrue(url.contains("to=2026-09-02T00:00:00Z"), url)
        XCTAssertTrue(url.contains("deviceId=dev-1"), url)
        XCTAssertTrue(url.contains("eventType=attestation_failed"), url)
    }

    func testEventsEndpointWithoutFiltersHasNoQuery() {
        XCTAssertEqual(
            AnalyticsEndpoints.events(EventsQuery()).url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/analytics/events"
        )
    }

    func testRiskAndComplianceEndpoints() {
        XCTAssertEqual(
            AnalyticsEndpoints.risk(range: .quarter).url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/analytics/risk?timeRange=90d"
        )
        XCTAssertEqual(
            AnalyticsEndpoints.compliance(period: .week).url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/analytics/compliance?period=7d"
        )
    }

    func testExportEndpoint() {
        XCTAssertEqual(
            AnalyticsEndpoints.export(data: .events, period: .day).url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/analytics/export?data=events&period=1d"
        )
        XCTAssertEqual(
            AnalyticsEndpoints.export(data: .devices, period: nil).url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/analytics/export?data=devices"
        )
    }

    func testDeviceEndpointPercentEncodesTheKeyId() {
        let url = AnalyticsEndpoints.device(keyId: "abc+/=").url(relativeTo: base).absoluteString
        XCTAssertTrue(url.hasPrefix("https://api.example.com/api/v1/analytics/devices/"), url)
        XCTAssertFalse(url.dropFirst("https://api.example.com/api/v1/analytics/devices/".count).contains("/"), url)
    }

    // MARK: - Decoding (wire fixtures mirror the backend DTOs)

    func testDecodesOverview() throws {
        let json = """
        {"totalAttestations":100,"successfulAttestations":97,"failedAttestations":3,"successRate":97.0,
         "uniqueDevices":42,"averageRiskScore":12.3,"suspiciousEvents":1,
         "recentEvents":[{"id":"E1","eventType":"attestation_validated","keyId":"K1","deviceId":null,
           "ipAddress":"1.2.3.4","success":true,"errorReason":null,"riskScore":5,"createdAt":"2026-09-01T21:52:37Z"}]}
        """.data(using: .utf8)!
        let overview = try JSONDecoder().decode(AttestationAnalytics.self, from: json)
        XCTAssertEqual(overview.uniqueDevices, 42)
        XCTAssertEqual(overview.recentEvents.first?.eventType, "attestation_validated")
        XCTAssertEqual(overview.recentEvents.first?.createdAt, "2026-09-01T21:52:37Z")
    }

    func testDecodesPaginatedEvents() throws {
        let json = """
        {"data":[],"meta":{"page":1,"perPage":50,"total":0,"totalPages":1}}
        """.data(using: .utf8)!
        let page = try JSONDecoder().decode(PaginatedEventsResponse.self, from: json)
        XCTAssertEqual(page.meta, PaginationMeta(page: 1, perPage: 50, total: 0, totalPages: 1))
    }

    func testDecodesRiskReportWithPeriodAsArray() throws {
        let json = """
        {"tenantId":"T","period":["2026-08-25T00:00:00Z","2026-09-01T00:00:00Z"],"totalDevices":3,
         "averageRiskScore":40.5,"riskDistribution":{"low":1,"medium":1,"high":0,"critical":1},
         "highRiskDevices":[{"keyId":"K9","deviceModel":"iPhone16,1","riskScore":88,"jailbreakDetected":true,
           "suspiciousEvents":4,"lastAttestation":"2026-09-01T10:00:00Z"}],
         "recentSecurityEvents":[{"eventType":"suspicious_activity","keyId":"K9","riskScore":88,"timestamp":"2026-09-01T10:00:00Z"}],
         "generatedAt":"2026-09-01T12:00:00Z"}
        """.data(using: .utf8)!
        let report = try JSONDecoder().decode(RiskAssessmentReport.self, from: json)
        XCTAssertEqual(report.period.count, 2)
        XCTAssertEqual(report.riskDistribution["critical"], 1)
        XCTAssertEqual(report.highRiskDevices.first?.keyId, "K9")
    }

    func testDecodesComplianceReport() throws {
        let json = """
        {"tenantId":"T","reportType":"summary","period":["a","b"],"totalDevices":2,"compliantDevices":1,
         "nonCompliantDevices":1,"complianceRate":50.0,"violationSummary":{"jailbreakDetected":1},
         "deviceCompliance":[{"keyId":"K1","deviceModel":null,"osVersion":"17.0","isCompliant":false,
           "complianceScore":40,"violations":["jailbreakDetected","outdatedOS(\\"16.0\\")"],"lastChecked":"2026-09-01T00:00:00Z"}],
         "generatedAt":"2026-09-01T00:00:00Z"}
        """.data(using: .utf8)!
        let report = try JSONDecoder().decode(ComplianceReport.self, from: json)
        XCTAssertEqual(report.deviceCompliance.first?.violations.count, 2)
        XCTAssertEqual(report.violationSummary["jailbreakDetected"], 1)
    }

    func testDecodesDeviceDetailWithSnakeCaseProfileAndEnumViolations() throws {
        let json = """
        {"keyId":"K1",
         "deviceProfile":{"id":"D1","organization_id":{"id":"O1"},"key_id":"K1","first_seen":"2026-08-01T00:00:00Z",
           "last_attestation":"2026-09-01T00:00:00Z","attestation_count":12,"risk_score":30,"device_model":"iPhone16,1",
           "os_version":"18.0","app_version":"2.1.0","first_app_version":"2.0.0","jailbreak_detected":false,
           "is_development_build":false,"app_store_receipt":true,"permissions":["camera"],"last_country":"US",
           "suspicious_events":0,"last_suspicious_event_at":null,"consecutive_clean_attestations":12,
           "device_fingerprint":null,"subject_id":null,"created_at":"2026-08-01T00:00:00Z","updated_at":"2026-09-01T00:00:00Z"},
         "recentEvents":[],
         "complianceStatus":{"isCompliant":false,"score":60,
           "violations":[{"jailbreakDetected":{}},{"outdatedOS":{"_0":"16.0"}},{"highRiskScore":{"_0":88}}],
           "lastChecked":"2026-09-01T00:00:00Z"},
         "lastUpdated":"2026-09-01T00:00:00Z"}
        """.data(using: .utf8)!
        let detail = try JSONDecoder().decode(DeviceDetailsResponse.self, from: json)
        XCTAssertEqual(detail.deviceProfile.deviceModel, "iPhone16,1")
        XCTAssertEqual(detail.deviceProfile.consecutiveCleanAttestations, 12)
        XCTAssertEqual(detail.deviceProfile.permissions, ["camera"])
        XCTAssertEqual(detail.complianceStatus.violations.map(\.description),
                       ["jailbreakDetected", "outdatedOS(\"16.0\")", "highRiskScore(88)"])
    }

    func testComplianceViolationRoundTripsItsWireShape() throws {
        let cases = [
            #"{"jailbreakDetected":{}}"#,
            #"{"outdatedOS":{"_0":"16.0"}}"#,
            #"{"highRiskScore":{"_0":88}}"#,
        ]
        for wire in cases {
            let decoded = try JSONDecoder().decode(ComplianceViolation.self, from: wire.data(using: .utf8)!)
            let encoded = try JSONEncoder().encode(decoded)
            XCTAssertEqual(String(decoding: encoded, as: UTF8.self), wire)
        }
    }

    func testDeviceProfileEncodesBackToSnakeCase() throws {
        let profile = DeviceProfile(
            id: "D1", keyId: "K1", firstSeen: "a", lastAttestation: "b", attestationCount: 1, riskScore: 2,
            jailbreakDetected: false, suspiciousEvents: 0
        )
        let json = String(decoding: try JSONEncoder().encode(profile), as: UTF8.self)
        XCTAssertTrue(json.contains("\"key_id\":\"K1\""), json)
        XCTAssertTrue(json.contains("\"risk_score\":2"), json)
    }

    // MARK: - Failing double

    func testFailingClientThrowsNotAuthenticated() async {
        do {
            _ = try await AnalyticsClient.failing.overview(nil)
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.notAuthenticated = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }
}
