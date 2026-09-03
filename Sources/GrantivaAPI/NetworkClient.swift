import Foundation
import GrantivaCore

// MARK: - Network Client

struct NetworkClient: Sendable {
    var get: @Sendable (URL) async throws -> Data
    var post: @Sendable (URL, Data?) async throws -> Data
    var put: @Sendable (URL, Data?) async throws -> Data
    var delete: @Sendable (URL) async throws -> Data

    /// Escape hatch for requests that need custom headers (multipart, image/png, etc.).
    var sendRequest: @Sendable (URLRequest) async throws -> Data
}

// MARK: - Typed Execution

extension NetworkClient {
    func execute<Request, Response>(
        _ endpoint: Endpoint<Request, Response>,
        baseURL: URL
    ) async throws -> Response {
        let url = try endpoint.url(relativeTo: baseURL)

        let responseData: Data
        switch endpoint.method {
        case .get:
            responseData = try await get(url)
        case .post:
            let body = try endpoint.body.map { try JSONEncoder().encode($0) }
            responseData = try await post(url, body)
        case .put:
            let body = try endpoint.body.map { try JSONEncoder().encode($0) }
            responseData = try await put(url, body)
        case .patch:
            // The typed closures only cover the four verbs the client was born
            // with; PATCH rides the raw-request path so it never degrades to PUT.
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            if let body = try endpoint.body.map({ try JSONEncoder().encode($0) }) {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = body
            }
            responseData = try await sendRequest(request)
        case .delete:
            responseData = try await delete(url)
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        return try JSONDecoder().decode(Response.self, from: responseData)
    }

    /// Download raw bytes (e.g. image data).
    func download(_ endpoint: Endpoint<EmptyBody, EmptyResponse>, baseURL: URL) async throws -> Data {
        let url = try endpoint.url(relativeTo: baseURL)
        var request = URLRequest(url: url)
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 300
        return try await sendRequest(request)
    }

    /// Upload raw bytes with a custom content type (e.g. image/png).
    func upload(_ endpoint: Endpoint<EmptyBody, EmptyResponse>, baseURL: URL, data: Data, contentType: String) async throws {
        let url = try endpoint.url(relativeTo: baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        _ = try await sendRequest(request)
    }
}

// MARK: - Authorized Live Implementation

extension NetworkClient {
    static func anonymous() -> NetworkClient {
        live(apiKey: nil)
    }

    static func authorized(apiKey: String) -> NetworkClient {
        live(apiKey: apiKey)
    }

    private static func live(apiKey: String?) -> NetworkClient {
        let session = URLSession.shared

        @Sendable func addAuth(_ request: inout URLRequest) {
            if let apiKey { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
            if request.value(forHTTPHeaderField: "Accept") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Accept")
            }
        }

        return NetworkClient(
            get: { url in
                var request = URLRequest(url: url)
                addAuth(&request)
                let (data, response) = try await session.data(for: request)
                try validateResponse(response, data: data)
                return data
            },
            post: { url, body in
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                addAuth(&request)
                if let body {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = body
                }
                let (data, response) = try await session.data(for: request)
                try validateResponse(response, data: data)
                return data
            },
            put: { url, body in
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                addAuth(&request)
                if let body {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = body
                }
                let (data, response) = try await session.data(for: request)
                try validateResponse(response, data: data)
                return data
            },
            delete: { url in
                var request = URLRequest(url: url)
                request.httpMethod = "DELETE"
                addAuth(&request)
                let (data, response) = try await session.data(for: request)
                try validateResponse(response, data: data)
                return data
            },
            sendRequest: { request in
                var request = request
                addAuth(&request)
                request.timeoutInterval = max(request.timeoutInterval, 300)
                let (data, response) = try await session.data(for: request)
                try validateResponse(response, data: data)
                return data
            }
        )
    }
}

// MARK: - Response Validation

private func validateResponse(_ response: URLResponse, data: Data) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
        throw GrantivaError.networkError("Invalid response", 0)
    }
    guard (200...299).contains(httpResponse.statusCode) else {
        if httpResponse.statusCode == 401 {
            throw GrantivaError.notAuthenticated
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        throw GrantivaError.networkError(body, httpResponse.statusCode)
    }
}
