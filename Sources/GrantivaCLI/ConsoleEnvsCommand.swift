import ArgumentParser
import Foundation
import GrantivaAPI
import GrantivaCore

// MARK: - console envs

@available(macOS 15, *)
struct ConsoleEnvsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "envs",
        abstract: "Manage flag environments (production, staging, ...).",
        subcommands: [
            ListCommand.self,
            CreateCommand.self,
            UpdateCommand.self,
            DeleteCommand.self,
            ReorderCommand.self,
        ]
    )

    /// Resolves an environment reference — a UUID, or a slug looked up via the
    /// environment list.
    static func resolveEnvironmentId(_ ref: String, client: ConsoleClient) async throws -> String {
        if UUID(uuidString: ref) != nil { return ref }
        let environments: [OrgFlagEnvironment]
        do {
            environments = try await client.listEnvironments()
        } catch {
            throw ConsoleSupport.map(error, scope: ConsoleScope.flagsRead)
        }
        guard let match = environments.first(where: { $0.slug == ref || $0.name == ref }) else {
            throw GrantivaError.notFound("environment not found: \(ref)")
        }
        return match.id
    }

    // MARK: - list

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List flag environments in sort order."
        )

        @OptionGroup var options: GlobalOptions

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            let environments: [OrgFlagEnvironment]
            do {
                environments = try await client.listEnvironments()
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsRead)
            }

            if options.json {
                Output.line(try JSONOutput.string(environments))
            } else {
                Output.line(ConsoleFormat.environmentsTable(environments))
            }
        }
    }

    // MARK: - create

    struct CreateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "create",
            abstract: "Create a flag environment."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Environment name, e.g. \"Staging\".")
        var name: String

        @Option(name: .long, help: "Display color as a hex code, e.g. #f59e0b.")
        var color: String?

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            let environment: OrgFlagEnvironment
            do {
                environment = try await client.createEnvironment(CreateFlagEnvironmentRequest(name: name, color: color))
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsWrite)
            }

            if options.json {
                Output.line(try JSONOutput.string(environment))
            } else {
                Output.line(ConsoleFormat.environmentsTable([environment]))
            }
        }
    }

    // MARK: - update

    struct UpdateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "update",
            abstract: "Rename or recolor a flag environment."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Environment slug (or UUID).")
        var env: String

        @Option(name: .long, help: "New environment name.")
        var name: String?

        @Option(name: .long, help: "New display color as a hex code.")
        var color: String?

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            guard name != nil || color != nil else {
                throw GrantivaError.invalidArgument("nothing to update — pass --name or --color")
            }

            let envId = try await ConsoleEnvsCommand.resolveEnvironmentId(env, client: client)
            let environment: OrgFlagEnvironment
            do {
                environment = try await client.updateEnvironment(envId, UpdateFlagEnvironmentRequest(name: name, color: color))
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsWrite)
            }

            if options.json {
                Output.line(try JSONOutput.string(environment))
            } else {
                Output.line(ConsoleFormat.environmentsTable([environment]))
            }
        }
    }

    // MARK: - delete

    struct DeleteCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "delete",
            abstract: "Delete a flag environment and its per-environment values."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Environment slug (or UUID).")
        var env: String

        @Flag(name: .long, help: "Skip the confirmation prompt (required when stdin is not a TTY).")
        var yes = false

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            try ConsoleSupport.confirm("delete environment '\(env)'", yes: yes)

            let envId = try await ConsoleEnvsCommand.resolveEnvironmentId(env, client: client)
            do {
                try await client.deleteEnvironment(envId)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsWrite)
            }

            if options.json {
                Output.line(try JSONOutput.string(OrgDeleteResponse(deleted: true, id: env)))
            } else {
                Output.line("Deleted environment '\(env)'")
            }
        }
    }

    // MARK: - reorder

    struct ReorderCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "reorder",
            abstract: "Move a flag environment up or down in the sort order."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Environment slug (or UUID).")
        var env: String

        @Argument(help: "Direction: up or down.")
        var direction: ReorderDirection

        func run() async throws {
            try await run(client: ConsoleSupport.makeClient())
        }

        func run(client: ConsoleClient) async throws {
            let envId = try await ConsoleEnvsCommand.resolveEnvironmentId(env, client: client)
            let environment: OrgFlagEnvironment
            do {
                environment = try await client.updateEnvironment(
                    envId,
                    UpdateFlagEnvironmentRequest(reorder: direction.rawValue)
                )
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.flagsWrite)
            }

            if options.json {
                Output.line(try JSONOutput.string(environment))
            } else {
                Output.line(ConsoleFormat.environmentsTable([environment]))
            }
        }
    }
}

// MARK: - Arguments

@available(macOS 15, *)
enum ReorderDirection: String, ExpressibleByArgument, CaseIterable, Sendable {
    case up
    case down
}
