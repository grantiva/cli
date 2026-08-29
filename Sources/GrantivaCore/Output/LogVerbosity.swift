import Logging

/// Resolves the diagnostic verbosity from the command line.
///
/// `LoggingSystem.bootstrap` has to run before any command is parsed — and
/// before any log line can be emitted — so the level is read straight off the
/// argument vector rather than out of a parsed `GlobalOptions`. `--verbose` and
/// `--quiet` mean the same thing for every subcommand, so there is nothing
/// per-command to consult. `VerbosityOptions` still declares both flags: that is
/// what puts them in `--help` and makes them parse.
///
/// Neither flag touches stdout. `--quiet` silences narration, not results —
/// `grantiva doctor --json --quiet | jq` is still valid JSON.
public enum LogVerbosity {
    /// `--verbose` wins when both are given: asking for detail and asking for
    /// silence at once is most plausibly a script that passes `--quiet` by
    /// default and a human adding `--verbose` to see what happened.
    public static func level(for arguments: [String]) -> Logger.Level {
        if arguments.contains("--verbose") { return .debug }
        if arguments.contains("--quiet") { return .warning }
        return .info
    }
}
