import ArgumentParser
import Foundation
import GrantivaCore

// MARK: - console open

@available(macOS 15, *)
struct ConsoleOpenCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "open",
        abstract: "Open the dashboard in your browser, optionally at an area.",
        discussion: "Areas: \(Area.allCases.map(\.rawValue).joined(separator: ", ")). With --json the URL is printed instead of opened."
    )

    enum Area: String, ExpressibleByArgument, CaseIterable {
        case home, flags, apps, claims, devices, analytics, vrt, releases, feedback, support, webhooks, alerts, keys, team, audit, settings, billing

        var path: String {
            switch self {
            case .home: return "/dashboard"
            case .flags: return "/dashboard/feature-flags"
            case .keys: return "/dashboard/settings/api-keys"
            case .team: return "/dashboard/settings/team"
            case .webhooks: return "/dashboard/settings/webhooks"
            case .alerts: return "/dashboard/settings/alerts"
            case .audit: return "/dashboard/audit-log"
            case .releases: return "/dashboard/whats-new"
            default: return "/dashboard/\(rawValue)"
            }
        }
    }

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Dashboard area. Default: the dashboard home.")
    var area: Area = .home

    /// Maps the API host the CLI is configured for to the matching web host.
    static func dashboardURL(area: Area, apiBaseURL: String) -> String {
        guard var components = URLComponents(string: apiBaseURL),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host?.lowercased(), !host.isEmpty
        else {
            return "https://grantiva.io" + area.path
        }

        let web: String
        if host == "dev-api.grantiva.io" {
            web = "https://dev.grantiva.io"
        } else if host == "api.grantiva.io" {
            web = "https://grantiva.io"
        } else {
            // A custom deployment: assume the dashboard shares the API origin.
            // URLComponents preserves IPv6 brackets and avoids carrying an API
            // base path, query, credentials, or fragment into the dashboard URL.
            components.path = ""
            components.query = nil
            components.fragment = nil
            components.user = nil
            components.password = nil
            web = components.string ?? "https://grantiva.io"
        }
        return web + area.path
    }

    func run() async throws {
        let apiBaseURL = AuthStore.resolveCredentials()?.baseURL
            ?? ProcessInfo.processInfo.environment["GRANTIVA_API_URL"]
            ?? GrantivaDefaults.apiBaseURL
        try run(apiBaseURL: apiBaseURL, openURL: Self.openInBrowser)
    }

    /// Injectable execution path so command behavior can be verified without
    /// launching a user's browser.
    func run(apiBaseURL: String, openURL: (String) throws -> Int32) throws {
        let url = Self.dashboardURL(area: area, apiBaseURL: apiBaseURL)
        if options.json {
            Output.line(try JSONOutput.string(["url": url]))
            return
        }

        let status = try openURL(url)
        guard status == 0 else {
            throw GrantivaError.commandFailed("open \(url)", status)
        }
        options.note("Opened \(url)")
    }

    private static func openInBrowser(_ url: String) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
