import Foundation
import GrantivaCore
import MCP

/// Context tool: returns project configuration, the booted simulator or running
/// emulator, the Xcode or Android SDK toolchain, and the runner session.
@available(macOS 15, *)
enum ContextTool {

    // MARK: - Tool Definition

    static let definition = Tool(
        name: "grantiva_context",
        description: "Get current project context: config, the device the UI tools act on (the runner session's simulator or emulator; without a session, the configured one), Xcode or Android SDK, and runner session status.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    // MARK: - Handler

    /// `session` is the session the UI tools would use (nil when none), so
    /// the device section and the session section never disagree.
    static func context(
        config: GrantivaConfig?,
        platform: Platform,
        session: RunnerSessionInfo?,
        listSimulators: @Sendable () async throws -> [SimulatorDevice],
        emulators: EmulatorToolDependencies?
    ) async throws -> CallTool.Result {
        var sections: [String] = []

        if let config {
            var configLines = ["[Config]", "  platform: \(platform.rawValue)"]
            switch platform {
            case .ios:
                if let scheme = config.scheme { configLines.append("  scheme: \(scheme)") }
                if let workspace = config.workspace { configLines.append("  workspace: \(workspace)") }
                if let project = config.project { configLines.append("  project: \(project)") }
                if let simulator = config.simulator { configLines.append("  simulator: \(simulator)") }
                if let bundleId = config.bundleId { configLines.append("  bundle_id: \(bundleId)") }
                if let buildSettings = config.buildSettings, !buildSettings.isEmpty {
                    configLines.append("  build_settings: \(buildSettings.joined(separator: " "))")
                }
            case .android:
                let android = config.android ?? AndroidProject()
                configLines.append("  module: \(android.module)")
                configLines.append("  variant: \(android.variant)")
                if let id = android.applicationId { configLines.append("  application_id: \(id)") }
                if let emulator = android.emulator { configLines.append("  emulator: \(emulator)") }
                if !android.buildArgs.isEmpty { configLines.append("  build_args: \(android.buildArgs.joined(separator: " "))") }
            }
            configLines.append("  screens: \(config.screens.count)")
            sections.append(configLines.joined(separator: "\n"))
        } else {
            sections.append("[Config]\n  No \(platform.configFileName) found in current directory.")
        }

        switch platform {
        case .ios:
            sections.append(await simulatorSection(session: session, configured: config?.simulator, listSimulators: listSimulators))
            if let version = try? await shell("xcodebuild -version") {
                sections.append("[Xcode]\n  \(version.replacingOccurrences(of: "\n", with: "\n  "))")
            }
        case .android:
            sections.append(await emulatorSection(session: session, configured: config?.android?.emulator, emulators: emulators))
            if let sdk = AndroidSDK.locate() {
                sections.append("[Android SDK]\n  \(sdk.root)")
            } else {
                sections.append("[Android SDK]\n  \(AndroidSDK.missingMessage)")
            }
        }

        if let session {
            sections.append("""
                [Runner Session]
                  pid: \(session.pid)
                  \(platform == .ios ? "wda_port" : "driver_port"): \(session.wdaPort)
                  \(platform == .ios ? "bundle_id" : "application_id"): \(session.bundleId)
                  udid: \(session.udid)
                """)
        } else {
            sections.append("[Runner Session]\n  No active session.")
        }

        return CallTool.Result(content: [.text(text: sections.joined(separator: "\n\n"), annotations: nil, _meta: nil)])
    }

    // MARK: - Device sections

    private static func describe(_ device: SimulatorDevice, source: String) -> String {
        "[Simulator]\n  name: \(device.name)\n  udid: \(device.udid)\n  runtime: \(device.runtime)\n  state: \(device.state)\n  source: \(source)"
    }

    /// The session's simulator; else the configured one; else the first
    /// booted simulator, labelled as such.
    static func simulatorSection(
        session: RunnerSessionInfo?,
        configured: String?,
        listSimulators: @Sendable () async throws -> [SimulatorDevice]
    ) async -> String {
        let devices: [SimulatorDevice]
        do {
            devices = try await listSimulators()
        } catch {
            return "[Simulator]\n  Could not list simulators: \(error.localizedDescription)"
        }
        if let session, !session.udid.isEmpty {
            if let device = devices.first(where: { $0.udid == session.udid }) {
                return describe(device, source: "runner session")
            }
            return "[Simulator]\n  udid: \(session.udid)\n  source: runner session (not in `xcrun simctl list devices`)"
        }
        if let configured {
            let matches = devices.filter { $0.udid == configured || $0.name == configured }
            if let booted = matches.first(where: \.isBooted) {
                return describe(booted, source: "simulator in grantiva.yml (no runner session)")
            }
            if matches.isEmpty {
                return "[Simulator]\n  Configured simulator \"\(configured)\" not found. No runner session."
            }
            return "[Simulator]\n  Configured simulator \"\(configured)\" is not booted. No runner session."
        }
        if let booted = devices.first(where: \.isBooted) {
            return describe(booted, source: "first booted simulator (no runner session, no simulator in grantiva.yml)")
        }
        return "[Simulator]\n  No simulator booted."
    }

    /// The session's serial; else the configured AVD's serial if it is
    /// running; else the running serials. A device-listing failure is
    /// reported as such, never as "No emulator running".
    static func emulatorSection(
        session: RunnerSessionInfo?,
        configured: String?,
        emulators: EmulatorToolDependencies?
    ) async -> String {
        guard let emulators else {
            if let session, !session.udid.isEmpty {
                return "[Emulator]\n  serial: \(session.udid)\n  source: runner session"
            }
            return "[Emulator]\n  \(AndroidSDK.missingMessage)"
        }
        func name(_ serial: String) async -> String {
            (try? await emulators.avdName(serial)) ?? serial
        }
        if let session, !session.udid.isEmpty {
            return "[Emulator]\n  name: \(await name(session.udid))\n  serial: \(session.udid)\n  source: runner session"
        }
        let devices: [ADBDevice]
        do {
            devices = try await emulators.listDevices().filter(\.isUsable)
        } catch {
            return "[Emulator]\n  Could not list devices: \(error.localizedDescription)"
        }
        var running: [(serial: String, name: String)] = []
        for device in devices {
            running.append((device.serial, device.isEmulator ? await name(device.serial) : device.serial))
        }
        if let configured, let match = running.first(where: { $0.name == configured || $0.serial == configured }) {
            return "[Emulator]\n  name: \(match.name)\n  serial: \(match.serial)\n  source: emulator in grantiva-android.yml (no runner session)"
        }
        guard !running.isEmpty else {
            return "[Emulator]\n  No emulator running."
        }
        let list = running.map { "  - \($0.serial) (\($0.name))" }.joined(separator: "\n")
        let lead = configured.map { "Configured emulator \"\($0)\" is not running. No runner session. Running:" }
            ?? "No runner session. Running:"
        return "[Emulator]\n  \(lead)\n\(list)"
    }
}
