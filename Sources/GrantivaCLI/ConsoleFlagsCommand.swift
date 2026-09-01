import ArgumentParser
import Foundation
import GrantivaAPI
import GrantivaCore

// MARK: - console flags

@available(macOS 15, *)
struct ConsoleFlagsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "flags",
        abstract: "Manage feature flags.",
        subcommands: [
            ListCommand.self,
            GetCommand.self,
            CreateCommand.self,
            UpdateCommand.self,
            OnCommand.self,
            OffCommand.self,
            DeleteCommand.self,
            ConsoleFlagsRulesCommand.self,
            ConsoleFlagsOverridesCommand.self,
            EvalCommand.self,
            HistoryCommand.self,
            WatchCommand.self,
        ],
        aliases: ["featureflags"]
    )

    // MARK: - list

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all feature flags."
        )

        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Only show flags scoped to this app ID.")
        var app: String?

        @Option(name: .long, help: "Show default values for this environment.")
        var env: String?

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            let flags: [OrgFlag]
            do {
                flags = try await client.listFlags(app, env)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsRead)
            }

            if options.json {
                Output.line(try JSONOutput.string(flags))
            } else {
                Output.line(ConsoleFormat.flagsTable(flags))
            }
        }
    }

    // MARK: - get

    struct GetCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "get",
            abstract: "Show one flag in detail, including rules and overrides."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Flag key (or UUID).")
        var key: String

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            let flag: OrgFlagDetail
            do {
                flag = try await client.getFlag(key)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsRead, flagKey: key)
            }

            if options.json {
                Output.line(try JSONOutput.string(flag))
            } else {
                Output.line(ConsoleFormat.flagDetail(flag))
            }
        }
    }

    // MARK: - create

    struct CreateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "create",
            abstract: "Create a feature flag.",
            discussion: """
            The value each environment serves while the flag is ON comes from \
            --value (applied to every environment) and/or repeated --env-value \
            pairs, which win over --value for their environment:

              grantiva console flags create dark_mode --name "Dark Mode" --type bool \\
                --value false --env-value staging=true
            """
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Flag key (lowercase letters, numbers, underscores).")
        var key: String

        @Option(name: .long, help: "Human-readable flag name.")
        var name: String

        @Option(name: .long, help: "Value type: bool, string, int, or json.")
        var type: FlagValueTypeArgument

        @Option(name: .long, help: "On-value applied to every environment.")
        var value: String?

        @Option(name: .customLong("env-value"), help: "Per-environment on-value as <environment>=<value> (repeatable).")
        var envValue: [String] = []

        @Option(name: .long, help: "Scope the flag to this app ID (default: org-wide).")
        var app: String?

        @Flag(name: .long, help: "Create the flag inactive.")
        var off = false

        @Option(name: .long, help: "Flag description.")
        var description: String?

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            let explicit = try ConsoleSupport.parseEnvValues(envValue)
            if let value {
                try ConsoleSupport.validateValue(value, type: type)
            }
            for (_, envValue) in explicit {
                try ConsoleSupport.validateValue(envValue, type: type)
            }

            var onValues = explicit
            if let value {
                // A blanket --value covers every environment the org has;
                // explicit --env-value pairs win for theirs.
                do {
                    for environment in try await client.listEnvironments() where onValues[environment.slug] == nil {
                        onValues[environment.slug] = value
                    }
                } catch {
                    throw ConsoleSupport.map(error, scope: ConsoleScope.flagsRead)
                }
            }

            let request = CreateOrgFlagRequest(
                flagKey: key,
                name: name,
                description: description,
                appId: app,
                valueType: type.wireValue,
                environmentValues: onValues.isEmpty
                    ? nil
                    : onValues.mapValues { OrgFlagEnvironmentValueInput(onValue: $0) },
                isActive: off ? false : nil
            )

            let flag: OrgFlagDetail
            do {
                flag = try await client.createFlag(request)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsWrite)
            }

            if options.json {
                Output.line(try JSONOutput.string(flag))
            } else {
                options.note("Created flag '\(flag.flagKey)'")
                Output.line(ConsoleFormat.flagDetail(flag))
            }
        }
    }

    // MARK: - update

    struct UpdateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "update",
            abstract: "Update a flag's name, description, or per-environment values."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Flag key (or UUID).")
        var key: String

        @Option(name: .long, help: "New flag name.")
        var name: String?

        @Option(name: .long, help: "New flag description.")
        var description: String?

        @Option(name: .customLong("env-value"), help: "Per-environment on-value as <environment>=<value> (repeatable).")
        var envValue: [String] = []

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            let environmentValues = try ConsoleSupport.parseEnvValues(envValue)
            guard name != nil || description != nil || !environmentValues.isEmpty else {
                throw GrantivaError.invalidArgument(
                    "nothing to update — pass --name, --description, or --env-value"
                )
            }

            let request = UpdateOrgFlagRequest(
                name: name,
                description: description,
                environmentValues: environmentValues.isEmpty
                    ? nil
                    : environmentValues.mapValues { OrgFlagEnvironmentValueInput(onValue: $0) }
            )

            let flag: OrgFlagDetail
            do {
                flag = try await client.updateFlag(key, request)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsWrite, flagKey: key)
            }

            if options.json {
                Output.line(try JSONOutput.string(flag))
            } else {
                Output.line(ConsoleFormat.flagDetail(flag))
            }
        }
    }

    // MARK: - on / off

    struct OnCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "on",
            abstract: "Turn a flag on."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Flag key (or UUID).")
        var key: String

        @Option(name: .long, help: "Only toggle in this environment.")
        var env: String?

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            try await toggle(key: key, isActive: true, env: env, options: options, client: client)
        }
    }

    struct OffCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "off",
            abstract: "Turn a flag off."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Flag key (or UUID).")
        var key: String

        @Option(name: .long, help: "Only toggle in this environment.")
        var env: String?

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            try await toggle(key: key, isActive: false, env: env, options: options, client: client)
        }
    }

    private static func toggle(
        key: String, isActive: Bool, env: String?, options: GlobalOptions, client: ConsoleClient
    ) async throws {
        let result: OrgFlagToggleResponse
        do {
            result = try await client.toggleFlag(key, ToggleOrgFlagRequest(isActive: isActive, environment: env))
        } catch {
            throw ConsoleSupport.map(error, scope: ConsoleScope.flagsWrite, flagKey: key)
        }

        if options.json {
            Output.line(try JSONOutput.string(result))
        } else {
            let scope = result.environment.map { " in \($0)" } ?? ""
            Output.line("\(result.flagKey) is now \(result.isActive ? "on" : "off")\(scope)")
        }
    }

    // MARK: - delete

    struct DeleteCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "delete",
            abstract: "Delete a flag, its rules, and its overrides."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Flag key (or UUID).")
        var key: String

        @Flag(name: .long, help: "Skip the confirmation prompt (required when stdin is not a TTY).")
        var yes = false

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            try ConsoleSupport.confirm("delete flag '\(key)'", yes: yes)

            do {
                try await client.deleteFlag(key)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsWrite, flagKey: key)
            }

            if options.json {
                Output.line(try JSONOutput.string(DeletedResult(deleted: true, flagKey: key)))
            } else {
                Output.line("Deleted flag '\(key)'")
            }
        }
    }

    // MARK: - eval

    struct EvalCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "eval",
            abstract: "Dry-run a flag against a simulated device and show the full rule trace.",
            discussion: """
            Evaluates the flag exactly as the SDK endpoint would for a device with \
            the given attributes, without recording an evaluation. Each targeting \
            rule is shown in priority order with per-condition expected vs actual.

              grantiva console flags eval dark_mode --os-version 18.1 --country US \\
                --risk-score 12 --custom beta_group=internal
            """
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Flag key (or UUID).")
        var key: String

        @Option(name: .customLong("device-model"), help: "Device model, e.g. iPhone16,1.")
        var deviceModel: String?

        @Option(name: .customLong("os-version"), help: "OS version, e.g. 18.1.2.")
        var osVersion: String?

        @Option(name: .customLong("app-version"), help: "App version, e.g. 2.1.0.")
        var appVersion: String?

        @Option(name: .customLong("device-id"), help: "Stable device identifier (drives rollout bucketing).")
        var deviceId: String?

        @Option(name: .customLong("risk-score"), help: "Risk score 0-100.")
        var riskScore: Int?

        @Option(name: .long, help: "Locale, e.g. en_US.")
        var locale: String?

        @Option(name: .long, help: "Country code, e.g. US.")
        var country: String?

        @Option(name: .customLong("user-id"), help: "Application-level user identifier.")
        var userId: String?

        @Option(name: .customLong("attestation-status"), help: "attested, unattested, or expired.")
        var attestationStatus: String?

        @Option(name: .long, help: "Custom attribute as <key>=<value> (repeatable).")
        var custom: [String] = []

        @Option(name: .long, help: "Environment to evaluate in (default: production).")
        var env: String?

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            let customAttributes = try ConsoleSupport.parseEnvValues(custom)
            let flagId = try await ConsoleSupport.resolveFlagId(key, client: client)

            let request = FlagEvaluationRequest(
                deviceModel: deviceModel,
                osVersion: osVersion,
                appVersion: appVersion,
                deviceId: deviceId,
                riskScore: riskScore,
                locale: locale,
                country: country,
                userId: userId,
                attestationStatus: attestationStatus,
                custom: customAttributes.isEmpty ? nil : customAttributes,
                environment: env
            )

            let result: FlagEvaluationResponse
            do {
                result = try await client.evaluateFlag(flagId, request)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsRead, flagKey: key)
            }

            if options.json {
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line(ConsoleFormat.evaluationTrace(result))
            }
        }
    }

    // MARK: - history

    struct HistoryCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "history",
            abstract: "Show a flag's change history."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Flag key (or UUID).")
        var key: String

        @Option(name: .long, help: "Maximum entries to return.")
        var limit: Int?

        @Option(name: .long, help: "Entries to skip (for paging).")
        var offset: Int?

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            let entries: [FlagHistoryEntry]
            do {
                entries = try await client.flagHistory(key, limit, offset)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsRead, flagKey: key)
            }

            if options.json {
                Output.line(try JSONOutput.string(entries))
            } else {
                Output.line(ConsoleFormat.historyTable(entries))
            }
        }
    }

    // MARK: - watch

    struct WatchCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "watch",
            abstract: "Stream live flag configuration updates (SSE). Ctrl-C to stop.",
            discussion: """
            Connects to the flags SSE stream and prints one line per server push: \
            the current configuration immediately on connect, then again on every \
            flag change. With --json, each line is one compact JSON document \
            (NDJSON) of the form {"event": ..., "data": ...}.
            """
        )

        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Environment to stream (default: production).")
        var env: String?

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            // Exit cleanly on Ctrl-C instead of dying mid-write with a signal.
            signal(SIGINT, SIG_IGN)
            let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
            sigint.setEventHandler {
                Foundation.exit(0)
            }
            sigint.resume()

            options.note("Watching flag configuration\(env.map { " (\($0))" } ?? "")... Ctrl-C to stop.")

            let events: AsyncThrowingStream<FlagStreamEvent, Error>
            do {
                events = try await client.streamFlags(env)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsRead)
            }

            let compactEncoder = JSONEncoder()
            compactEncoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

            for try await event in events {
                if options.json {
                    let line = try compactEncoder.encode(event)
                    Output.line(String(decoding: line, as: UTF8.self))
                } else {
                    Output.line("[\(Self.timestamp())] \(event.event): \(event.data)")
                }
            }
        }

        private static func timestamp() -> String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.string(from: Date())
        }
    }
}

// MARK: - Output Models

@available(macOS 15, *)
struct DeletedResult: Codable, Sendable {
    let deleted: Bool
    let flagKey: String

    enum CodingKeys: String, CodingKey {
        case deleted
        case flagKey = "flag_key"
    }
}
