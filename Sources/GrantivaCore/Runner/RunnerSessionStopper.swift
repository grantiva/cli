import Darwin
import Foundation

/// Stops a keep-alive session, whichever command started it (K14, K15).
///
/// - A session a live grantiva process holds (`run --keep-alive`, a
///   foreground `runner start`) is released the way a person would: SIGINT
///   to that grantiva process, which reaps its runner, writes its ready file,
///   releases its lease and removes its session files, then exits.
/// - A `runner start --detach` session, or an orphan whose grantiva process is
///   gone, has no one to ask: the runner's process group is terminated and
///   its session files, forwards (Android) and lease are cleaned up here.
public struct RunnerSessionStopper: Sendable {
    public enum Outcome: Equatable, Sendable {
        /// The grantiva process holding the session got SIGINT and exited.
        /// `reaped`: device helpers the runner left running, ended here (L04).
        case released(grantivaPid: Int32, runnerPid: Int32, udid: String, reaped: [ReapedProcess] = [])
        /// The runner's group was terminated; `killed` when it took SIGKILL.
        case terminated(runnerPid: Int32, udid: String, killed: Bool, reaped: [ReapedProcess] = [])

        public var runnerPid: Int32 {
            switch self {
            case .released(_, let pid, _, _), .terminated(let pid, _, _, _): return pid
            }
        }

        public var udid: String {
            switch self {
            case .released(_, _, let udid, _), .terminated(_, let udid, _, _): return udid
            }
        }

        /// Device helpers the runner left running that the stop ended.
        public var reaped: [ReapedProcess] {
            switch self {
            case .released(_, _, _, let reaped), .terminated(_, _, _, let reaped): return reaped
            }
        }
    }

    public var store: KeepAliveSessionStore
    public var isProcessAlive: @Sendable (Int32) -> Bool
    public var parentPid: @Sendable (Int32) -> Int32?
    /// True when `pid` is a grantiva-runner process (pids are reused).
    public var isRunnerProcess: @Sendable (Int32) async -> Bool
    /// True when `pid` is a grantiva process.
    public var isGrantivaProcess: @Sendable (Int32) async -> Bool
    public var interrupt: @Sendable (Int32) -> Void
    public var terminateGroup: @Sendable (Int32) -> ChildProcess.GroupTermination
    public var removeSessionFiles: @Sendable (Int32) -> Void
    public var releaseLease: @Sendable (String) -> Void
    public var cleanupOrphans: @Sendable (String) async -> Void
    /// Ends the device helpers (`simctl diagnose`, …) a stopped runner left.
    public var helperReaper: RunnerHelperReaper
    /// How long a grantiva process gets to exit after SIGINT. Its own
    /// shutdown gives the runner 5 s before escalating.
    public var waitTimeout: TimeInterval
    public var pollInterval: Duration

    public init(
        store: KeepAliveSessionStore,
        isProcessAlive: @escaping @Sendable (Int32) -> Bool,
        parentPid: @escaping @Sendable (Int32) -> Int32?,
        isRunnerProcess: @escaping @Sendable (Int32) async -> Bool,
        isGrantivaProcess: @escaping @Sendable (Int32) async -> Bool,
        interrupt: @escaping @Sendable (Int32) -> Void,
        terminateGroup: @escaping @Sendable (Int32) -> ChildProcess.GroupTermination,
        removeSessionFiles: @escaping @Sendable (Int32) -> Void,
        releaseLease: @escaping @Sendable (String) -> Void,
        cleanupOrphans: @escaping @Sendable (String) async -> Void,
        helperReaper: RunnerHelperReaper = .inert,
        waitTimeout: TimeInterval = 30,
        pollInterval: Duration = .milliseconds(100)
    ) {
        self.store = store
        self.isProcessAlive = isProcessAlive
        self.parentPid = parentPid
        self.isRunnerProcess = isRunnerProcess
        self.isGrantivaProcess = isGrantivaProcess
        self.interrupt = interrupt
        self.terminateGroup = terminateGroup
        self.removeSessionFiles = removeSessionFiles
        self.releaseLease = releaseLease
        self.cleanupOrphans = cleanupOrphans
        self.helperReaper = helperReaper
        self.waitTimeout = waitTimeout
        self.pollInterval = pollInterval
    }

    public static func live(store: KeepAliveSessionStore = KeepAliveSessionStore()) -> RunnerSessionStopper {
        RunnerSessionStopper(
            store: store,
            isProcessAlive: KeepAliveSessionStore.processIsAlive,
            parentPid: { ProcessLookup.parentPid(of: $0) },
            isRunnerProcess: { ProcessLookup.name(of: $0)?.lowercased() == "grantiva-runner" },
            isGrantivaProcess: { ProcessLookup.name(of: $0)?.lowercased() == "grantiva" },
            interrupt: { _ = kill($0, SIGINT) },
            terminateGroup: { ChildProcess.terminateGroup($0, gracePeriod: 5) },
            removeSessionFiles: { store.removeSessionFiles(runnerPid: $0) },
            releaseLease: { SimulatorLease.forceRelease(udid: $0) },
            cleanupOrphans: { serial in
                guard let platform = try? AndroidPlatform.live() else { return }
                await platform.cleanupOrphans(deviceID: serial)
            },
            helperReaper: .live()
        )
    }

