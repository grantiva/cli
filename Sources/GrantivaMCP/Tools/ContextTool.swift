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
        description: "Get current project context: config, booted simulator or running emulator, Xcode or Android SDK, and runner session status.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
        ]),
        annotations: .init(readOnlyHint: true, openWorldHint: false)
    )

    // MARK: - Handler

    static func context(
        config: GrantivaConfig?,
        platform: Platform,
        device: any DevicePlatform,
        simManager: SimulatorManager
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
            if let booted = try? await simManager.bootedDevice() {
                sections.append("[Simulator]\n  name: \(booted.name)\n  udid: \(booted.udid)\n  runtime: \(booted.runtime)\n  state: \(booted.state)")
            } else {
                sections.append("[Simulator]\n  No simulator booted.")
            }
            if let version = try? await shell("xcodebuild -version") {
                sections.append("[Xcode]\n  \(version.replacingOccurrences(of: "\n", with: "\n  "))")
            }
        case .android:
            if let booted = try? await device.defaultDevice() {
                sections.append("[Emulator]\n  name: \(booted.name)\n  serial: \(booted.udid)")
            } else {
                sections.append("[Emulator]\n  No emulator running.")
            }
            if let sdk = AndroidSDK.locate() {
                sections.append("[Android SDK]\n  \(sdk.root)")
            } else {
                sections.append("[Android SDK]\n  \(AndroidSDK.missingMessage)")
            }
        }

        if let session = try? RunnerSessionInfo.load(), session.isAlive {
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
}
