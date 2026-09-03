import ArgumentParser
import Foundation
import GrantivaAPI
import GrantivaCore

// MARK: - Shared helpers

enum ConsoleAdmin {
    /// Prints `value` as JSON or via `human`, respecting `--json`.
    static func emit<T: Encodable>(_ value: T, options: GlobalOptions, human: () -> String) throws {
        if options.json {
            Output.line(try JSONOutput.string(value))
        } else {
            Output.line(human())
        }
    }

    static func onOff(_ flag: Bool) -> String { flag ? "on" : "off" }
    static func date(_ iso: String?) -> String { iso.map(ConsoleFormat.shortDate) ?? "-" }
}

// MARK: - console webhooks

@available(macOS 15, *)
struct ConsoleWebhooksCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "webhooks",
        abstract: "Manage webhook endpoints and inspect their deliveries.",
        subcommands: [ListCommand.self, GetCommand.self, CreateCommand.self, EnableCommand.self, DisableCommand.self, UpdateCommand.self, DeleteCommand.self, TestCommand.self, DeliveriesCommand.self, RetryCommand.self]
    )

    static func notFound(_ id: String) -> String { "webhook not found: \(id)" }

    static func validateID(_ id: String, label: String = "Webhook ID") throws {
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError("\(label) must not be blank.")
        }
    }

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "list", abstract: "List webhook endpoints.")
        @OptionGroup var options: GlobalOptions
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            let hooks: [Webhook]
            do { hooks = try await client.listWebhooks() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.webhooksRead) }
            try ConsoleAdmin.emit(hooks, options: options) { ConsoleAdminFormat.webhooks(hooks) }
        }
    }

    struct GetCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "get", abstract: "Show one webhook endpoint.")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Webhook ID.") var webhook: String
        func validate() throws { try ConsoleWebhooksCommand.validateID(webhook) }
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            let hooks: [Webhook]
            do { hooks = try await client.listWebhooks() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.webhooksRead) }
            guard let hook = hooks.first(where: { $0.id == webhook }) else {
                throw GrantivaError.notFound(ConsoleWebhooksCommand.notFound(webhook))
            }
            try ConsoleAdmin.emit(hook, options: options) { ConsoleAdminFormat.webhooks([hook]) }
        }
    }

    struct CreateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "create",
            abstract: "Create a webhook endpoint. The signing secret is shown once.",
            discussion: "Example:\n  grantiva console webhooks create https://ops.example.com/grantiva --event device.high_risk --event flag.updated"
        )
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Endpoint URL (https).") var url: String
        @Option(name: .long, help: "Event type to subscribe to. Repeatable.") var event: [String]
        @Option(name: .long, help: "Description.") var description: String?
        func validate() throws {
            if event.isEmpty { throw ValidationError("Pass at least one --event.") }
            if event.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                throw ValidationError("Event types must not be blank.")
            }
            guard url == url.trimmingCharacters(in: .whitespacesAndNewlines),
                  let parsed = URL(string: url), parsed.scheme?.lowercased() == "https",
                  let host = parsed.host, !host.isEmpty, parsed.fragment == nil else {
                throw ValidationError("URL must be an https URL.")
            }
        }
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            let created: WebhookCreated
            do { created = try await client.createWebhook(CreateWebhookRequest(url: url, events: event, description: description)) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.webhooksWrite)
            }
            try ConsoleAdmin.emit(created, options: options) {
                """
                Created webhook \(created.id)
                  URL:     \(created.url)
                  Events:  \(created.events.joined(separator: ", "))
                  Secret:  \(created.secret)
                Store the secret now; it is not shown again. Verify deliveries with the X-Grantiva-Signature header (sha256= HMAC of the body).
                """
            }
        }
    }

    struct EnableCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "enable", abstract: "Resume deliveries to a webhook.")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Webhook ID.") var webhook: String
        func validate() throws { try ConsoleWebhooksCommand.validateID(webhook) }
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            try await ConsoleWebhooksCommand.patch(webhook, PatchWebhookRequest(isActive: true), options: options, client: client)
        }
    }

    struct DisableCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "disable", abstract: "Pause deliveries to a webhook without deleting it.")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Webhook ID.") var webhook: String
        func validate() throws { try ConsoleWebhooksCommand.validateID(webhook) }
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            try await ConsoleWebhooksCommand.patch(webhook, PatchWebhookRequest(isActive: false), options: options, client: client)
        }
    }

    struct UpdateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "update", abstract: "Change a webhook's events or description.")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Webhook ID.") var webhook: String
        @Option(name: .long, help: "Replace the subscribed events. Repeatable.") var event: [String] = []
        @Option(name: .long, help: "New description.") var description: String?
        func validate() throws {
            try ConsoleWebhooksCommand.validateID(webhook)
            if event.isEmpty, description == nil { throw ValidationError("Nothing to update. Pass --event or --description.") }
            if event.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                throw ValidationError("Event types must not be blank.")
            }
        }
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            try await ConsoleWebhooksCommand.patch(webhook, PatchWebhookRequest(events: event.isEmpty ? nil : event, description: description), options: options, client: client)
        }
    }

    static func patch(_ id: String, _ body: PatchWebhookRequest, options: GlobalOptions, client: OrgAdminClient) async throws {
        let hook: Webhook
        do { hook = try await client.patchWebhook(id, body) } catch {
            throw ConsoleSupport.map(error, scope: ConsoleScope.webhooksWrite, notFound: notFound(id))
        }
        try ConsoleAdmin.emit(hook, options: options) { ConsoleAdminFormat.webhooks([hook]) }
    }

    struct DeleteCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete a webhook endpoint and its delivery history.")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Webhook ID.") var webhook: String
        @Flag(name: .long, help: "Skip the confirmation prompt (required when stdin is not a TTY).") var yes = false
        func validate() throws {
            try ConsoleWebhooksCommand.validateID(webhook)
        }
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            try await run(client: client, interactive: isatty(fileno(stdin)) == 1)
        }
        func run(client: OrgAdminClient, interactive: Bool, readAnswer: () -> String? = { readLine() }) async throws {
            try ConsoleSupport.confirm("delete webhook '\(webhook)'", yes: yes, interactive: interactive, readAnswer: readAnswer)
            do { try await client.deleteWebhook(webhook) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.webhooksDelete, notFound: ConsoleWebhooksCommand.notFound(webhook))
            }
            try ConsoleAdmin.emit(OrgDeleteResponse(deleted: true, id: webhook), options: options) { "Deleted webhook '\(webhook)'" }
        }
    }

    struct TestCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "test", abstract: "Send a test event and report the endpoint's response.")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Webhook ID.") var webhook: String
        func validate() throws { try ConsoleWebhooksCommand.validateID(webhook) }
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            let result: WebhookTestResult
            do { result = try await client.testWebhook(webhook) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.webhooksTest, notFound: ConsoleWebhooksCommand.notFound(webhook))
            }
            try ConsoleAdmin.emit(result, options: options) {
                var lines = ["\(result.success ? "Delivered" : "Failed") in \(result.latencyMs) ms"]
                if let status = result.httpStatus { lines.append("  HTTP \(status)") }
                if let error = result.error { lines.append("  Error: \(error)") }
                if let body = result.responseBody, !body.isEmpty { lines.append("  Response: \(body.prefix(300))") }
                return lines.joined(separator: "\n")
            }
            if !result.success { throw ExitCode(1) }
        }
    }

    struct DeliveriesCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "deliveries", abstract: "List recent deliveries for a webhook.")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Webhook ID.") var webhook: String
        func validate() throws { try ConsoleWebhooksCommand.validateID(webhook) }
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            let items: [WebhookDelivery]
            do { items = try await client.deliveries(webhook) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.webhooksRead, notFound: ConsoleWebhooksCommand.notFound(webhook))
            }
            try ConsoleAdmin.emit(items, options: options) { ConsoleAdminFormat.deliveries(items) }
        }
    }

    struct RetryCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "retry", abstract: "Retry a failed delivery.")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Webhook ID.") var webhook: String
        @Argument(help: "Delivery ID.") var delivery: String
        func validate() throws {
            try ConsoleWebhooksCommand.validateID(webhook)
            try ConsoleWebhooksCommand.validateID(delivery, label: "Delivery ID")
        }
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            let item: WebhookDelivery
            do { item = try await client.retryDelivery(webhook, delivery) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.webhooksWrite, notFound: "delivery not found: \(delivery)")
            }
            try ConsoleAdmin.emit(item, options: options) { ConsoleAdminFormat.deliveries([item]) }
        }
    }
}

