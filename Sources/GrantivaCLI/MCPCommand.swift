import ArgumentParser
import Foundation
import GrantivaMCP

@available(macOS 15, *)
struct MCPCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Start the Grantiva MCP server for AI agent integration.",
        discussion: """
            The server starts without a runner session or a config file. Device tools \
            (grantiva_tap, grantiva_swipe, grantiva_type, grantiva_screenshot, grantiva_a11y_*, \
            grantiva_script) need a runner session and return an error until one exists; they \
            pick it up on the next call. The session is the project's .grantiva/session.json \
            (grantiva runner start), or a grantiva run --keep-alive or runner start session \
            started from the same project directory for the same platform. Sessions from other \
            projects or the other platform are never used. Simulator, emulator, build, context, \
            and VRT tools work without a session.
            """
    )

    @Option(name: .long, help: "Project directory (default: the current directory). Its grantiva.yml or grantiva-android.yml and runner session are used when present.")
    var projectDir: String?

    @OptionGroup var platformOptions: PlatformOptions

    func run() async throws {
        let directory = projectDir.map { URL(fileURLWithPath: $0) }
        try await GrantivaMCPServer(projectDirectory: directory, platform: platformOptions.platform).run()
    }
}
