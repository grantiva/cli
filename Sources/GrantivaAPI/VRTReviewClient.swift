import Foundation
import GrantivaCore

// MARK: - Run Review Endpoints (key-auth VRT API — snake_case wire)

enum RunReviewEndpoints {
    private static let prefix = "api/v1/vrt/runs"

    private static func segment(_ value: String) -> String {
        EndpointPath.segment(value)
    }

    static func approve(project: String, runId: String, body: ApproveRunRequest) -> Endpoint<ApproveRunRequest, RunDetailResponse> {
        Endpoint(path: "\(prefix)/\(segment(project))/\(segment(runId))/approve", method: .post, body: body)
    }

    static func reject(project: String, runId: String) -> Endpoint<EmptyBody, RunDetailResponse> {
        Endpoint(path: "\(prefix)/\(segment(project))/\(segment(runId))/reject", method: .post)
    }

    static func review(project: String, runId: String, screen: String, action: ScreenReviewAction) -> Endpoint<EmptyBody, RunScreenResultResponse> {
        Endpoint(path: "\(prefix)/\(segment(project))/\(segment(runId))/screens/\(segment(screen))/\(action.rawValue)", method: .post)
    }
}

public struct ApproveRunRequest: Codable, Sendable, Equatable {
    /// Accept every still-unreviewed failed/new screen before approving.
    public let acceptUnreviewed: Bool?

    enum CodingKeys: String, CodingKey {
        case acceptUnreviewed = "accept_unreviewed"
    }

    public init(acceptUnreviewed: Bool? = nil) {
        self.acceptUnreviewed = acceptUnreviewed
    }
}

public enum ScreenReviewAction: String, Sendable, CaseIterable {
    case accept, flag, reset
}

// MARK: - VRTReviewClient

/// API client for `grantiva console vrt`: run listing, detail, and review
/// on the key-authenticated VRT API. Sibling of `RangeClient`, which owns
/// run creation and baselines.
public struct VRTReviewClient: Sendable {
    public var listRuns: @Sendable (_ project: String) async throws -> [RunListItem]
    public var getRun: @Sendable (_ project: String, _ runId: String) async throws -> RunDetailResponse
    public var approveRun: @Sendable (_ project: String, _ runId: String, ApproveRunRequest) async throws -> RunDetailResponse
    public var rejectRun: @Sendable (_ project: String, _ runId: String) async throws -> RunDetailResponse
    public var reviewScreen: @Sendable (_ project: String, _ runId: String, _ screen: String, ScreenReviewAction) async throws -> RunScreenResultResponse

    public init(
        listRuns: @escaping @Sendable (String) async throws -> [RunListItem],
        getRun: @escaping @Sendable (String, String) async throws -> RunDetailResponse,
        approveRun: @escaping @Sendable (String, String, ApproveRunRequest) async throws -> RunDetailResponse,
        rejectRun: @escaping @Sendable (String, String) async throws -> RunDetailResponse,
        reviewScreen: @escaping @Sendable (String, String, String, ScreenReviewAction) async throws -> RunScreenResultResponse
    ) {
        self.listRuns = listRuns
        self.getRun = getRun
        self.approveRun = approveRun
        self.rejectRun = rejectRun
        self.reviewScreen = reviewScreen
    }

    public init(apiKey: String, baseURL: String) throws {
        let baseURL = try validatedAPIBaseURL(baseURL)
        let client = NetworkClient.authorized(apiKey: apiKey)
        self.init(
            listRuns: { project in
                let response: RunListResponse = try await client.execute(RunEndpoints.list(project: project), baseURL: baseURL)
                return response.runs
            },
            getRun: { project, runId in
                try await client.execute(RunEndpoints.detail(project: project, runId: runId), baseURL: baseURL)
            },
            approveRun: { project, runId, body in
                try await client.execute(RunReviewEndpoints.approve(project: project, runId: runId, body: body), baseURL: baseURL)
            },
            rejectRun: { project, runId in
                try await client.execute(RunReviewEndpoints.reject(project: project, runId: runId), baseURL: baseURL)
            },
            reviewScreen: { project, runId, screen, action in
                try await client.execute(RunReviewEndpoints.review(project: project, runId: runId, screen: screen, action: action), baseURL: baseURL)
            }
        )
    }

    public static let failing = VRTReviewClient(
        listRuns: { _ in throw GrantivaError.notAuthenticated },
        getRun: { _, _ in throw GrantivaError.notAuthenticated },
        approveRun: { _, _, _ in throw GrantivaError.notAuthenticated },
        rejectRun: { _, _ in throw GrantivaError.notAuthenticated },
        reviewScreen: { _, _, _, _ in throw GrantivaError.notAuthenticated }
    )
}
