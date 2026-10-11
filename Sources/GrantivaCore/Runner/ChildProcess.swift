import Darwin
import Foundation

/// A child process spawned into its **own process group**.
///
/// `Foundation.Process` gives a child the parent's process group, so a signal
/// aimed at the group hits grantiva itself, and grantiva cannot signal the
/// child's descendants (WebDriverAgent's `xcodebuild test-without-building`,
/// `simctl diagnose`) as a unit. The runner spawns those itself and does not
/// always reap them, which is how a cancelled `--keep-alive` run strands
/// processes that keep owning the simulator.
///
/// `ChildProcess` spawns with `POSIX_SPAWN_SETPGROUP` so the child becomes the
/// leader of a fresh group. Every descendant inherits that group unless it
/// deliberately leaves, so `kill(-pgid, …)` reaps the whole tree in one call.
///
/// `POSIX_SPAWN_CLOEXEC_DEFAULT` matches Foundation's own behaviour: only the
/// descriptors named in the file actions are handed to the child, so no lock or
/// lease descriptor can leak into it and outlive this process.
public final class ChildProcess: @unchecked Sendable {
    public let pid: pid_t
    /// The child is spawned as its own process-group leader, so the group id
    /// equals the child's pid.
    public var processGroup: pid_t { pid }

    /// What was spawned, for the `--verbose` exit line.
    let executable: String
    let arguments: [String]
    let logged: Bool

    private let stateLock = NSLock()
    private var exitStatus: Int32?

    private init(pid: pid_t, executable: String, arguments: [String], logged: Bool) {
        self.pid = pid
        self.executable = executable
        self.arguments = arguments
        self.logged = logged
    }

    /// Spawns `executable` in a new process group.
    ///
    /// - Parameters:
    ///   - stdout/stderr: descriptors the child should write to. They are
    ///     dup2'd into the child; ownership stays with the caller.
    ///   - processGroup: 0 (the default) makes the child the leader of a new
    ///     group; a group id joins that existing group instead.
    public static func spawn(
        executable: String,
        arguments: [String],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil,
        stdin: Int32? = nil,
        stdout: Int32,
        stderr: Int32,
        processGroup: pid_t = 0,
        logged: Bool = true
    ) throws -> ChildProcess {
        var attributes: posix_spawnattr_t?
        guard posix_spawnattr_init(&attributes) == 0 else {
            throw GrantivaError.commandFailed("Could not initialize spawn attributes for \(executable)", 1)
        }
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(
            &attributes,
            Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT)
        )
        // 0 == "make the child the leader of a new group whose id is its pid".
        posix_spawnattr_setpgroup(&attributes, processGroup)

        var actions: posix_spawn_file_actions_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else {
            throw GrantivaError.commandFailed("Could not initialize spawn file actions for \(executable)", 1)
        }
        defer { posix_spawn_file_actions_destroy(&actions) }

        var devNull: Int32 = -1
        if let stdin {
            posix_spawn_file_actions_adddup2(&actions, stdin, 0)
        } else {
            devNull = Darwin.open("/dev/null", O_RDONLY | O_CLOEXEC)
            if devNull >= 0 {
                posix_spawn_file_actions_adddup2(&actions, devNull, 0)
            }
        }
        defer { if devNull >= 0 { Darwin.close(devNull) } }
        posix_spawn_file_actions_adddup2(&actions, stdout, 1)
        posix_spawn_file_actions_adddup2(&actions, stderr, 2)
        if let workingDirectory {
            posix_spawn_file_actions_addchdir_np(&actions, workingDirectory)
        }

        let argv = [executable] + arguments
        var cArgv: [UnsafeMutablePointer<CChar>?] = argv.map { strdup($0) }
        cArgv.append(nil)
        defer { for pointer in cArgv where pointer != nil { free(pointer) } }

        let mergedEnvironment = environment.map { overrides in
            ProcessInfo.processInfo.environment.merging(overrides) { _, new in new }
        }
        var cEnv: [UnsafeMutablePointer<CChar>?]?
        if let mergedEnvironment {
            var built: [UnsafeMutablePointer<CChar>?] = mergedEnvironment
                .map { strdup("\($0.key)=\($0.value)") }
            built.append(nil)
            cEnv = built
        }
        defer {
            if let cEnv {
                for pointer in cEnv where pointer != nil { free(pointer) }
            }
        }

