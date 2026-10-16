import Darwin
import Foundation
import Logging

/// A running `xcrun simctl bootstatus <udid> -b`.
public protocol BootStatusChild: AnyObject, Sendable {
    /// The pid recorded at spawn; `terminate()` signals this pid (and the
    /// process group it leads) and nothing else.
    var pid: pid_t { get }
    /// The exit status once the child has exited, without blocking; nil while it runs.
    func poll() -> Int32?
    /// What the child printed, for a failure message.
    func output() -> String
    /// Ends the child by its recorded pid and reaps it.
    func terminate()
}

/// The bound on waiting for a simulator to finish booting (IOS-015).
///
/// `simctl bootstatus -b` was seen to never return under load while
/// `simctl list` already showed the device Booted and a fresh `bootstatus`
/// reported it finished: an unbounded wait hung `simulator ensure` (and every
/// command that boots) until something killed it. The wait now gives
/// bootstatus `bootStatusGrace` seconds to finish on its own, then accepts
/// `simctl list` reporting the device Booted as the end of the boot and ends
/// the stuck bootstatus. Past `timeout` with neither, it fails with an error
/// that names the device and the setting to raise.
public struct SimulatorBootWait: Sendable {
    public static let timeoutVariable = "GRANTIVA_SIMULATOR_BOOT_TIMEOUT_SECONDS"
    public static let graceVariable = "GRANTIVA_SIMULATOR_BOOTSTATUS_GRACE_SECONDS"

    /// The overall bound on the wait.
    public let timeout: TimeInterval
    /// How long bootstatus runs before `simctl list` reporting Booted counts as booted.
    public let bootStatusGrace: TimeInterval
    public let pollInterval: TimeInterval

    public init(
        timeout: TimeInterval? = nil,
        bootStatusGrace: TimeInterval? = nil,
        pollInterval: TimeInterval = 1,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.timeout = timeout ?? Self.nonnegativeDouble(environment[Self.timeoutVariable]) ?? 300
        self.bootStatusGrace = bootStatusGrace ?? Self.nonnegativeDouble(environment[Self.graceVariable]) ?? 60
        self.pollInterval = pollInterval
    }

    /// How a wait ended.
    public enum Outcome: Equatable, Sendable {
        /// bootstatus exited 0.
        case bootStatusFinished
        /// bootstatus had not returned, `simctl list` showed the device
        /// Booted, and bootstatus was ended.
        case listedBooted
    }

    /// Waits for `udid` to boot: `start` spawns bootstatus, `isBooted` asks
    /// `simctl list`. The child is always gone when this returns or throws.
    public func wait(
        udid: String,
        start: () throws -> BootStatusChild,
        isBooted: () async throws -> Bool
    ) async throws -> Outcome {
        let child = try start()
        let began = Date()
        while true {
            if let status = child.poll() {
                guard status == 0 else {
                    let output = child.output()
                    throw GrantivaError.commandFailed(
                        output.isEmpty ? "xcrun simctl bootstatus \(udid) -b exited with code \(status)" : output,
                        status
                    )
                }
                return .bootStatusFinished
            }
            let elapsed = Date().timeIntervalSince(began)
            if elapsed >= min(bootStatusGrace, timeout), (try? await isBooted()) == true {
                GrantivaLog.logger.notice(
                    "\(Self.fallbackMessage(udid: udid, pid: child.pid, elapsed: elapsed))"
                )
                child.terminate()
                return .listedBooted
            }
            if elapsed >= timeout {
                child.terminate()
                throw GrantivaError.commandFailed(Self.timeoutMessage(udid: udid, timeout: timeout), 1)
            }
            do {
                try await Task.sleep(for: .seconds(pollInterval))
            } catch {
                child.terminate()
                throw error
            }
        }
    }

    static func fallbackMessage(udid: String, pid: pid_t, elapsed: TimeInterval) -> String {
        "`simctl bootstatus \(udid) -b` has not returned after \(Int(elapsed))s but `simctl list` shows the simulator Booted; "
            + "ending bootstatus (pid \(pid)) and continuing."
    }

    static func timeoutMessage(udid: String, timeout: TimeInterval) -> String {
        "Timed out after \(Int(timeout))s waiting for simulator \(udid) to boot: `simctl bootstatus -b` did not finish "
            + "and `simctl list` never showed it Booted. Raise \(timeoutVariable) to wait longer."
    }

