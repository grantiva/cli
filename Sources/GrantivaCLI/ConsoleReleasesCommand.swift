import ArgumentParser
import Foundation
import GrantivaAPI
import GrantivaCore

// MARK: - console releases

@available(macOS 15, *)
struct ConsoleReleasesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "releases",
        abstract: "Author the What's New release notes shown to users after they upgrade.",
        discussion: """
            A note is attached to an app and a version. Devices see the notes for versions between the \
            one they installed and the one they are running, once published.
            """,
        subcommands: [
            ListCommand.self,
            GetCommand.self,
            CreateCommand.self,
            UpdateCommand.self,
            PublishCommand.self,
            UnpublishCommand.self,
            DeleteCommand.self,
        ]
    )

    static func notFound(_ id: String) -> String { "release note not found: \(id)" }

    /// Resolves `--app` (bundle ID or UUID) to an app UUID.
    static func resolveApp(_ ref: String, orgClient: OrgClient) async throws -> String {
        if UUID(uuidString: ref) != nil { return ref }
        do { return try await orgClient.getApp(ref).id } catch {
            throw ConsoleSupport.map(error, scope: ConsoleScope.appsRead, notFound: ConsoleAppsCommand.notFound(ref))
        }
    }

    /// Reads `--body` inline text or `@path`.
    static func bodyText(_ raw: String) throws -> String {
        guard raw.hasPrefix("@") else { return raw }
        let path = String(raw.dropFirst())
        guard let data = FileManager.default.contents(atPath: path), let text = String(data: data, encoding: .utf8) else {
            throw GrantivaError.invalidArgument("--body: cannot read \(path)")
        }
        return text
    }

    // MARK: - list / get

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "list", abstract: "List release notes, newest first.")

        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Only notes for this app (bundle ID or UUID).")
        var app: String?

        @Option(name: .long, help: "Page number, starting at 1.")
        var page: Int?

        @Option(name: .long, help: "Notes per page, 1–100. Default 20.")
        var per: Int?

        func validate() throws {
            if let page, page < 1 { throw ValidationError("--page must be at least 1.") }
            if let per, !(1...100).contains(per) { throw ValidationError("--per must be between 1 and 100.") }
        }

        func run() async throws {
            try await run(client: ConsoleSupport.makeReleaseNotesClient(), orgClient: ConsoleSupport.makeOrgClient())
        }

        func run(client: ReleaseNotesClient, orgClient: OrgClient) async throws {
            var appId: String?
            if let app { appId = try await ConsoleReleasesCommand.resolveApp(app, orgClient: orgClient) }
            let result: ReleaseNotePage
            do { result = try await client.list(appId, page, per) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.releaseNotesRead)
            }
            if options.json {
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line(ConsoleReleasesFormat.page(result))
            }
        }
    }

    struct GetCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "get", abstract: "Show a release note including its body.")

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Release note ID.")
        var note: String

        func run() async throws { try await run(client: ConsoleSupport.makeReleaseNotesClient()) }

        func run(client: ReleaseNotesClient) async throws {
            let result: ReleaseNote
            do { result = try await client.get(note) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.releaseNotesRead, notFound: ConsoleReleasesCommand.notFound(note))
            }
            if options.json {
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line(ConsoleReleasesFormat.detail(result))
            }
        }
    }

    // MARK: - create

    struct CreateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "create",
            abstract: "Create a release note for an app version.",
            discussion: """
                Example:
                  grantiva console releases create com.example.app 2.1.0 --title "Dark mode" --body @notes.md --publish
                """
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "App bundle ID or UUID.")
        var app: String

        @Argument(help: "Version, e.g. 2.1.0.")
        var version: String

        @Option(name: .long, help: "Title (up to 200 characters).")
        var title: String

        @Option(name: .long, help: "Body as Markdown, inline or @file.md (up to 20,000 characters).")
        var body: String

        @Flag(name: .long, help: "Publish immediately.")
        var publish = false

        func run() async throws {
            try await run(client: ConsoleSupport.makeReleaseNotesClient(), orgClient: ConsoleSupport.makeOrgClient())
        }

        func run(client: ReleaseNotesClient, orgClient: OrgClient) async throws {
            let appId = try await ConsoleReleasesCommand.resolveApp(app, orgClient: orgClient)
            let request = CreateReleaseNoteRequest(
                appId: appId, version: version, title: title, body: try ConsoleReleasesCommand.bodyText(body),
                isPublished: publish ? true : nil
            )
            let note: ReleaseNote
            do { note = try await client.create(request) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.releaseNotesWrite)
            }
            if options.json {
                Output.line(try JSONOutput.string(note))
            } else {
                options.note("Created release note \(note.id) for \(note.version)\(note.isPublished ? " (published)" : "")")
                Output.line(ConsoleReleasesFormat.detail(note))
            }
        }
    }

    // MARK: - update

    struct UpdateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "update", abstract: "Change a note's version, title, or body. Use publish/unpublish for its state.")

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Release note ID.")
        var note: String

        @Option(name: .long, help: "New version.")
        var version: String?

        @Option(name: .long, help: "New title.")
        var title: String?

        @Option(name: .long, help: "New body, inline or @file.md.")
        var body: String?

        func validate() throws {
            if version == nil, title == nil, body == nil { throw ValidationError("Nothing to update.") }
        }

        func run() async throws { try await run(client: ConsoleSupport.makeReleaseNotesClient()) }

        func run(client: ReleaseNotesClient) async throws {
            let request = UpdateReleaseNoteRequest(version: version, title: title, body: try body.map(ConsoleReleasesCommand.bodyText))
            let updated: ReleaseNote
            do { updated = try await client.update(note, request) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.releaseNotesWrite, notFound: ConsoleReleasesCommand.notFound(note))
            }
            if options.json {
                Output.line(try JSONOutput.string(updated))
            } else {
                Output.line(ConsoleReleasesFormat.detail(updated))
            }
        }
    }

    // MARK: - publish / unpublish / delete

    struct PublishCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "publish", abstract: "Publish a note so upgrading devices see it.")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Release note ID.") var note: String
        func run() async throws { try await run(client: ConsoleSupport.makeReleaseNotesClient()) }
        func run(client: ReleaseNotesClient) async throws {
            try await ConsoleReleasesCommand.toggle(note, options: options, verb: "published") { try await client.publish($0) }
        }
    }

    struct UnpublishCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "unpublish", abstract: "Hide a note from devices. Devices that already read it are not shown it again on republish.")
        @OptionGroup var options: GlobalOptions
        @Argument(help: "Release note ID.") var note: String
        func run() async throws { try await run(client: ConsoleSupport.makeReleaseNotesClient()) }
        func run(client: ReleaseNotesClient) async throws {
            try await ConsoleReleasesCommand.toggle(note, options: options, verb: "unpublished") { try await client.unpublish($0) }
        }
    }

    static func toggle(_ id: String, options: GlobalOptions, verb: String, _ call: (String) async throws -> ReleaseNote) async throws {
        let note: ReleaseNote
        do { note = try await call(id) } catch {
            throw ConsoleSupport.map(error, scope: ConsoleScope.releaseNotesWrite, notFound: notFound(id))
        }
        if options.json {
            Output.line(try JSONOutput.string(note))
        } else {
            Output.line("Release note \(note.version) \(verb)")
        }
    }

    struct DeleteCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete a release note.")

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Release note ID.")
        var note: String

        @Flag(name: .long, help: "Skip the confirmation prompt (required when stdin is not a TTY).")
        var yes = false

        func run() async throws { try await run(client: ConsoleSupport.makeReleaseNotesClient()) }

        func run(client: ReleaseNotesClient) async throws {
            try ConsoleSupport.confirm("delete release note '\(note)'", yes: yes)
            do { try await client.delete(note) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.releaseNotesWrite, notFound: ConsoleReleasesCommand.notFound(note))
            }
            if options.json {
                Output.line(try JSONOutput.string(OrgDeleteResponse(deleted: true, id: note)))
            } else {
                Output.line("Deleted release note '\(note)'")
            }
        }
    }
}

