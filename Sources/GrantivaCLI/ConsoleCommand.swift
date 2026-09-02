import ArgumentParser
import Foundation
import GrantivaAPI
import GrantivaCore

// MARK: - console

/// Namespace for everything dashboard-shaped: every feature of the Grantiva
/// web dashboard, as CLI subcommands. Phase 1 covers feature flags and flag
/// environments.
@available(macOS 15, *)
struct ConsoleCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "console",
        abstract: "Manage your Grantiva dashboard from the terminal.",
        subcommands: [
            ConsoleFlagsCommand.self,
            ConsoleEnvsCommand.self,
            ConsoleAnalyticsCommand.self,
            ConsoleDevicesCommand.self,
            ConsoleAppsCommand.self,
            ConsoleClaimsCommand.self,
            ConsoleVRTCommand.self,
            ConsoleReleasesCommand.self,
            ConsoleFeedbackCommand.self,
            ConsoleSupportCommand.self,
            ConsoleWebhooksCommand.self,
            ConsoleAlertsCommand.self,
            ConsoleKeysCommand.self,
            ConsoleTeamCommand.self,
            ConsoleAuditCommand.self,
            ConsoleOrgCommand.self,
            ConsoleOpenCommand.self,
        ]
    )
}

// MARK: - Shared Support

/// Scopes an API key needs for console flag operations. Used in 403 messages
/// so the user knows exactly which scope their key is missing.
enum ConsoleScope {
    static let flagsRead = "flags:read"
    static let flagsWrite = "flags:write"
    static let analyticsRead = "analytics:read"
    static let analyticsExport = "analytics:export"
    static let devicesRead = "devices:read"
    static let appsRead = "apps:read"
    static let appsWrite = "apps:write"
    static let appsDelete = "apps:delete"
    static let claimsRead = "claims:read"
    static let claimsWrite = "claims:write"
    static let claimsDelete = "claims:delete"
    static let claimsTest = "claims:test"
    static let vrtRead = "vrt:read"
    static let vrtWrite = "vrt:write"
    static let releaseNotesRead = "release_notes:read"
    static let releaseNotesWrite = "release_notes:write"
    static let feedbackRead = "feedback:read"
    static let feedbackManage = "feedback:manage"
    static let webhooksRead = "webhooks:read"
    static let webhooksWrite = "webhooks:write"
    static let webhooksDelete = "webhooks:delete"
    static let webhooksTest = "webhooks:test"
    static let alertsRead = "alerts:read"
    static let alertsWrite = "alerts:write"
    static let orgRead = "org:read"
    static let orgWrite = "org:write"
    static let keysRead = "keys:read"
    static let keysWrite = "keys:write"
    static let adminTeam = "admin:team"
    static let adminAudit = "admin:audit"
    static let adminBilling = "admin:billing"
}

enum ConsoleSupport {
    /// Builds a live client from resolved credentials, or fails with the
    /// standard "run grantiva auth login" guidance.
    static func makeClient() throws -> ConsoleClient {
        guard let credentials = AuthStore.resolveCredentials() else {
            throw GrantivaError.notAuthenticated
        }
        return ConsoleClient(apiKey: credentials.apiKey, baseURL: credentials.baseURL)
    }

    /// Same credential resolution, for the `/api/v1/org/*` apps, claims and
    /// devices surface.
    static func makeOrgClient() throws -> OrgClient {
        guard let credentials = AuthStore.resolveCredentials() else {
            throw GrantivaError.notAuthenticated
        }
        return OrgClient(apiKey: credentials.apiKey, baseURL: credentials.baseURL)
    }

    /// Same credential resolution, for org administration.
    static func makeOrgAdminClient() throws -> OrgAdminClient {
        guard let credentials = AuthStore.resolveCredentials() else {
            throw GrantivaError.notAuthenticated
        }
        return OrgAdminClient(apiKey: credentials.apiKey, baseURL: credentials.baseURL)
    }

    /// Same credential resolution, for staff-side feedback and support.
    static func makeFeedbackClient() throws -> FeedbackClient {
        guard let credentials = AuthStore.resolveCredentials() else {
            throw GrantivaError.notAuthenticated
        }
        return FeedbackClient(apiKey: credentials.apiKey, baseURL: credentials.baseURL)
    }

