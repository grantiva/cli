import ArgumentParser
import Foundation
import GrantivaAPI
import GrantivaCore

// MARK: - console analytics

@available(macOS 15, *)
struct ConsoleAnalyticsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "analytics",
        abstract: "Attestation analytics: overview, event log, risk and compliance reports, CSV export.",
        subcommands: [
            OverviewCommand.self,
            EventsCommand.self,
            DeviceCommand.self,
            RiskCommand.self,
            ComplianceCommand.self,
            ExportCommand.self,
        ]
    )

    /// `1d`, `7d`, `30d`, `90d` — the only windows the server honours. It
    /// silently falls back on anything else, so reject bad input here.
    enum Range: String, ExpressibleByArgument, CaseIterable {
        case day = "1d", week = "7d", month = "30d", quarter = "90d"

        var wire: AnalyticsTimeRange { AnalyticsTimeRange(rawValue: rawValue)! }
    }

    // MARK: - overview

    struct OverviewCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "overview",
            abstract: "Attestation totals, success rate, unique devices, average risk, and the latest events."
        )

        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Window in days. Default 30.")
        var days: Int?

        @Option(name: .long, help: "Window: 1d, 7d, 30d, or 90d. Default 30d.")
        var period: Range?

        func validate() throws {
            if days != nil, period != nil { throw ValidationError("Pass either --period or --days, not both.") }
            if let days, days < 1 {
                throw ValidationError("--days must be at least 1.")
            }
        }

        func run() async throws {
            try await run(client: ConsoleSupport.makeAnalyticsClient())
        }

        func run(client: AnalyticsClient) async throws {
            let effectiveDays = period.map { Int($0.rawValue.dropLast())! } ?? days
            let overview: AttestationAnalytics
            do {
                overview = try await client.overview(effectiveDays)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.analyticsRead)
            }

            if options.json {
                Output.line(try JSONOutput.string(overview))
            } else {
                Output.line(ConsoleAnalyticsFormat.overview(overview, days: effectiveDays ?? 30))
            }
        }
    }

    // MARK: - device

    struct DeviceCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "device",
            abstract: "Show one device's risk profile, compliance status, and recent events."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Device key ID.")
        var keyId: String

        func run() async throws {
            try await run(client: ConsoleSupport.makeAnalyticsClient())
        }

        func run(client: AnalyticsClient) async throws {
            let detail: DeviceDetailsResponse
            do {
                detail = try await client.device(keyId)
            } catch {
                throw ConsoleSupport.map(
                    error,
                    scope: ConsoleScope.analyticsRead,
                    notFound: "analytics device not found: \(keyId)"
                )
            }

            if options.json {
                Output.line(try JSONOutput.string(detail))
            } else {
                Output.line(ConsoleAnalyticsFormat.device(detail))
            }
        }
    }

    // MARK: - events

    struct EventsCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "events",
            abstract: "Page through the attestation event log."
        )

        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Page number, starting at 1.")
        var page: Int?

        @Option(name: [.customLong("per"), .customLong("per-page")], help: "Events per page, 1–200. Default 50. (--per-page is retained as an alias.)")
        var perPage: Int?

        @Option(name: .long, help: "Only events at or after this ISO 8601 timestamp, e.g. 2026-09-01T00:00:00Z.")
        var from: String?

        @Option(name: .long, help: "Only events at or before this ISO 8601 timestamp.")
        var to: String?

        @Option(name: .long, help: "Only events for this device ID.")
        var device: String?

        @Option(
            name: .long,
            help: "Only this event type: \(AttestationEventType.allCases.map(\.rawValue).joined(separator: ", "))."
        )
        var type: String?

        func validate() throws {
            if let page, page < 1 { throw ValidationError("--page must be at least 1.") }
            if let perPage, !(1...200).contains(perPage) { throw ValidationError("--per must be between 1 and 200.") }
            let fromDate = try Self.validateTimestamp(from, option: "--from")
            let toDate = try Self.validateTimestamp(to, option: "--to")
            if let fromDate, let toDate, fromDate > toDate {
                throw ValidationError("--from must not be later than --to.")
            }
            if let device, device.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ValidationError("--device must not be empty.")
            }
            if let type, AttestationEventType(rawValue: type) == nil {
                throw ValidationError(
                    "Unknown event type '\(type)'. Expected one of: "
                        + AttestationEventType.allCases.map(\.rawValue).joined(separator: ", ")
                )
            }
        }

        private static func validateTimestamp(_ value: String?, option: String) throws -> Date? {
            guard let value else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            throw ValidationError("\(option) must be an ISO 8601 timestamp, for example 2026-09-01T00:00:00Z.")
        }

        func run() async throws {
            try await run(client: ConsoleSupport.makeAnalyticsClient())
        }

        func run(client: AnalyticsClient) async throws {
            let query = EventsQuery(
                page: page,
                perPage: perPage,
                from: from,
                to: to,
                deviceId: device,
                eventType: type.flatMap(AttestationEventType.init(rawValue:))
            )
            let response: PaginatedEventsResponse
            do {
                response = try await client.events(query)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.analyticsRead)
            }

            if options.json {
                Output.line(try JSONOutput.string(response))
            } else {
                Output.line(ConsoleAnalyticsFormat.events(response))
            }
        }
    }

    // MARK: - risk

    struct RiskCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "risk",
            abstract: "Risk distribution, critical-risk devices, and recent suspicious activity."
        )

        @OptionGroup var options: GlobalOptions

        @Option(name: [.customLong("period"), .customLong("range")], help: "Window: 1d, 7d, 30d, or 90d. Default 7d. (--range is retained as an alias.)")
        var range: Range?

        func run() async throws {
            try await run(client: ConsoleSupport.makeAnalyticsClient())
        }

        func run(client: AnalyticsClient) async throws {
            let report: RiskAssessmentReport
            do {
                report = try await client.risk(range?.wire)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.analyticsRead)
            }

            if options.json {
                Output.line(try JSONOutput.string(report))
            } else {
                Output.line(ConsoleAnalyticsFormat.risk(report))
            }
        }
    }

    // MARK: - compliance

    struct ComplianceCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "compliance",
            abstract: "Compliance rate, violation counts, and the devices that are out of compliance."
        )

        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Reporting period label: 1d, 7d, 30d, or 90d. Default 30d.")
        var period: Range?

        @Flag(name: .long, help: "List every device, not just the non-compliant ones.")
        var all = false

        func run() async throws {
            try await run(client: ConsoleSupport.makeAnalyticsClient())
        }

        func run(client: AnalyticsClient) async throws {
            let report: ComplianceReport
            do {
                report = try await client.compliance(period?.wire)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.analyticsRead)
            }

            if options.json {
                Output.line(try JSONOutput.string(report))
            } else {
                Output.line(ConsoleAnalyticsFormat.compliance(report, showAll: all))
            }
        }
    }

    // MARK: - export

    struct ExportCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "export",
            abstract: "Export devices or events as CSV, to stdout or a file.",
            discussion: """
                The export is always CSV (up to 10,000 rows). Without --out the CSV \
                is written to stdout, so `grantiva console analytics export --data events > events.csv` \
                works. --json reports what was written and requires --out.
                """
        )

        enum Dataset: String, ExpressibleByArgument, CaseIterable {
            case devices, events

            var wire: AnalyticsExportData { AnalyticsExportData(rawValue: rawValue)! }
        }

        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Which dataset: devices or events.")
        var data: Dataset

        @Option(name: .long, help: "Window for the events export: 1d, 7d, 30d, or 90d. Default 30d. Ignored for devices.")
        var period: Range?

        @Option(name: .long, help: "Write the CSV to this path instead of stdout.")
        var out: String?

        func validate() throws {
            if options.json, out == nil {
                throw ValidationError("--json needs --out: the export itself is CSV, and --json reports where it went.")
            }
        }

        func run() async throws {
            try await run(client: ConsoleSupport.makeAnalyticsClient())
        }

        func run(client: AnalyticsClient) async throws {
            let csv: Data
            do {
                csv = try await client.export(data.wire, period?.wire)
            } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.analyticsExport)
            }

            // Header row plus data rows; the server always includes the header.
            let rows = max(csv.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true).count - 1, 0)

            guard let out else {
                Output.write(csv)
                return
            }

            let url = URL(fileURLWithPath: out)
            try csv.write(to: url)

            if options.json {
                Output.line(try JSONOutput.string(ExportReceipt(data: data.rawValue, path: url.path, bytes: csv.count, rows: rows)))
            } else {
                options.note("Wrote \(rows) \(data.rawValue) rows (\(csv.count) bytes) to \(url.path)")
            }
        }

        struct ExportReceipt: Encodable {
            let data: String
            let path: String
            let bytes: Int
            let rows: Int
        }
    }
}