// MARK: - console alerts

@available(macOS 15, *)
struct ConsoleAlertsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "alerts",
        abstract: "Risk alert rules, the attestation failure-rate alert, and notification preferences.",
        subcommands: [RulesCommand.self, FailureRateCommand.self, NotificationsCommand.self]
    )

    struct RulesCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "rules", abstract: "Risk alert rules (Business plan and up).", subcommands: [ListCommand.self, GetCommand.self, CreateCommand.self, UpdateCommand.self, DeleteCommand.self, DeliveriesCommand.self])

        struct ListCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "list", abstract: "List risk alert rules.")
            @OptionGroup var options: GlobalOptions
            func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
            func run(client: OrgAdminClient) async throws {
                let rules: [RiskAlertRule]
                do { rules = try await client.listRules() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.alertsRead) }
                try ConsoleAdmin.emit(rules, options: options) { ConsoleAdminFormat.rules(rules) }
            }
        }

        struct GetCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "get", abstract: "Show one risk alert rule.")
            @OptionGroup var options: GlobalOptions
            @Argument(help: "Rule ID.") var rule: String
            func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
            func run(client: OrgAdminClient) async throws {
                let rules: [RiskAlertRule]
                do { rules = try await client.listRules() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.alertsRead) }
                guard let found = rules.first(where: { $0.id == rule }) else {
                    throw GrantivaError.notFound("rule not found: \(rule)")
                }
                try ConsoleAdmin.emit(found, options: options) { ConsoleAdminFormat.rules([found]) }
            }
        }

        struct CreateCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "create", abstract: "Alert a webhook when a device's risk score crosses a threshold.")
            @OptionGroup var options: GlobalOptions
            @Argument(help: "Rule name.") var name: String
            @Option(name: .long, help: "Risk score threshold, 0–100.") var threshold: Int
            @Option(name: .long, help: "gt (above) or gte (at or above). Default gte.") var comparison: String = "gte"
            @Option(name: .long, help: "Webhook URL to call.") var url: String
            func validate() throws {
                if !(0...100).contains(threshold) { throw ValidationError("--threshold must be 0–100.") }
                if !["gt", "gte"].contains(comparison) { throw ValidationError("--comparison must be gt or gte.") }
            }
            func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
            func run(client: OrgAdminClient) async throws {
                let rule: RiskAlertRule
                do { rule = try await client.createRule(CreateRiskAlertRuleRequest(name: name, threshold: threshold, comparison: comparison, webhookUrl: url)) } catch {
                    throw ConsoleSupport.map(error, scope: ConsoleScope.alertsWrite)
                }
                try ConsoleAdmin.emit(rule, options: options) { ConsoleAdminFormat.rules([rule]) }
            }
        }

        struct UpdateCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "update", abstract: "Change a rule's name, threshold, comparison, URL, or active state.")
            @OptionGroup var options: GlobalOptions
            @Argument(help: "Rule ID.") var rule: String
            @Option(name: .long) var name: String?
            @Option(name: .long, help: "0–100.") var threshold: Int?
            @Option(name: .long, help: "gt or gte.") var comparison: String?
            @Option(name: .long) var url: String?
            @Flag(name: .long, inversion: .prefixedNo, help: "Activate or deactivate the rule.") var active: Bool?
            func validate() throws {
                if name == nil, threshold == nil, comparison == nil, url == nil, active == nil { throw ValidationError("Nothing to update.") }
                if let threshold, !(0...100).contains(threshold) { throw ValidationError("--threshold must be 0–100.") }
                if let comparison, !["gt", "gte"].contains(comparison) { throw ValidationError("--comparison must be gt or gte.") }
            }
            func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
            func run(client: OrgAdminClient) async throws {
                let updated: RiskAlertRule
                do { updated = try await client.patchRule(rule, PatchRiskAlertRuleRequest(name: name, threshold: threshold, comparison: comparison, webhookUrl: url, isActive: active)) } catch {
                    throw ConsoleSupport.map(error, scope: ConsoleScope.alertsWrite, notFound: "rule not found: \(rule)")
                }
                try ConsoleAdmin.emit(updated, options: options) { ConsoleAdminFormat.rules([updated]) }
            }
        }

        struct DeleteCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete a risk alert rule.")
            @OptionGroup var options: GlobalOptions
            @Argument(help: "Rule ID.") var rule: String
            @Flag(name: .long, help: "Skip the confirmation prompt (required when stdin is not a TTY).") var yes = false
            func validate() throws {
                if rule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw ValidationError("Rule ID must not be blank.")
                }
            }
            func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
            func run(client: OrgAdminClient) async throws {
                try await run(client: client, interactive: isatty(fileno(stdin)) == 1)
            }
            func run(client: OrgAdminClient, interactive: Bool, readAnswer: () -> String? = { readLine() }) async throws {
                try ConsoleSupport.confirm("delete risk alert rule '\(rule)'", yes: yes, interactive: interactive, readAnswer: readAnswer)
                do { try await client.deleteRule(rule) } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.alertsWrite, notFound: "rule not found: \(rule)") }
                try ConsoleAdmin.emit(OrgDeleteResponse(deleted: true, id: rule), options: options) { "Deleted rule '\(rule)'" }
            }
        }

        struct DeliveriesCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "deliveries", abstract: "Recent risk alert deliveries across all rules.")
            @OptionGroup var options: GlobalOptions
            func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
            func run(client: OrgAdminClient) async throws {
                let items: [RiskAlertDelivery]
                do { items = try await client.ruleDeliveries() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.alertsRead) }
                try ConsoleAdmin.emit(items, options: options) { ConsoleAdminFormat.ruleDeliveries(items) }
            }
        }
    }

    struct FailureRateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "failure-rate", abstract: "The attestation failure-rate alert.", subcommands: [GetCommand.self, SetCommand.self, HistoryCommand.self])

        struct GetCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "get", abstract: "Show the failure-rate alert settings.")
            @OptionGroup var options: GlobalOptions
            func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
            func run(client: OrgAdminClient) async throws {
                let alert: FailureRateAlert
                do { alert = try await client.failureRate() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.alertsRead) }
                try ConsoleAdmin.emit(alert, options: options) { ConsoleAdminFormat.failureRate(alert) }
            }
        }

        struct SetCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "set", abstract: "Enable, disable, or tune the failure-rate alert.")
            @OptionGroup var options: GlobalOptions
            @Flag(name: .long, inversion: .prefixedNo, help: "Turn the alert on or off.") var enabled: Bool?
            @Option(name: .long, help: "Failure-rate percentage that triggers the alert, 5–50.") var threshold: Int?
            @Option(name: .customLong("min-attestations"), help: "Minimum attestations in the window before the rate counts.") var minAttestations: Int?
            func validate() throws {
                if enabled == nil, threshold == nil, minAttestations == nil { throw ValidationError("Nothing to set. Pass --enabled/--no-enabled, --threshold, or --min-attestations.") }
                if let threshold, !(5...50).contains(threshold) { throw ValidationError("--threshold must be 5–50.") }
                if let minAttestations, minAttestations < 1 { throw ValidationError("--min-attestations must be at least 1.") }
            }
            func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
            func run(client: OrgAdminClient) async throws {
                let alert: FailureRateAlert
                do { alert = try await client.patchFailureRate(PatchFailureRateAlertRequest(isEnabled: enabled, threshold: threshold, minAttestationCount: minAttestations)) } catch {
                    throw ConsoleSupport.map(error, scope: ConsoleScope.orgWrite)
                }
                try ConsoleAdmin.emit(alert, options: options) { ConsoleAdminFormat.failureRate(alert) }
            }
        }

        struct HistoryCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "history", abstract: "Times the failure-rate alert fired.")
            @OptionGroup var options: GlobalOptions
            func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
            func run(client: OrgAdminClient) async throws {
                let events: [FailureRateAlertEvent]
                do { events = try await client.failureRateHistory() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.alertsRead) }
                try ConsoleAdmin.emit(events, options: options) {
                    guard !events.isEmpty else { return "The failure-rate alert has never fired." }
                    return ConsoleFormat.table(headers: ["WHEN", "FAILURE RATE", "ATTESTATIONS"], rows: events.map {
                        [ConsoleAdmin.date($0.triggeredAt), String(format: "%.1f%%", $0.failureRate), String($0.attestationCount)]
                    })
                }
            }
        }
    }

    struct NotificationsCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "notifications", abstract: "Which events email the org admin.", subcommands: [GetCommand.self, SetCommand.self])

        static let toggles = ["newFeatureRequest", "featureVoteThreshold", "featureStatusChange", "newSupportTicket", "ticketAdminReply", "ticketResolved", "ticketUserReply", "flagToggle", "teamInvite", "usageAlert"]

        struct GetCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "get", abstract: "Show notification preferences.")
            @OptionGroup var options: GlobalOptions
            func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
            func run(client: OrgAdminClient) async throws {
                let prefs: NotificationPreferences
                do { prefs = try await client.notificationPreferences() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.orgRead) }
                try ConsoleAdmin.emit(prefs, options: options) { ConsoleAdminFormat.notificationPreferences(prefs) }
            }
        }

        struct SetCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "set",
                abstract: "Turn notifications on or off.",
                discussion: "Example:\n  grantiva console alerts notifications set flagToggle=off usageAlert=on featureVoteThresholdCount=25\nToggles: \(NotificationsCommand.toggles.joined(separator: ", "))"
            )
            @OptionGroup var options: GlobalOptions
            @Argument(help: "name=on|off pairs, or featureVoteThresholdCount=<n>.") var settings: [String]
            func validate() throws {
                if settings.isEmpty { throw ValidationError("Pass at least one name=on|off.") }
                for pair in settings {
                    let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                    guard parts.count == 2 else { throw ValidationError("Expected name=value, got '\(pair)'.") }
                    if parts[0] == "featureVoteThresholdCount" {
                        guard let n = Int(parts[1]), (1...10_000).contains(n) else { throw ValidationError("featureVoteThresholdCount must be 1–10000.") }
                    } else {
                        guard NotificationsCommand.toggles.contains(parts[0]) else { throw ValidationError("Unknown preference '\(parts[0])'.") }
                        guard ["on", "off", "true", "false"].contains(parts[1].lowercased()) else { throw ValidationError("'\(parts[0])' must be on or off.") }
                    }
                }
            }
            func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
            func run(client: OrgAdminClient) async throws {
                var values: [String: JSONValue] = [:]
                for pair in settings {
                    let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                    if parts[0] == "featureVoteThresholdCount" {
                        values[parts[0]] = .number(Double(Int(parts[1])!))
                    } else {
                        values[parts[0]] = .bool(["on", "true"].contains(parts[1].lowercased()))
                    }
                }
                let prefs: NotificationPreferences
                do { prefs = try await client.patchNotificationPreferences(PatchNotificationPreferencesRequest(values: values)) } catch {
                    throw ConsoleSupport.map(error, scope: ConsoleScope.orgWrite)
                }
                try ConsoleAdmin.emit(prefs, options: options) { ConsoleAdminFormat.notificationPreferences(prefs) }
            }
        }
    }
}