    /// Same credential resolution, for VRT run review.
    static func makeVRTReviewClient() throws -> VRTReviewClient {
        guard let credentials = AuthStore.resolveCredentials() else {
            throw GrantivaError.notAuthenticated
        }
        return VRTReviewClient(apiKey: credentials.apiKey, baseURL: credentials.baseURL)
    }

    /// Same credential resolution, for release note authoring.
    static func makeReleaseNotesClient() throws -> ReleaseNotesClient {
        guard let credentials = AuthStore.resolveCredentials() else {
            throw GrantivaError.notAuthenticated
        }
        return ReleaseNotesClient(apiKey: credentials.apiKey, baseURL: credentials.baseURL)
    }

    /// Same credential resolution, for the analytics/devices surface.
    static func makeAnalyticsClient() throws -> AnalyticsClient {
        guard let credentials = AuthStore.resolveCredentials() else {
            throw GrantivaError.notAuthenticated
        }
        return AnalyticsClient(apiKey: credentials.apiKey, baseURL: credentials.baseURL)
    }

    /// Maps raw HTTP failures onto messages a person can act on:
    /// 403 names the missing scope, 404 names the flag key, 429 surfaces the
    /// server's retry guidance instead of a raw JSON blob.
    static func map(_ error: Error, scope: String, flagKey: String? = nil, notFound: String? = nil) -> Error {
        guard case GrantivaError.networkError(let body, let status) = error else {
            return error
        }
        switch status {
        case 403:
            // The backend answers 403 for several things: a key without the
            // scope ("Insufficient permissions. Required scopes: flags:write"),
            // a tier limit ("Targeting rule limit reached…"), or a rule such as
            // "This key cannot grant scopes it does not hold". Only the first
            // gets the mint-a-new-key hint; every other explanation is shown
            // verbatim, because sending someone at a plan limit to create a key
            // is the wrong advice.
            if let serverMessage = errorMessage(fromBody: body),
               !serverMessage.hasPrefix("Insufficient permissions")
            {
                return GrantivaError.permissionDenied(serverMessage)
            }
            return GrantivaError.permissionDenied(
                "Permission denied: this API key is missing the '\(scope)' scope. "
                    + "Create a key with '\(scope)' in the dashboard under Settings → API Keys."
            )
        case 404:
            if let notFound {
                return GrantivaError.notFound(notFound)
            }
            if let flagKey {
                return GrantivaError.notFound("flag not found: \(flagKey)")
            }
            return GrantivaError.notFound("not found: \(body.isEmpty ? "resource does not exist" : body)")
        case 429:
            // The backend's rate limiter returns
            // {"error":"Rate limit exceeded. Retry after N seconds.","code":"rate_limited",...}
            // — surface the human-readable message, not the JSON envelope.
            let message = errorMessage(fromBody: body)
                ?? "Rate limit exceeded. Wait a moment and retry."
            return GrantivaError.permissionDenied(message)
        default:
            return error
        }
    }

    /// Extracts the `error` message from a JSON error envelope, if present.
    static func errorMessage(fromBody body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = object["error"] as? String,
              !message.isEmpty
        else {
            return nil
        }
        return message
    }

    /// Resolves a flag reference to its UUID. The org endpoints accept a
    /// flag_key directly; the pre-existing rules/evaluate endpoints need the
    /// UUID, so a key is resolved through `GET /api/v1/org/flags/:flagRef`.
    static func resolveFlagId(_ ref: String, client: ConsoleClient) async throws -> String {
        if UUID(uuidString: ref) != nil { return ref }
        do {
            return try await client.getFlag(ref).id
        } catch {
            throw map(error, scope: ConsoleScope.flagsRead, flagKey: ref)
        }
    }

