import ArgumentParser
import Foundation
import GrantivaAPI
import GrantivaCore

// MARK: - console flags rules

@available(macOS 15, *)
struct ConsoleFlagsRulesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rules",
        abstract: "Manage a flag's targeting rules.",
        discussion: """
        Rules are evaluated in priority order; the first rule whose conditions \
        all pass (and whose rollout bucket accepts the device) decides the \
        flag's value.

        Conditions are given as repeated --when options in the form \
        <attribute>:<operator>:<value>, or as a --conditions-json array. \
        Operators: eq, neq, gt, gte, lt, lte, in, not_in, contains, \
        starts_with. For in/not_in, comma-separate the values:

          --when os_version:gte:18.0 --when country:in:US,CA

        Attributes: os_version, device_model, app_version, risk_score, locale, \
        country, device_id, user_id, attestation_status, or custom.<key>.
        """,
        subcommands: [
            ListCommand.self,
            AddCommand.self,
            UpdateCommand.self,
            DeleteCommand.self,
            ReorderCommand.self,
        ]
    )

    // MARK: - list

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List a flag's targeting rules in priority order."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Flag key (or UUID).")
        var key: String

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            let flagId = try await ConsoleSupport.resolveFlagId(key, client: client)
            let rules: [FlagRuleResponse]
            do {
                rules = try await client.listRules(flagId)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsRead, flagKey: key)
            }

            if options.json {
                Output.line(try JSONOutput.string(rules))
            } else {
                Output.line(ConsoleFormat.rulesTable(rules))
            }
        }
    }

    // MARK: - add

    struct AddCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "add",
            abstract: "Add a targeting rule to a flag (appended at lowest priority)."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Flag key (or UUID).")
        var key: String

        @Option(name: .long, help: "Rule name.")
        var name: String

        @Option(name: .long, help: "Value the flag resolves to when this rule matches.")
        var value: String

        @Option(name: .long, help: "Condition as <attribute>:<operator>:<value> (repeatable).")
        var when: [String] = []

        @Option(name: .customLong("conditions-json"), help: "Conditions as a JSON array of {attribute, operator, value}.")
        var conditionsJSON: String?

        @Option(name: .long, help: "Rollout percentage 0-100 (default: 100).")
        var rollout: Int?

        @Flag(name: .long, help: "Create the rule inactive.")
        var inactive = false

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            let conditions = try ConsoleSupport.parseConditions(when: when, conditionsJSON: conditionsJSON)
            guard !conditions.isEmpty else {
                throw GrantivaError.invalidArgument("at least one condition is required — pass --when or --conditions-json")
            }

            let flagId = try await ConsoleSupport.resolveFlagId(key, client: client)
            let request = CreateFlagRuleRequest(
                name: name,
                conditions: conditions,
                value: value,
                rolloutPercentage: rollout,
                isActive: inactive ? false : nil
            )

            let rule: FlagRuleResponse
            do {
                rule = try await client.createRule(flagId, request)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsWrite, flagKey: key)
            }

            if options.json {
                Output.line(try JSONOutput.string(rule))
            } else {
                Output.line(ConsoleFormat.rulesTable([rule]))
            }
        }
    }

    // MARK: - update

    struct UpdateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "update",
            abstract: "Update a targeting rule."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Flag key (or UUID).")
        var key: String

        @Argument(help: "Rule ID (from 'rules list').")
        var ruleId: String

        @Option(name: .long, help: "New rule name.")
        var name: String?

        @Option(name: .long, help: "New value the flag resolves to when this rule matches.")
        var value: String?

        @Option(name: .long, help: "Replacement condition as <attribute>:<operator>:<value> (repeatable; replaces all conditions).")
        var when: [String] = []

        @Option(name: .customLong("conditions-json"), help: "Replacement conditions as a JSON array (replaces all conditions).")
        var conditionsJSON: String?

        @Option(name: .long, help: "New rollout percentage 0-100.")
        var rollout: Int?

        @Flag(name: .long, help: "Activate the rule.")
        var active = false

        @Flag(name: .long, help: "Deactivate the rule.")
        var inactive = false

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            if active && inactive {
                throw GrantivaError.invalidArgument("--active and --inactive are mutually exclusive")
            }
            let conditions = try ConsoleSupport.parseConditions(when: when, conditionsJSON: conditionsJSON)
            let isActive: Bool? = active ? true : (inactive ? false : nil)

            guard name != nil || value != nil || !conditions.isEmpty || rollout != nil || isActive != nil else {
                throw GrantivaError.invalidArgument(
                    "nothing to update — pass --name, --value, --when, --conditions-json, --rollout, --active, or --inactive"
                )
            }

            let flagId = try await ConsoleSupport.resolveFlagId(key, client: client)
            let request = UpdateFlagRuleRequest(
                name: name,
                conditions: conditions.isEmpty ? nil : conditions,
                value: value,
                rolloutPercentage: rollout,
                isActive: isActive
            )

            let rule: FlagRuleResponse
            do {
                rule = try await client.updateRule(flagId, ruleId, request)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsWrite, flagKey: key)
            }

            if options.json {
                Output.line(try JSONOutput.string(rule))
            } else {
                Output.line(ConsoleFormat.rulesTable([rule]))
            }
        }
    }

    // MARK: - delete

    struct DeleteCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "delete",
            abstract: "Delete a targeting rule."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Flag key (or UUID).")
        var key: String

        @Argument(help: "Rule ID (from 'rules list').")
        var ruleId: String

        @Flag(name: .long, help: "Skip the confirmation prompt (required when stdin is not a TTY).")
        var yes = false

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            try ConsoleSupport.confirm("delete rule \(ruleId) from flag '\(key)'", yes: yes)

            let flagId = try await ConsoleSupport.resolveFlagId(key, client: client)
            do {
                try await client.deleteRule(flagId, ruleId)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsWrite, flagKey: key)
            }

            if options.json {
                Output.line(try JSONOutput.string(RuleDeletedResult(deleted: true, ruleId: ruleId, flagKey: key)))
            } else {
                Output.line("Deleted rule \(ruleId) from flag '\(key)'")
            }
        }
    }

    // MARK: - reorder

    struct ReorderCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "reorder",
            abstract: "Reorder a flag's rules.",
            discussion: "Pass every rule ID in the desired priority order (index 0 evaluates first)."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Flag key (or UUID).")
        var key: String

        @Argument(help: "All rule IDs, in the new priority order.")
        var ruleIds: [String]

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            guard !ruleIds.isEmpty else {
                throw GrantivaError.invalidArgument("pass every rule ID in the new priority order")
            }

            let flagId = try await ConsoleSupport.resolveFlagId(key, client: client)
            let rules: [FlagRuleResponse]
            do {
                rules = try await client.reorderRules(flagId, ReorderFlagRulesRequest(ruleIds: ruleIds))
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsWrite, flagKey: key)
            }

            if options.json {
                Output.line(try JSONOutput.string(rules))
            } else {
                Output.line(ConsoleFormat.rulesTable(rules))
            }
        }
    }
}

// MARK: - Output Models

@available(macOS 15, *)
struct RuleDeletedResult: Codable, Sendable {
    let deleted: Bool
    let ruleId: String
    let flagKey: String

    enum CodingKeys: String, CodingKey {
        case deleted
        case ruleId = "rule_id"
        case flagKey = "flag_key"
    }
}
