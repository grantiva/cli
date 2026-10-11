import Darwin
import Foundation

/// One row of `ps -axo pid=,ppid=,pgid=,command=`.
public struct HostProcess: Equatable, Sendable {
    public let pid: Int32
    public let ppid: Int32
    public let pgid: Int32
    public let command: String

    public init(pid: Int32, ppid: Int32, pgid: Int32, command: String) {
        self.pid = pid
        self.ppid = ppid
        self.pgid = pgid
        self.command = command
    }

    public static func parse(_ psOutput: String) -> [HostProcess] {
        psOutput.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            let fields = line.split(maxSplits: 3, whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count == 4,
                  let pid = Int32(fields[0]), let ppid = Int32(fields[1]), let pgid = Int32(fields[2])
            else { return nil }
            return HostProcess(pid: pid, ppid: ppid, pgid: pgid, command: String(fields[3]))
        }
    }

    /// The host's process table, full command lines included.
    public static func snapshot() async throws -> String {
        try await shell("/bin/ps -ww -axo pid=,ppid=,pgid=,command=")
    }
}

/// The processes a runner started, as seen while it lived: every process
/// whose parent is the runner or one of these, or that is in the runner's
/// process group. A member keeps its place after its parent dies and it is
/// reparented to launchd, which is exactly what happens to the
/// `simctl diagnose` WebDriverAgent's xcodebuild starts when it is
/// interrupted (L04).
struct RunnerLineage: Sendable {
    let runnerPid: Int32
    /// pid -> the command line it had when last seen as a member.
    private(set) var members: [Int32: String] = [:]

    init(runnerPid: Int32) {
        self.runnerPid = runnerPid
    }

    mutating func observe(_ processes: [HostProcess]) {
        let table = Self.byPid(processes)
        var changed = true
        while changed {
            changed = false
            for process in processes where process.pid != runnerPid && process.pid > 1 {
                let descends = process.ppid == runnerPid || process.pgid == runnerPid
                    || isMemberParent(process.ppid, in: table)
                guard descends, members[process.pid] != process.command else { continue }
                members[process.pid] = process.command
                changed = true
            }
        }
    }

    /// True when `process` is one this runner started: still attached to a
    /// member, or seen as a member with this same command line (a reused pid
    /// runs something else).
    /// The runner itself is not one: stopping it is the caller's job.
    func owns(_ process: HostProcess, in table: [Int32: HostProcess]) -> Bool {
        guard process.pid != runnerPid else { return false }
        if process.pgid == runnerPid || process.ppid == runnerPid { return true }
        if isMemberParent(process.ppid, in: table) { return true }
        return members[process.pid] == process.command
    }

    /// True when `ppid` is a member that still runs the command it had as
    /// one: a member's pid reused by something else is not a member, and
    /// neither are its children.
    func isMemberParent(_ ppid: Int32, in table: [Int32: HostProcess]) -> Bool {
        guard ppid > 1, let recorded = members[ppid], let parent = table[ppid] else { return false }
        return parent.command == recorded
    }

    static func byPid(_ processes: [HostProcess]) -> [Int32: HostProcess] {
        Dictionary(processes.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
    }
}

/// Ends the device helpers a stopped runner left behind (L04).
///
/// Stopping the runner's process group is not enough on iOS: when
/// WebDriverAgent's `xcodebuild test-without-building` is interrupted it
/// starts `simctl diagnose --udid=<device>` (up to 600 s) in a process group
/// of its own, and that process outlives the group. This finds such
/// processes by two facts together, never by name alone:
/// - the command line names the device (the reaper's runner,
///   WebDriverAgent and diagnose rules), and
/// - the stopped runner started it: it descends from the runner by parent or
///   process group in a snapshot taken while the runner was stopping, or it
///   writes into that runner's own run directory
///   (`<runner home>/…/devices/<udid>/…/run-<runner pid>-…`).
public struct RunnerHelperReaper: Sendable {
    /// `ps -axo pid=,ppid=,pgid=,command=` output.
    public var snapshot: @Sendable () async throws -> String
    /// `kill(pid, signal)`; a negative pid names a process group.
    public var signal: @Sendable (Int32, Int32) -> Void
    public var isAlive: @Sendable (Int32) -> Bool
    /// The runner homes a run directory may live under.
    public var runnerBases: [String]
    /// How long a helper gets after SIGINT before SIGKILL.
    public var gracePeriod: TimeInterval
    public var pollInterval: Duration

    public init(
        snapshot: @escaping @Sendable () async throws -> String,
        signal: @escaping @Sendable (Int32, Int32) -> Void,
        isAlive: @escaping @Sendable (Int32) -> Bool,
        runnerBases: [String],
        gracePeriod: TimeInterval = 3,
        pollInterval: Duration = .milliseconds(100)
    ) {
        self.snapshot = snapshot
        self.signal = signal
        self.isAlive = isAlive
        self.runnerBases = runnerBases
        self.gracePeriod = gracePeriod
        self.pollInterval = pollInterval
    }

