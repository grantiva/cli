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
        let web: String
        if apiBaseURL.contains("dev-api.grantiva.io") {
            web = "https://dev.grantiva.io"
        } else if apiBaseURL.contains("api.grantiva.io") {
            web = "https://grantiva.io"
        } else if let url = URL(string: apiBaseURL), let host = url.host {
            // A custom deployment: assume the dashboard shares the API host.
            web = "\(url.scheme ?? "https")://\(host)\(url.port.map { ":\($0)" } ?? "")"
        } else {
            web = "https://grantiva.io"
        }
        return web + area.path
    }

    func run() async throws {
        let apiBaseURL = AuthStore.resolveCredentials()?.baseURL
            ?? ProcessInfo.processInfo.environment["GRANTIVA_API_URL"]
            ?? GrantivaDefaults.apiBaseURL
        let url = Self.dashboardURL(area: area, apiBaseURL: apiBaseURL)
        if options.json {
            Output.line(try JSONOutput.string(["url": url]))
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw GrantivaError.invalidArgument("could not open \(url)")
        }
        options.note("Opened \(url)")
    }
}
