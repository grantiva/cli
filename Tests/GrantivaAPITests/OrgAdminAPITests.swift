import XCTest
@testable import GrantivaAPI
import GrantivaCore

final class OrgAdminAPITests: XCTestCase {
    private let base = URL(string: "https://api.example.com")!

    func testEndpointShapes() {
        XCTAssertEqual(try! OrgAdminEndpoints.listWebhooks().url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/webhooks")
        XCTAssertEqual(try! OrgAdminEndpoints.retry("W", "D").url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/webhooks/W/deliveries/D/retry")
        XCTAssertEqual(OrgAdminEndpoints.patchWebhook("W", PatchWebhookRequest(isActive: false)).method, .patch)
        XCTAssertEqual(OrgAdminEndpoints.deleteRule("R").method, .delete)
        XCTAssertEqual(try! OrgAdminEndpoints.patchFailureRate(PatchFailureRateAlertRequest(threshold: 20)).url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/alerts/failure-rate")
        XCTAssertEqual(try! OrgAdminEndpoints.rotateKey("K", RotateAPIKeyRequest()).url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/api-keys/K/rotate")
        XCTAssertEqual(try! OrgAdminEndpoints.removeMember("M").url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/members/M/remove")
        let audit = try! OrgAdminEndpoints.auditLog(page: 2, per: 25).url(relativeTo: base).absoluteString
        XCTAssertTrue(audit.contains("page=2") && audit.contains("per=25"), audit)
        XCTAssertEqual(try! OrgAdminEndpoints.usage().url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/usage")
    }

    func testAdminIdentifiersAreEncodedAsSinglePathSegments() {
        let url = try! OrgAdminEndpoints.retry("W#1", "D/2").url(relativeTo: base)
        XCTAssertEqual(
            url.absoluteString,
            "https://api.example.com/api/v1/org/webhooks/W%231/deliveries/D%2F2/retry"
        )
    }

    func testRequestsEncodeCamelCaseAndOmitNils() throws {
        let hook = String(decoding: try JSONEncoder().encode(CreateWebhookRequest(url: "https://x", events: ["device.new"])), as: UTF8.self)
        XCTAssertTrue(hook.contains("\"events\":[\"device.new\"]"), hook)
        XCTAssertFalse(hook.contains("description"), hook)
        let key = String(decoding: try JSONEncoder().encode(CreateAPIKeyRequest(name: "ci", scopes: ["flags:read"])), as: UTF8.self)
        XCTAssertFalse(key.contains("expiresAt"), key)
        let prefs = String(decoding: try JSONEncoder().encode(PatchNotificationPreferencesRequest(values: ["flagToggle": .bool(false), "featureVoteThresholdCount": .number(25)])), as: UTF8.self)
        XCTAssertTrue(prefs.contains("\"flagToggle\":false"), prefs)
        XCTAssertTrue(prefs.contains("\"featureVoteThresholdCount\":25"), prefs)
    }

    func testDecodesResponses() throws {
        let created = #"{"id":"W1","url":"https://x","events":["device.new"],"isActive":true,"description":null,"secret":"whsec_abc","createdAt":"2026-09-01T00:00:00Z"}"#
        XCTAssertEqual(try JSONDecoder().decode(WebhookCreated.self, from: Data(created.utf8)).secret, "whsec_abc")
        let key = #"{"id":"K1","name":"ci","keyPrefix":"grantiva_prod_sk_abc...","rawKey":"grantiva_prod_sk_abcdef","scopes":["flags:read"],"keyType":null,"isActive":true,"expiresAt":null,"createdAt":null}"#
        XCTAssertEqual(try JSONDecoder().decode(APIKeyCreated.self, from: Data(key.utf8)).scopes, ["flags:read"])
        let usage = #"{"currentMAD":12,"tierLimit":1000,"tierName":"Free","billingPeriodStart":"2026-09-01T00:00:00Z","billingPeriodEnd":"2026-10-01T00:00:00Z","usagePercent":1.2,"daysUntilReset":29,"resetDate":"2026-10-01"}"#
        XCTAssertEqual(try JSONDecoder().decode(OrgUsage.self, from: Data(usage.utf8)).currentMAD, 12)
        let audit = #"{"items":[{"id":"A1","actorEmail":"gpat_x...","action":"org.settings_updated","resourceType":"organization","resourceId":null,"metadata":{"name":"New"},"ipAddress":null,"createdAt":"2026-09-01T00:00:00Z"}],"metadata":{"page":1,"per":50,"total":1}}"#
        XCTAssertEqual(try JSONDecoder().decode(PaginatedItems<AuditEntry>.self, from: Data(audit.utf8)).items.first?.action, "org.settings_updated")
        let prefs = #"{"newFeatureRequest":true,"featureVoteThreshold":true,"featureVoteThresholdCount":10,"featureStatusChange":true,"newSupportTicket":true,"ticketAdminReply":true,"ticketResolved":true,"ticketUserReply":true,"flagToggle":false,"teamInvite":true,"usageAlert":true}"#
        XCTAssertFalse(try JSONDecoder().decode(NotificationPreferences.self, from: Data(prefs.utf8)).flagToggle)
    }

    func testFailingDouble() async {
        do { _ = try await OrgAdminClient.failing.settings(); XCTFail() } catch { }
    }
}
