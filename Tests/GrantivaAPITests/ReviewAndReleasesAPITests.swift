import XCTest
@testable import GrantivaAPI
import GrantivaCore

final class ReviewAndReleasesAPITests: XCTestCase {
    private let base = URL(string: "https://api.example.com")!

    func testReviewEndpoints() {
        XCTAssertEqual(
            try! RunReviewEndpoints.approve(project: "app", runId: "R1", body: ApproveRunRequest()).url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/vrt/runs/app/R1/approve"
        )
        XCTAssertEqual(RunReviewEndpoints.reject(project: "app", runId: "R1").method, .post)
        XCTAssertEqual(
            try! RunReviewEndpoints.review(project: "my app", runId: "R1", screen: "Home/Main", action: .flag).url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/vrt/runs/my%20app/R1/screens/Home%2FMain/flag"
        )
    }

    func testApproveBodyOmitsNilAndEncodesSnakeCase() throws {
        XCTAssertEqual(String(decoding: try JSONEncoder().encode(ApproveRunRequest()), as: UTF8.self), "{}")
        XCTAssertEqual(String(decoding: try JSONEncoder().encode(ApproveRunRequest(acceptUnreviewed: true)), as: UTF8.self), #"{"accept_unreviewed":true}"#)
    }

    func testRunDetailDecodesReviewFieldsAndToleratesTheirAbsence() throws {
        let withReview = #"{"run":{"id":"R1","branch":"main","trigger":"ci","status":"failed","screen_count":2,"passed_count":1,"failed_count":1,"new_count":0},"screens":[{"id":"S1","screen_name":"home","status":"failed","review_status":"accepted","pixel_threshold":0.01,"perceptual_threshold":0.1}],"logs":"","pending_review_count":0}"#
        let detail = try JSONDecoder().decode(RunDetailResponse.self, from: Data(withReview.utf8))
        XCTAssertEqual(detail.pendingReviewCount, 0)
        XCTAssertEqual(detail.screens.first?.reviewStatus, "accepted")

        let legacy = #"{"run":{"id":"R1","branch":"main","trigger":"ci","status":"failed","screen_count":1,"passed_count":0,"failed_count":1,"new_count":0},"screens":[{"id":"S1","screen_name":"home","status":"failed","pixel_threshold":0.01,"perceptual_threshold":0.1}]}"#
        let old = try JSONDecoder().decode(RunDetailResponse.self, from: Data(legacy.utf8))
        XCTAssertNil(old.pendingReviewCount)
        XCTAssertNil(old.screens.first?.reviewStatus)
    }

    func testReleaseNoteEndpointsAndCamelCaseWire() throws {
        let url = try ReleaseNoteEndpoints.list(appId: "A", page: 2, per: 10).url(relativeTo: base).absoluteString
        XCTAssertTrue(url.hasPrefix("https://api.example.com/api/v1/org/release-notes?"), url)
        for fragment in ["appId=A", "page=2", "per=10"] { XCTAssertTrue(url.contains(fragment), url) }
        XCTAssertEqual(ReleaseNoteEndpoints.update(noteId: "N", body: UpdateReleaseNoteRequest(title: "x")).method, .patch)
        XCTAssertEqual(try ReleaseNoteEndpoints.publish(noteId: "N").url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/release-notes/N/publish")

        let json = String(decoding: try JSONEncoder().encode(CreateReleaseNoteRequest(appId: "A", version: "2.1.0", title: "T", body: "B")), as: UTF8.self)
        XCTAssertTrue(json.contains("\"appId\":\"A\""), json)
        XCTAssertFalse(json.contains("isPublished"), json)

        let page = #"{"items":[{"id":"N1","appId":"A","version":"2.1.0","title":"T","body":"B","isPublished":true,"publishedAt":"2026-09-01T00:00:00Z","createdAt":"2026-09-01T00:00:00Z","updatedAt":"2026-09-01T00:00:00Z"}],"metadata":{"page":1,"per":20,"total":1}}"#
        let decoded = try JSONDecoder().decode(ReleaseNotePage.self, from: Data(page.utf8))
        XCTAssertEqual(decoded.items.first?.version, "2.1.0")
        XCTAssertEqual(decoded.metadata.total, 1)
    }

    func testReleaseNoteIdentifierIsEncodedAsOnePathSegment() {
        let url = try! ReleaseNoteEndpoints.publish(noteId: "N#1/2").url(relativeTo: base)
        XCTAssertEqual(
            url.absoluteString,
            "https://api.example.com/api/v1/org/release-notes/N%231%2F2/publish"
        )
    }

    func testFailingDoubles() async {
        do { _ = try await VRTReviewClient.failing.listRuns("p"); XCTFail() } catch { }
        do { _ = try await ReleaseNotesClient.failing.get("n"); XCTFail() } catch { }
    }
}
