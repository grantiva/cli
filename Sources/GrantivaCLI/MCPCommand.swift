import ArgumentParser
import Foundation
import GrantivaMCP

@available(macOS 15, *)
struct MCPCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Start the Grantiva MCP server for AI agent integration."
    )

    @Option(name: .long, help: "Project directory containing grantiva.yml and .grantiva/session.json.")
    var projectDir: String?

    func run() async throws {
        let directory = projectDir.map { URL(fileURLWithPath: $0) }
        try await GrantivaMCPServer(projectDirectory: directory).run()
    }
}
