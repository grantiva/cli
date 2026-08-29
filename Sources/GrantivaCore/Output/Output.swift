import Foundation

/// Program output: the bytes a command exists to produce.
///
/// This is **not logging, and must never be routed through `GrantivaLog` or any
/// other `Logger`.** A logger writes to stderr through a handler that decorates
/// what it is given — a level, a label, a timestamp — and every one of those
/// decorations destroys the two things callers do with this text:
///
///     udid=$(grantiva simulator ensure --name "iPhone 17")
///     grantiva doctor --json | jq '.[] | select(.status == "fail")'
///
/// A command substitution captures stdout verbatim, and `jq` refuses anything
/// that is not a bare JSON document. Both broke in 1.7.0, when `ensure` put a
/// sentence on stdout where a UDID was expected; the failure surfaced much
/// later, as an unusable `--device` argument.
///
/// The rule that keeps the two apart:
///
/// - **Program output** — a `--json` payload, the `ensure` UDID, a rendered
///   result table, a dumped view hierarchy — is what the command was invoked
///   to produce. It goes here, undecorated, on stdout.
/// - **Diagnostics** — progress narration, warnings, errors, anything a caller
///   would not capture — goes to `GrantivaLog.logger`, which writes to stderr.
///
/// A future refactor that swept "all output" into the logger would reintroduce
/// the 1.7.0 bug across every command at once. `OutputStreamContractTests` pins
/// the contract: no direct standard-library printing anywhere in `Sources/`,
/// and stdout of a `--json` command parses as a single JSON document with
/// nothing else on it.
public enum Output {
    private static let lock = NSLock()

    /// Writes `text` and a newline to stdout, exactly as given.
    public static func line(_ text: String) {
        write(Data((text + "\n").utf8))
    }

    /// Writes raw bytes to stdout, exactly as given.
    public static func write(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        FileHandle.standardOutput.write(data)
    }
}
