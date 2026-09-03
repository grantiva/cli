import ArgumentParser
import Foundation
import GrantivaAPI
import GrantivaCore

// MARK: - console feedback

@available(macOS 15, *)
struct ConsoleFeedbackCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "feedback",
        abstract: "Triage feature requests: list, read the thread, set status, reply as the team.",
        subcommands: [ListCommand.self, GetCommand.self, SetStatusCommand.self, CommentCommand.self]
    )

    static func notFound(_ id: String) -> String { "feature request not found: \(id)" }

    static func validateReference(_ value: String, name: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError("\(name) must not be empty.") }
        guard trimmed == value else {
            throw ValidationError("\(name) must not have leading or trailing whitespace.")
        }
    }

    static func messageText(_ raw: String) throws -> String {
        let text = try ConsoleReleasesCommand.bodyText(raw)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GrantivaError.invalidArgument("--body must not be empty.")
        }
        return text
    }

    enum Status: String, ExpressibleByArgument, CaseIterable {
        case pending, open, planned, in_progress, shipped, declined, duplicate
        var wire: FeatureStatus { FeatureStatus(rawValue: rawValue)! }
    }

    enum Sort: String, ExpressibleByArgument, CaseIterable {
        case votes, newest, oldest
        var wire: FeedbackSort { FeedbackSort(rawValue: rawValue)! }
    }

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "list", abstract: "List feature requests, most voted first.")

        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Only this status: \(Status.allCases.map(\.rawValue).joined(separator: ", ")).")
        var status: Status?

        @Option(name: .long, help: "Only requests for this app (bundle ID or UUID).")
        var app: String?

        @Option(name: .long, help: "Match title or description (case-insensitive).")
        var search: String?

        @Option(name: .long, help: "Order: votes (default), newest, or oldest.")
        var sort: Sort?

        @Option(name: .long, help: "Page number, starting at 1.")
        var page: Int?

        @Option(name: .long, help: "Requests per page, 1–100. Default 20.")
        var per: Int?

        func validate() throws {
            if let page, page < 1 { throw ValidationError("--page must be at least 1.") }
            if let per, !(1...100).contains(per) { throw ValidationError("--per must be between 1 and 100.") }
            if let app { try ConsoleFeedbackCommand.validateReference(app, name: "--app") }
        }

        func run() async throws {
            try await run(client: ConsoleSupport.makeFeedbackClient(), orgClient: ConsoleSupport.makeOrgClient())
        }

        func run(client: FeedbackClient, orgClient: OrgClient) async throws {
            var appId: String?
            if let app { appId = try await ConsoleReleasesCommand.resolveApp(app, orgClient: orgClient) }
            let query = FeedbackQuery(status: status?.wire, appId: appId, search: search, sort: sort?.wire, page: page, per: per)
            let page: OrgPage<OrgFeatureRequest>
            do { page = try await client.listFeatures(query) } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.feedbackRead) }
            if options.json {
                Output.line(try JSONOutput.string(page))
            } else {
                Output.line(ConsoleFeedbackFormat.featuresPage(page))
            }
        }
    }

    struct GetCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "get", abstract: "Show a feature request with its comment thread.")

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Feature request ID.")
        var request: String

        func validate() throws {
            try ConsoleFeedbackCommand.validateReference(request, name: "Feature request ID")
        }

        func run() async throws { try await run(client: ConsoleSupport.makeFeedbackClient()) }

        func run(client: FeedbackClient) async throws {
            let detail: OrgFeatureRequestDetail
            do { detail = try await client.getFeature(request) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.feedbackRead, notFound: ConsoleFeedbackCommand.notFound(request))
            }
            if options.json {
                Output.line(try JSONOutput.string(detail))
            } else {
                Output.line(ConsoleFeedbackFormat.featureDetail(detail))
            }
        }
    }

    struct SetStatusCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set-status",
            abstract: "Change a feature request's status. The org admin is emailed if that notification is on."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Feature request ID.")
        var request: String

        @Argument(help: "New status: \(Status.allCases.map(\.rawValue).joined(separator: ", ")).")
        var status: Status

        func validate() throws {
            try ConsoleFeedbackCommand.validateReference(request, name: "Feature request ID")
        }

        func run() async throws { try await run(client: ConsoleSupport.makeFeedbackClient()) }

        func run(client: FeedbackClient) async throws {
            let feature: OrgFeatureRequest
            do { feature = try await client.setFeatureStatus(request, status.wire) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.feedbackManage, notFound: ConsoleFeedbackCommand.notFound(request))
            }
            if options.json {
                Output.line(try JSONOutput.string(feature))
            } else {
                Output.line("\(feature.title) is now \(feature.status)")
            }
        }
    }

    struct CommentCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "comment",
            abstract: "Reply on a feature request as the team. Devices following the thread get a push."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Feature request ID.")
        var request: String

        @Option(name: .long, help: "Comment text, inline or @file.")
        var body: String

        func validate() throws {
            try ConsoleFeedbackCommand.validateReference(request, name: "Feature request ID")
        }

        func run() async throws { try await run(client: ConsoleSupport.makeFeedbackClient()) }

        func run(client: FeedbackClient) async throws {
            let text = try ConsoleFeedbackCommand.messageText(body)
            let comment: OrgFeedbackComment
            do { comment = try await client.addFeatureComment(request, text) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.feedbackManage, notFound: ConsoleFeedbackCommand.notFound(request))
            }
            if options.json {
                Output.line(try JSONOutput.string(comment))
            } else {
                Output.line("Comment posted (\(comment.id))")
            }
        }
    }
}

