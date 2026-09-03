import Foundation

// MARK: - Auth Endpoints

enum AuthEndpoints {
    static func me() -> Endpoint<EmptyBody, MeResponse> {
        Endpoint(path: "api/v1/auth/me", method: .get)
    }
}

// MARK: - Baseline Endpoints

enum BaselineEndpoints {
    private static let prefix = "api/v1/vrt/baselines"

    static func list(project: String, branch: String) -> Endpoint<EmptyBody, BaselineListResponse> {
        Endpoint(
            path: "\(prefix)/\(EndpointPath.segment(project))/\(EndpointPath.segment(branch))",
            method: .get
        )
    }

    static func download(project: String, branch: String, screen: String) -> Endpoint<EmptyBody, EmptyResponse> {
        Endpoint(
            path: "\(prefix)/\(EndpointPath.segment(project))/\(EndpointPath.segment(branch))/\(EndpointPath.segment(screen))",
            method: .get
        )
    }

    static func upload(project: String, branch: String, screen: String) -> Endpoint<EmptyBody, EmptyResponse> {
        Endpoint(
            path: "\(prefix)/\(EndpointPath.segment(project))/\(EndpointPath.segment(branch))/\(EndpointPath.segment(screen))",
            method: .post
        )
    }

    static func delete(project: String, branch: String, screen: String) -> Endpoint<EmptyBody, EmptyResponse> {
        Endpoint(
            path: "\(prefix)/\(EndpointPath.segment(project))/\(EndpointPath.segment(branch))/\(EndpointPath.segment(screen))",
            method: .delete
        )
    }

    static func promote(project: String, branch: String, body: PromoteBaselinesRequest) -> Endpoint<PromoteBaselinesRequest, EmptyResponse> {
        Endpoint(
            path: "\(prefix)/\(EndpointPath.segment(project))/\(EndpointPath.segment(branch))/promote",
            method: .post,
            body: body
        )
    }
}

// MARK: - Run Endpoints

enum RunEndpoints {
    private static let prefix = "api/v1/vrt/runs"

    static func create(project: String) -> Endpoint<EmptyBody, RunResponse> {
        Endpoint(
            path: "\(prefix)/\(EndpointPath.segment(project))",
            method: .post
        )
    }

    static func list(project: String) -> Endpoint<EmptyBody, RunListResponse> {
        Endpoint(
            path: "\(prefix)/\(EndpointPath.segment(project))",
            method: .get
        )
    }

    static func detail(project: String, runId: String) -> Endpoint<EmptyBody, RunDetailResponse> {
        Endpoint(
            path: "\(prefix)/\(EndpointPath.segment(project))/\(EndpointPath.segment(runId))",
            method: .get
        )
    }

    static func complete(project: String, runId: String) -> Endpoint<EmptyBody, RunResponse> {
        Endpoint(
            path: "\(prefix)/\(EndpointPath.segment(project))/\(EndpointPath.segment(runId))",
            method: .patch
        )
    }

    static func appendLog(project: String, runId: String) -> Endpoint<EmptyBody, EmptyResponse> {
        Endpoint(
            path: "\(prefix)/\(EndpointPath.segment(project))/\(EndpointPath.segment(runId))/logs",
            method: .post
        )
    }
}
