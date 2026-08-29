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
            abstract: "Create or reuse a named simulator and boot it. `--name` alone is enough: the device type is read from the name and the newest installed runtime is used."
        )
        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Simulator name. Also the source of the device type when --device-type is omitted, so `--name \"iPhone 17\"` works on its own.")
        var name: String

        @Option(name: .long, help: "Device type name (\"iPhone 17 Pro\") or identifier. Defaults to the device model named in --name.")
        var deviceType: String?

        @Option(name: .long, help: "Runtime name, version, identifier, or `latest`. Defaults to the newest installed iOS runtime.")
        var runtime: String?

        @Flag(inversion: .prefixedNo, help: "Boot the simulator and wait for it to be ready. On by default; --no-boot creates it without booting.")
        var boot = true

        func run() async throws {
            let result = try await SimulatorManager.live.ensure(
                name: name, deviceType: deviceType, runtime: runtime, boot: boot
            )
            if options.json {
                print(try JSONOutput.string(result))
                return
            }
            let rendered = Self.render(result)
            FileHandle.standardError.write(Data(rendered.stderr.utf8))
            print(rendered.stdout)
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
        /// The human-readable context still exists; it goes to stderr, where a
        /// terminal shows it and a command substitution ignores it.
        static func render(_ result: SimulatorProvisionResult) -> (stdout: String, stderr: String) {
            let verb = result.created ? "Created" : "Reused"
            return (
                stdout: result.udid,
                stderr: "\(verb) \(result.name) (\(result.udid)) — \(result.state)\n"
            )
        }
    }

    struct Delete: AsyncParsableCommand {
        @OptionGroup var options: GlobalOptions
        @Option(name: .long) var name: String
        func run() async throws {
            let device = try await SimulatorManager.live.delete(name: name)
            let result = DeleteResult(name: device.name, udid: device.udid, deleted: true)
            if options.json { print(try JSONOutput.string(result)) } else { print("Deleted \(device.name) (\(device.udid))") }
        }
    }

    struct Sessions: AsyncParsableCommand {
        @OptionGroup var options: GlobalOptions

        func run() async throws {
            let sessions = try await SimulatorManager.live.managedSessions()
            if options.json {
                print(try JSONOutput.string(sessions))
            } else if sessions.isEmpty {
                print("No Grantiva-managed simulator sessions.")
            } else {
                print("Grantiva-managed simulator sessions (\(sessions.count)/\(SimulatorCapacity.live.maximum)):")
                for session in sessions {
                    print("  \(session.name) (\(session.udid)) — \(session.sessionId) [\(session.state.rawValue)]")
                }
            }
        }
    }

    struct Teardown: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "End a managed session, or reclaim one simulator by UDID when no ledger entry exists."
        )
        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Ticket/session identifier to shut down and release.")
        var sessionId: String?

        @Option(name: .long, help: "Simulator UDID to reclaim. Use with --force when a run was killed and left processes owning the device.")
        var udid: String?

        @Flag(name: .long, help: "Reclaim by live process inspection instead of the session ledger: kills the grantiva-runner, WebDriverAgent xcodebuild, and simctl diagnose processes holding the simulator, breaks the lease, and reconciles the session registry.")
        var force = false

        func validate() throws {
            switch (sessionId, udid) {
            case (nil, nil):
                throw ValidationError("Pass --session-id <id> or --udid <UDID>.")
            case (.some, .some):
                throw ValidationError("--session-id and --udid are mutually exclusive; pass one.")
            default:
                break
            }
            // `--udid "$UDID"` with UDID unset arrives here as "", which is
            // non-nil and so satisfied the check above, then matched no
            // process, released no lease, and exited 0 — reporting a
            // reclaimed device to a script that had named none.
            do {
                if let udid { _ = try SimulatorUDID.validate(udid) }
                if let sessionId { _ = try SimulatorUDID.validateSessionID(sessionId) }
            } catch let error as GrantivaError {
                throw ValidationError(error.errorDescription ?? String(describing: error))
            }
        }

        /// The validated targets. `validate()` has already rejected blank and
        /// malformed values by the time these are read.
        private var target: String? { udid?.trimmingCharacters(in: .whitespacesAndNewlines) }
        private var session: String? { sessionId?.trimmingCharacters(in: .whitespacesAndNewlines) }

        func run() async throws {
            if force {
                try await runForce()
                return
            }
            if let target {
                let result = try await SimulatorManager.live.teardown(udid: target)
                try report(outcomes: result, subject: target)
                return
            }
            let outcomes = try await SimulatorManager.live.teardown(sessionId: session ?? "")
            try report(outcomes: outcomes, subject: session ?? "")
        }

        private func runForce() async throws {
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

            if options.json {
                print(try JSONOutput.string(results))
                return
            }
            for result in results {
                if result.processes.isEmpty {
                    print("No processes were holding \(result.udid).")
                } else {
                    for process in result.processes {
                        print("Killed \(process.kind.rawValue) pid \(process.pid) holding \(result.udid).")
                    }
                }
                if result.leaseReleased {
                    print("Released the simulator lease for \(result.udid).")
                }
                if result.capacityRecordsCleared > 0 {
                    print("Cleared \(result.capacityRecordsCleared) session record(s) for \(result.udid).")
                }
            }
        }

        private func report(outcomes: [SimulatorTeardownOutcome], subject: String) throws {
            if options.json {
                print(try JSONOutput.string(outcomes))
            } else if outcomes.isEmpty {
                print(
                    "No active Grantiva-managed simulators for \(subject). "
                        + "If a simulator is still owned, reclaim it with `grantiva simulator teardown --udid <UDID> --force`."
                )
            } else {
                for outcome in outcomes {
                    let session = outcome.session
                    let action = outcome.deleted ? "Deleted Grantiva-created" : "Shut down"
                    print("\(action) \(session.name) (\(session.udid)) and released session \(session.sessionId).")
                }
            }
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
                print(try JSONOutput.string(removed))
            } else if removed.isEmpty {
                print("No orphaned Grantiva-created simulators to delete.")
            } else {
                for record in removed {
                    print("Deleted \(record.name) (\(record.udid)).")
                }
            }
        }
    }
}

private struct DeleteResult: Codable { let name: String; let udid: String; let deleted: Bool }
