import ArgumentParser
import Foundation
import GrantivaAPI
import GrantivaCore

// MARK: - console flags overrides

@available(macOS 15, *)
struct ConsoleFlagsOverridesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "overrides",
        abstract: "Manage per-device flag overrides.",
        discussion: """
        An override pins a flag to a fixed value for one device (by its device \
        key ID), taking precedence over all targeting rules. Useful for \
        support and QA: force a flag on for one tester's device without \
        touching rules.
        """,
        subcommands: [
            ListCommand.self,
            AddCommand.self,
            DeleteCommand.self,
        ]
    )

    // MARK: - list

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List a flag's device overrides."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Flag key (or UUID).")
        var key: String

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            let overrides: [OrgFlagOverride]
            do {
                overrides = try await client.listOverrides(key)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsRead, flagKey: key)
            }

            if options.json {
                Output.line(try JSONOutput.string(overrides))
            } else {
                Output.line(ConsoleFormat.overridesTable(overrides))
            }
        }
    }

    // MARK: - add

    struct AddCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "add",
            abstract: "Force a flag value for one device."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Flag key (or UUID).")
        var key: String

        @Option(name: .long, help: "Device key ID to override for.")
        var device: String

        @Option(name: .long, help: "Value to force for this device.")
        var value: String

        @Option(name: .customLong("expires-at"), help: "Expiry as ISO8601 (default: never expires).")
        var expiresAt: String?

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            let request = CreateFlagOverrideRequest(
                deviceKeyId: device,
                forcedValue: value,
                expiresAt: expiresAt
            )

            let override: OrgFlagOverride
            do {
                override = try await client.createOverride(key, request)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsWrite, flagKey: key)
            }

            if options.json {
                Output.line(try JSONOutput.string(override))
            } else {
                Output.line(ConsoleFormat.overridesTable([override]))
            }
        }
    }

    // MARK: - delete

    struct DeleteCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "delete",
            abstract: "Remove a device override."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Flag key (or UUID).")
        var key: String

        @Argument(help: "Override ID (from 'overrides list').")
        var overrideId: String

        @Flag(name: .long, help: "Skip the confirmation prompt (required when stdin is not a TTY).")
        var yes = false

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            try ConsoleSupport.confirm("delete override \(overrideId) from flag '\(key)'", yes: yes)

            do {
                try await client.deleteOverride(key, overrideId)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsWrite, flagKey: key)
            }

            if options.json {
                Output.line(try JSONOutput.string(OverrideDeletedResult(deleted: true, overrideId: overrideId, flagKey: key)))
            } else {
                Output.line("Deleted override \(overrideId) from flag '\(key)'")
            }
        }
    }
}

// MARK: - Output Models

@available(macOS 15, *)
struct OverrideDeletedResult: Codable, Sendable {
    let deleted: Bool
    let overrideId: String
    let flagKey: String

    enum CodingKeys: String, CodingKey {
        case deleted
        case overrideId = "override_id"
        case flagKey = "flag_key"
    }
}
