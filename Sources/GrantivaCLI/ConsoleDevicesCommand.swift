import ArgumentParser
import Foundation
import GrantivaAPI
import GrantivaCore

// MARK: - console devices

@available(macOS 15, *)
struct ConsoleDevicesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "devices",
        abstract: "Attested devices: list, filter, and inspect by key ID.",
        subcommands: [
            ListCommand.self,
            GetCommand.self,
        ]
    )

    static func notFound(_ keyId: String) -> String { "device not found: \(keyId)" }

    // MARK: - list

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List devices, most recently attested first.",
            discussion: "Risk bands: low 0–20, medium 21–50, high 51–75, critical 76–100."
        )

        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Page number, starting at 1.")
        var page: Int?

        @Option(name: .long, help: "Devices per page, 1–100. Default 20.")
        var per: Int?

        @Option(name: .customLong("risk-min"), help: "Only devices with risk score at or above this (0–100).")
        var riskMin: Int?

        @Option(name: .customLong("risk-max"), help: "Only devices with risk score at or below this (0–100).")
        var riskMax: Int?

        @Flag(name: .long, inversion: .prefixedNo, help: "Only jailbroken devices, or only clean ones with --no-jailbroken.")
        var jailbroken: Bool?

        @Option(name: .long, help: "Only devices attesting under this app (UUID or bundle ID).")
        var app: String?

        @Option(name: .long, help: "Match key ID, model, OS version, or country (case-insensitive).")
        var search: String?

        func validate() throws {
            if let page, page < 1 { throw ValidationError("--page must be at least 1.") }
            if let per, !(1...100).contains(per) { throw ValidationError("--per must be between 1 and 100.") }
            for (name, value) in [("--risk-min", riskMin), ("--risk-max", riskMax)] {
                if let value, !(0...100).contains(value) { throw ValidationError("\(name) must be between 0 and 100.") }
            }
            if let riskMin, let riskMax, riskMin > riskMax { throw ValidationError("--risk-min must not exceed --risk-max.") }
        }

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            var appId = app
            if let app, UUID(uuidString: app) == nil {
                // The API filters by app UUID; resolve a bundle id first.
                do { appId = try await client.getApp(app).id } catch {
                    throw ConsoleSupport.map(error, scope: ConsoleScope.appsRead, notFound: ConsoleAppsCommand.notFound(app))
                }
            }
            let query = OrgDeviceQuery(page: page, per: per, riskMin: riskMin, riskMax: riskMax, jailbroken: jailbroken, appId: appId, search: search)
            let list: OrgDeviceList
            do { list = try await client.listDevices(query) } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.devicesRead) }
            if options.json {
                Output.line(try JSONOutput.string(list))
            } else {
                Output.line(ConsoleOrgFormat.devicesList(list))
            }
        }
    }

    // MARK: - get

    struct GetCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "get",
            abstract: "Show a device's profile and its recent attestation events."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "The device's App Attest key ID.")
        var keyId: String

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            let detail: OrgDeviceDetail
            do { detail = try await client.getDevice(keyId) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.devicesRead, notFound: ConsoleDevicesCommand.notFound(keyId))
            }
            if options.json {
                Output.line(try JSONOutput.string(detail))
            } else {
                Output.line(ConsoleOrgFormat.deviceDetail(detail))
            }
        }
    }
}
