import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaAPI
import GrantivaCore

final class ConsoleFeedbackCommandTests: XCTestCase {
    private static func feature(_ title: String, votes: Int = 0, status: String = "pending") -> OrgFeatureRequest {
        OrgFeatureRequest(id: "F-\(title)", title: title, description: "d", status: status, submitterId: "dev", voteCount: votes, commentCount: 0)
    }

    private static func ticket(_ subject: String, status: String = "open", priority: String = "normal") -> OrgSupportTicket {
        OrgSupportTicket(id: "T-\(subject)", subject: subject, status: status, priority: priority, submitterId: "dev", submitterEmail: "u@x.com", messageCount: 1)
    }

    func testFeedbackListBuildsQueryAndResolvesApp() async throws {
        var org = OrgClient.failing
        org.getApp = { ref in OrgApp(id: "APP-UUID", appName: "A", bundleId: ref, teamId: "T", isActive: true, isPrimary: true) }
        var client = FeedbackClient.failing
        let captured = Capture<FeedbackQuery>()
        client.listFeatures = { query in
            await captured.set(query)
            return OrgPage(items: [Self.feature("Dark mode", votes: 9)], page: 1, per: 20, total: 1)
        }
        try await ConsoleFeedbackCommand.ListCommand.parse(["--status", "planned", "--app", "com.x.app", "--search", "dark", "--sort", "newest", "--json"]).run(client: client, orgClient: org)
        let sent = await captured.value
        XCTAssertEqual(sent?.status, .planned)
        XCTAssertEqual(sent?.appId, "APP-UUID")
        XCTAssertEqual(sent?.search, "dark")
        XCTAssertEqual(sent?.sort, .newest)
        XCTAssertThrowsError(try ConsoleFeedbackCommand.ListCommand.parse(["--status", "done"]))
        XCTAssertThrowsError(try ConsoleFeedbackCommand.ListCommand.parse(["--sort", "random"]))
    }

    func testFeedbackSetStatusAndCommentParseAndMap() async throws {
        XCTAssertEqual(try ConsoleFeedbackCommand.SetStatusCommand.parse(["F1", "in_progress"]).status, .in_progress)
        XCTAssertThrowsError(try ConsoleFeedbackCommand.SetStatusCommand.parse(["F1", "later"]))
        XCTAssertThrowsError(try ConsoleFeedbackCommand.CommentCommand.parse(["F1"]))

        var client = FeedbackClient.failing
        client.setFeatureStatus = { _, _ in throw GrantivaError.networkError("", 404) }
        do {
            try await ConsoleFeedbackCommand.SetStatusCommand.parse(["F9", "shipped"]).run(client: client)
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.notFound(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertEqual(message, "feature request not found: F9")
        }
        client.addFeatureComment = { _, _ in throw GrantivaError.networkError("Forbidden", 403) }
        do {
            try await ConsoleFeedbackCommand.CommentCommand.parse(["F1", "--body", "Soon"]).run(client: client)
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.permissionDenied(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertTrue(message.contains("feedback:manage"), message)
        }
    }

    func testSupportReplyReadsBodyFromFile() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("reply.md")
        try "Fixed in 2.1.1".write(to: file, atomically: true, encoding: .utf8)
        var client = FeedbackClient.failing
        let captured = Capture<String>()
        client.addTicketMessage = { _, body in
            await captured.set(body)
            return OrgTicketMessage(id: "M1", authorId: "gpat_x", authorType: "admin", body: body)
        }
        try await ConsoleSupportCommand.ReplyCommand.parse(["T1", "--body", "@\(file.path)", "--json"]).run(client: client)
        let sent = await captured.value
        XCTAssertEqual(sent, "Fixed in 2.1.1")
    }

    func testSupportListAndPriorityParse() throws {
        let list = try ConsoleSupportCommand.ListCommand.parse(["--status", "awaiting_reply", "--priority", "urgent", "--per", "5"])
        XCTAssertEqual(list.status, .awaiting_reply)
        XCTAssertEqual(list.priority, .urgent)
        XCTAssertThrowsError(try ConsoleSupportCommand.ListCommand.parse(["--priority", "meh"]))
        XCTAssertEqual(try ConsoleSupportCommand.SetPriorityCommand.parse(["T1", "high"]).priority, .high)
        XCTAssertThrowsError(try ConsoleSupportCommand.SetStatusCommand.parse(["T1", "escalated"]))
    }

    func testThreadRenderingLabelsTeamAndUser() {
        let text = ConsoleFeedbackFormat.thread([
            OrgFeedbackComment(id: "1", authorId: "device-1", authorType: "user", body: "It crashes", createdAt: "2026-09-01T10:00:00Z"),
            OrgFeedbackComment(id: "2", authorId: "gpat_abc...", authorType: "admin", body: "On it\nThanks", createdAt: "2026-09-01T11:00:00Z"),
        ], empty: "none")
        XCTAssertTrue(text.contains("[2026-09-01 10:00] User (device-1):"), text)
        XCTAssertTrue(text.contains("[2026-09-01 11:00] Team (gpat_abc...):"), text)
        XCTAssertTrue(text.contains("\n  On it\n  Thanks"), "multi-line bodies stay indented: \(text)")
        XCTAssertEqual(ConsoleFeedbackFormat.thread([], empty: "none"), "none")
    }

    func testPagesRenderFooters() {
        let features = ConsoleFeedbackFormat.featuresPage(OrgPage(items: [Self.feature("A", votes: 3, status: "planned")], page: 2, per: 1, total: 5))
        XCTAssertTrue(features.contains("Page 2 of 5 · 5 requests"), features)
        let tickets = ConsoleFeedbackFormat.ticketsPage(OrgPage(items: [Self.ticket("Crash", priority: "urgent")], page: 1, per: 20, total: 1))
        XCTAssertTrue(tickets.contains("urgent"), tickets)
        XCTAssertTrue(tickets.contains("1 ticket\n") || tickets.hasSuffix("1 ticket"), tickets)
    }
}

private actor Capture<T: Sendable> {
    private(set) var value: T?
    func set(_ new: T) { value = new }
}
