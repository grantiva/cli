import XCTest
@testable import GrantivaAPI
import GrantivaCore

final class FeedbackAPITests: XCTestCase {
    private let base = URL(string: "https://api.example.com")!

    func testFeedbackEndpointsCarryFilters() {
        let url = OrgFeedbackEndpoints.listFeatures(FeedbackQuery(status: .inProgress, appId: "A", search: "dark", sort: .oldest, page: 2, per: 10)).url(relativeTo: base).absoluteString
        for fragment in ["status=in_progress", "app_id=A", "search=dark", "sort=oldest", "page=2", "per=10"] { XCTAssertTrue(url.contains(fragment), url) }
        XCTAssertEqual(OrgFeedbackEndpoints.listFeatures(FeedbackQuery()).url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/feedback")
        XCTAssertEqual(OrgFeedbackEndpoints.setFeatureStatus("F1", body: OrgSetStatusRequest(status: "shipped")).url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/feedback/F1/status")
        XCTAssertEqual(OrgFeedbackEndpoints.addTicketMessage("T1", body: OrgMessageBodyRequest(body: "x")).url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/support/T1/messages")
        let tickets = OrgFeedbackEndpoints.listTickets(SupportQuery(status: .awaitingReply, priority: .urgent)).url(relativeTo: base).absoluteString
        XCTAssertTrue(tickets.contains("status=awaiting_reply") && tickets.contains("priority=urgent"), tickets)
    }

    func testDecodesFeedbackAndSupportShapes() throws {
        let page = #"{"items":[{"id":"F1","app_id":null,"title":"Dark mode","description":"pls","status":"planned","submitter_id":"dev","vote_count":9,"comment_count":1,"created_at":"2026-09-01T00:00:00Z","updated_at":"2026-09-01T00:00:00Z"}],"page":1,"per":20,"total":1}"#
        let decoded = try JSONDecoder().decode(OrgPage<OrgFeatureRequest>.self, from: Data(page.utf8))
        XCTAssertEqual(decoded.items.first?.voteCount, 9)

        let detail = #"{"ticket":{"id":"T1","app_id":null,"subject":"Crash","status":"awaiting_reply","priority":"urgent","submitter_id":"dev","submitter_email":"u@x.com","message_count":2,"created_at":null,"updated_at":null},"messages":[{"id":"M1","author_id":"dev","author_type":"user","body":"It crashes","created_at":"2026-09-01T00:00:00Z"},{"id":"M2","author_id":"gpat_x...","author_type":"admin","body":"On it","created_at":"2026-09-01T01:00:00Z"}]}"#
        let ticket = try JSONDecoder().decode(OrgSupportTicketDetail.self, from: Data(detail.utf8))
        XCTAssertEqual(ticket.messages.map(\.authorType), ["user", "admin"])
        XCTAssertEqual(ticket.ticket.priority, "urgent")
    }

    func testFailingDouble() async {
        do { _ = try await FeedbackClient.failing.getTicket("t"); XCTFail() } catch { }
    }
}
