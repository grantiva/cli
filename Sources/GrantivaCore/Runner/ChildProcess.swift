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

    private let stateLock = NSLock()
    private var exitStatus: Int32?

    private init(pid: pid_t) {
        self.pid = pid
    }

    /// Spawns `executable` in a new process group.
    ///
    /// - Parameters:
    ///   - stdout/stderr: descriptors the child should write to. They are
    ///     dup2'd into the child; ownership stays with the caller.
    public static func spawn(
        executable: String,
        arguments: [String],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil,
        stdin: Int32? = nil,
        stdout: Int32,
        stderr: Int32
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
        posix_spawnattr_setpgroup(&attributes, 0)

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
        return ChildProcess(pid: pid)
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
        exitStatus = status
        stateLock.unlock()
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

    /// Escalating shutdown: SIGINT (so the runner can release WebDriverAgent
    /// cleanly), then SIGTERM, then SIGKILL, to the entire process group.
    public func terminateGroup(gracePeriod: TimeInterval = 5) {
        Self.terminateGroup(processGroup, gracePeriod: gracePeriod)
    }

    public static func terminateGroup(_ pgid: pid_t, gracePeriod: TimeInterval = 5) {
        guard pgid > 1, pgid != getpgrp() else { return }
        kill(-pgid, SIGINT)
        let deadline = Date().addingTimeInterval(gracePeriod)
        while Date() < deadline {
            if kill(-pgid, 0) != 0 { return }
            usleep(100_000)
        }
        kill(-pgid, SIGTERM)
        let hardDeadline = Date().addingTimeInterval(min(gracePeriod, 2))
        while Date() < hardDeadline {
            if kill(-pgid, 0) != 0 { return }
            usleep(100_000)
        }
        kill(-pgid, SIGKILL)
    }
}