// MARK: - console keys

@available(macOS 15, *)
struct ConsoleKeysCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "keys",
        abstract: "Manage API keys. A key can only create keys with scopes it holds itself.",
        subcommands: [ListCommand.self, GetCommand.self, CreateCommand.self, RotateCommand.self, RevokeCommand.self]
    )

    static func notFound(_ id: String) -> String { "API key not found: \(id)" }

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "list", abstract: "List API keys (prefixes only).")
        @OptionGroup var options: GlobalOptions
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            let keys: [APIKeySummary]
            do { keys = try await client.listKeys() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.keysRead) }
            try ConsoleAdmin.emit(keys, options: options) { ConsoleAdminFormat.keys(keys) }
        }
    }

    struct GetCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "get", abstract: "Show one API key (prefix only).")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Key ID.") var key: String
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            let keys: [APIKeySummary]
            do { keys = try await client.listKeys() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.keysRead) }
            guard let found = keys.first(where: { $0.id == key }) else {
                throw GrantivaError.notFound(ConsoleKeysCommand.notFound(key))
            }
            try ConsoleAdmin.emit(found, options: options) { ConsoleAdminFormat.keys([found]) }
        }
    }

    struct CreateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "create",
            abstract: "Create an API key. The raw key is shown once.",
            discussion: "Example:\n  grantiva console keys create ci-flags --scope flags:read --scope flags:write --expires 2027-01-01T00:00:00Z"
        )
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Key name.") var name: String
        @Option(name: .long, help: "Scope to grant. Repeatable.") var scope: [String]
        @Option(name: .long, help: "Expiry as an ISO 8601 timestamp.") var expires: String?
        func validate() throws {
            if scope.isEmpty { throw ValidationError("Pass at least one --scope.") }
            if name.trimmingCharacters(in: .whitespaces).isEmpty { throw ValidationError("Name must not be blank.") }
        }
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            let created: APIKeyCreated
            do { created = try await client.createKey(CreateAPIKeyRequest(name: name, scopes: scope, expiresAt: expires)) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.keysWrite)
            }
            try ConsoleAdmin.emit(created, options: options) { ConsoleAdminFormat.createdKey(created) }
        }
    }

    struct RotateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "rotate", abstract: "Replace a key with a new one holding the same scopes. The old key is revoked immediately unless --grace-days is given.")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Key ID.") var key: String
        @Option(name: .customLong("grace-days"), help: "Keep the old key working for this many days.") var graceDays: Int?
        func validate() throws {
            if let graceDays, !(1...90).contains(graceDays) { throw ValidationError("--grace-days must be 1–90.") }
        }
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            let created: APIKeyCreated
            do { created = try await client.rotateKey(key, RotateAPIKeyRequest(gracePeriodDays: graceDays)) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.keysWrite, notFound: ConsoleKeysCommand.notFound(key))
            }
            try ConsoleAdmin.emit(created, options: options) { ConsoleAdminFormat.createdKey(created) }
        }
    }

    struct RevokeCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "revoke", abstract: "Revoke a key immediately.")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Key ID.") var key: String
        @Flag(name: .long, help: "Skip the confirmation prompt (required when stdin is not a TTY).") var yes = false
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            try ConsoleSupport.confirm("revoke API key '\(key)'", yes: yes)
            do { try await client.revokeKey(key) } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.keysWrite, notFound: ConsoleKeysCommand.notFound(key)) }
            try ConsoleAdmin.emit(OrgDeleteResponse(deleted: true, id: key), options: options) { "Revoked API key '\(key)'" }
        }
    }
}