    /// Gate for destructive verbs: `--yes` skips it; otherwise a TTY gets a
    /// prompt on stderr and a non-TTY refuses.
    ///
    /// `interactive` and `readAnswer` are injectable for tests.
    static func confirm(
        _ action: String,
        yes: Bool,
        interactive: Bool = isatty(fileno(stdin)) == 1,
        readAnswer: () -> String? = { readLine() }
    ) throws {
        guard !yes else { return }
        guard interactive else {
            throw GrantivaError.invalidArgument("refusing to \(action) without --yes (stdin is not a TTY)")
        }
        // The prompt is a diagnostic conversation, not program output — stderr.
        FileHandle.standardError.write(Data("\(action.prefix(1).capitalized + action.dropFirst())? [y/N] ".utf8))
        let answer = (readAnswer() ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        guard answer == "y" || answer == "yes" else {
            throw GrantivaError.aborted
        }
    }

    /// Parses repeated `--env-value production=true` pairs into a slug→value map.
    static func parseEnvValues(_ pairs: [String]) throws -> [String: String] {
        var values: [String: String] = [:]
        for pair in pairs {
            guard let eq = pair.firstIndex(of: "="), eq != pair.startIndex else {
                throw GrantivaError.invalidArgument(
                    "--env-value expects <environment>=<value>, got '\(pair)'"
                )
            }
            let env = String(pair[..<eq])
            let value = String(pair[pair.index(after: eq)...])
            values[env] = value
        }
        return values
    }

    /// Parses rule conditions from repeated `--when attribute:op:value` options
    /// and/or a `--conditions-json` blob. `in`/`not_in` values may be
    /// comma-separated and become arrays.
    static func parseConditions(when: [String], conditionsJSON: String?) throws -> [RuleCondition] {
        var conditions: [RuleCondition] = []

        for spec in when {
            let parts = spec.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3, !parts[0].isEmpty, !parts[1].isEmpty else {
                throw GrantivaError.invalidArgument(
                    "--when expects <attribute>:<operator>:<value>, got '\(spec)'"
                )
            }
            let attribute = String(parts[0])
            let op = String(parts[1])
            let validOperators = ["eq", "neq", "gt", "gte", "lt", "lte", "in", "not_in", "contains", "starts_with"]
            guard validOperators.contains(op) else {
                throw GrantivaError.invalidArgument(
                    "unknown operator '\(op)' in --when '\(spec)'. Valid: \(validOperators.joined(separator: ", "))"
                )
            }
            let rawValue = String(parts[2])
            let value: ConditionValue
            if op == "in" || op == "not_in" {
                value = .array(rawValue.split(separator: ",").map(String.init))
            } else {
                value = .string(rawValue)
            }
            conditions.append(RuleCondition(attribute: attribute, operator: op, value: value))
        }

        if let conditionsJSON {
            guard let data = conditionsJSON.data(using: .utf8) else {
                throw GrantivaError.invalidArgument("--conditions-json is not valid UTF-8")
            }
            do {
                conditions.append(contentsOf: try JSONDecoder().decode([RuleCondition].self, from: data))
            } catch {
                throw GrantivaError.invalidArgument(
                    "--conditions-json must be a JSON array of {attribute, operator, value} objects: \(error.localizedDescription)"
                )
            }
        }

        return conditions
    }

    /// Validates a raw flag value against the flag's declared type.
    static func validateValue(_ value: String, type: FlagValueTypeArgument) throws {
        switch type {
        case .bool:
            guard value == "true" || value == "false" else {
                throw GrantivaError.invalidArgument("bool flags take 'true' or 'false', got '\(value)'")
            }
        case .int:
            guard Int(value) != nil else {
                throw GrantivaError.invalidArgument("int flags take an integer value, got '\(value)'")
            }
        case .json:
            guard let data = value.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil
            else {
                throw GrantivaError.invalidArgument("json flags take a valid JSON document, got '\(value)'")
            }
        case .string:
            break
        }
    }
}

// MARK: - Value Type Argument

/// The `--type` argument for `flags create`, mapped to the backend's wire values.
enum FlagValueTypeArgument: String, ExpressibleByArgument, CaseIterable, Sendable {
    case bool
    case string
    case int
    case json

    var wireValue: String {
        switch self {
        case .bool: return "boolean"
        case .string: return "string"
        case .int: return "integer"
        case .json: return "json"
        }
    }
}
