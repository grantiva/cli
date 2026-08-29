import GrantivaCore
import Logging

public enum LoggingBootstrap {
    /// Installs the CLI-shaped log handler and sets the level from the command
    /// line. Must run before anything logs.
    public static func bootstrap(arguments: [String] = CommandLine.arguments) {
        GrantivaLogLevel.current = LogVerbosity.level(for: arguments)
        LoggingSystem.bootstrap { label in CLILogHandler(label: label) }
    }
}
