import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaAPI
import GrantivaCore

final class ConsoleVRTReleasesCommandTests: XCTestCase {
    private static func run(status: String, screens: [RunScreenResultResponse], pending: Int? = 0) -> RunDetailResponse {
        RunDetailResponse(
            run: RunListItem(id: "R1", branch: "main", commitSha: nil, trigger: "ci", status: status, screenCount: screens.count,
                             passedCount: 0, failedCount: screens.count, newCount: 0, duration: nil, userEmail: nil, createdAt: nil),
            screens: screens, pendingReviewCount: pending
        )
    }

    private static func screen(_ name: String, status: String = "failed", review: String? = nil) -> RunScreenResultResponse {
        RunScreenResultResponse(id: name, screenName: name, status: status, reviewStatus: review, pixelDiffPercent: 1.5,
                                perceptualDistance: nil, pixelThreshold: 0.01, perceptualThreshold: 0.1, message: nil)
    }

    // MARK: - vrt

    func testVRTApproveSendsAcceptAllOnlyWhenAsked() async throws {
        var client = VRTReviewClient.failing
        let captured = Capture<ApproveRunRequest>()
        client.approveRun = { _, _, body in
            await captured.set(body)
            return Self.run(status: "approved", screens: [Self.screen("home", status: "approved", review: "accepted")])
        }
        try await ConsoleVRTCommand.ApproveCommand.parse(["app", "R1", "--json"]).run(client: client)
        var sent = await captured.value
        XCTAssertNil(sent?.acceptUnreviewed)
        try await ConsoleVRTCommand.ApproveCommand.parse(["app", "R1", "--accept-all", "--json"]).run(client: client)
        sent = await captured.value
        XCTAssertEqual(sent?.acceptUnreviewed, true)
    }

