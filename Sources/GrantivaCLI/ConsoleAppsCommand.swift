import ArgumentParser
import Foundation
import GrantivaAPI
import GrantivaCore

// MARK: - console apps

@available(macOS 15, *)
struct ConsoleAppsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apps",
        abstract: "Register and manage the apps (bundle IDs) attesting under this organization.",
        subcommands: [
            ListCommand.self,
            GetCommand.self,
            RegisterCommand.self,
            UpdateCommand.self,
            DeleteCommand.self,
            ActivateCommand.self,
            DeactivateCommand.self,
            SetPrimaryCommand.self,
        ]
    )

    static func notFound(_ ref: String) -> String { "app not found: \(ref)" }

    // MARK: - list

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "list", abstract: "List registered apps, primary first.")

        @OptionGroup var options: GlobalOptions

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            let apps: [OrgApp]
            do { apps = try await client.listApps() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.appsRead) }
            if options.json {
                Output.line(try JSONOutput.string(apps))
            } else {
                Output.line(ConsoleOrgFormat.appsTable(apps))
            }
        }
    }

    // MARK: - get

    struct GetCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "get", abstract: "Show one app by bundle ID or UUID.")

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Bundle ID (com.example.app) or app UUID.")
        var app: String

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            let result: OrgApp
            do { result = try await client.getApp(app) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.appsRead, notFound: ConsoleAppsCommand.notFound(app))
            }
            if options.json {
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line(ConsoleOrgFormat.appDetail(result))
            }
        }
    }

    // MARK: - register

    struct RegisterCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "register",
            abstract: "Register an app so devices running it can attest.",
            discussion: "The first app registered becomes the primary app. Bundle ID and Team ID cannot be changed afterwards."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Bundle ID, e.g. com.example.app.")
        var bundleId: String

        @Option(name: .customLong("team-id"), help: "Apple Developer Team ID (10 characters, from developer.apple.com).")
        var teamId: String

        @Option(name: .long, help: "Display name. Defaults to the last segment of the bundle ID.")
        var name: String?

        @Option(name: .long, help: "Description.")
        var description: String?

        @Flag(name: .long, help: "Make this the primary app, demoting the current one.")
        var primary = false

        func validate() throws {
            let trimmed = teamId.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { throw ValidationError("--team-id must not be empty.") }
            if trimmed.count != 10 || !trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) {
                throw ValidationError("--team-id should be the 10-character alphanumeric Apple Team ID, e.g. A1B2C3D4E5.")
            }
        }

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            let displayName = name ?? String(bundleId.split(separator: ".").last ?? Substring(bundleId))
            let request = CreateOrgAppRequest(
                appName: displayName,
                bundleId: bundleId,
                teamId: teamId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                description: description,
                isPrimary: primary ? true : nil
            )
            let app: OrgApp
            do { app = try await client.createApp(request) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.appsWrite)
            }
            if options.json {
                Output.line(try JSONOutput.string(app))
            } else {
                options.note("Registered \(app.bundleId)\(app.isPrimary ? " (primary)" : "")")
                Output.line(ConsoleOrgFormat.appDetail(app))
            }
        }
    }

    // MARK: - update

    struct UpdateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "update", abstract: "Rename an app or change its description and toggles.")

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Bundle ID or app UUID.")
        var app: String

        @Option(name: .long, help: "New display name.")
        var name: String?

        @Option(name: .long, help: "New description.")
        var description: String?

        @Flag(name: .long, inversion: .prefixedNo, help: "Enable or disable analytics for this app.")
        var analytics: Bool?

        @Flag(name: .long, inversion: .prefixedNo, help: "Enable or disable webhooks for this app.")
        var webhooks: Bool?

        func validate() throws {
            if name == nil, description == nil, analytics == nil, webhooks == nil {
                throw ValidationError("Nothing to update. Pass --name, --description, --analytics/--no-analytics, or --webhooks/--no-webhooks.")
            }
        }

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            let request = UpdateOrgAppRequest(appName: name, description: description, analyticsEnabled: analytics, webhookEnabled: webhooks)
            let updated: OrgApp
            do { updated = try await client.updateApp(app, request) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.appsWrite, notFound: ConsoleAppsCommand.notFound(app))
            }
            if options.json {
                Output.line(try JSONOutput.string(updated))
            } else {
                Output.line(ConsoleOrgFormat.appDetail(updated))
            }
        }
    }

    // MARK: - delete

    struct DeleteCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "delete",
            abstract: "Delete an app and everything attached to it.",
            discussion: "Deleting an app removes its device profiles, flags, and attestation history. The primary app and the last remaining app cannot be deleted."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Bundle ID or app UUID.")
        var app: String

        @Flag(name: .long, help: "Skip the confirmation prompt (required when stdin is not a TTY).")
        var yes = false

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            try ConsoleSupport.confirm("delete app '\(app)' and all of its devices, flags and history", yes: yes)
            let result: OrgDeleteResponse
            do { result = try await client.deleteApp(app) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.appsDelete, notFound: ConsoleAppsCommand.notFound(app))
            }
            if options.json {
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line("Deleted app '\(app)'")
            }
        }
    }

    // MARK: - activate / deactivate / set-primary

    struct ActivateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "activate", abstract: "Allow attestations from this app.")

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Bundle ID or app UUID.")
        var app: String

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            try await ConsoleAppsCommand.lifecycle(app, options: options, verb: "activated") { try await client.activateApp($0) }
        }
    }

    struct DeactivateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "deactivate", abstract: "Stop accepting attestations from this app. The primary app cannot be deactivated.")

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Bundle ID or app UUID.")
        var app: String

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            try await ConsoleAppsCommand.lifecycle(app, options: options, verb: "deactivated") { try await client.deactivateApp($0) }
        }
    }

    struct SetPrimaryCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "set-primary", abstract: "Make this app the primary app. It must be active.")

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Bundle ID or app UUID.")
        var app: String

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            try await ConsoleAppsCommand.lifecycle(app, options: options, verb: "is now primary") { try await client.setPrimaryApp($0) }
        }
    }

    static func lifecycle(
        _ ref: String,
        options: GlobalOptions,
        verb: String,
        _ call: (String) async throws -> OrgApp
    ) async throws {
        let app: OrgApp
        do { app = try await call(ref) } catch {
            throw ConsoleSupport.map(error, scope: ConsoleScope.appsWrite, notFound: notFound(ref))
        }
        if options.json {
            Output.line(try JSONOutput.string(app))
        } else {
            Output.line("\(app.bundleId) \(verb)")
        }
    }
}
