import ArgumentParser
import Foundation
import GrantivaCore

struct SimulatorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "simulator",
        abstract: "Provision, inspect, and tear down managed simulators.",
        subcommands: [Ensure.self, Delete.self, Sessions.self, Teardown.self, Cleanup.self]
    )

    struct Ensure: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create or reuse a named simulator and boot it. `--name` alone reuses an existing simulator with that name. To create one, the name must contain a device model (\"iPhone 17\") or --device-type must be given; the newest installed runtime is used unless --runtime is passed."
        )
        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Simulator name. An existing simulator with this name is reused as-is. When creating, the device type is read from the name if --device-type is omitted, so `--name \"iPhone 17\"` works on its own.")
        var name: String

        @Option(name: .long, help: "Device type name (\"iPhone 17 Pro\") or identifier. Defaults to the device model named in --name. Checked against an existing simulator only when given.")
        var deviceType: String?

        @Option(name: .long, help: "Runtime name, version, identifier, or `latest`. Defaults to the newest installed iOS runtime when creating. Checked against an existing simulator only when given.")
        var runtime: String?

        @Flag(inversion: .prefixedNo, help: "Boot the simulator and wait for it to be ready. On by default; --no-boot creates it without booting.")
        var boot = true

        func run() async throws {
            let result = try await SimulatorManager.live.ensure(
                name: name, deviceType: deviceType, runtime: runtime, boot: boot
            )
            if options.json {
                Output.line(try JSONOutput.string(result))
                return
            }
            let rendered = Self.render(result)
            // The context line is a diagnostic: it goes to the log, which
            // writes stderr. The UDID is the result, and goes to stdout.
            GrantivaLog.logger.info("\(rendered.stderr)")
            Output.line(rendered.stdout)
        }

        /// stdout is the UDID and nothing else, so it can be captured directly:
        ///
        ///     udid=$(grantiva simulator ensure --name "iPhone 17")
        ///
        /// That substitution is the whole reason this command exists — it
        /// replaces a `simctl list -j` + `create` + `bootstatus` shell
        /// function whose output was a UDID. A prose line on stdout would have
        /// been captured verbatim, so callers got "Created iPhone 17 (…) —
        /// Booted" where they expected an identifier, and the failure surfaced
        /// later as an unusable --device argument.
        ///
        /// The human-readable context still exists; it is logged, and the log
        /// writes stderr, where a terminal shows it and a command substitution
        /// ignores it. It carries no trailing newline because the log handler
        /// terminates its own lines.
        static func render(_ result: SimulatorProvisionResult) -> (stdout: String, stderr: String) {
            let verb = result.created ? "Created" : "Reused"
            return (
                stdout: result.udid,
                stderr: "\(verb) \(result.name) (\(result.udid)) — \(result.state)"
            )
        }
    }

    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Explicitly delete a named simulator.")
        @OptionGroup var options: GlobalOptions
        @Option(name: .long, help: "Name of the simulator to delete.")
        var name: String
        func run() async throws {
            let device = try await SimulatorManager.live.delete(name: name)
            let result = DeleteResult(name: device.name, udid: device.udid, deleted: true)
            if options.json { Output.line(try JSONOutput.string(result)) } else { Output.line("Deleted \(device.name) (\(device.udid))") }
        }
    }

    struct Sessions: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List Grantiva-managed simulator capacity slots.")
        @OptionGroup var options: GlobalOptions

        func run() async throws {
            let sessions = try await SimulatorManager.live.managedSessions()
            if options.json {
                Output.line(try JSONOutput.string(sessions))
            } else if sessions.isEmpty {
                Output.line("No Grantiva-managed simulator sessions.")
            } else {
                Output.line("Grantiva-managed simulator sessions (\(sessions.count)/\(SimulatorCapacity.live.maximum)):")
                for session in sessions {
                    Output.line("  \(session.name) (\(session.udid)) — \(session.sessionId) [\(session.state.rawValue)]")
                }
            }
        }
    }

    struct Teardown: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "End a managed session, or reclaim one simulator by UDID when no ledger entry exists.",
            discussion: "A runner session on a torn-down simulator (`grantiva runner start` or `grantiva run --keep-alive`) is stopped first and its session files are removed; --json reports it as runnerSessionStopped. The WebDriverAgent xcodebuild and simctl diagnose the stopped run left writing into the simulator's runner home are then ended (reapedProcesses in --json) before that home is removed. Without --force, a process still holding a simulator the teardown deletes or shuts down that it did not start (a runner, WebDriverAgent's xcodebuild, a simctl diagnose, a grantiva run) is not killed: a warning on stderr names its pid and command, --json lists it in leftoverProcesses, and the teardown goes on. --force reclaims such processes."
        )
        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Ticket/session identifier to shut down and release.")
        var sessionId: String?

        @Option(name: .long, help: "Simulator UDID to reclaim. Use with --force when a run was killed and left processes owning the device.")
        var udid: String?

        @Flag(name: .long, help: "Reclaim by live process inspection instead of the session ledger: kills the grantiva-runner, WebDriverAgent xcodebuild, and simctl diagnose processes holding the simulator, breaks the lease, and reconciles the session registry. Without it, such processes are only named (a stderr warning and leftoverProcesses in --json).")
        var force = false

        func validate() throws {
            switch (sessionId, udid) {
            case (nil, nil):
                throw ValidationError("Pass --session-id <id> or --udid <UDID>.")
            case (.some, .some):
                throw ValidationError(ExclusiveFlags.message("--session-id", "--udid"))
            default:
                break
            }
            // `--udid "$UDID"` with UDID unset arrives here as "", which is
            // non-nil and so satisfied the check above, then matched no
            // process, released no lease, and exited 0 — reporting a
            // reclaimed device to a script that had named none.
            try usageCheck {
                if let udid { _ = try SimulatorUDID.validate(udid) }
                if let sessionId { _ = try SimulatorUDID.validateSessionID(sessionId) }
            }
        }

        /// The validated targets. `validate()` has already rejected blank and
        /// malformed values by the time these are read.
        private var target: String? { udid?.trimmingCharacters(in: .whitespacesAndNewlines) }
        private var session: String? { sessionId?.trimmingCharacters(in: .whitespacesAndNewlines) }

        func run() async throws {
            // Runner sessions on the devices go first (K15): the runner gets
            // to release WebDriverAgent before its simulator disappears.
            let managed = (try? await SimulatorManager.live.managedSessions()) ?? []
            let udids = Self.runnerStopTargets(udid: target, sessionId: session, force: force, managed: managed)
            let stopped = await Self.stopRunnerSessions(udids: udids) { await DeviceRunnerSessions.live.stop(udid: $0) }
            if !options.json { stopped.lines.forEach(Output.line) }

            if force {
                try await runForce(
                    reaped: stopped.reaped, stopped: stopped.stopped,
                    sessionFilesRemoved: stopped.sessionFilesRemoved
                )
                return
            }

            // What still holds the devices now is not this teardown's to
            // kill (L04): name it rather than proceed silently.
            let devices = Self.leftoverCheckTargets(udid: target, sessionId: session, managed: managed)
            let leftovers = Self.leftoverProcesses(
                udids: devices, psOutput: (try? await SimulatorReaper.processSnapshot()) ?? "", excludingPID: getpid()
            )
            for line in Self.leftoverWarnings(leftovers) {
                FileHandle.standardError.write(Data("Warning: \(line)\n".utf8))
            }

            if let target {
                let result = try await SimulatorManager.live.teardown(udid: target)
                try report(outcomes: Self.marking(result, stopped: stopped.stopped, leftovers: leftovers, reaped: stopped.reaped), subject: target)
                return
            }
            let outcomes = try await SimulatorManager.live.teardown(sessionId: session ?? "")
            try report(outcomes: Self.marking(outcomes, stopped: stopped.stopped, leftovers: leftovers, reaped: stopped.reaped), subject: session ?? "")
        }

        /// The devices a non-force teardown checks for leftover processes:
        /// those it deletes or shuts down. A `--udid` with no ledger record
        /// deletes nothing, so there is nothing to warn about.
        static func leftoverCheckTargets(udid: String?, sessionId: String?, managed: [ManagedSimulatorSession]) -> [String] {
            runnerStopTargets(udid: udid, sessionId: sessionId, force: false, managed: managed)
        }

        /// Processes holding each of `udids` (the reaper's rules: a runner,
        /// WebDriverAgent's xcodebuild, `simctl diagnose`, a grantiva run).
        static func leftoverProcesses(udids: [String], psOutput: String, excludingPID: Int32 = 0) -> [String: [ReapedProcess]] {
            var found: [String: [ReapedProcess]] = [:]
            for udid in udids {
                let processes = SimulatorReaper.processes(owning: udid, psOutput: psOutput, excludingPID: excludingPID)
                if !processes.isEmpty { found[udid] = processes }
            }
            return found
        }

        /// One line per leftover process, naming its pid and command.
        static func leftoverWarnings(_ leftovers: [String: [ReapedProcess]]) -> [String] {
            leftovers.keys.sorted().flatMap { udid in
                (leftovers[udid] ?? []).map { process in
                    "\(udid) is still held by \(process.kind.rawValue) pid \(process.pid), which this teardown did not start: \(process.command). "
                        + "Stop it, or reclaim the simulator with `grantiva simulator teardown --udid \(udid) --force`."
                }
            }
        }

        /// The devices whose runner sessions teardown stops: only those it
        /// will act on. A `--udid` without `--force` and without a ledger
        /// record is a no-op teardown, so it stops nothing either.
        static func runnerStopTargets(
            udid: String?, sessionId: String?, force: Bool, managed: [ManagedSimulatorSession]
        ) -> [String] {
            if let udid {
                return force || managed.contains(where: { $0.udid == udid }) ? [udid] : []
            }
            return managed.filter { $0.sessionId == sessionId }.map(\.udid)
        }

        /// Stops the runner sessions on each of `udids`; returns the devices
        /// that had one, a line per stopped session and per helper it ended,
        /// and the helpers (`simctl diagnose`, …) ended per device (L63),
        /// keyed by the uppercased UDID so a `--udid` in any case matches.
        static func stopRunnerSessions(
            udids: [String],
            sessionFiles: (String) -> [String] = { KeepAliveSessionStore().sessionFilePaths(udid: $0) },
            stop: (String) async -> [RunnerSessionStopper.Outcome]
        ) async -> (
            stopped: [String], lines: [String], reaped: [String: [ReapedProcess]],
            sessionFilesRemoved: [String: [String]]
        ) {
            var stopped: [String] = []
            var lines: [String] = []
            var reaped: [String: [ReapedProcess]] = [:]
            var sessionFilesRemoved: [String: [String]] = [:]
            for udid in udids {
                let before = sessionFiles(udid)
                let outcomes = await stop(udid)
                if !outcomes.isEmpty { stopped.append(udid) }
                lines += outcomes.map(DeviceRunnerSessions.render)
                let helpers = outcomes.flatMap(\.reaped)
                lines += RunnerStopCommand.reapedLines(helpers, udid: udid)
                if !helpers.isEmpty { reaped[udid.uppercased(), default: []] += helpers }
                let removed = before.filter { !FileManager.default.fileExists(atPath: $0) }
                if !removed.isEmpty { sessionFilesRemoved[udid.uppercased()] = removed }
            }
            return (stopped, lines, reaped, sessionFilesRemoved)
        }

        static func marking(
            _ outcomes: [SimulatorTeardownOutcome], stopped: [String], leftovers: [String: [ReapedProcess]] = [:],
            reaped: [String: [ReapedProcess]] = [:]
        ) -> [SimulatorTeardownOutcome] {
            outcomes.map { outcome in
                var outcome = outcome
                outcome.runnerSessionStopped = stopped.contains(outcome.udid)
                outcome.leftoverProcesses = leftovers[outcome.udid] ?? []
                outcome.reapedProcesses = reaped[outcome.udid.uppercased()] ?? []
                return outcome
            }
        }

        /// `reaped`: the helpers the runner-session stop already ended per
        /// device, listed in each result's `reapedProcesses` (L63).
        private func runForce(
            reaped: [String: [ReapedProcess]] = [:], stopped: [String] = [],
            sessionFilesRemoved: [String: [String]] = [:]
        ) async throws {
            var udids: [String] = []
            if let target {
                udids = [target]
            } else if let sessionId = session {
                udids = try await SimulatorManager.live.managedSessions()
                    .filter { $0.sessionId == sessionId }
                    .map(\.udid)
                guard !udids.isEmpty else {
                    throw GrantivaError.invalidArgument(
                        "No Grantiva-managed simulators for session \(sessionId). Pass --udid <UDID> to reclaim a specific simulator."
                    )
                }
            }

            var results: [ForceTeardownResult] = []
            for target in udids {
                results.append(try await SimulatorReaper.forceTeardown(udid: target))
            }
            results = Self.addingReaped(
                reaped, to: results, stopped: stopped, sessionFilesRemoved: sessionFilesRemoved
            )

            let output = try Self.forceOutput(results, json: options.json)
            output.lines.forEach(Output.line)
            if let error = output.error { throw error }
        }

        /// `results` with the helpers the runner-session stop ended on each
        /// device; a device that had some counts as reclaimed.
        static func addingReaped(
            _ reaped: [String: [ReapedProcess]], to results: [ForceTeardownResult], stopped: [String] = [],
            sessionFilesRemoved: [String: [String]] = [:]
        ) -> [ForceTeardownResult] {
            results.map { result in
                var result = result
                result.runnerSessionStopped = stopped.contains { $0.caseInsensitiveCompare(result.udid) == .orderedSame }
                result.reapedProcesses = reaped[result.udid.uppercased()] ?? []
                result.sessionFilesRemoved = Array(Set(
                    result.sessionFilesRemoved + (sessionFilesRemoved[result.udid.uppercased()] ?? [])
                )).sorted()
                if result.runnerSessionStopped || !result.reapedProcesses.isEmpty { result.reclaimed = true }
                return result
            }
        }

        /// What `--force` prints for `results`, and the error it then exits
        /// with when a runner home was left behind (in JSON mode too).
        static func forceOutput(_ results: [ForceTeardownResult], json: Bool) throws -> (lines: [String], error: GrantivaError?) {
            let error = deviceHomeError(results.flatMap(\.deviceHomeFailures))
            if json { return ([try JSONOutput.string(results)], error) }
            var lines: [String] = []
            for result in results {
                if result.processes.isEmpty {
                    lines.append("No processes were holding \(result.udid).")
                } else {
                    for process in result.processes {
                        lines.append("Killed \(process.kind.rawValue) pid \(process.pid) holding \(result.udid).")
                    }
                }
                if result.leaseReleased {
                    lines.append("Released the simulator lease for \(result.udid).")
                }
                if result.capacityRecordsCleared > 0 {
                    lines.append("Cleared \(result.capacityRecordsCleared) session record(s) for \(result.udid).")
                }
                for kept in result.capacityRecordsKept {
                    lines.append("Kept the session record for \(kept.udid) under \(kept.sessionId): \(kept.reason).")
                }
                if !result.sessionFilesRemoved.isEmpty {
                    lines.append("Removed \(result.sessionFilesRemoved.count) stale keep-alive session file(s) of runners that are no longer running.")
                }
                for home in result.deviceHomesRemoved {
                    lines.append("Removed the runner home \(home).")
                }
                for directory in result.temporaryDirectoriesRemoved {
                    lines.append("Removed the killed run's temp directory \(directory).")
                }
            }
            return (lines, error)
        }

        /// The error a teardown ends with when it released the simulator but
        /// left runner homes behind, or nil when every home was removed.
        static func deviceHomeError(_ failures: [String]) -> GrantivaError? {
            guard !failures.isEmpty else { return nil }
            return GrantivaError.unavailable(
                "The simulator was released, but its runner home could not be removed: "
                    + failures.map(WDADeviceHome.withoutTrailingPeriod).joined(separator: "; ") + ". Delete it by hand."
            )
        }

        private func report(outcomes: [SimulatorTeardownOutcome], subject: String) throws {
            if options.json {
                Output.line(try JSONOutput.string(outcomes))
            } else if outcomes.isEmpty {
                Output.line(
                    "No active Grantiva-managed simulators for \(subject). "
                        + "If a simulator is still owned, reclaim it with `grantiva simulator teardown --udid <UDID> --force`."
                )
            } else {
                for outcome in outcomes {
                    guard let session = outcome.session else {
                        // No Grantiva session held the device; only its runner homes went.
                        Output.line("No Grantiva session held \(outcome.udid); the simulator was left as it is.")
                        for home in outcome.deviceHomesRemoved {
                            Output.line("Removed the runner home \(home).")
                        }
                        continue
                    }
                    let action = outcome.deleted ? "Deleted Grantiva-created" : "Shut down"
                    Output.line("\(action) \(session.name) (\(session.udid)) and released session \(session.sessionId).")
                }
            }
            if let error = Self.deviceHomeError(outcomes.flatMap(\.deviceHomeFailures)) { throw error }
        }
    }

    struct Cleanup: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete Grantiva-created simulators that are shut down and not part of an active session."
        )
        @OptionGroup var options: GlobalOptions

        func run() async throws {
            let removed = try await SimulatorManager.live.cleanup()
            if options.json {
                Output.line(try JSONOutput.string(removed))
            } else if removed.isEmpty {
                Output.line("No orphaned Grantiva-created simulators to delete.")
            } else {
                for record in removed {
                    Output.line("Deleted \(record.name) (\(record.udid)).")
                }
            }
        }
    }
}

private struct DeleteResult: Codable { let name: String; let udid: String; let deleted: Bool }
