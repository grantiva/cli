import ArgumentParser
import Foundation
import GrantivaCore

@available(macOS 15, *)
struct AuthCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "auth",
        abstract: "Manage authentication with Grantiva.",
        subcommands: [LoginCommand.self, StatusCommand.self, LogoutCommand.self]
    )

    // MARK: - Login

    struct LoginCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "login",
            abstract: "Authenticate with Grantiva API."
        )

        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "API key for Grantiva (skip browser flow)")
        var apiKey: String?

        @Option(name: .long, help: "Base URL for Grantiva API")
        var baseURL: String = GrantivaDefaults.apiBaseURL

        var authStore: AuthStore = .live

        func run() async throws {
            let validatedBaseURL = try Self.validatedBaseURL(baseURL)
            if let apiKey {
                try await loginWithAPIKey(apiKey, baseURL: validatedBaseURL)
            } else {
                try await loginWithBrowser(baseURL: validatedBaseURL)
            }
        }

        static func validatedBaseURL(_ value: String) throws -> URL {
            guard let url = URL(string: value),
                  ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  url.host != nil
            else {
                throw GrantivaError.invalidArgument("--base-url must be a valid http or https URL")
            }
            return url
        }

        // MARK: - Direct API key flow (CI / headless)

        private func loginWithAPIKey(_ apiKey: String, baseURL: URL) async throws {
            let meURL = baseURL.appending(path: "api/v1/auth/me")
            var request = URLRequest(url: meURL)
            request.httpMethod = "GET"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GrantivaError.networkError("Invalid response", 0)
            }

            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 {
                    throw GrantivaError.notAuthenticated
                }
                let body = String(data: data, encoding: .utf8) ?? ""
                throw GrantivaError.networkError(body, httpResponse.statusCode)
            }

            let meResponse = try JSONDecoder().decode(MeResponse.self, from: data)

            let credentials = AuthCredentials(
                apiKey: apiKey,
                baseURL: baseURL.absoluteString,
                email: meResponse.email
            )
            try authStore.save(credentials)

            if options.json {
                let result = LoginResult(
                    authenticated: true,
                    email: meResponse.email,
                    baseURL: baseURL.absoluteString,
                    apiKeyPrefix: meResponse.apiKeyPrefix
                )
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line("Authenticated as \(meResponse.email)")
                Output.line("API key: \(meResponse.apiKeyPrefix)...")
                Output.line("Credentials saved to ~/.grantiva/auth.json")
            }
        }

        // MARK: - Browser-based flow

        private func loginWithBrowser(baseURL: URL) async throws {
            // 1. Create a CLI session
            let sessionURL = baseURL.appending(path: "api/v1/auth/cli/sessions")
            var createRequest = URLRequest(url: sessionURL)
            createRequest.httpMethod = "POST"
            createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            createRequest.setValue("application/json", forHTTPHeaderField: "Accept")

            let (createData, createResponse) = try await URLSession.shared.data(for: createRequest)

            guard let createHTTP = createResponse as? HTTPURLResponse, createHTTP.statusCode == 200 else {
                throw GrantivaError.networkError("Failed to create auth session", (createResponse as? HTTPURLResponse)?.statusCode ?? 0)
            }

            let session = try JSONDecoder().decode(CreateSessionResponse.self, from: createData)

            // 2. Open browser
            let loginEndpoint = baseURL.appending(path: "api/v1/auth/cli")
            guard var loginComponents = URLComponents(url: loginEndpoint, resolvingAgainstBaseURL: false) else {
                throw GrantivaError.invalidArgument("--base-url must be a valid http or https URL")
            }
            loginComponents.queryItems = [URLQueryItem(name: "session", value: session.sessionId)]
            guard let loginURL = loginComponents.url else {
                throw GrantivaError.invalidArgument("could not construct authentication URL")
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [loginURL.absoluteString]
            try process.run()
            process.waitUntilExit()

            options.note("Opening browser to sign in...")
            options.note("If the browser doesn't open, visit: \(loginURL.absoluteString)")
            options.note("Waiting for authentication...")

            // 3. Poll for completion
            let pollURL = baseURL
                .appending(path: "api/v1/auth/cli/sessions")
                .appending(path: session.sessionId)
            let timeout: TimeInterval = 300 // 5 minutes
            let interval: TimeInterval = 2
            let start = Date()

            while Date().timeIntervalSince(start) < timeout {
                try await Task.sleep(for: .seconds(interval))

                var pollRequest = URLRequest(url: pollURL)
                pollRequest.httpMethod = "GET"
                pollRequest.setValue("application/json", forHTTPHeaderField: "Accept")

                let (pollData, pollResponse) = try await URLSession.shared.data(for: pollRequest)

                guard let pollHTTP = pollResponse as? HTTPURLResponse, pollHTTP.statusCode == 200 else {
                    continue
                }

                let pollResult = try JSONDecoder().decode(PollSessionResponse.self, from: pollData)

                if pollResult.status == "complete",
                   let apiKey = pollResult.apiKey,
                   let email = pollResult.email
                {
                    let credentials = AuthCredentials(
                        apiKey: apiKey,
                        baseURL: baseURL.absoluteString,
                        email: email
                    )
                    try authStore.save(credentials)

                    let prefix = String(apiKey.prefix(8))

                    if options.json {
                        let result = LoginResult(
                            authenticated: true,
                            email: email,
                            baseURL: baseURL.absoluteString,
                            apiKeyPrefix: prefix
                        )
                        Output.line(try JSONOutput.string(result))
                    } else {
                        Output.line("Authenticated as \(email)")
                        Output.line("API key: \(prefix)...")
                        Output.line("Credentials saved to ~/.grantiva/auth.json")
                    }
                    return
                }
            }

            // Timeout
            // The thrown error carries the failure; this is only the hint that
            // goes with it, so it is a diagnostic and not part of any result.
            options.note("You can also authenticate directly: grantiva auth login --api-key <key>")
            throw GrantivaError.networkError("Authentication timed out after 5 minutes", 0)
        }
    }

    // MARK: - Status

    struct StatusCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show current authentication status."
        )

        @OptionGroup var options: GlobalOptions

        var authStore: AuthStore = .live

        func run() async throws {
            let env = ProcessInfo.processInfo.environment

            if let apiKey = env["GRANTIVA_API_KEY"], !apiKey.isEmpty {
                let baseURL = env["GRANTIVA_API_URL"] ?? GrantivaDefaults.apiBaseURL
                let prefix = String(apiKey.prefix(8))

                if options.json {
                    let result = StatusResult(
                        authenticated: true,
                        source: "env",
                        email: nil,
                        baseURL: baseURL,
                        apiKeyPrefix: prefix
                    )
                    Output.line(try JSONOutput.string(result))
                } else {
                    Output.line("Authenticated via environment variable")
                    Output.line("  Base URL: \(baseURL)")
                    Output.line("  API key:  \(prefix)...")
                }
                return
            }

            if let credentials = authStore.load() {
                let prefix = String(credentials.apiKey.prefix(8))

                if options.json {
                    let result = StatusResult(
                        authenticated: true,
                        source: "file",
                        email: credentials.email,
                        baseURL: credentials.baseURL,
                        apiKeyPrefix: prefix
                    )
                    Output.line(try JSONOutput.string(result))
                } else {
                    Output.line("Authenticated via ~/.grantiva/auth.json")
                    if let email = credentials.email {
                        Output.line("  Email:    \(email)")
                    }
                    Output.line("  Base URL: \(credentials.baseURL)")
                    Output.line("  API key:  \(prefix)...")
                }
                return
            }

            if options.json {
                let result = StatusResult(
                    authenticated: false,
                    source: nil,
                    email: nil,
                    baseURL: nil,
                    apiKeyPrefix: nil
                )
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line("Not authenticated. Run: grantiva auth login")
            }
        }
    }

    // MARK: - Logout

    struct LogoutCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "logout",
            abstract: "Remove saved authentication credentials."
        )

        @OptionGroup var options: GlobalOptions

        var authStore: AuthStore = .live

        func run() async throws {
            try authStore.delete()

            if options.json {
                let result = LogoutResult(success: true, message: "Credentials removed")
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line("Logged out. Credentials removed from ~/.grantiva/auth.json")
            }
        }
    }
}

// MARK: - Response Models (CLI session flow)

@available(macOS 15, *)
private struct CreateSessionResponse: Codable, Sendable {
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
    }
}

@available(macOS 15, *)
private struct PollSessionResponse: Codable, Sendable {
    let status: String
    let apiKey: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case status
        case apiKey = "api_key"
        case email
    }
}

// MARK: - Response Models (API key validation)

@available(macOS 15, *)
private struct MeResponse: Codable, Sendable {
    let email: String
    let apiKeyPrefix: String

    enum CodingKeys: String, CodingKey {
        case email
        case apiKeyPrefix = "api_key_prefix"
    }
}

// MARK: - Output Models

@available(macOS 15, *)
private struct LoginResult: Codable, Sendable {
    let authenticated: Bool
    let email: String
    let baseURL: String
    let apiKeyPrefix: String
}

@available(macOS 15, *)
private struct StatusResult: Codable, Sendable {
    let authenticated: Bool
    let source: String?
    let email: String?
    let baseURL: String?
    let apiKeyPrefix: String?
}

@available(macOS 15, *)
private struct LogoutResult: Codable, Sendable {
    let success: Bool
    let message: String
}