// MARK: - console support

@available(macOS 15, *)
struct ConsoleSupportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "support",
        abstract: "Work support tickets: list, read the conversation, reply, set status and priority.",
        subcommands: [ListCommand.self, GetCommand.self, ReplyCommand.self, SetStatusCommand.self, SetPriorityCommand.self]
    )

    static func notFound(_ id: String) -> String { "support ticket not found: \(id)" }

    enum Status: String, ExpressibleByArgument, CaseIterable {
        case open, awaiting_reply, resolved, closed
        var wire: TicketStatus { TicketStatus(rawValue: rawValue)! }
    }

    enum Priority: String, ExpressibleByArgument, CaseIterable {
        case low, normal, high, urgent
        var wire: TicketPriority { TicketPriority(rawValue: rawValue)! }
    }

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "list", abstract: "List tickets, most recently updated first.")

        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Only this status: \(Status.allCases.map(\.rawValue).joined(separator: ", ")).")
        var status: Status?

        @Option(name: .long, help: "Only this priority: \(Priority.allCases.map(\.rawValue).joined(separator: ", ")).")
        var priority: Priority?

        @Option(name: .long, help: "Only tickets for this app (bundle ID or UUID).")
        var app: String?

        @Option(name: .long, help: "Match subject or submitter email (case-insensitive).")
        var search: String?

        @Option(name: .long, help: "Page number, starting at 1.")
        var page: Int?

        @Option(name: .long, help: "Tickets per page, 1–100. Default 20.")
        var per: Int?

        func validate() throws {
            if let page, page < 1 { throw ValidationError("--page must be at least 1.") }
            if let per, !(1...100).contains(per) { throw ValidationError("--per must be between 1 and 100.") }
            if let app { try ConsoleFeedbackCommand.validateReference(app, name: "--app") }
        }

        func run() async throws {
            try await run(client: ConsoleSupport.makeFeedbackClient(), orgClient: ConsoleSupport.makeOrgClient())
        }

        func run(client: FeedbackClient, orgClient: OrgClient) async throws {
            var appId: String?
            if let app { appId = try await ConsoleReleasesCommand.resolveApp(app, orgClient: orgClient) }
            let query = SupportQuery(status: status?.wire, priority: priority?.wire, appId: appId, search: search, page: page, per: per)
            let page: OrgPage<OrgSupportTicket>
            do { page = try await client.listTickets(query) } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.feedbackRead) }
            if options.json {
                Output.line(try JSONOutput.string(page))
            } else {
                Output.line(ConsoleFeedbackFormat.ticketsPage(page))
            }
        }
    }

    struct GetCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "get", abstract: "Show a ticket with its full conversation.")

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Ticket ID.")
        var ticket: String

        func validate() throws {
            try ConsoleFeedbackCommand.validateReference(ticket, name: "Ticket ID")
        }

        func run() async throws { try await run(client: ConsoleSupport.makeFeedbackClient()) }

        func run(client: FeedbackClient) async throws {
            let detail: OrgSupportTicketDetail
            do { detail = try await client.getTicket(ticket) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.feedbackRead, notFound: ConsoleSupportCommand.notFound(ticket))
            }
            if options.json {
                Output.line(try JSONOutput.string(detail))
            } else {
                Output.line(ConsoleFeedbackFormat.ticketDetail(detail))
            }
        }
    }

    struct ReplyCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "reply",
            abstract: "Reply to a ticket as the team. Moves it to awaiting_reply and emails the submitter if that notification is on."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Ticket ID.")
        var ticket: String

        @Option(name: .long, help: "Reply text, inline or @file.")
        var body: String

        func validate() throws {
            try ConsoleFeedbackCommand.validateReference(ticket, name: "Ticket ID")
        }

        func run() async throws { try await run(client: ConsoleSupport.makeFeedbackClient()) }

        func run(client: FeedbackClient) async throws {
            let text = try ConsoleFeedbackCommand.messageText(body)
            let message: OrgTicketMessage
            do { message = try await client.addTicketMessage(ticket, text) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.feedbackManage, notFound: ConsoleSupportCommand.notFound(ticket))
            }
            if options.json {
                Output.line(try JSONOutput.string(message))
            } else {
                Output.line("Reply posted (\(message.id)); ticket is awaiting the submitter")
            }
        }
    }

    struct SetStatusCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "set-status", abstract: "Change a ticket's status. Resolving emails the submitter if that notification is on.")

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Ticket ID.")
        var ticket: String

        @Argument(help: "New status: \(Status.allCases.map(\.rawValue).joined(separator: ", ")).")
        var status: Status

        func validate() throws {
            try ConsoleFeedbackCommand.validateReference(ticket, name: "Ticket ID")
        }

        func run() async throws { try await run(client: ConsoleSupport.makeFeedbackClient()) }

        func run(client: FeedbackClient) async throws {
            let result: OrgSupportTicket
            do { result = try await client.setTicketStatus(ticket, status.wire) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.feedbackManage, notFound: ConsoleSupportCommand.notFound(ticket))
            }
            if options.json {
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line("\(result.subject) is now \(result.status)")
            }
        }
    }

    struct SetPriorityCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "set-priority", abstract: "Change a ticket's priority.")

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Ticket ID.")
        var ticket: String

        @Argument(help: "New priority: \(Priority.allCases.map(\.rawValue).joined(separator: ", ")).")
        var priority: Priority

        func validate() throws {
            try ConsoleFeedbackCommand.validateReference(ticket, name: "Ticket ID")
        }

        func run() async throws { try await run(client: ConsoleSupport.makeFeedbackClient()) }

        func run(client: FeedbackClient) async throws {
            let result: OrgSupportTicket
            do { result = try await client.setTicketPriority(ticket, priority.wire) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.feedbackManage, notFound: ConsoleSupportCommand.notFound(ticket))
            }
            if options.json {
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line("\(result.subject) is now \(result.priority) priority")
            }
        }
    }
}