// MARK: - console team

@available(macOS 15, *)
struct ConsoleTeamCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "team",
        abstract: "Members and invites.",
        subcommands: [MembersCommand.self, GetCommand.self, InvitesCommand.self, InviteCommand.self, RevokeInviteCommand.self, RemoveCommand.self]
    )

    struct MembersCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "members", abstract: "List members and their roles.")
        @OptionGroup var options: GlobalOptions
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            let members: [OrgMember]
            do { members = try await client.members() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.orgRead) }
            try ConsoleAdmin.emit(members, options: options) { ConsoleAdminFormat.members(members) }
        }
    }

    struct GetCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "get", abstract: "Show one organization member.")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Membership ID.") var membership: String
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            let members: [OrgMember]
            do { members = try await client.members() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.orgRead) }
            guard let member = members.first(where: { $0.id == membership }) else {
                throw GrantivaError.notFound("membership not found: \(membership)")
            }
            try ConsoleAdmin.emit(member, options: options) { ConsoleAdminFormat.members([member]) }
        }
    }

    struct InvitesCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "invites", abstract: "List invites.")
        @OptionGroup var options: GlobalOptions
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            let invites: [OrgInvite]
            do { invites = try await client.invites() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.orgRead) }
            try ConsoleAdmin.emit(invites, options: options) { ConsoleAdminFormat.invites(invites) }
        }
    }

    struct InviteCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "invite", abstract: "Email an invite to join the organization.")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Email address.") var email: String
        @Option(name: .long, help: "Role: viewer, member, or admin. Default member.") var role: String?
        func validate() throws {
            if !email.contains("@") { throw ValidationError("'\(email)' is not an email address.") }
            if let role, !["viewer", "member", "admin"].contains(role) { throw ValidationError("--role must be viewer, member, or admin.") }
        }
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            let invite: OrgInvite
            do { invite = try await client.invite(InviteRequest(email: email, orgRole: role)) } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.adminTeam) }
            try ConsoleAdmin.emit(invite, options: options) { "Invited \(invite.email) as \(invite.orgRole ?? "member"); expires \(ConsoleAdmin.date(invite.expiresAt))" }
        }
    }

    struct RevokeInviteCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "revoke-invite", abstract: "Cancel a pending invite.")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Invite ID.") var invite: String
        @Flag(name: .long, help: "Skip the confirmation prompt (required when stdin is not a TTY).") var yes = false
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            try ConsoleSupport.confirm("revoke invite '\(invite)'", yes: yes)
            do { try await client.revokeInvite(invite) } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.adminTeam, notFound: "invite not found: \(invite)") }
            try ConsoleAdmin.emit(OrgDeleteResponse(deleted: true, id: invite), options: options) { "Revoked invite '\(invite)'" }
        }
    }

    struct RemoveCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "remove", abstract: "Remove a member. Admins and the owner cannot be removed with an API key.")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Membership ID (from `team members`).") var membership: String
        @Flag(name: .long, help: "Skip the confirmation prompt (required when stdin is not a TTY).") var yes = false
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            try ConsoleSupport.confirm("remove member '\(membership)'", yes: yes)
            do { try await client.removeMember(membership) } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.adminTeam, notFound: "membership not found: \(membership)") }
            try ConsoleAdmin.emit(OrgDeleteResponse(deleted: true, id: membership), options: options) { "Removed member '\(membership)'" }
        }
    }
}

