import ArgumentParser
import GrantivaCore

struct SimulatorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "simulator",
        abstract: "Provision, inspect, and tear down managed simulators.",
        subcommands: [Ensure.self, Delete.self, Sessions.self, Teardown.self]
    )

    struct Ensure: AsyncParsableCommand {
        @OptionGroup var options: GlobalOptions
        @Option(name: .long) var name: String
        @Option(name: .long) var deviceType: String
        @Option(name: .long) var runtime: String
        @Flag(name: .long) var boot = false
        func run() async throws {
            let result = try await SimulatorManager.live.ensure(name: name, deviceType: deviceType, runtime: runtime, boot: boot)
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
        @OptionGroup var options: GlobalOptions
        @Option(name: .long, help: "Ticket/session identifier to shut down and release")
        var sessionId: String

        func run() async throws {
            let sessions = try await SimulatorManager.live.teardown(sessionId: sessionId)
            if options.json {
                print(try JSONOutput.string(sessions))
            } else if sessions.isEmpty {
                print("No active Grantiva-managed simulators for session \(sessionId).")
            } else {
                for session in sessions {
                    print("Shut down \(session.name) (\(session.udid)) and released session \(session.sessionId).")
                }
            }
        }
    }
}

private struct DeleteResult: Codable { let name: String; let udid: String; let deleted: Bool }