// MARK: - Formatting

enum ConsoleFeedbackFormat {
    static func featuresPage(_ page: OrgPage<OrgFeatureRequest>) -> String {
        guard !page.items.isEmpty else { return "No feature requests." }
        let rows = page.items.map { feature in
            [
                feature.id,
                String(feature.voteCount),
                feature.status,
                truncate(feature.title, 48),
                String(feature.commentCount),
                feature.updatedAt.map(ConsoleFormat.shortDate) ?? "-",
            ]
        }
        return ConsoleFormat.table(headers: ["ID", "VOTES", "STATUS", "TITLE", "COMMENTS", "UPDATED"], rows: rows) + pageFooter(page.page, page.per, page.total, "request")
    }

    static func featureDetail(_ detail: OrgFeatureRequestDetail) -> String {
        let feature = detail.feature
        var lines: [String] = []
        lines.append("\(feature.title)")
        lines.append("  ID:        \(feature.id)")
        lines.append("  Status:    \(feature.status)   Votes: \(feature.voteCount)   Comments: \(feature.commentCount)")
        lines.append("  Submitter: \(feature.submitterId)")
        if let created = feature.createdAt { lines.append("  Created:   \(ConsoleFormat.shortDate(created))") }
        lines.append("")
        lines.append(feature.description)
        lines.append("")
        lines.append(thread(detail.comments, empty: "No comments yet."))
        return lines.joined(separator: "\n")
    }

    static func ticketsPage(_ page: OrgPage<OrgSupportTicket>) -> String {
        guard !page.items.isEmpty else { return "No tickets." }
        let rows = page.items.map { ticket in
            [
                ticket.id,
                ticket.status,
                ticket.priority,
                truncate(ticket.subject, 48),
                ticket.submitterEmail ?? "-",
                String(ticket.messageCount),
                ticket.updatedAt.map(ConsoleFormat.shortDate) ?? "-",
            ]
        }
        return ConsoleFormat.table(headers: ["ID", "STATUS", "PRIORITY", "SUBJECT", "FROM", "MSGS", "UPDATED"], rows: rows) + pageFooter(page.page, page.per, page.total, "ticket")
    }

    static func ticketDetail(_ detail: OrgSupportTicketDetail) -> String {
        let ticket = detail.ticket
        var lines: [String] = []
        lines.append("\(ticket.subject)")
        lines.append("  ID:        \(ticket.id)")
        lines.append("  Status:    \(ticket.status)   Priority: \(ticket.priority)")
        lines.append("  From:      \(ticket.submitterEmail ?? ticket.submitterId)")
        if let created = ticket.createdAt { lines.append("  Opened:    \(ConsoleFormat.shortDate(created))") }
        lines.append("")
        lines.append(thread(detail.messages, empty: "No messages."))
        return lines.joined(separator: "\n")
    }

    static func thread(_ messages: [OrgFeedbackComment], empty: String) -> String {
        guard !messages.isEmpty else { return empty }
        return messages.map { message in
            let who = message.authorType == "admin" ? "Team" : "User"
            let when = message.createdAt.map(ConsoleFormat.shortDate) ?? ""
            return "[\(when)] \(who) (\(message.authorId)):\n  \(message.body.replacingOccurrences(of: "\n", with: "\n  "))"
        }.joined(separator: "\n\n")
    }

    static func pageFooter(_ page: Int, _ per: Int, _ total: Int, _ noun: String) -> String {
        let pages = max(Int((Double(total) / Double(max(per, 1))).rounded(.up)), 1)
        return "\n\nPage \(page) of \(pages) · \(total) \(noun)\(total == 1 ? "" : "s")"
    }

    static func truncate(_ text: String, _ max: Int) -> String {
        text.count <= max ? text : String(text.prefix(max - 1)) + "…"
    }
}
