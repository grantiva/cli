import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaAPI
import GrantivaCore
import ArgumentParser

final class ConsoleOrgAdminCommandTests: XCTestCase {
    func testResourceGetCommandsParse() throws {
        XCTAssertEqual(try ConsoleWebhooksCommand.GetCommand.parse(["W1"]).webhook, "W1")
        XCTAssertEqual(try ConsoleAlertsCommand.RulesCommand.GetCommand.parse(["R1"]).rule, "R1")
        XCTAssertEqual(try ConsoleKeysCommand.GetCommand.parse(["K1"]).key, "K1")
        XCTAssertEqual(try ConsoleTeamCommand.GetCommand.parse(["M1"]).membership, "M1")
    }

    func testResourceGetCommandsSelectRequestedRecord() async throws {
        let decoder = JSONDecoder()
        var client = OrgAdminClient.failing
        client.listWebhooks = {
            [try! decoder.decode(Webhook.self, from: Data(#"{"id":"W1","url":"https://x","events":["device.new"],"isActive":true,"description":null,"createdAt":null,"updatedAt":null}"#.utf8))]
        }
        client.listRules = {
            [try! decoder.decode(RiskAlertRule.self, from: Data(#"{"id":"R1","name":"High risk","threshold":80,"comparison":"gte","webhookUrl":"https://x","isActive":true,"createdAt":null}"#.utf8))]
        }
        client.listKeys = {
            [try! decoder.decode(APIKeySummary.self, from: Data(#"{"id":"K1","name":"CI","keyPrefix":"gpat_abc","scopes":["flags:read"],"keyType":"org","isActive":true,"lastUsedAt":null,"expiresAt":null,"createdAt":null}"#.utf8))]
        }
        client.members = {
            [try! decoder.decode(OrgMember.self, from: Data(#"{"id":"M1","userId":"U1","email":"dev@example.com","orgRole":"member","joinedAt":"2026-09-01T00:00:00Z"}"#.utf8))]
        }

        try await ConsoleWebhooksCommand.GetCommand.parse(["W1", "--json"]).run(client: client)
        try await ConsoleAlertsCommand.RulesCommand.GetCommand.parse(["R1", "--json"]).run(client: client)
        try await ConsoleKeysCommand.GetCommand.parse(["K1", "--json"]).run(client: client)
        try await ConsoleTeamCommand.GetCommand.parse(["M1", "--json"]).run(client: client)
    }

    func testResourceGetMapsMissingRecord() async throws {
        var client = OrgAdminClient.failing
        client.listWebhooks = { [] }
        do {
            try await ConsoleWebhooksCommand.GetCommand.parse(["missing"]).run(client: client)
            XCTFail("expected not found")
        } catch {
            guard case GrantivaError.notFound(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertEqual(message, "webhook not found: missing")
        }
    }

    func testWebhookCreateValidation() throws {
        XCTAssertNoThrow(try ConsoleWebhooksCommand.CreateCommand.parse(["https://ops.example.com/h", "--event", "device.new"]))
        XCTAssertThrowsError(try ConsoleWebhooksCommand.CreateCommand.parse(["https://ops.example.com/h"]))
        XCTAssertThrowsError(try ConsoleWebhooksCommand.CreateCommand.parse(["http://ops.example.com/h", "--event", "device.new"]))
        XCTAssertNoThrow(try ConsoleWebhooksCommand.CreateCommand.parse(["https://ops.example.com/h", "--event", "server.new_event"]))
        XCTAssertThrowsError(try ConsoleWebhooksCommand.UpdateCommand.parse(["W1"]))
    }

    func testWebhookTestExitsNonZeroOnFailure() async throws {
        var client = OrgAdminClient.failing
        client.testWebhook = { _ in WebhookTestResult(success: false, httpStatus: 500, responseBody: "boom", latencyMs: 12, error: nil) }
        do {
            try await ConsoleWebhooksCommand.TestCommand.parse(["W1", "--json"]).run(client: client)
            XCTFail("expected non-zero exit")
        } catch let code as ExitCode {
            XCTAssertEqual(code, ExitCode(1))
        }
    }

    func testAlertsValidation() throws {
        XCTAssertThrowsError(try ConsoleAlertsCommand.RulesCommand.CreateCommand.parse(["r", "--threshold", "101", "--url", "https://x"]))
        XCTAssertThrowsError(try ConsoleAlertsCommand.RulesCommand.CreateCommand.parse(["r", "--threshold", "80", "--comparison", "lt", "--url", "https://x"]))
        XCTAssertEqual(try ConsoleAlertsCommand.RulesCommand.CreateCommand.parse(["r", "--threshold", "80", "--url", "https://x"]).comparison, "gte")
        XCTAssertThrowsError(try ConsoleAlertsCommand.FailureRateCommand.SetCommand.parse(["--threshold", "60"]))
        XCTAssertThrowsError(try ConsoleAlertsCommand.FailureRateCommand.SetCommand.parse([]))
        XCTAssertEqual(try ConsoleAlertsCommand.FailureRateCommand.SetCommand.parse(["--no-enabled"]).enabled, false)
        XCTAssertThrowsError(try ConsoleAlertsCommand.NotificationsCommand.SetCommand.parse(["bogus=on"]))
        XCTAssertThrowsError(try ConsoleAlertsCommand.NotificationsCommand.SetCommand.parse(["flagToggle=maybe"]))
        XCTAssertThrowsError(try ConsoleAlertsCommand.NotificationsCommand.SetCommand.parse(["featureVoteThresholdCount=0"]))
    }

    func testNotificationsSetBuildsAPatch() async throws {
        var client = OrgAdminClient.failing
        let captured = Capture<PatchNotificationPreferencesRequest>()
        client.patchNotificationPreferences = { request in
            await captured.set(request)
            return NotificationPreferences(newFeatureRequest: true, featureVoteThreshold: true, featureVoteThresholdCount: 25, featureStatusChange: true, newSupportTicket: true, ticketAdminReply: true, ticketResolved: true, ticketUserReply: true, flagToggle: false, teamInvite: true, usageAlert: true)
        }
        try await ConsoleAlertsCommand.NotificationsCommand.SetCommand.parse(["flagToggle=off", "featureVoteThresholdCount=25", "--json"]).run(client: client)
        let sent = await captured.value
        XCTAssertEqual(sent?.values["flagToggle"], .bool(false))
        XCTAssertEqual(sent?.values["featureVoteThresholdCount"], .number(25))
    }

    func testKeysCreateAndRotateParse() throws {
        let create = try ConsoleKeysCommand.CreateCommand.parse(["ci", "--scope", "flags:read", "--scope", "flags:write", "--expires", "2027-01-01T00:00:00Z"])
        XCTAssertEqual(create.scope, ["flags:read", "flags:write"])
        XCTAssertEqual(create.expires, "2027-01-01T00:00:00Z")
        XCTAssertThrowsError(try ConsoleKeysCommand.CreateCommand.parse(["ci"]))
        XCTAssertThrowsError(try ConsoleKeysCommand.RotateCommand.parse(["K1", "--grace-days", "365"]))
    }

    func testKeysCreateSurfacesTheSubsetRule() async throws {
        var client = OrgAdminClient.failing
        client.createKey = { _ in throw GrantivaError.networkError(#"{"error":"This key cannot grant scopes it does not hold: flags:write","code":"forbidden"}"#, 403) }
        do {
            try await ConsoleKeysCommand.CreateCommand.parse(["ci", "--scope", "flags:write"]).run(client: client)
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.permissionDenied(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertTrue(message.contains("cannot grant scopes it does not hold"), "the server's reason, not a generic scope hint: \(message)")
        }
    }

    func testTeamInviteAndRemoveParse() throws {
        XCTAssertThrowsError(try ConsoleTeamCommand.InviteCommand.parse(["not-an-email"]))
        XCTAssertThrowsError(try ConsoleTeamCommand.InviteCommand.parse(["a@b.com", "--role", "owner"]))
        XCTAssertEqual(try ConsoleTeamCommand.InviteCommand.parse(["a@b.com", "--role", "viewer"]).role, "viewer")
    }

    func testRemoveAndRevokeRefuseOffTTYWithoutYes() async throws {
        for run in [
            { try await ConsoleTeamCommand.RemoveCommand.parse(["M1"]).run(client: .failing) },
            { try await ConsoleTeamCommand.RevokeInviteCommand.parse(["I1"]).run(client: .failing) },
            { try await ConsoleKeysCommand.RevokeCommand.parse(["K1"]).run(client: .failing) },
            { try await ConsoleWebhooksCommand.DeleteCommand.parse(["W1"]).run(client: .failing) },
        ] as [() async throws -> Void] {
            do {
                try await run()
                XCTFail("expected refusal")
            } catch {
                guard case GrantivaError.invalidArgument(let message) = error else { return XCTFail("unexpected \(error)") }
                XCTAssertTrue(message.contains("--yes"), message)
            }
        }
    }

    func testOrgUsageAndAuditFormatting() {
        let usage = ConsoleAdminFormat.usage(OrgUsage(currentMAD: 12, tierLimit: 1000, tierName: "Free", billingPeriodStart: "2026-09-01T00:00:00Z", billingPeriodEnd: "2026-10-01T00:00:00Z", usagePercent: 1.2, daysUntilReset: 29, resetDate: "2026-10-01"))
        XCTAssertTrue(usage.contains("12 of 1000 monthly active devices (1.2%)"), usage)
        let audit = ConsoleAdminFormat.audit(PaginatedItems(items: [AuditEntry(id: "1", actorEmail: "gpat_x...", action: "org.settings_updated", resourceType: "organization", resourceId: nil, metadata: ["name": "New"], ipAddress: nil, createdAt: "2026-09-01T10:00:00Z")], metadata: .init(page: 1, per: 50, total: 1)))
        XCTAssertTrue(audit.contains("name=New"), audit)
        XCTAssertTrue(audit.contains("Page 1 of 1 · 1 entries"), audit)
    }
}

private actor Capture<T: Sendable> {
    private(set) var value: T?
    func set(_ new: T) { value = new }
}
