import ArgumentParser
import GrantivaCore

struct SimulatorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "simulator", abstract: "Provision and remove exact, named simulators.", subcommands: [Ensure.self, Delete.self])

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
}

private struct DeleteResult: Codable { let name: String; let udid: String; let deleted: Bool }
