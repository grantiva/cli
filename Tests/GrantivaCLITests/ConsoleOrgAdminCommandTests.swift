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

    func testBillingShowIsTheDefaultAndExplicitAliasStillParses() {
        XCTAssertTrue(try ConsoleOrgCommand.BillingCommand.parseAsRoot([]) is ConsoleOrgCommand.BillingCommand.ShowCommand)
        XCTAssertTrue(try ConsoleOrgCommand.BillingCommand.parseAsRoot(["show"]) is ConsoleOrgCommand.BillingCommand.ShowCommand)
    }

    func testOrgSetNameRejectsAllKindsOfBlankInput() {
        XCTAssertThrowsError(try ConsoleOrgCommand.SettingsCommand.SetNameCommand.parse([" \t\n "]))
    }

    func testOrgSettingsSetNameSendsExactName() async throws {
        let decoder = JSONDecoder()
        let response = try decoder.decode(OrgSettings.self, from: Data(#"{"id":"O1","name":"New Name","slug":"new-name","serviceTier":"Free","serviceTierRawValue":"free","billingEmail":null,"createdAt":null,"updatedAt":null}"#.utf8))
        let captured = Capture<UpdateSettingsRequest>()
        var client = OrgAdminClient.failing
        client.updateSettings = { request in
            await captured.set(request)
            return response
        }

        try await ConsoleOrgCommand.SettingsCommand.SetNameCommand.parse(["New Name", "--json"]).run(client: client)

        let sent = await captured.value
        XCTAssertEqual(sent, UpdateSettingsRequest(name: "New Name"))
    }

    func testOrgSettingsBillingAndAuditCallExpectedClients() async throws {
        let decoder = JSONDecoder()
        let settings = try decoder.decode(OrgSettings.self, from: Data(#"{"id":"O1","name":"Example","slug":"example","serviceTier":"Free","serviceTierRawValue":"free","billingEmail":null,"createdAt":null,"updatedAt":null}"#.utf8))
        let billing = try decoder.decode(OrgBilling.self, from: Data(#"{"plan":"Free","planRawValue":"free","madUsed":3,"madLimit":100,"currentPeriodEnd":null,"stripeCustomerId":null,"stripeSubscriptionId":null}"#.utf8))
        let settingsCall = Capture<Bool>()
        let billingCall = Capture<Bool>()
        let auditCall = Capture<AuditQuery>()
        var client = OrgAdminClient.failing
        client.settings = {
            await settingsCall.set(true)
            return settings
        }
        client.billing = {
            await billingCall.set(true)
            return billing
        }
        client.auditLog = { page, per in
            await auditCall.set(AuditQuery(page: page, per: per))
            return PaginatedItems(items: [], metadata: .init(page: page ?? 1, per: per ?? 50, total: 0))
        }

        try await ConsoleOrgCommand.SettingsCommand.GetCommand.parse(["--json"]).run(client: client)
        try await ConsoleOrgCommand.BillingCommand.ShowCommand.parse(["--json"]).run(client: client)
        try await ConsoleAuditCommand.ListCommand.parse(["--page", "2", "--per", "25", "--json"]).run(client: client)

        let didCallSettings = await settingsCall.value
        let didCallBilling = await billingCall.value
        let sentAuditQuery = await auditCall.value
        XCTAssertEqual(didCallSettings, true)
        XCTAssertEqual(didCallBilling, true)
        XCTAssertEqual(sentAuditQuery, AuditQuery(page: 2, per: 25))
    }

    func testOrgSettingsBillingAndAuditMapRequiredScopes() async throws {
        var client = OrgAdminClient.failing
        client.settings = { throw GrantivaError.networkError("", 403) }
        client.billing = { throw GrantivaError.networkError("", 403) }
        client.auditLog = { _, _ in throw GrantivaError.networkError("", 403) }

        try await assertPermissionScope("org:read") {
            try await ConsoleOrgCommand.SettingsCommand.GetCommand.parse([]).run(client: client)
        }
        try await assertPermissionScope("admin:billing") {
            try await ConsoleOrgCommand.BillingCommand.ShowCommand.parse([]).run(client: client)
        }
        try await assertPermissionScope("admin:audit") {
            try await ConsoleAuditCommand.ListCommand.parse([]).run(client: client)
        }
    }

    func testWebhookCreateValidation() throws {
        XCTAssertNoThrow(try ConsoleWebhooksCommand.CreateCommand.parse(["https://ops.example.com/h", "--event", "device.new"]))
        XCTAssertThrowsError(try ConsoleWebhooksCommand.CreateCommand.parse(["https://ops.example.com/h"]))
        XCTAssertThrowsError(try ConsoleWebhooksCommand.CreateCommand.parse(["http://ops.example.com/h", "--event", "device.new"]))
        XCTAssertThrowsError(try ConsoleWebhooksCommand.CreateCommand.parse([" https://ops.example.com/h", "--event", "device.new"]))
        XCTAssertThrowsError(try ConsoleWebhooksCommand.CreateCommand.parse(["https://ops.example.com/h#fragment", "--event", "device.new"]))
        XCTAssertThrowsError(try ConsoleWebhooksCommand.CreateCommand.parse(["https://ops.example.com/h", "--event", " \n "]))
        XCTAssertNoThrow(try ConsoleWebhooksCommand.CreateCommand.parse(["https://ops.example.com/h", "--event", "server.new_event"]))
        XCTAssertThrowsError(try ConsoleWebhooksCommand.UpdateCommand.parse(["W1"]))
        XCTAssertThrowsError(try ConsoleWebhooksCommand.UpdateCommand.parse(["W1", "--event", "\t"]))
    }

    func testWebhookCommandsRejectBlankResourceIDs() {
        XCTAssertThrowsError(try ConsoleWebhooksCommand.GetCommand.parse([" \n "]))
        XCTAssertThrowsError(try ConsoleWebhooksCommand.EnableCommand.parse([" \n "]))
        XCTAssertThrowsError(try ConsoleWebhooksCommand.DisableCommand.parse([" \n "]))
        XCTAssertThrowsError(try ConsoleWebhooksCommand.UpdateCommand.parse([" \n ", "--description", "x"]))
        XCTAssertThrowsError(try ConsoleWebhooksCommand.TestCommand.parse([" \n "]))
        XCTAssertThrowsError(try ConsoleWebhooksCommand.DeliveriesCommand.parse([" \n "]))
        XCTAssertThrowsError(try ConsoleWebhooksCommand.RetryCommand.parse(["W1", " \n "]))
    }

    func testWebhookListAndCreateRunClientPaths() async throws {
        let request = Capture<CreateWebhookRequest>()
        var client = OrgAdminClient.failing
        client.listWebhooks = { [Webhook(id: "W1", url: "https://example.com/h", events: ["device.new"], isActive: true)] }
        client.createWebhook = { value in
            await request.set(value)
            return try! JSONDecoder().decode(WebhookCreated.self, from: Data(#"{"id":"W2","url":"https://example.com/h","events":["device.new"],"isActive":true,"description":"ops","secret":"whsec_once","createdAt":null}"#.utf8))
        }

        try await ConsoleWebhooksCommand.ListCommand.parse(["--json"]).run(client: client)
        try await ConsoleWebhooksCommand.CreateCommand.parse([
            "https://example.com/h", "--event", "device.new", "--description", "ops", "--json",
        ]).run(client: client)

        let capturedRequest = await request.value
        XCTAssertEqual(capturedRequest, CreateWebhookRequest(url: "https://example.com/h", events: ["device.new"], description: "ops"))
    }

    func testWebhookPatchCommandsBuildExactRequests() async throws {
        struct Call: Sendable, Equatable { let id: String; let body: PatchWebhookRequest }
        let calls = Capture<[Call]>()
        var client = OrgAdminClient.failing
        client.patchWebhook = { id, body in
            var current = await calls.value ?? []
            current.append(Call(id: id, body: body))
            await calls.set(current)
            return Webhook(id: id, url: "https://example.com/h", events: body.events ?? ["device.new"], isActive: body.isActive ?? true, description: body.description)
        }

        try await ConsoleWebhooksCommand.EnableCommand.parse(["W1", "--json"]).run(client: client)
        try await ConsoleWebhooksCommand.DisableCommand.parse(["W2", "--json"]).run(client: client)
        try await ConsoleWebhooksCommand.UpdateCommand.parse([
            "W3", "--event", "flag.updated", "--event", "device.high_risk", "--description", "security", "--json",
        ]).run(client: client)

        let capturedCalls = await calls.value
        XCTAssertEqual(capturedCalls, [
            Call(id: "W1", body: PatchWebhookRequest(isActive: true)),
            Call(id: "W2", body: PatchWebhookRequest(isActive: false)),
            Call(id: "W3", body: PatchWebhookRequest(events: ["flag.updated", "device.high_risk"], description: "security")),
        ])
    }

    func testWebhookTestDeliveriesAndRetryRunClientPaths() async throws {
        let tested = Capture<String>()
        let deliveriesFor = Capture<String>()
        let retried = Capture<[String]>()
        var client = OrgAdminClient.failing
        client.testWebhook = { id in
            await tested.set(id)
            return WebhookTestResult(success: true, httpStatus: 204, responseBody: nil, latencyMs: 4, error: nil)
        }
        client.deliveries = { id in await deliveriesFor.set(id); return [] }
        client.retryDelivery = { id, delivery in
            await retried.set([id, delivery])
            return try! JSONDecoder().decode(WebhookDelivery.self, from: Data(#"{"id":"D1","webhookId":"W1","eventType":"device.new","status":"delivered","httpStatus":204,"responseBody":null,"error":null,"attemptCount":2,"nextRetryAt":null,"deliveredAt":null,"createdAt":null}"#.utf8))
        }

        try await ConsoleWebhooksCommand.TestCommand.parse(["W1", "--json"]).run(client: client)
        try await ConsoleWebhooksCommand.DeliveriesCommand.parse(["W2", "--json"]).run(client: client)
        try await ConsoleWebhooksCommand.RetryCommand.parse(["W3", "D1", "--json"]).run(client: client)

        let testedID = await tested.value
        let deliveriesID = await deliveriesFor.value
        let retriedIDs = await retried.value
        XCTAssertEqual(testedID, "W1")
        XCTAssertEqual(deliveriesID, "W2")
        XCTAssertEqual(retriedIDs, ["W3", "D1"])
    }

    func testWebhookMutationsMapMissingResources() async throws {
        var client = OrgAdminClient.failing
        client.patchWebhook = { _, _ in throw GrantivaError.networkError("", 404) }
        client.testWebhook = { _ in throw GrantivaError.networkError("", 404) }
        client.deliveries = { _ in throw GrantivaError.networkError("", 404) }

        for run in [
            { try await ConsoleWebhooksCommand.EnableCommand.parse(["W1"]).run(client: client) },
            { try await ConsoleWebhooksCommand.TestCommand.parse(["W1"]).run(client: client) },
            { try await ConsoleWebhooksCommand.DeliveriesCommand.parse(["W1"]).run(client: client) },
        ] as [() async throws -> Void] {
            do {
                try await run()
                XCTFail("expected missing webhook")
            } catch {
                guard case GrantivaError.notFound(let message) = error else { return XCTFail("unexpected \(error)") }
                XCTAssertEqual(message, "webhook not found: W1")
            }
        }
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

    func testDestructiveAdminCommandsRejectBlankIDs() {
        XCTAssertThrowsError(try ConsoleWebhooksCommand.DeleteCommand.parse([" \n\t ", "--yes"]))
        XCTAssertThrowsError(try ConsoleAlertsCommand.RulesCommand.DeleteCommand.parse([" \n\t ", "--yes"]))
    }

    func testDestructiveAdminCommandsRefuseOffTTYBeforeCallingClient() async throws {
        let deletedWebhook = Capture<String>()
        let deletedRule = Capture<String>()
        var client = OrgAdminClient.failing
        client.deleteWebhook = { await deletedWebhook.set($0) }
        client.deleteRule = { await deletedRule.set($0) }

        do {
            try await ConsoleWebhooksCommand.DeleteCommand.parse(["W1"]).run(
                client: client,
                interactive: false,
                readAnswer: { XCTFail("non-TTY refusal must not read stdin"); return "yes" }
            )
            XCTFail("expected non-TTY refusal")
        } catch {
            guard case GrantivaError.invalidArgument(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertTrue(message.contains("--yes"), message)
        }

        do {
            try await ConsoleAlertsCommand.RulesCommand.DeleteCommand.parse(["R1"]).run(
                client: client,
                interactive: false,
                readAnswer: { XCTFail("non-TTY refusal must not read stdin"); return "yes" }
            )
            XCTFail("expected non-TTY refusal")
        } catch {
            guard case GrantivaError.invalidArgument(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertTrue(message.contains("--yes"), message)
        }

        let webhookCall = await deletedWebhook.value
        let ruleCall = await deletedRule.value
        XCTAssertNil(webhookCall, "webhook client must not run before confirmation")
        XCTAssertNil(ruleCall, "rule client must not run before confirmation")
    }

    func testDestructiveAdminCommandsWithYesCallClientWithExactID() async throws {
        let deletedWebhook = Capture<String>()
        let deletedRule = Capture<String>()
        var client = OrgAdminClient.failing
        client.deleteWebhook = { await deletedWebhook.set($0) }
        client.deleteRule = { await deletedRule.set($0) }

        try await ConsoleWebhooksCommand.DeleteCommand.parse(["W1", "--yes", "--json"]).run(client: client, interactive: false)
        try await ConsoleAlertsCommand.RulesCommand.DeleteCommand.parse(["R1", "--yes", "--json"]).run(client: client, interactive: false)

        let webhookCall = await deletedWebhook.value
        let ruleCall = await deletedRule.value
        XCTAssertEqual(webhookCall, "W1")
        XCTAssertEqual(ruleCall, "R1")
    }

    func testDestructiveAdminCommandsMapMissingResources() async throws {
        var client = OrgAdminClient.failing
        client.deleteWebhook = { _ in throw GrantivaError.networkError("", 404) }
        client.deleteRule = { _ in throw GrantivaError.networkError("", 404) }

        do {
            try await ConsoleWebhooksCommand.DeleteCommand.parse(["W1", "--yes"]).run(client: client, interactive: false)
            XCTFail("expected missing webhook")
        } catch {
            guard case GrantivaError.notFound(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertEqual(message, "webhook not found: W1")
        }

        do {
            try await ConsoleAlertsCommand.RulesCommand.DeleteCommand.parse(["R1", "--yes"]).run(client: client, interactive: false)
            XCTFail("expected missing rule")
        } catch {
            guard case GrantivaError.notFound(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertEqual(message, "rule not found: R1")
        }
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
        XCTAssertThrowsError(try ConsoleKeysCommand.CreateCommand.parse(["ci", "--scope", " "]))
        XCTAssertThrowsError(try ConsoleKeysCommand.CreateCommand.parse(["ci", "--scope", "flags:read", "--expires", "tomorrow"]))
        XCTAssertNoThrow(try ConsoleKeysCommand.CreateCommand.parse(["ci", "--scope", "flags:read", "--expires", "2027-01-01T00:00:00Z"]))
        XCTAssertNoThrow(try ConsoleKeysCommand.CreateCommand.parse(["ci", "--scope", "flags:read", "--expires", "2027-01-01T00:00:00.123Z"]))
    }

    func testKeysCreateNormalizesRequest() async throws {
        let captured = Capture<CreateAPIKeyRequest>()
        var client = OrgAdminClient.failing
        client.createKey = { request in
            await captured.set(request)
            return try! JSONDecoder().decode(APIKeyCreated.self, from: Data(#"{"id":"K1","name":"CI key","keyPrefix":"gpat_abc","rawKey":"secret","scopes":["flags:read"],"keyType":"org","isActive":true,"expiresAt":"2027-01-01T00:00:00Z","createdAt":null}"#.utf8))
        }

        try await ConsoleKeysCommand.CreateCommand.parse([
            " CI key \n", "--scope", " flags:read \n", "--expires", "2027-01-01T00:00:00Z", "--json",
        ]).run(client: client)

        let request = await captured.value
        XCTAssertEqual(request?.name, "CI key")
        XCTAssertEqual(request?.scopes, ["flags:read"])
        XCTAssertEqual(request?.expiresAt, "2027-01-01T00:00:00Z")
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
        XCTAssertThrowsError(try ConsoleTeamCommand.InviteCommand.parse(["@example.com"]))
        XCTAssertNoThrow(try ConsoleTeamCommand.InviteCommand.parse(["a@localhost"]))
        XCTAssertThrowsError(try ConsoleTeamCommand.InviteCommand.parse(["a@@example.com"]))
        XCTAssertThrowsError(try ConsoleTeamCommand.InviteCommand.parse(["a@b.com", "--role", "owner"]))
        XCTAssertEqual(try ConsoleTeamCommand.InviteCommand.parse(["a@b.com", "--role", "viewer"]).role, "viewer")
    }

    func testTeamInviteNormalizesEmailAndBuildsRequest() async throws {
        let captured = Capture<InviteRequest>()
        var client = OrgAdminClient.failing
        client.invite = { request in
            await captured.set(request)
            return try! JSONDecoder().decode(OrgInvite.self, from: Data(#"{"id":"I1","email":"dev@example.com","orgRole":"admin","status":"pending","invitedBy":null,"expiresAt":"2026-09-10T00:00:00Z","createdAt":null}"#.utf8))
        }

        try await ConsoleTeamCommand.InviteCommand.parse([
            " dev@example.com \n", "--role", "admin", "--json",
        ]).run(client: client)

        let request = await captured.value
        XCTAssertEqual(request?.email, "dev@example.com")
        XCTAssertEqual(request?.orgRole, "admin")
    }

    func testKeysAndTeamRejectBlankResourceIDs() {
        let blank = " \n\t "
        XCTAssertThrowsError(try ConsoleKeysCommand.GetCommand.parse([blank]))
        XCTAssertThrowsError(try ConsoleKeysCommand.RotateCommand.parse([blank, "--yes"]))
        XCTAssertThrowsError(try ConsoleKeysCommand.RevokeCommand.parse([blank, "--yes"]))
        XCTAssertThrowsError(try ConsoleTeamCommand.GetCommand.parse([blank]))
        XCTAssertThrowsError(try ConsoleTeamCommand.RevokeInviteCommand.parse([blank, "--yes"]))
        XCTAssertThrowsError(try ConsoleTeamCommand.RemoveCommand.parse([blank, "--yes"]))
    }

    func testRotateRevokeAndRemoveRefuseBeforeCallingClients() async throws {
        let rotated = Capture<String>()
        let revokedKey = Capture<String>()
        let revokedInvite = Capture<String>()
        let removedMember = Capture<String>()
        var client = OrgAdminClient.failing
        client.rotateKey = { id, _ in
            await rotated.set(id)
            throw GrantivaError.networkError("", 500)
        }
        client.revokeKey = { await revokedKey.set($0) }
        client.revokeInvite = { await revokedInvite.set($0) }
        client.removeMember = { await removedMember.set($0) }

        let operations: [() async throws -> Void] = [
            { try await ConsoleKeysCommand.RotateCommand.parse(["K1"]).run(client: client, interactive: false) },
            { try await ConsoleKeysCommand.RevokeCommand.parse(["K1"]).run(client: client, interactive: false) },
            { try await ConsoleTeamCommand.RevokeInviteCommand.parse(["I1"]).run(client: client, interactive: false) },
            { try await ConsoleTeamCommand.RemoveCommand.parse(["M1"]).run(client: client, interactive: false) },
        ]
        for operation in operations {
            do {
                try await operation()
                XCTFail("expected non-TTY refusal")
            } catch {
                guard case GrantivaError.invalidArgument(let message) = error else { return XCTFail("unexpected \(error)") }
                XCTAssertTrue(message.contains("--yes"), message)
            }
        }

        let rotatedValue = await rotated.value
        let revokedKeyValue = await revokedKey.value
        let revokedInviteValue = await revokedInvite.value
        let removedMemberValue = await removedMember.value
        XCTAssertNil(rotatedValue)
        XCTAssertNil(revokedKeyValue)
        XCTAssertNil(revokedInviteValue)
        XCTAssertNil(removedMemberValue)
    }

    func testRotateRevokeAndRemoveWithYesSendExactRequests() async throws {
        let rotated = Capture<(String, Int?)>()
        let revokedKey = Capture<String>()
        let revokedInvite = Capture<String>()
        let removedMember = Capture<String>()
        var client = OrgAdminClient.failing
        client.rotateKey = { id, request in
            await rotated.set((id, request.gracePeriodDays))
            return try! JSONDecoder().decode(APIKeyCreated.self, from: Data(#"{"id":"K2","name":"CI","keyPrefix":"gpat_new","rawKey":"secret","scopes":["flags:read"],"keyType":"org","isActive":true,"expiresAt":null,"createdAt":null}"#.utf8))
        }
        client.revokeKey = { await revokedKey.set($0) }
        client.revokeInvite = { await revokedInvite.set($0) }
        client.removeMember = { await removedMember.set($0) }

        try await ConsoleKeysCommand.RotateCommand.parse(["K1", "--grace-days", "7", "--yes", "--json"]).run(client: client, interactive: false)
        try await ConsoleKeysCommand.RevokeCommand.parse(["K1", "--yes", "--json"]).run(client: client, interactive: false)
        try await ConsoleTeamCommand.RevokeInviteCommand.parse(["I1", "--yes", "--json"]).run(client: client, interactive: false)
        try await ConsoleTeamCommand.RemoveCommand.parse(["M1", "--yes", "--json"]).run(client: client, interactive: false)

        let rotateRequest = await rotated.value
        XCTAssertEqual(rotateRequest?.0, "K1")
        XCTAssertEqual(rotateRequest?.1, 7)
        let revokedKeyValue = await revokedKey.value
        let revokedInviteValue = await revokedInvite.value
        let removedMemberValue = await removedMember.value
        XCTAssertEqual(revokedKeyValue, "K1")
        XCTAssertEqual(revokedInviteValue, "I1")
        XCTAssertEqual(removedMemberValue, "M1")
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

private struct AuditQuery: Sendable, Equatable {
    let page: Int?
    let per: Int?
}

private func assertPermissionScope(
    _ scope: String,
    operation: () async throws -> Void
) async throws {
    do {
        try await operation()
        XCTFail("expected permission error")
    } catch {
        guard case GrantivaError.permissionDenied(let message) = error else {
            return XCTFail("unexpected \(error)")
        }
        XCTAssertTrue(message.contains("'\(scope)'"), message)
    }
}

private actor Capture<T: Sendable> {
    private(set) var value: T?
    func set(_ new: T) { value = new }
}
