import ArgumentParser
import Foundation
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

    /// Runs the command like ArgumentParser's `main`, except that a usage
    /// error prints `usageErrorMessage(for:)`. N3-08: every usage error reads
    /// the same way, an `Error:` line, then `Usage:` and `See '…--help'`.
    /// ArgumentParser alone adds a `Help:` line describing the option to a
    /// missing-argument error, which no other usage error has.
    public static func main(_ arguments: [String]?) async {
        do {
            var command = try parseAsRoot(arguments)
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
        } catch {
            guard exitCode(for: error) == .validationFailure else { exit(withError: error) }
            FileHandle.standardError.write(Data((usageErrorMessage(for: error) + "\n").utf8))
            exit(withError: ExitCode.validationFailure)
        }
    }

    /// The message for a usage error: ArgumentParser's, without the `Help:`
    /// lines it adds only to a missing-argument error.
    public static func usageErrorMessage(for error: Error) -> String {
        fullMessage(for: error)
            .components(separatedBy: "\n")
            .filter { !$0.hasPrefix("Help:") }
            .joined(separator: "\n")
    }

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
