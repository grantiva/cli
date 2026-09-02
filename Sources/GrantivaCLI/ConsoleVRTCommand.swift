import ArgumentParser
import Foundation
import GrantivaAPI
import GrantivaCore

// MARK: - console vrt

@available(macOS 15, *)
struct ConsoleVRTCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vrt",
        abstract: "Review visual regression runs: approve, reject, and accept or flag individual screens.",
        discussion: """
            `grantiva ci run` creates and completes a run. These commands close the loop from a \
            pipeline: review the screens that changed, then approve (promoting accepted captures to \
            baselines) or reject.
            """,
        subcommands: [
            RunsCommand.self,
            ApproveCommand.self,
            RejectCommand.self,
            ScreenCommand.self,
        ]
    )

    static func runNotFound(_ project: String, _ run: String) -> String { "run not found: \(run) in project \(project)" }

    // MARK: - runs list / get

    struct RunsCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "runs",
            abstract: "List or inspect runs.",
            subcommands: [ListCommand.self, GetCommand.self]
        )

        struct ListCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "list", abstract: "List a project's runs, newest first.")

            @OptionGroup var options: GlobalOptions

            @Argument(help: "Project slug.")
            var project: String

            func run() async throws { try await run(client: ConsoleSupport.makeVRTReviewClient()) }

            func run(client: VRTReviewClient) async throws {
                let runs: [RunListItem]
                do { runs = try await client.listRuns(project) } catch {
                    throw ConsoleSupport.map(error, scope: ConsoleScope.vrtRead, notFound: "project not found: \(project)")
                }
                if options.json {
                    Output.line(try JSONOutput.string(runs))
                } else {
                    Output.line(ConsoleVRTFormat.runsTable(runs))
                }
            }
        }

        struct GetCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "get", abstract: "Show a run with every screen's result and review state.")

            @OptionGroup var options: GlobalOptions

            @Argument(help: "Project slug.")
            var project: String

            @Argument(help: "Run ID.")
            var run: String

            func run() async throws { try await run(client: ConsoleSupport.makeVRTReviewClient()) }

            func run(client: VRTReviewClient) async throws {
                let detail: RunDetailResponse
                do { detail = try await client.getRun(project, run) } catch {
                    throw ConsoleSupport.map(error, scope: ConsoleScope.vrtRead, notFound: ConsoleVRTCommand.runNotFound(project, run))
                }
                if options.json {
                    Output.line(try JSONOutput.string(detail))
                } else {
                    Output.line(ConsoleVRTFormat.runDetail(detail))
                }
            }
        }
    }

    // MARK: - approve

    struct ApproveCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "approve",
            abstract: "Approve a run: accepted screens become the branch baselines.",
            discussion: """
                Every failed or new screen must have been accepted or flagged first, unless \
                --accept-all is given, which accepts all of them. Flagged screens keep the old baseline.
                """
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Project slug.")
        var project: String

        @Argument(help: "Run ID.")
        var run: String

        @Flag(name: .customLong("accept-all"), help: "Accept every screen still awaiting review, then approve.")
        var acceptAll = false

        func run() async throws { try await run(client: ConsoleSupport.makeVRTReviewClient()) }

        func run(client: VRTReviewClient) async throws {
            let detail: RunDetailResponse
            do {
                detail = try await client.approveRun(project, run, ApproveRunRequest(acceptUnreviewed: acceptAll ? true : nil))
            } catch {
                throw ConsoleVRTCommand.mapReview(error, notFound: ConsoleVRTCommand.runNotFound(project, run))
            }
            if options.json {
                Output.line(try JSONOutput.string(detail))
            } else {
                let promoted = detail.screens.filter { $0.status == "approved" }.map(\.screenName)
                options.note("Run \(run) approved" + (promoted.isEmpty ? "" : "; new baselines: \(promoted.joined(separator: ", "))"))
                Output.line(ConsoleVRTFormat.runDetail(detail))
            }
        }
    }

    // MARK: - reject

    struct RejectCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "reject", abstract: "Reject a run. Baselines are untouched.")

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Project slug.")
        var project: String

        @Argument(help: "Run ID.")
        var run: String

        func run() async throws { try await run(client: ConsoleSupport.makeVRTReviewClient()) }

        func run(client: VRTReviewClient) async throws {
            let detail: RunDetailResponse
            do { detail = try await client.rejectRun(project, run) } catch {
                throw ConsoleVRTCommand.mapReview(error, notFound: ConsoleVRTCommand.runNotFound(project, run))
            }
            if options.json {
                Output.line(try JSONOutput.string(detail))
            } else {
                Output.line("Run \(run) rejected")
            }
        }
    }

    // MARK: - screen accept / flag / reset

    struct ScreenCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "screen",
            abstract: "Review one screen of a run.",
            subcommands: [AcceptCommand.self, FlagCommand.self, ResetCommand.self]
        )

        struct AcceptCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "accept", abstract: "Accept a screen's new capture; it becomes the baseline on approval.")
            @OptionGroup var options: GlobalOptions
            @Argument(help: "Project slug.") var project: String
            @Argument(help: "Run ID.") var run: String
            @Argument(help: "Screen name(s).") var screens: [String]
            func run() async throws { try await run(client: ConsoleSupport.makeVRTReviewClient()) }
            func run(client: VRTReviewClient) async throws {
                try await ConsoleVRTCommand.review(.accept, project: project, run: run, screens: screens, options: options, client: client)
            }
        }

        struct FlagCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "flag", abstract: "Flag a screen as a real regression; the old baseline is kept.")
            @OptionGroup var options: GlobalOptions
            @Argument(help: "Project slug.") var project: String
            @Argument(help: "Run ID.") var run: String
            @Argument(help: "Screen name(s).") var screens: [String]
            func run() async throws { try await run(client: ConsoleSupport.makeVRTReviewClient()) }
            func run(client: VRTReviewClient) async throws {
                try await ConsoleVRTCommand.review(.flag, project: project, run: run, screens: screens, options: options, client: client)
            }
        }

        struct ResetCommand: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "reset", abstract: "Clear a screen's review decision.")
            @OptionGroup var options: GlobalOptions
            @Argument(help: "Project slug.") var project: String
            @Argument(help: "Run ID.") var run: String
            @Argument(help: "Screen name(s).") var screens: [String]
            func run() async throws { try await run(client: ConsoleSupport.makeVRTReviewClient()) }
            func run(client: VRTReviewClient) async throws {
                try await ConsoleVRTCommand.review(.reset, project: project, run: run, screens: screens, options: options, client: client)
            }
        }
    }

    static func review(
        _ action: ScreenReviewAction,
        project: String,
        run: String,
        screens: [String],
        options: GlobalOptions,
        client: VRTReviewClient
    ) async throws {
        guard !screens.isEmpty else { throw GrantivaError.invalidArgument("name at least one screen") }
        var results: [RunScreenResultResponse] = []
        for screen in screens {
            do {
                results.append(try await client.reviewScreen(project, run, screen, action))
            } catch {
                throw mapReview(error, notFound: "screen not found: \(screen) in run \(run)")
            }
        }
        if options.json {
            Output.line(try JSONOutput.string(results))
        } else {
            Output.line(ConsoleVRTFormat.screensTable(results))
        }
    }

    /// Review errors: a 409 carries the server's state explanation
    /// ("Cannot approve a run with status: rejected"); a 400 is the approval gate.
    static func mapReview(_ error: Error, notFound: String) -> Error {
        if case GrantivaError.networkError(let body, let status) = error, status == 409 || status == 400 {
            let message = ConsoleSupport.errorMessage(fromBody: body) ?? (status == 409 ? "run is not in a reviewable state" : "bad request")
            return GrantivaError.invalidArgument(message)
        }
        return ConsoleSupport.map(error, scope: ConsoleScope.vrtWrite, notFound: notFound)
    }
}

