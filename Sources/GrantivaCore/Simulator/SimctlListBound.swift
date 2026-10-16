import Darwin
import Foundation
import Logging

/// A running `xcrun simctl list …` whose stdout is the result.
public protocol SimctlListChild: BootStatusChild {
    /// Everything the child wrote to stdout, trimmed.
    func standardOutput() -> String
}

/// The bound on one `simctl list` call on the ensure and boot path.
///
/// `xcrun simctl list devices --json` was seen to stall for 10.6 minutes under
/// load, and `simulator ensure` (which lists the devices several times) waited
/// on it with no deadline. Each list call now runs as a tracked child observed
/// with a non-blocking `waitpid`; one that has not returned within `timeout` is
/// ended by its recorded pid and run once more, and a second stall fails with
/// an error naming the command and the setting to raise.
public struct SimctlListBound: Sendable {
    public static let timeoutVariable = "GRANTIVA_SIMULATOR_LIST_TIMEOUT_SECONDS"
    public static let defaultTimeout: TimeInterval = 120
    /// Runs of a stalled call: the first and one retry.
    public static let attempts = 2

    public let timeout: TimeInterval
    /// The longest pause between polls; the first polls are shorter, so a
    /// list that returns at once is not held back.
    public let pollInterval: TimeInterval

    public init(
        timeout: TimeInterval? = nil,
        pollInterval: TimeInterval = 0.2,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.timeout = timeout ?? Self.positiveDouble(environment[Self.timeoutVariable]) ?? Self.defaultTimeout
        self.pollInterval = pollInterval
    }

    /// Runs `command` (for messages) through `start`, returning its stdout.
    /// The child is always gone when this returns or throws.
    public func run(command: String, start: () throws -> SimctlListChild) async throws -> String {
        for attempt in 1...Self.attempts {
            let child = try start()
            let began = Date()
            var pause = min(0.01, pollInterval)
            while true {
                if let status = child.poll() {
                    guard status == 0 else {
                        let output = child.output()
                        throw GrantivaError.commandFailed(
                            output.isEmpty ? "\(command) exited with code \(status)" : output, status
                        )
                    }
                    return child.standardOutput()
                }
                if Date().timeIntervalSince(began) >= timeout {
                    child.terminate()
                    GrantivaLog.logger.notice(
                        "\(Self.stallMessage(command: command, pid: child.pid, timeout: timeout, retrying: attempt < Self.attempts))"
                    )
                    break
                }
                do {
                    try await Task.sleep(for: .seconds(pause))
                } catch {
                    child.terminate()
                    throw error
                }
                pause = min(pause * 2, pollInterval)
            }
        }
        throw GrantivaError.commandFailed(Self.timeoutMessage(command: command, timeout: timeout), 1)
    }

    static func stallMessage(command: String, pid: pid_t, timeout: TimeInterval, retrying: Bool) -> String {
        "`\(command)` did not return within \(Int(timeout))s; ended it (pid \(pid))"
            + (retrying ? " and running it once more." : ".")
    }

    static func timeoutMessage(command: String, timeout: TimeInterval) -> String {
        "`\(command)` did not return within \(Int(timeout))s, twice: CoreSimulator is not answering. "
            + "Raise \(timeoutVariable) to wait longer."
    }

    private static func positiveDouble(_ value: String?) -> Double? {
        guard let value, let parsed = Double(value), parsed > 0 else { return nil }
        return parsed
    }
}