    private static func nonnegativeDouble(_ value: String?) -> Double? {
        guard let value, let parsed = Double(value), parsed >= 0 else { return nil }
        return parsed
    }
}

/// `simctl bootstatus -b` spawned into a process group of its own, its exit
/// observed with a non-blocking `waitpid`, and its output kept in a temporary
/// file. It is registered with `ShellChildren`, so an interrupt ends it.
final class LiveBootStatusChild: BootStatusChild, @unchecked Sendable {
    private let child: ChildProcess
    private let outputPath: String
    private let tracked: UInt64
    private let lock = NSLock()
    private var unregistered = false

    var pid: pid_t { child.pid }

    private init(child: ChildProcess, outputPath: String, tracked: UInt64) {
        self.child = child
        self.outputPath = outputPath
        self.tracked = tracked
    }

    static func start(udid: String) throws -> LiveBootStatusChild {
        try start(executable: "/usr/bin/xcrun", arguments: ["simctl", "bootstatus", udid, "-b"])
    }

    static func start(executable: String, arguments: [String]) throws -> LiveBootStatusChild {
        let outputPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-bootstatus-\(getpid())-\(UUID().uuidString).log").path
        let descriptor = Darwin.open(outputPath, O_CREAT | O_WRONLY | O_TRUNC | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw GrantivaError.commandFailed("Could not create \(outputPath): \(String(cString: strerror(errno)))", 1)
        }
        defer { Darwin.close(descriptor) }
        let child = try ChildProcess.spawn(
            executable: executable, arguments: arguments, stdout: descriptor, stderr: descriptor
        )
        let command = ([executable == "/usr/bin/xcrun" ? "xcrun" : executable] + arguments).joined(separator: " ")
        let tracked = ShellChildren.shared.register(child.pid, command: command)
        return LiveBootStatusChild(child: child, outputPath: outputPath, tracked: tracked)
    }

    func poll() -> Int32? {
        let status = child.poll()
        if status != nil { unregister() }
        return status
    }

    func output() -> String {
        let data = FileManager.default.contents(atPath: outputPath) ?? Data()
        let lines = String(decoding: data, as: UTF8.self)
            .split(separator: "\n").suffix(20).joined(separator: "\n")
        return lines.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// SIGTERM to the recorded pid and the group it leads, SIGKILL after two
    /// seconds if it is still running, then reaped.
    func terminate() {
        defer { unregister() }
        guard child.poll() == nil else { return }
        let pid = child.pid
        func send(_ signal: Int32) {
            if pid > 1, getpgid(pid) == pid, pid != getpgrp() { kill(-pid, signal) }
            kill(pid, signal)
        }
        send(SIGTERM)
        let deadline = Date().addingTimeInterval(2)
        while child.poll() == nil, Date() < deadline { usleep(20_000) }
        if child.poll() == nil {
            send(SIGKILL)
            child.wait()
        }
    }

    private func unregister() {
        let first = lock.withLock { () -> Bool in
            defer { unregistered = true }
            return !unregistered
        }
        if first { ShellChildren.shared.unregister(tracked) }
    }

    deinit {
        try? FileManager.default.removeItem(atPath: outputPath)
    }
}

/// bootstatus run through a `simctl` executor (the test seam's scripted
/// `simctl`): a task stands in for the child, and terminating it cancels the task.
final class ExecutorBootStatusChild: BootStatusChild, @unchecked Sendable {
    private let lock = NSLock()
    private var status: Int32?
    private var failure = ""
    private var task: Task<Void, Never>?

    let pid: pid_t = 0

    init(udid: String, execute: @escaping @Sendable (String) async throws -> String) {
        task = Task { [self] in
            do {
                _ = try await execute("xcrun simctl bootstatus \(udid) -b")
                finish(0, "")
            } catch GrantivaError.commandFailed(let message, let code) {
                finish(code == 0 ? 1 : code, message)
            } catch {
                finish(1, "\(error)")
            }
        }
    }

    private func finish(_ code: Int32, _ message: String) {
        lock.withLock {
            if status == nil {
                status = code
                failure = message
            }
        }
    }

    func poll() -> Int32? { lock.withLock { status } }
    func output() -> String { lock.withLock { failure } }
    func terminate() {
        task?.cancel()
        finish(SIGTERM, "terminated")
    }
}
