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
    ///
    /// The command path is the first three non-option tokens, so options
    /// before `update` (`console --json releases update`) do not hide it. An
    /// option is a flag only when it is one of `flagNames`; any other option
    /// without `=` takes the next token as its value, which is therefore not
    /// a subcommand name.
    public static func normalizedArguments(_ arguments: [String]) -> [String] {
        let flagNames: Set<String> = ["--json", "--verbose", "--quiet", "-h", "--help", "--version"]
        var path: [String] = []
        var index = 0
        while index < arguments.count, path.count < 3 {
            let argument = arguments[index]
            if argument == "--" { return arguments }
            if argument.hasPrefix("-") {
                if !flagNames.contains(argument), !argument.contains("=") { index += 1 }
            } else {
                path.append(argument)
            }
            index += 1
        }
        guard path == ["console", "releases", "update"] else { return arguments }
        var result = arguments
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