    public static func live(runnerBase: String? = nil) -> RunnerHelperReaper {
        let runnerBase = runnerBase ?? RunnerManager.baseDir
        let resolved = URL(fileURLWithPath: runnerBase).resolvingSymlinksInPath().path
        let standardized = URL(fileURLWithPath: runnerBase).standardizedFileURL.path
        return RunnerHelperReaper(
            snapshot: { try await HostProcess.snapshot() },
            signal: { _ = kill($0, $1) },
            isAlive: KeepAliveSessionStore.processIsAlive,
            runnerBases: Array(Set([runnerBase, resolved, standardized]))
        )
    }

    /// Does nothing: no snapshot, no signal. The default where a caller has
    /// no reaper.
    public static let inert = RunnerHelperReaper(
        snapshot: { "" }, signal: { _, _ in }, isAlive: { _ in false }, runnerBases: []
    )

    /// Runs `body`, which stops the runner `runnerPid` (already confirmed to
    /// be a grantiva-runner), while watching the processes it started; then,
    /// once the runner is gone, ends those that still hold `udid` and waits
    /// for them to exit.
    public func stopping<T: Sendable>(
        runnerPid: Int32, udid: String, _ body: @escaping @Sendable () async -> T
    ) async -> (T, [ReapedProcess]) {
        var lineage = RunnerLineage(runnerPid: runnerPid)
        if let table = try? await snapshot() { lineage.observe(HostProcess.parse(table)) }

        let work = Task { await body() }
        let sampler = Task { [lineage, snapshot, pollInterval] () -> RunnerLineage in
            var lineage = lineage
            while !Task.isCancelled {
                if let table = try? await snapshot() { lineage.observe(HostProcess.parse(table)) }
                try? await Task.sleep(for: pollInterval)
            }
            return lineage
        }
        let value = await work.value
        sampler.cancel()
        lineage = await sampler.value
        // A runner that is still alive still uses its helpers.
        guard !isAlive(runnerPid) else { return (value, []) }
        return (value, await reap(udid: udid, lineage: lineage))
    }

    /// For a runner that had already exited: ends only helpers that write
    /// into its run directory.
    public func sweep(exitedRunnerPid: Int32, udid: String) async -> [ReapedProcess] {
        await reap(udid: udid, lineage: RunnerLineage(runnerPid: exitedRunnerPid), followLineage: false)
    }

    private func reap(udid: String, lineage: RunnerLineage, followLineage: Bool = true) async -> [ReapedProcess] {
        guard !udid.isEmpty, let table = try? await snapshot() else { return [] }
        var lineage = lineage
        let processes = HostProcess.parse(table)
        if followLineage { lineage.observe(processes) }
        let me = getpid()
        let byPid = RunnerLineage.byPid(processes)
        var targets = processes.compactMap { process -> ReapedProcess? in
            guard process.pid > 1, process.pid != me,
                  let kind = SimulatorReaper.kind(of: process.command, owning: udid), kind != .grantiva,
                  (followLineage && lineage.owns(process, in: byPid))
                    || writesIntoRunDirectory(process.command, runnerPid: lineage.runnerPid, udid: udid)
            else { return nil }
            return ReapedProcess(pid: process.pid, processGroup: process.pgid, kind: kind, command: process.command)
        }.sorted { $0.pid < $1.pid }
        await terminate(&targets)
        return targets
    }

    /// True when `command` writes into the run directory runner `runnerPid`
    /// created for `udid` under one of `runnerBases`.
    ///
    /// The run directory is `run-<runner pid>-<start timestamp>`; only the
    /// pid is matched and the timestamp suffix is ignored. The pid, the
    /// device directory and the runner home together name the stopped
    /// runner's run, and the reaper never runs while that runner is alive.
    func writesIntoRunDirectory(_ command: String, runnerPid: Int32, udid: String) -> Bool {
        let needle = command.lowercased()
        let device = "/devices/\(udid.lowercased())/"
        let run = "/run-\(runnerPid)-"
        return runnerBases.contains { base in
            guard !base.isEmpty else { return false }
            let prefix = base.lowercased() + "/"
            guard let start = needle.range(of: prefix) else { return false }
            let rest = needle[start.upperBound...].prefix { $0 != " " }
            return rest.contains(device) && rest.contains(run)
        }
    }

    /// SIGINT each target (and its group, when it leads one of its own),
    /// wait up to `gracePeriod`, SIGKILL the survivors, then wait for them.
    private func terminate(_ targets: inout [ReapedProcess]) async {
        guard !targets.isEmpty else { return }
        let ownGroup = getpgrp()
        func send(_ sig: Int32, _ target: ReapedProcess) {
            signal(target.pid, sig)
            if target.processGroup == target.pid, target.processGroup > 1, target.processGroup != ownGroup {
                signal(-target.processGroup, sig)
            }
        }
        for index in targets.indices {
            send(SIGINT, targets[index])
            targets[index].killed = true
        }
        let pending = targets
        if await waitForExit(pending, timeout: gracePeriod) { return }
        for target in pending where isAlive(target.pid) { send(SIGKILL, target) }
        _ = await waitForExit(pending, timeout: 2)
    }

    private func waitForExit(_ targets: [ReapedProcess], timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while targets.contains(where: { isAlive($0.pid) }) {
            if Date() >= deadline { return false }
            try? await Task.sleep(for: pollInterval)
        }
        return true
    }
}
