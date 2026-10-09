import ArgumentParser
import Foundation
import GrantivaCore

struct EmulatorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "emulator",
        abstract: "Provision, inspect, and tear down Android emulators.",
        subcommands: [Ensure.self, Delete.self, Sessions.self, Teardown.self]
    )

    struct Ensure: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create the AVD when missing (installing its system image first) and boot it. stdout is the serial, or the AVD name with --no-boot."
        )
        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "AVD name. Defaults to emulator in grantiva-android.yml.")
        var name: String?

        @Option(name: .long, help: "System image package for a new AVD, e.g. \"system-images;android-35;google_apis;arm64-v8a\". Defaults to system_image in grantiva-android.yml, then that value.")
        var systemImage: String?

        @Flag(inversion: .prefixedNo, help: "Boot the emulator and wait for it to be ready. On by default; --no-boot creates it without booting.")
        var boot = true

        @Flag(name: .long, help: "Boot without a window.")
        var headless = false

        static func resolveName(flag: String?, config: GrantivaConfig?) throws -> String {
            guard let name = flag ?? config?.android?.emulator, !name.isEmpty else {
                throw GrantivaError.invalidArgument("No AVD named. Pass --name or set emulator in grantiva-android.yml.")
            }
            return name
        }

        /// stdout is the identifier a script captures:
        ///
        ///     serial=$(grantiva emulator ensure --name Pixel_8_API_35)
        ///
        /// The prose goes to the log (stderr), as `simulator ensure` does.
        static func render(_ result: EmulatorProvisionResult) -> (stdout: String, stderr: String) {
            let verb = result.created ? "Created" : "Reused"
            let serial = result.serial.map { " (\($0))" } ?? ""
            return (stdout: result.serial ?? result.name, stderr: "\(verb) \(result.name)\(serial) — \(result.state)")
        }

        func run() async throws {
            let config = try GrantivaConfig.loadIfPresent(platform: .android)
            let avd = try Self.resolveName(flag: name, config: config)
            let platform = try AndroidPlatform.live(options: .init(headless: headless))
            let result = try await platform.emulators.ensure(avd: avd, systemImage: systemImage ?? config?.android?.systemImage, boot: boot)
            if options.json {
                Output.line(try JSONOutput.string(result))
                return
            }
            let rendered = Self.render(result)
            GrantivaLog.logger.info("\(rendered.stderr)")
            Output.line(rendered.stdout)
        }
    }

    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Delete an AVD Grantiva created. Others need --force. A running AVD is never deleted.")
        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "AVD name to delete.")
        var name: String

        @Flag(name: .long, help: "Delete an AVD Grantiva did not create.")
        var force = false

        func run() async throws {
            let platform = try AndroidPlatform.live()
            try await platform.emulators.deleteAVD(name: name, force: force)
            if options.json {
                let data = try JSONSerialization.data(withJSONObject: ["name": name, "deleted": true], options: [.sortedKeys])
                Output.line(String(decoding: data, as: UTF8.self))
            } else {
                Output.line("Deleted AVD \(name)")
            }
        }
    }

    struct Sessions: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List the emulators Grantiva started.")
        @OptionGroup var options: GlobalOptions

        static func render(_ sessions: [EmulatorSessionRecord]) -> [String] {
            guard !sessions.isEmpty else { return ["No emulators started by Grantiva are running."] }
            return ["Grantiva-started emulators (\(sessions.count)):"] + sessions.map {
                "  \($0.serial) (\($0.avd)) — pid \($0.pid) \($0.processAlive ? "running" : "exited"), adb: \($0.adbState)"
            }
        }

        func run() async throws {
            let sessions = try await AndroidPlatform.live().emulators.sessions()
            if options.json {
                Output.line(try JSONOutput.string(sessions))
            } else {
                Self.render(sessions).forEach(Output.line)
            }
        }
    }

    struct Teardown: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Kill emulators Grantiva started: one by serial, or all of them. Stops the UIAutomator2 server and removes the serial's adb forwards first.")
        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Emulator serial to kill, e.g. emulator-5554.")
        var serial: String?

        @Flag(name: .long, help: "Kill every emulator Grantiva started.")
        var all = false

        @Flag(name: .long, help: "Kill the serial even though Grantiva did not start it.")
        var force = false

        func validate() throws {
            switch (serial, all) {
            case (nil, false):
                throw ValidationError("Pass --serial <serial> or --all.")
            case (.some, true):
                throw ValidationError("--serial and --all are mutually exclusive; pass one.")
            default:
                break
            }
            if let serial {
                do {
                    let trimmed = try DeviceID.validate(serial, flag: "--serial")
                    guard DeviceID.isAndroidSerial(trimmed) else {
                        throw GrantivaError.invalidArgument("--serial \(trimmed) is a simulator UDID, not an emulator serial. Use `grantiva simulator teardown` for simulators.")
                    }
                } catch let error as GrantivaError {
                    throw ValidationError(error.errorDescription ?? String(describing: error))
                }
            }
        }

        func run() async throws {
            let emulators = try AndroidPlatform.live().emulators
            let outcomes: [EmulatorTeardownOutcome]
            if let serial {
                outcomes = [try await emulators.teardown(serial: serial.trimmingCharacters(in: .whitespacesAndNewlines), force: force)]
            } else {
                outcomes = try await emulators.teardownAll()
            }
            if options.json {
                Output.line(try JSONOutput.string(outcomes))
            } else if outcomes.isEmpty {
                Output.line("No emulators started by Grantiva are running.")
            } else {
                for outcome in outcomes {
                    let name = outcome.avd.map { " (\($0))" } ?? ""
                    Output.line(outcome.killed ? "Killed \(outcome.serial)\(name)." : "\(outcome.serial)\(name) was already gone; dropped its record.")
                }
            }
        }
    }
}