// MARK: - Formatting

enum ConsoleReleasesFormat {
    static func page(_ page: ReleaseNotePage) -> String {
        guard !page.items.isEmpty else { return "No release notes." }
        let rows = page.items.map { note in
            [
                note.id,
                note.version,
                note.title,
                note.isPublished ? "published" : "draft",
                note.publishedAt.map(ConsoleFormat.shortDate) ?? "-",
                note.createdAt.map(ConsoleFormat.shortDate) ?? "-",
            ]
        }
        let table = ConsoleFormat.table(headers: ["ID", "VERSION", "TITLE", "STATE", "PUBLISHED", "CREATED"], rows: rows)
        let pages = max(Int((Double(page.metadata.total) / Double(max(page.metadata.per, 1))).rounded(.up)), 1)
        return table + "\n\nPage \(page.metadata.page) of \(pages) · \(page.metadata.total) note\(page.metadata.total == 1 ? "" : "s")"
    }

    static func detail(_ note: ReleaseNote) -> String {
        var lines: [String] = []
        lines.append("\(note.version) — \(note.title)")
        lines.append("  ID:        \(note.id)")
        lines.append("  App:       \(note.appId)")
        lines.append("  State:     \(note.isPublished ? "published" : "draft")\(note.publishedAt.map { " (\(ConsoleFormat.shortDate($0)))" } ?? "")")
        if let updated = note.updatedAt { lines.append("  Updated:   \(ConsoleFormat.shortDate(updated))") }
        lines.append("")
        lines.append(note.body)
        return lines.joined(separator: "\n")
    }
}