    /// Stops `session`. Throws when a grantiva process holding it does not
    /// exit within `waitTimeout` of SIGINT.
    public func stop(_ session: KeepAliveSession) async throws -> Outcome {
        let udid = session.udid ?? ""
        // Every pid is checked before it is signalled: the owner must still
        // be a grantiva process and the runner's parent, and the runner must
        // still be a grantiva-runner (pids are reused).
        if let owner = session.ownerPid, owner > 1, owner != getpid(), session.detached != true,
           isProcessAlive(owner), parentPid(session.pid) == owner,
           await isRunnerProcess(session.pid), await isGrantivaProcess(owner) {
            let (exited, reaped) = await helperReaper.stopping(runnerPid: session.pid, udid: udid) { [self] in
                interrupt(owner)
                return await waitForExit(owner, timeout: waitTimeout)
            }
            guard exited else {
                throw GrantivaError.unavailable(
                    "The grantiva process holding the keep-alive session (pid \(owner), \(udid)) did not exit within \(Int(waitTimeout))s of SIGINT. "
                        + "Release it with kill -INT \(owner), or reclaim the device with `grantiva \(DeviceID.isAndroidSerial(udid) ? "emulator teardown --serial" : "simulator teardown --udid") \(udid) --force`."
                )
            }
            if !isProcessAlive(session.pid) { removeSessionFiles(session.pid) }
            return .released(grantivaPid: owner, runnerPid: session.pid, udid: udid, reaped: reaped)
        }
        return await terminate(runnerPid: session.pid, udid: udid)
    }

    /// Terminates a runner nobody holds and cleans up after it. A pid that
    /// is no longer a grantiva-runner is never signalled; its files are still
    /// removed.
    func terminate(runnerPid: Int32, udid: String) async -> Outcome {
        var killed = false
        var reaped: [ReapedProcess] = []
        if isProcessAlive(runnerPid), await isRunnerProcess(runnerPid) {
            (killed, reaped) = await helperReaper.stopping(runnerPid: runnerPid, udid: udid) { [self] in
                let killed = terminateGroup(runnerPid) == .killed
                _ = await waitForExit(runnerPid, timeout: 3)
                return killed
            }
        } else if !udid.isEmpty {
            reaped = await helperReaper.sweep(exitedRunnerPid: runnerPid, udid: udid)
        }
        removeSessionFiles(runnerPid)
        if DeviceID.isAndroidSerial(udid) { await cleanupOrphans(udid) }
        if !udid.isEmpty { releaseLease(udid) }
        return .terminated(runnerPid: runnerPid, udid: udid, killed: killed, reaped: reaped)
    }

    /// Every session on `udid`, orphans included, plus the `runner start`
    /// session file's runner when it names `udid` and is not among them.
    /// Failures to stop one are reported on stderr and do not stop the rest.
    public func stopSessions(udid: String, runnerStartSession: RunnerSessionInfo?) async -> [Outcome] {
        var outcomes: [Outcome] = []
        let sessions = store.liveSessions(includingOrphans: true)
            .filter { $0.udid?.caseInsensitiveCompare(udid) == .orderedSame }
        for session in sessions {
            do {
                outcomes.append(try await stop(session))
            } catch {
                FileHandle.standardError.write(Data("Warning: \(error.localizedDescription)\n".utf8))
            }
        }
        if let file = runnerStartSession, file.udid.caseInsensitiveCompare(udid) == .orderedSame,
           !sessions.contains(where: { $0.pid == file.pid }), isProcessAlive(file.pid) {
            outcomes.append(await terminate(runnerPid: file.pid, udid: udid))
        }
        return outcomes
    }

    private func waitForExit(_ pid: Int32, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while isProcessAlive(pid) {
            if Date() >= deadline { return false }
            try? await Task.sleep(for: pollInterval)
        }
        return true
    }
}

/// Reads a process's parent and short name from the kernel.
public enum ProcessLookup {
    static func info(_ pid: Int32) -> kinfo_proc? {
        guard pid > 0 else { return nil }
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info
    }

    public static func parentPid(of pid: Int32) -> Int32? {
        info(pid).map { $0.kp_eproc.e_ppid }
    }

    /// The kernel's command name (up to 15 characters, enough for
    /// `grantiva-runner`).
    public static func name(of pid: Int32) -> String? {
        guard var info = info(pid) else { return nil }
        return withUnsafeBytes(of: &info.kp_proc.p_comm) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
