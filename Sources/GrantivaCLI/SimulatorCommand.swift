import ArgumentParser
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
            if options.json { print(try JSONOutput.string(result)) }
            else { print("\(result.created ? "Created" : "Reused") \(result.name) (\(result.udid)) — \(result.state)") }
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
        }

        func run() async throws {
            if force {
                try await runForce()
                return
            }
            if let udid {
                let result = try await SimulatorManager.live.teardown(udid: udid)
                try report(outcomes: result, subject: udid)
                return
            }
            let outcomes = try await SimulatorManager.live.teardown(sessionId: sessionId ?? "")
            try report(outcomes: outcomes, subject: sessionId ?? "")
        }

        private func runForce() async throws {
            var udids: [String] = []
            if let udid {
                udids = [udid]
            } else if let sessionId {
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