// MARK: - console audit

@available(macOS 15, *)
struct ConsoleAuditCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "audit", abstract: "The organization audit log.", subcommands: [ListCommand.self])

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "list", abstract: "List audit entries, newest first.")
        @OptionGroup var options: GlobalOptions
        @Option(name: .long, help: "Page number, starting at 1.") var page: Int?
        @Option(name: .long, help: "Entries per page, 1–100. Default 50.") var per: Int?
        func validate() throws {
            if let page, page < 1 { throw ValidationError("--page must be at least 1.") }
            if let per, !(1...100).contains(per) { throw ValidationError("--per must be 1–100.") }
        }
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            let result: PaginatedItems<AuditEntry>
            do { result = try await client.auditLog(page, per) } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.adminAudit) }
            try ConsoleAdmin.emit(result, options: options) { ConsoleAdminFormat.audit(result) }
        }
    }
}

// MARK: - console org

@available(macOS 15, *)
struct ConsoleOrgCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "org", abstract: "Organization settings, usage, and billing.", subcommands: [SettingsCommand.self, UsageCommand.self, BillingCommand.self])

    struct SettingsCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "settings", abstract: "Organization settings.", subcommands: [GetCommand.self, SetNameCommand.self])

        struct GetCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "get", abstract: "Show organization settings.")
            @OptionGroup var options: GlobalOptions
            func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
            func run(client: OrgAdminClient) async throws {
                let settings: OrgSettings
                do { settings = try await client.settings() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.orgRead) }
                try ConsoleAdmin.emit(settings, options: options) { ConsoleAdminFormat.settings(settings) }
            }
        }

        struct SetNameCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "set-name", abstract: "Rename the organization. The slug follows the name.")
            @OptionGroup var options: GlobalOptions
            @Argument(help: "New name.") var name: String
            func validate() throws {
                if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw ValidationError("Name must not be blank.")
                }
            }
            func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
            func run(client: OrgAdminClient) async throws {
                let settings: OrgSettings
                do { settings = try await client.updateSettings(UpdateSettingsRequest(name: name)) } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.orgWrite) }
                try ConsoleAdmin.emit(settings, options: options) { ConsoleAdminFormat.settings(settings) }
            }
        }
    }

    struct UsageCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "usage", abstract: "Monthly active devices against the plan limit.")
        @OptionGroup var options: GlobalOptions
        func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
        func run(client: OrgAdminClient) async throws {
            let usage: OrgUsage
            do { usage = try await client.usage() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.orgRead) }
            try ConsoleAdmin.emit(usage, options: options) { ConsoleAdminFormat.usage(usage) }
        }
    }

    struct BillingCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "billing",
            abstract: "Plan and billing period (read-only; manage billing in the dashboard).",
            subcommands: [ShowCommand.self],
            defaultSubcommand: ShowCommand.self
        )

        struct ShowCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "show", abstract: "Show the plan, usage, and current period.")
            @OptionGroup var options: GlobalOptions
            func run() async throws { try await run(client: ConsoleSupport.makeOrgAdminClient()) }
            func run(client: OrgAdminClient) async throws {
                let billing: OrgBilling
                do { billing = try await client.billing() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.adminBilling) }
                try ConsoleAdmin.emit(billing, options: options) { ConsoleAdminFormat.billing(billing) }
            }
        }
    }
}

