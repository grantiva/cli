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
    private var exitSignal: Int32?

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
            Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF)
        )
        // The child starts with no signal blocked and SIGINT and SIGTERM at
        // their defaults, whatever this process inherited (a CI runner or a
        // script's `&` can hand grantiva SIGINT blocked or ignored). Without
        // this, the runner and the lifetime watchdog could not be interrupted:
        // a shell cannot even trap a signal that was ignored on entry.
        // SIGHUP, SIGQUIT and SIGPIPE are reset only when they are not ignored
        // here: `nohup grantiva …` ignores SIGHUP so the command survives a
        // closing terminal, and the runner it starts must survive it too (L11).
        var emptyMask = sigset_t()
        sigemptyset(&emptyMask)
        posix_spawnattr_setsigmask(&attributes, &emptyMask)
        var defaults = sigset_t()
        sigemptyset(&defaults)
        for signal in signalsToReset() { sigaddset(&defaults, signal) }
        posix_spawnattr_setsigdefault(&attributes, &defaults)
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

    /// The signals a spawned child gets at their default disposition:
    /// SIGINT and SIGTERM always (`runner stop`, Ctrl-C and the watchdog rely
    /// on them), SIGHUP, SIGQUIT and SIGPIPE only when this process does not
    /// ignore them, so an ignored one is handed on as it is.
    static func signalsToReset(isIgnored: (Int32) -> Bool = isIgnoredInThisProcess) -> [Int32] {
        [SIGINT, SIGTERM] + [SIGHUP, SIGQUIT, SIGPIPE].filter { !isIgnored($0) }
    }

    /// Whether `signalNumber`'s disposition in this process is SIG_IGN.
    static func isIgnoredInThisProcess(_ signalNumber: Int32) -> Bool {
        var action = sigaction()
        guard sigaction(signalNumber, nil, &action) == 0 else { return false }
        // SIG_IGN is the handler value 1.
        return unsafeBitCast(action.__sigaction_u.__sa_handler, to: Int.self) == 1
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
        var result: pid_t
        repeat {
            result = waitpid(pid, &raw, 0)
        } while result < 0 && errno == EINTR
        if result < 0 {
            // ECHILD: reaped by a concurrent `poll()`, which records the
            // status just after its waitpid returns. Wait for that record;
            // never report an exit status nobody saw (it would read as 0).
            let deadline = Date().addingTimeInterval(2)
            repeat {
                stateLock.lock()
                let recorded = exitStatus
                stateLock.unlock()
                if let recorded { return recorded }
                usleep(10_000)
            } while Date() < deadline
            return Self.unknownExitStatus
        }
        return record(raw: raw)
    }

    /// What `wait()` returns when someone else reaped the child and its
    /// status was never recorded: a failure, never 0.
    static let unknownExitStatus: Int32 = 255

    /// The exit status if the child has exited, without blocking; nil while
    /// it runs. A child that has exited is reaped here, and `wait()` then
    /// returns the same status.
    @discardableResult
    public func poll() -> Int32? {
        stateLock.lock()
        if let exitStatus {
            stateLock.unlock()
            return exitStatus
        }
        stateLock.unlock()
        var raw: Int32 = 0
        let result = waitpid(pid, &raw, WNOHANG)
        guard result == pid else {
            if result < 0, errno == ECHILD {
                stateLock.lock()
                defer { stateLock.unlock() }
                return exitStatus
            }
            return nil
        }
        return record(raw: raw)
    }

    /// The signal that killed the child, once it has been reaped by one.
    public var terminatingSignal: Int32? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return exitSignal
    }

    private func record(raw: Int32) -> Int32 {
        let status = Self.terminationStatus(raw: raw)
        let signal: Int32? = raw & 0x7f == 0 ? nil : raw & 0x7f
        stateLock.lock()
        let first = exitStatus == nil
        if first {
            exitStatus = status
            exitSignal = signal
        }
        let recorded = exitStatus ?? status
        stateLock.unlock()
        if first, logged {
            SubprocessLog.ended(executable: executable, arguments: arguments, status: status, signal: signal)
        }
        return recorded
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
    /// `kill -9` included. While it waits, a SIGINT, SIGTERM or SIGHUP (from
    /// grantiva signalling the group, or a closing terminal) ends it at once
    /// without touching the runner: grantiva is alive and in charge then.
    /// Once the pipe closes it ignores those signals and: interrupts the
    /// group, waits up to `$3` tenths of a second (default 100) for the runner
    /// to release WebDriverAgent, then SIGTERMs the group and waits as long
    /// again, then SIGKILLs the runner; it removes the runner's keep-alive
    /// session files from `$2` whichever way the runner went (neither the dead
    /// grantiva nor a killed runner removes them); and finally SIGTERMs
    /// whatever is left in the group. Being a member of the group, it keeps
    /// the group id from being reused while it works.
    static let watchdogScript = """
    trap 'exit 0' INT TERM HUP
    read _ignored
    trap '' INT TERM HUP
    ticks=${3:-100}
    wait_runner() { i=0; while kill -0 "$1" 2>/dev/null && [ "$i" -lt "$ticks" ]; do sleep 0.1; i=$((i+1)); done; }
    kill -INT -"$1" 2>/dev/null
    wait_runner "$1"
    if kill -0 "$1" 2>/dev/null; then kill -TERM -"$1" 2>/dev/null; wait_runner "$1"; fi
    if kill -0 "$1" 2>/dev/null; then kill -KILL "$1" 2>/dev/null; sleep 0.2; fi
    if [ -n "$2" ]; then rm -f "$2/$1".owner.json "$2/$1"-*.grantiva; fi
    kill -TERM -"$1" 2>/dev/null
    exit 0
    """

    /// Ties the child's process group to this process: when this process
    /// dies, however it dies, the group is interrupted (see `watchdogScript`).
    /// Returns the write end of the watchdog's pipe; close it once the child
    /// has been waited for (tests close it early to simulate this process
    /// dying). Nil when the watchdog could not be started, in which case the
    /// child simply is not bound. `graceTicks` (tenths of a second per stage)
    /// is shortened by tests.
    @discardableResult
    public func bindLifetimeToParent(sessionDirectory: String? = nil, graceTicks: Int = 100) -> Int32? {
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
                arguments: ["-c", Self.watchdogScript, "grantiva-watchdog", String(processGroup), sessionDirectory ?? "", String(graceTicks)],
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
