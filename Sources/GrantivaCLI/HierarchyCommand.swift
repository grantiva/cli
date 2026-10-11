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

    // `.unconditional`: `--timeout -1` is rejected by range in validate(),
    // not reported as a missing value.
    @Option(name: .long, parsing: .unconditional, help: "Seconds to wait for GrantivaAgent's (iOS) or UIAutomator2's (Android) page-source response. Default: 60.")
    var timeout: Double = 60

    @Option(name: .long, help: "Output format: xml (default) or json. --json is the same as --format json.")
    var format: OutputFormat?

    /// `--json` selects JSON, as it does on every command that offers it.
    var outputFormat: OutputFormat {
        options.json ? .json : (format ?? .xml)
    }

    var devicePlatform = InjectedDevicePlatform()

    enum OutputFormat: String, CaseIterable, ExpressibleByArgument {
        case xml
        case json
    }

    func validate() throws {
        guard timeout > 0 else {
            throw ValidationError("--timeout must be greater than zero")
        }
        if let udid { _ = try usageCheck { try DeviceID.validate(udid) } }
        if options.json, format == .xml {
            throw ValidationError("--json and --format xml conflict; pass one.")
        }
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
        // An Android runner publishes port 0; without the owner sidecar there
        // is neither a device to forward to nor a port to read from.
        if session.port <= 0 {
            throw GrantivaError.invalidArgument(
                "The keep-alive session (pid \(session.pid)) records no device and no port. Pass --udid <serial> for an Android session, or use `grantiva runner dump-hierarchy`."
            )
        }

        // The runner's `sessionId` is its own keep-alive identifier, not a
        // WebDriverAgent session, so the session-scoped route 404s. The bare
        // /source route serves the current application's tree. JSON is built
        // from the XML, exactly as `runner dump-hierarchy --format json` does.
        let path = "/source"

        guard let url = URL(string: "http://127.0.0.1:\(session.port)\(path)") else {
            throw GrantivaError.invalidArgument("Failed to build GrantivaAgent URL")
        }

        let request = URLRequest(url: url, timeoutInterval: timeout)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw Self.agentError(error, port: session.port, timeout: timeout)
        }

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

        Output.line(try Self.renderIOSSource(data, format: outputFormat))
    }

    /// The agent's `/source` response as printed. WDA wraps the source in
    /// `{"value": …, "sessionId": …}`; the envelope is never printed. XML is
    /// the unwrapped XML; JSON is the element tree (`type`, `label`, …,
    /// `children`) that `runner dump-hierarchy --format json` and the MCP
    /// `grantiva_a11y_tree` tool print, parsed from that XML (or, when the
    /// agent already answered with a JSON tree, that tree).
    static func renderIOSSource(_ data: Data, format: OutputFormat) throws -> String {
        let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let value = envelope?["value"]
        switch format {
        case .xml:
            if let xml = value as? String { return xml }
            return String(decoding: data, as: UTF8.self)
        case .json:
            let tree: Any
            if let xml = value as? String {
                tree = try WDAHierarchyXMLParser(xml: xml).parse()
            } else if let object = value as? [String: Any] {
                tree = object
            } else if let xml = String(data: data, encoding: .utf8), xml.hasPrefix("<") {
                tree = try WDAHierarchyXMLParser(xml: xml).parse()
            } else {
                throw GrantivaError.commandFailed("GrantivaAgent returned a page source that is neither XML nor a JSON tree.", 1)
            }
            let json = try JSONSerialization.data(withJSONObject: tree, options: [.prettyPrinted, .sortedKeys])
            return String(decoding: json, as: UTF8.self)
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
            switch outputFormat {
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

    /// Turns URLSession's NSError dumps into one line naming the port and
    /// what to check. Anything else passes through unchanged.
    static func agentError(_ error: Error, port: Int, timeout: Double) -> Error {
        guard let urlError = error as? URLError else { return error }
        switch urlError.code {
        case .timedOut:
            let seconds = timeout == timeout.rounded() ? String(Int(timeout)) : String(timeout)
            return GrantivaError.unavailable(
                "GrantivaAgent on port \(port) did not answer within \(seconds)s (--timeout). Is the run still alive?"
            )
        case .cannotConnectToHost, .networkConnectionLost, .cannotFindHost:
            return GrantivaError.unavailable(
                "Cannot reach GrantivaAgent on port \(port). Is the grantiva run --keep-alive session still alive?"
            )
        default:
            return error
        }
    }

    /// Resolves the keep-alive session to query. `store` is injectable for tests.
    func locateSession(store: KeepAliveSessionStore = KeepAliveSessionStore()) throws -> KeepAliveSession {
        try store.locate(udid: udid.map { try DeviceID.validate($0) })
    }

}