// MARK: - Formatting

enum ConsoleAdminFormat {
    static func webhooks(_ hooks: [Webhook]) -> String {
        guard !hooks.isEmpty else { return "No webhooks." }
        return ConsoleFormat.table(headers: ["ID", "URL", "STATE", "EVENTS", "CREATED"], rows: hooks.map {
            [$0.id, $0.url, $0.isActive ? "active" : "paused", $0.events.joined(separator: ","), ConsoleAdmin.date($0.createdAt)]
        })
    }

    static func deliveries(_ items: [WebhookDelivery]) -> String {
        guard !items.isEmpty else { return "No deliveries." }
        return ConsoleFormat.table(headers: ["ID", "EVENT", "STATUS", "HTTP", "ATTEMPTS", "CREATED", "ERROR"], rows: items.map {
            [$0.id, $0.eventType, $0.status, $0.httpStatus.map(String.init) ?? "-", String($0.attemptCount), ConsoleAdmin.date($0.createdAt), $0.error ?? ""]
        })
    }

    static func rules(_ rules: [RiskAlertRule]) -> String {
        guard !rules.isEmpty else { return "No risk alert rules." }
        return ConsoleFormat.table(headers: ["ID", "NAME", "TRIGGER", "STATE", "WEBHOOK"], rows: rules.map {
            [$0.id, $0.name, "score \($0.comparison == "gt" ? ">" : ">=") \($0.threshold)", $0.isActive ? "active" : "paused", $0.webhookUrl]
        })
    }

