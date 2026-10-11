import Darwin
import Foundation

/// The `--verbose` lines for subprocesses Grantiva keeps running: the runner,
/// `adb logcat`, `simctl spawn … log stream`, `simctl io … recordVideo`. Same
/// shape as `shell`'s: `$ <command line>` when one starts, and
/// `exit N: <command line>` (or `stopped by SIGINT: <command line>`) when it
/// ends. Values that look like secrets are redacted.
public enum SubprocessLog {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var observers: [UUID: @Sendable (String) -> Void] = [:]

    public static func started(executable: String, arguments: [String]) {
        emit("$ \(commandLine(executable: executable, arguments: arguments))")
    }

    /// `signal` is the signal that ended the process, if one did.
    public static func ended(executable: String, arguments: [String], status: Int32, signal: Int32?) {
        let command = commandLine(executable: executable, arguments: arguments)
        if let signal {
            emit("stopped by \(signalName(signal)): \(command)")
        } else {
            emit("exit \(status): \(command)")
        }
    }

    /// Runs `process` and logs its start.
    public static func run(_ process: Process) throws {
        try process.run()
        emit("$ \(commandLine(of: process))")
    }

    /// Logs how `process` ended. Call once it has exited.
    public static func ended(_ process: Process) {
        let signal = process.terminationReason == .uncaughtSignal ? process.terminationStatus : nil
        ended(
            executable: process.executableURL?.path ?? "", arguments: process.arguments ?? [],
            status: process.terminationStatus, signal: signal
        )
    }

    public static func commandLine(of process: Process) -> String {
        commandLine(executable: process.executableURL?.path ?? "", arguments: process.arguments ?? [])
    }

    public static func commandLine(
        executable: String, arguments: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        let secrets = secretValues(in: environment)
        var words: [String] = []
        var redactNext = false
        for argument in arguments {
            var word = argument
            if redactNext {
                word = redacted
                redactNext = false
            } else if let equals = word.firstIndex(of: "="), isSecretName(String(word[..<equals])) {
                word = String(word[...equals]) + redacted
            } else if isSecretName(word) {
                redactNext = true
            }
            for secret in secrets where word.contains(secret) {
                word = word.replacingOccurrences(of: secret, with: redacted)
            }
            words.append(quoted(word))
        }
        return ([quoted(executable)] + words).joined(separator: " ")
    }

    static let redacted = "<redacted>"

    /// Flags and environment names whose value is a credential.
    static func isSecretName(_ name: String) -> Bool {
        let lowered = name.trimmingCharacters(in: CharacterSet(charactersIn: "-")).lowercased()
        return ["api-key", "api_key", "apikey", "token", "password", "secret"].contains { lowered.hasSuffix($0) }
    }

    static func secretValues(in environment: [String: String]) -> [String] {
        environment
            .filter { isSecretName($0.key) && $0.value.count >= 6 }
            .map(\.value)
    }

    static func quoted(_ word: String) -> String {
        let plain = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_./=:,@+%")
        if !word.isEmpty, word.unicodeScalars.allSatisfy(plain.contains) { return word }
        return shellQuoted(word)
    }

    public static func signalName(_ signal: Int32) -> String {
        switch signal {
        case SIGINT: return "SIGINT"
        case SIGTERM: return "SIGTERM"
        case SIGKILL: return "SIGKILL"
        case SIGHUP: return "SIGHUP"
        case SIGPIPE: return "SIGPIPE"
        default: return "signal \(signal)"
        }
    }

    private static func emit(_ line: String) {
        GrantivaLog.logger.debug("\(line)")
        let current = lock.withLock { Array(observers.values) }
        for observer in current { observer(line) }
    }

    /// Test seam: the lines logged while `body` runs.
    public static func capturing(_ body: () throws -> Void) rethrows -> [String] {
        let id = UUID()
        let collected = Collected()
        lock.withLock { observers[id] = { collected.append($0) } }
        defer { _ = lock.withLock { observers.removeValue(forKey: id) } }
        try body()
        return collected.lines
    }

    private final class Collected: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [String] = []
        func append(_ line: String) { lock.withLock { storage.append(line) } }
        var lines: [String] { lock.withLock { storage } }
    }
}