        var pid: pid_t = 0
        let result: Int32
        if var cEnv {
            result = posix_spawn(&pid, executable, &actions, &attributes, &cArgv, &cEnv)
        } else {
            result = posix_spawn(&pid, executable, &actions, &attributes, &cArgv, environ)
        }
        guard result == 0 else {
            throw GrantivaError.commandFailed(
                "Could not spawn \(executable): \(String(cString: strerror(result)))",
                1
            )
        }
        if logged { SubprocessLog.started(executable: executable, arguments: arguments) }
        return ChildProcess(pid: pid, executable: executable, arguments: arguments, logged: logged)
    }

    /// True while the child itself has not been reaped.
    public var isRunning: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard exitStatus == nil else { return false }
        return kill(pid, 0) == 0 || errno == EPERM
    }

    /// Blocks until the child exits and returns a Foundation-compatible
    /// termination status: the exit code, or the signal number when the child
    /// was killed by a signal.
    @discardableResult
    public func wait() -> Int32 {
        stateLock.lock()
        if let exitStatus {
            stateLock.unlock()
            return exitStatus
        }
        stateLock.unlock()

        var raw: Int32 = 0
        while waitpid(pid, &raw, 0) < 0 {
            if errno == EINTR { continue }
            break
        }
        let status = Self.terminationStatus(raw: raw)
        stateLock.lock()
        let first = exitStatus == nil
        exitStatus = status
        stateLock.unlock()
        if first, logged {
            SubprocessLog.ended(
                executable: executable, arguments: arguments,
                status: status, signal: raw & 0x7f == 0 ? nil : raw & 0x7f
            )
        }
        return status
    }

    static func terminationStatus(raw: Int32) -> Int32 {
        if raw & 0x7f == 0 { return (raw >> 8) & 0xff } // exited normally
        return raw & 0x7f // killed by signal
    }

    /// Sends `signal` to the child's whole process group.
    public func signalGroup(_ signal: Int32) {
        Self.signalGroup(processGroup, signal)
    }

    static func signalGroup(_ pgid: pid_t, _ signal: Int32) {
        guard pgid > 1, pgid != getpgrp() else { return }
        kill(-pgid, signal)
    }

    /// How an escalating shutdown ended.
    public enum GroupTermination: Equatable, Sendable {
        /// Nothing in the group was running.
        case alreadyGone
        /// The group exited after SIGINT.
        case interrupted
        /// The group ignored SIGINT and exited after SIGTERM.
        case terminated
        /// The group ignored SIGINT and SIGTERM and was sent SIGKILL.
        case killed
    }

    /// Escalating shutdown: SIGINT (so the runner can release WebDriverAgent
    /// cleanly), then SIGTERM, then SIGKILL, to the entire process group.
    @discardableResult
    public func terminateGroup(gracePeriod: TimeInterval = 5) -> GroupTermination {
        Self.terminateGroup(processGroup, gracePeriod: gracePeriod)
    }

    @discardableResult
    public static func terminateGroup(_ pgid: pid_t, gracePeriod: TimeInterval = 5) -> GroupTermination {
        guard pgid > 1, pgid != getpgrp() else { return .alreadyGone }
        guard kill(-pgid, SIGINT) == 0 else { return .alreadyGone }
        let deadline = Date().addingTimeInterval(gracePeriod)
        while Date() < deadline {
            if kill(-pgid, 0) != 0 { return .interrupted }
            usleep(100_000)
        }
        kill(-pgid, SIGTERM)
        let hardDeadline = Date().addingTimeInterval(min(gracePeriod, 2))
        while Date() < hardDeadline {
            if kill(-pgid, 0) != 0 { return .terminated }
            usleep(100_000)
        }
        kill(-pgid, SIGKILL)
        return .killed
    }

    // MARK: - Lifetime bound to grantiva's (K79)

    /// The watchdog `bindLifetimeToParent` starts. It joins the runner's
    /// process group and blocks reading a pipe whose only write end grantiva
    /// holds. The kernel closes that end when grantiva exits for any reason,
    /// `kill -9` included; the watchdog then interrupts the group, waits up to
    /// ten seconds for the runner to release WebDriverAgent, and terminates
    /// whatever is left. Being a member of the group, it keeps the group id
    /// from being reused while it waits, and a SIGINT or SIGTERM grantiva
    /// itself sends to the group ends it at once.
    static let watchdogScript = """
    trap 'exit 0' INT TERM HUP
    read _ignored
    trap '' INT
    kill -INT -"$1" 2>/dev/null
    trap 'exit 0' INT
    i=0
    while kill -0 "$1" 2>/dev/null && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i+1)); done
    trap '' TERM
    kill -TERM -"$1" 2>/dev/null
    """

    /// Ties the child's process group to this process: when this process
    /// dies, however it dies, the group is interrupted. Returns the write end
    /// of the watchdog's pipe (kept open for the life of this process; tests
    /// close it to simulate that death), or nil when the watchdog could not be
    /// started, in which case the child simply is not bound.
    @discardableResult
    public func bindLifetimeToParent() -> Int32? {
        var fds: [Int32] = [-1, -1]
        guard pipe(&fds) == 0 else { return nil }
        _ = fcntl(fds[0], F_SETFD, FD_CLOEXEC)
        _ = fcntl(fds[1], F_SETFD, FD_CLOEXEC)
        let devNull = Darwin.open("/dev/null", O_WRONLY | O_CLOEXEC)
        defer {
            Darwin.close(fds[0])
            if devNull >= 0 { Darwin.close(devNull) }
        }
        let output = devNull >= 0 ? devNull : fds[0]
        do {
            let watchdog = try Self.spawn(
                executable: "/bin/sh",
                arguments: ["-c", Self.watchdogScript, "grantiva-watchdog", String(processGroup)],
                stdin: fds[0], stdout: output, stderr: output,
                processGroup: processGroup, logged: false
            )
            // Reap it whenever it ends so it never lingers as a zombie.
            DispatchQueue.global(qos: .utility).async { watchdog.wait() }
            return fds[1]
        } catch {
            Darwin.close(fds[1])
            return nil
        }
    }
}