    static func ruleDeliveries(_ items: [RiskAlertDelivery]) -> String {
        guard !items.isEmpty else { return "No risk alert deliveries." }
        return ConsoleFormat.table(headers: ["WHEN", "RULE", "DEVICE", "SCORE", "STATUS", "HTTP", "ERROR"], rows: items.map {
            [ConsoleAdmin.date($0.createdAt), $0.ruleId, $0.deviceId, String($0.riskScore), $0.status, $0.httpStatus.map(String.init) ?? "-", $0.error ?? ""]
        })
    }

    static func failureRate(_ alert: FailureRateAlert) -> String {
        """
        Failure-rate alert: \(alert.isEnabled ? "enabled" : "disabled")
          Threshold:        \(alert.threshold)% of attestations failing
          Min attestations: \(alert.minAttestationCount)
          Last alerted:     \(ConsoleAdmin.date(alert.lastAlertedAt))
        """
    }

    static func notificationPreferences(_ p: NotificationPreferences) -> String {
        let rows: [(String, String)] = [
            ("newFeatureRequest", ConsoleAdmin.onOff(p.newFeatureRequest)),
            ("featureVoteThreshold", "\(ConsoleAdmin.onOff(p.featureVoteThreshold)) (at \(p.featureVoteThresholdCount) votes)"),
            ("featureStatusChange", ConsoleAdmin.onOff(p.featureStatusChange)),
            ("newSupportTicket", ConsoleAdmin.onOff(p.newSupportTicket)),
            ("ticketAdminReply", ConsoleAdmin.onOff(p.ticketAdminReply)),
            ("ticketResolved", ConsoleAdmin.onOff(p.ticketResolved)),
            ("ticketUserReply", ConsoleAdmin.onOff(p.ticketUserReply)),
            ("flagToggle", ConsoleAdmin.onOff(p.flagToggle)),
            ("teamInvite", ConsoleAdmin.onOff(p.teamInvite)),
            ("usageAlert", ConsoleAdmin.onOff(p.usageAlert)),
        ]
        return ConsoleFormat.table(headers: ["PREFERENCE", "EMAIL"], rows: rows.map { [$0.0, $0.1] })
    }