// MARK: - Formatting

enum ConsoleVRTFormat {
    static func runsTable(_ runs: [RunListItem]) -> String {
        guard !runs.isEmpty else { return "No runs found." }
        let rows = runs.map { run in
            [
                run.id,
                run.branch,
                run.status,
                "\(run.passedCount)/\(run.screenCount)",
                String(run.failedCount),
                String(run.newCount),
                run.commitSha.map { String($0.prefix(8)) } ?? "-",
                run.createdAt.map(ConsoleFormat.shortDate) ?? "-",
            ]
        }
        return ConsoleFormat.table(headers: ["RUN", "BRANCH", "STATUS", "PASSED", "FAILED", "NEW", "COMMIT", "CREATED"], rows: rows)
    }

    static func runDetail(_ detail: RunDetailResponse) -> String {
        let run = detail.run
        var lines: [String] = []
        lines.append("Run \(run.id) — \(run.branch) — \(run.status)")
        lines.append("  Screens: \(run.screenCount)   Passed: \(run.passedCount)   Failed: \(run.failedCount)   New: \(run.newCount)")
        if let pending = detail.pendingReviewCount {
            lines.append("  Awaiting review: \(pending)")
        }
        if let commit = run.commitSha { lines.append("  Commit:  \(commit)") }
        if let created = run.createdAt { lines.append("  Created: \(ConsoleFormat.shortDate(created))") }
        lines.append("")
        lines.append(screensTable(detail.screens))
        return lines.joined(separator: "\n")
    }

    static func screensTable(_ screens: [RunScreenResultResponse]) -> String {
        guard !screens.isEmpty else { return "No screens." }
        let rows = screens.map { screen in
            [
                screen.screenName,
                screen.status,
                screen.reviewStatus ?? (needsReview(screen) ? "pending" : ""),
                screen.pixelDiffPercent.map { String(format: "%.2f%%", $0) } ?? "-",
                screen.message ?? "",
            ]
        }
        return ConsoleFormat.table(headers: ["SCREEN", "RESULT", "REVIEW", "PIXEL DIFF", "MESSAGE"], rows: rows)
    }

    static func needsReview(_ screen: RunScreenResultResponse) -> Bool {
        ["failed", "new", "new_screen"].contains(screen.status)
    }
}
