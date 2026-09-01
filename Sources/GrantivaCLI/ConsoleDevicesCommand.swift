import ArgumentParser
import Foundation
import GrantivaAPI
import GrantivaCore

// MARK: - console devices

@available(macOS 15, *)
struct ConsoleDevicesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "devices",
        abstract: "Attested devices: profile, compliance, and recent events for a key.",
        discussion: """
            Device listing is not yet available to API keys; use `console analytics risk` \
            and `console analytics compliance` to find key IDs, or export the device CSV \
            with `console analytics export --data devices`.
            """,
        subcommands: [
            GetCommand.self,
        ]
    )

    // MARK: - get

    struct GetCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "get",
            abstract: "Show a device's profile, compliance status, and recent events."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "The device's App Attest key ID.")
        var keyId: String

        func run() async throws {
            try await run(client: ConsoleSupport.makeAnalyticsClient())
        }

        func run(client: AnalyticsClient) async throws {
            let detail: DeviceDetailsResponse
            do {
                detail = try await client.device(keyId)
            } catch {
                throw deviceNotFound(ConsoleSupport.map(error, scope: ConsoleScope.analyticsRead), keyId: keyId)
            }

            if options.json {
                Output.line(try JSONOutput.string(detail))
            } else {
                Output.line(ConsoleAnalyticsFormat.device(detail))
            }
        }
    }
}

/// `ConsoleSupport.map` renders a bare 404 as "not found: …" using the
/// server body; for a device the key ID is the useful thing to echo.
private func deviceNotFound(_ error: Error, keyId: String) -> Error {
    if case GrantivaError.notFound = error {
        return GrantivaError.notFound("device not found: \(keyId)")
    }
    return error
}
