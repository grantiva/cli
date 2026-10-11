import ArgumentParser
import GrantivaCore

@available(macOS 15, *)
public struct GrantivaCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "grantiva",
        abstract: "The Grantiva CLI for iOS and Android developers.",
        version: grantivaVersion,
        subcommands: [
            BuildCommand.self,
            RunCommand.self,
            RecordCommand.self,
            SimulatorCommand.self,
            EmulatorCommand.self,
            HierarchyCommand.self,
            CICommand.self,
            DiffCommand.self,
            AuthCommand.self,
            ConsoleCommand.self,
            DoctorCommand.self,
            RunnerCommand.self,
            InitCommand.self,
            MCPCommand.self,
        ]
    )

    public init() {}

    /// `console releases update` took the new version as `--version
    /// <version>`, which shadowed the `--version` flag every command
    /// inherits. The option is now `--release-version`; this keeps the old
    /// spelling working where it carries a value (`--version 2.2.0`,
    /// `--version=2.2.0`), and leaves a bare `--version` to print the CLI
    /// version.
    public static func normalizedArguments(_ arguments: [String]) -> [String] {
        guard arguments.count > 3, Array(arguments.prefix(3)) == ["console", "releases", "update"] else { return arguments }
        var result = arguments
        var index = 3
        while index < result.count {
            let argument = result[index]
            if argument == "--" { break }
            if argument.hasPrefix("--version=") {
                result[index] = "--release-version=" + argument.dropFirst("--version=".count)
            } else if argument == "--version", index + 1 < result.count, !result[index + 1].hasPrefix("-") {
                result[index] = "--release-version"
                index += 1
            }
            index += 1
        }
        return result
    }
}