    func testVRTApproveSurfacesTheGateAndStateConflicts() async throws {
        var client = VRTReviewClient.failing
        client.approveRun = { _, _, _ in
            throw GrantivaError.networkError(#"{"error":"Review all failed and new screens before approving.","code":"bad_request"}"#, 400)
        }
        do {
            try await ConsoleVRTCommand.ApproveCommand.parse(["app", "R1"]).run(client: client)
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.invalidArgument(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertEqual(message, "Review all failed and new screens before approving.")
        }
        client.approveRun = { _, _, _ in
            throw GrantivaError.networkError(#"{"error":"Cannot approve a run with status: rejected"}"#, 409)
        }
        do {
            try await ConsoleVRTCommand.ApproveCommand.parse(["app", "R1"]).run(client: client)
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.invalidArgument(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertTrue(message.contains("rejected"), message)
        }
    }

    func testVRTScreenReviewsEachScreenInOrder() async throws {
        var client = VRTReviewClient.failing
        let calls = Capture<[String]>()
        client.getRun = { _, _ in Self.run(status: "pending", screens: [Self.screen("home"), Self.screen("settings")]) }
        client.reviewScreen = { _, _, screen, action in
            let existing = await calls.value ?? []
            await calls.set(existing + ["\(action.rawValue):\(screen)"])
            return Self.screen(screen, review: action == .reset ? nil : "\(action.rawValue)ed")
        }
        try await ConsoleVRTCommand.ScreenCommand.FlagCommand.parse(["app", "R1", "home", "settings", "--json"]).run(client: client)
        let made = await calls.value
        XCTAssertEqual(made, ["flag:home", "flag:settings"])
        XCTAssertThrowsError(try ConsoleVRTCommand.ScreenCommand.AcceptCommand.parse(["app", "R1"]))
    }

    func testVRTScreenValidatesEveryNameBeforeReviewing() async throws {
        var client = VRTReviewClient.failing
        let calls = Capture<[String]>()
        client.getRun = { _, _ in Self.run(status: "pending", screens: [Self.screen("home"), Self.screen("settings")]) }
        client.reviewScreen = { _, _, screen, _ in
            await calls.set((await calls.value ?? []) + [screen])
            return Self.screen(screen, review: "accepted")
        }

        do {
            try await ConsoleVRTCommand.ScreenCommand.AcceptCommand.parse([
                "app", "R1", "home", "misspelled", "settings", "--json",
            ]).run(client: client)
            XCTFail("expected validation failure")
        } catch {
            guard case GrantivaError.notFound(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertTrue(message.contains("misspelled"), message)
        }
        let made = await calls.value ?? []
        XCTAssertEqual(made, [])
    }

    func testVRTRunsGetMapsNotFound() async throws {
        var client = VRTReviewClient.failing
        client.getRun = { _, _ in throw GrantivaError.networkError("", 404) }
        do {
            try await ConsoleVRTCommand.RunsCommand.GetCommand.parse(["app", "R9"]).run(client: client)
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.notFound(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertEqual(message, "run not found: R9 in project app")
        }
    }

    func testVRTRunsListCallsClientAndMapsReadErrors() async throws {
        var client = VRTReviewClient.failing
        let captured = Capture<String>()
        client.listRuns = { project in
            await captured.set(project)
            return [Self.run(status: "pending", screens: []).run]
        }
        try await ConsoleVRTCommand.RunsCommand.ListCommand.parse(["my-app", "--json"]).run(client: client)
        let project = await captured.value
        XCTAssertEqual(project, "my-app")

        client.listRuns = { _ in throw GrantivaError.networkError("", 404) }
        do {
            try await ConsoleVRTCommand.RunsCommand.ListCommand.parse(["missing"]).run(client: client)
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.notFound(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertEqual(message, "project not found: missing")
        }
    }

    func testVRTRunsListRejectsBlankProjectBeforeCallingClient() async throws {
        XCTAssertThrowsError(try ConsoleVRTCommand.RunsCommand.ListCommand.parse(["   "]))
    }

    func testVRTScreensTableShowsPendingForUnreviewedFailures() {
        let table = ConsoleVRTFormat.screensTable([Self.screen("home"), Self.screen("about", status: "passed"), Self.screen("cart", review: "flagged")])
        let lines = table.split(separator: "\n").map(String.init)
        XCTAssertTrue(lines.contains { $0.hasPrefix("home") && $0.contains("pending") }, table)
        XCTAssertTrue(lines.contains { $0.hasPrefix("cart") && $0.contains("flagged") }, table)
        XCTAssertFalse(lines.contains { $0.hasPrefix("about") && $0.contains("pending") }, table)
    }

    // MARK: - releases

    func testReleasesCreateResolvesBundleIdAndReadsBodyFile() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("notes.md")
        try "## Dark mode\n- Everywhere".write(to: file, atomically: true, encoding: .utf8)

        var org = OrgClient.failing
        org.getApp = { ref in OrgApp(id: "APP-UUID", appName: "A", bundleId: ref, teamId: "T", isActive: true, isPrimary: true) }
        var notes = ReleaseNotesClient.failing
        let captured = Capture<CreateReleaseNoteRequest>()
        notes.create = { request in
            await captured.set(request)
            return ReleaseNote(id: "N1", appId: request.appId, version: request.version, title: request.title, body: request.body, isPublished: request.isPublished ?? false)
        }
        try await ConsoleReleasesCommand.CreateCommand.parse([
            "com.example.app", "2.1.0", "--title", "Dark mode", "--body", "@\(file.path)", "--publish", "--json",
        ]).run(client: notes, orgClient: org)
        let sent = await captured.value
        XCTAssertEqual(sent?.appId, "APP-UUID")
        XCTAssertEqual(sent?.body, "## Dark mode\n- Everywhere")
        XCTAssertEqual(sent?.isPublished, true)

        // A UUID app ref is passed through without a lookup.
        org.getApp = { _ in throw GrantivaError.networkError("must not be called", 500) }
        try await ConsoleReleasesCommand.CreateCommand.parse([
            "11111111-2222-3333-4444-555555555555", "2.2.0", "--title", "T", "--body", "inline", "--json",
        ]).run(client: notes, orgClient: org)
        let second = await captured.value
        XCTAssertEqual(second?.appId, "11111111-2222-3333-4444-555555555555")
        XCTAssertNil(second?.isPublished)
    }

    func testReleasesUpdateAndListValidation() throws {
        XCTAssertThrowsError(try ConsoleReleasesCommand.UpdateCommand.parse(["N1"]))
        XCTAssertNoThrow(try ConsoleReleasesCommand.UpdateCommand.parse(["N1", "--title", "x"]))
        XCTAssertThrowsError(try ConsoleReleasesCommand.ListCommand.parse(["--per", "0"]))
        XCTAssertEqual(try ConsoleReleasesCommand.ListCommand.parse(["--app", "com.x", "--page", "2"]).page, 2)
    }

    func testReleasesDeleteRefusesWithoutYesOffTTY() async throws {
        do {
            try await ConsoleReleasesCommand.DeleteCommand.parse(["N1"]).run(client: .failing)
            XCTFail("expected refusal")
        } catch {
            guard case GrantivaError.invalidArgument(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertTrue(message.contains("--yes"), message)
        }
    }

    func testReleasesPublishMapsNotFound() async throws {
        var notes = ReleaseNotesClient.failing
        notes.publish = { _ in throw GrantivaError.networkError("", 404) }
        do {
            try await ConsoleReleasesCommand.PublishCommand.parse(["N9"]).run(client: notes)
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.notFound(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertEqual(message, "release note not found: N9")
        }
    }
}

private actor Capture<T: Sendable> {
    private(set) var value: T?
    func set(_ new: T) { value = new }
}
