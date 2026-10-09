import ArgumentParser
import Foundation
import GrantivaCore

/// Dumps the current UI hierarchy of a simulator via a running GrantivaAgent
/// session. Requires that `grantiva run --keep-alive` is actively holding the
/// session open in another shell, or on CI as a backgrounded process.
struct HierarchyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hierarchy",
        abstract: "Dump the UI hierarchy of a booted simulator or emulator without relaunching the app.",
        discussion: """
        Finds the session published by `grantiva run --keep-alive` (in \
        /tmp/grantiva-sessions, with the simulator UDID or adb serial recorded by \
        grantiva) and reads the current page source: from GrantivaAgent on iOS, from \
        the UIAutomator2 server on Android. The target \
        app is never touched — no launch, no stopApp, no clearState.

        Typical agent workflow:

            # Terminal 1 (or backgrounded in CI):
            grantiva run --keep-alive --flow flows/onboarding.yaml

            # Terminal 2:
            grantiva hierarchy > state.xml

        If no keep-alive session is running, this command fails with a clear \
        message rather than trying to start one (which would relaunch the app \
        and destroy the state you wanted to inspect).
        """
    )

    @OptionGroup var options: GlobalOptions

    @Option(name: .long, help: "Simulator UDID or adb serial to target (default: newest keep-alive session)")
    var udid: String?

    @Option(name: .long, help: "Seconds to wait for GrantivaAgent's page-source response. Default: 60.")
    var timeout: Double = 60

    @Option(name: .long, help: "Output format: xml or json")
    var format: OutputFormat = .xml

    var devicePlatform = InjectedDevicePlatform()

    enum OutputFormat: String, ExpressibleByArgument {
        case xml
        case json
    }

    func validate() throws {
        guard timeout > 0 else {
            throw ValidationError("--timeout must be greater than zero")
        }
        if let udid { _ = try DeviceID.validate(udid) }
    }

    func run() async throws {
        try await run(store: KeepAliveSessionStore())
    }

    /// `store` is injectable for tests.
    func run(store: KeepAliveSessionStore) async throws {
        let session = try locateSession(store: store)
        if let serial = session.udid, DeviceID.isAndroidSerial(serial) {
            try await runAndroid(serial: serial)
            return
        }

        // The runner's `sessionId` is its own keep-alive identifier, not a
        // WebDriverAgent session, so the session-scoped route 404s. The bare
        // /source route serves the current application's tree.
        let path = format == .json ? "/source?format=json" : "/source"

        guard let url = URL(string: "http://127.0.0.1:\(session.port)\(path)") else {
            throw GrantivaError.invalidArgument("Failed to build GrantivaAgent URL")
        }

        let request = URLRequest(url: url, timeoutInterval: timeout)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GrantivaError.commandFailed("GrantivaAgent returned a non-HTTP response", 1)
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GrantivaError.commandFailed(
                "GrantivaAgent /source failed (HTTP \(http.statusCode)):\n\(body.prefix(500))",
                Int32(http.statusCode)
            )
        }

        // WDA wraps /source in {"value": "<xml>"}. Unwrap for cleanliness.
        if format == .xml, let wrapped = unwrapWDASource(data) {
            Output.line(wrapped)
        } else {
            Output.write(data)
            Output.line("")
        }
    }

    /// The runner's session file carries port 0 for Android (it does not
    /// proxy UIAutomator2), so the serial from the owner sidecar is all that
    /// is needed: the platform forwards a port and finds the held session.
    func runAndroid(serial: String) async throws {
        let device = try devicePlatform.make(.android)
        let attachment = try await device.attachDriver(deviceID: serial, port: nil)
        let text: String
        do {
            switch format {
            case .xml:
                text = try await attachment.client.hierarchyXML()
            case .json:
                let tree = try await attachment.client.hierarchy()
                let data = try JSONSerialization.data(withJSONObject: tree, options: [.prettyPrinted, .sortedKeys])
                text = String(decoding: data, as: UTF8.self)
            }
        } catch {
            await attachment.detach()
            throw error
        }
        await attachment.detach()
        Output.line(text)
    }

    /// Resolves the keep-alive session to query. `store` is injectable for tests.
    func locateSession(store: KeepAliveSessionStore = KeepAliveSessionStore()) throws -> KeepAliveSession {
        try store.locate(udid: udid.map { try DeviceID.validate($0) })
    }

    /// WDA returns `{"value": "<?xml…>", "sessionId": "…"}`. Extract the XML.
    private func unwrapWDASource(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = obj["value"] as? String else {
            return nil
        }
        return value
    }
}