    static func keys(_ keys: [APIKeySummary]) -> String {
        guard !keys.isEmpty else { return "No API keys." }
        return ConsoleFormat.table(headers: ["ID", "NAME", "PREFIX", "TYPE", "STATE", "SCOPES", "LAST USED", "EXPIRES"], rows: keys.map {
            [$0.id, $0.name, $0.keyPrefix, $0.keyType ?? "org", $0.isActive ? "active" : "revoked", $0.scopes.joined(separator: ","), ConsoleAdmin.date($0.lastUsedAt), ConsoleAdmin.date($0.expiresAt)]
        })
    }

    static func createdKey(_ key: APIKeyCreated) -> String {
        """
        Created API key '\(key.name)' (\(key.id))
          Key:     \(key.rawKey)
          Scopes:  \(key.scopes.joined(separator: ", "))
          Expires: \(ConsoleAdmin.date(key.expiresAt))
        Store the key now; it is not shown again.
        """
    }

    static func members(_ members: [OrgMember]) -> String {
        guard !members.isEmpty else { return "No members." }
        return ConsoleFormat.table(headers: ["MEMBERSHIP", "EMAIL", "ROLE", "JOINED"], rows: members.map {
            [$0.id, $0.email, $0.orgRole, ConsoleAdmin.date($0.joinedAt)]
        })
    }

    static func invites(_ invites: [OrgInvite]) -> String {
        guard !invites.isEmpty else { return "No invites." }
        return ConsoleFormat.table(headers: ["ID", "EMAIL", "ROLE", "STATUS", "INVITED BY", "EXPIRES"], rows: invites.map {
            [$0.id, $0.email, $0.orgRole ?? "member", $0.status, $0.invitedBy ?? "-", ConsoleAdmin.date($0.expiresAt)]
        })
    }

    static func audit(_ page: PaginatedItems<AuditEntry>) -> String {
        guard !page.items.isEmpty else { return "No audit entries." }
        let table = ConsoleFormat.table(headers: ["WHEN", "ACTOR", "ACTION", "RESOURCE", "DETAILS"], rows: page.items.map { entry in
            let details = (entry.metadata ?? [:]).sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            return [ConsoleAdmin.date(entry.createdAt), entry.actorEmail, entry.action, entry.resourceType, details]
        })
        let pages = max(Int((Double(page.metadata.total) / Double(max(page.metadata.per, 1))).rounded(.up)), 1)
        return table + "\n\nPage \(page.metadata.page) of \(pages) · \(page.metadata.total) entries"
    }

    static func settings(_ s: OrgSettings) -> String {
        """
        \(s.name) (\(s.slug))
          ID:      \(s.id)
          Plan:    \(s.serviceTier)
          Billing: \(s.billingEmail ?? "-")
          Created: \(ConsoleAdmin.date(s.createdAt))
        """
    }

    static func usage(_ u: OrgUsage) -> String {
        let limit = u.tierLimit.map(String.init) ?? "unlimited"
        let percent = u.usagePercent.map { String(format: " (%.1f%%)", $0) } ?? ""
        return """
        \(u.tierName) plan: \(u.currentMAD) of \(limit) monthly active devices\(percent)
          Period: \(String(u.billingPeriodStart.prefix(10))) → \(String(u.billingPeriodEnd.prefix(10)))
          Resets: \(u.resetDate)\(u.daysUntilReset.map { " (in \($0) days)" } ?? "")
        """
    }

    static func billing(_ b: OrgBilling) -> String {
        """
        Plan: \(b.plan)
          Devices this period: \(b.madUsed) of \(b.madLimit.map(String.init) ?? "unlimited")
          Period ends:         \(ConsoleAdmin.date(b.currentPeriodEnd))
          Stripe customer:     \(b.stripeCustomerId ?? "-")
        Manage billing in the dashboard.
        """
    }
}
