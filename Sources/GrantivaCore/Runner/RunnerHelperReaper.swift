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
    /// When set, no wait outlasts it: a teardown's single deadline (L63).
    /// `runner stop` leaves it nil and keeps its own bounds.
    public var deadline: Date?
    /// When true (a teardown, L63), the lineage reap SIGKILLs the stopped
    /// run's `xcodebuild test-without-building` at once instead of SIGINT,
    /// which would make it start a diagnose. `runner stop` leaves it false.
    public var killsXcodebuildAtOnce = false

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

    /// After an interrupt stopped runner `runnerPid` (B4-L72.3): ends the
    /// helpers still writing into its run directory. Interrupted while WDA is
    /// still starting, the runner leaves WebDriverAgent's `xcodebuild
    /// test-without-building` (a process group of its own) to launchd, where
    /// it later starts a 600 s `simctl diagnose`. That xcodebuild takes
    /// SIGKILL at once (SIGINT is what makes it start the diagnose); a
    /// diagnose already running gets SIGINT, then SIGKILL. A second round
    /// catches a diagnose started while the first one ran.
    ///
    /// Blocks for at most `timeout`: the signal relay runs it from its
    /// synchronous cleanup, before it releases the device and exits.
    @discardableResult
    public func reapAfterInterrupt(runnerPid: Int32, udid: String, timeout: TimeInterval = 8) -> [ReapedProcess] {
        guard runnerPid > 1, !udid.isEmpty else { return [] }
        var reaper = self
        reaper.killsXcodebuildAtOnce = true
        reaper.deadline = Date().addingTimeInterval(timeout)
        let result = ReapResult()
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            var reaped: [ReapedProcess] = []
            for _ in 0..<2 {
                let round = await reaper.sweep(exitedRunnerPid: runnerPid, udid: udid).filter { found in
                    !reaped.contains { $0.pid == found.pid && $0.command == found.command }
                }
                reaped += round
                if round.isEmpty { break }
                if let deadline = reaper.deadline, Date() >= deadline { break }
            }
            result.set(reaped)
            done.signal()
        }
        _ = done.wait(timeout: .now() + timeout + 1)
        return result.value.sorted { $0.pid < $1.pid }
    }

    /// Has an interrupt that stops the iOS runner leading `group` also end
    /// the helpers it left outside the group (`reapAfterInterrupt`).
    public static func reapOnInterrupt(group: pid_t, udid: String, relay: SignalRelay = .shared) {
        relay.afterGroupTermination(group: group) {
            RunnerHelperReaper.live().reapAfterInterrupt(runnerPid: group, udid: udid)
        }
    }

    private final class ReapResult: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: [ReapedProcess] = []
        var value: [ReapedProcess] { lock.withLock { stored } }
        func set(_ value: [ReapedProcess]) { lock.withLock { stored = value } }
    }

    /// After a teardown stopped the runners on `udid` (L63): ends the
    /// WebDriverAgent `xcodebuild` and `simctl diagnose` still writing into
    /// the device's runner home (`<runner home>/…/devices/<udid>`), so the
    /// home the teardown then removes stays removed.
    ///
    /// An interrupted xcodebuild starts diagnose in a process group of its
    /// own and exits, so neither the runner's group nor its lineage holds it
    /// by the time the teardown looks; the device home it writes into names
    /// it as the stopped run's. Ending an xcodebuild can start another
    /// diagnose, so the table is read again after each round, up to `rounds`
    /// times, and while `deadline` allows after the first.
    ///
    /// The runner is already stopped and its home is about to go, so the
    /// run's `xcodebuild test-without-building` takes SIGKILL at once (SIGINT
    /// is what makes it start a diagnose). A diagnose gets SIGINT, then
    /// SIGKILL after `gracePeriod`; from the second round on everything
    /// takes SIGKILL at once. A helper is killed, never left.
    public func reapDeviceHome(udid: String, rounds: Int = 3) async -> [ReapedProcess] {
        guard !udid.isEmpty else { return [] }
        let me = getpid()
        var reaped: [ReapedProcess] = []
        for round in 0..<max(rounds, 1) {
            if round > 0, let deadline, Date() >= deadline { break }
            guard let table = try? await snapshot() else { break }
            var targets = HostProcess.parse(table).compactMap { process -> ReapedProcess? in
                guard process.pid > 1, process.pid != me,
                      !reaped.contains(where: { $0.pid == process.pid && $0.command == process.command }),
                      let kind = SimulatorReaper.kind(of: process.command, owning: udid),
                      kind == .diagnose || kind == .webDriverAgent,
                      writesIntoDeviceHome(process.command, udid: udid)
                else { return nil }
                return ReapedProcess(pid: process.pid, processGroup: process.pgid, kind: kind, command: process.command)
            }
            guard !targets.isEmpty else { break }
            await terminate(&targets) { round > 0 || $0.kind == .webDriverAgent }
            reaped += targets
        }
        return reaped.sorted { $0.pid < $1.pid }
    }

    /// True when a path in `command` lies in the runner home of `udid`
    /// (`<runner base>/…/devices/<udid>`) under one of `runnerBases`.
    func writesIntoDeviceHome(_ command: String, udid: String) -> Bool {
        let needle = command.lowercased()
        let device = "/devices/\(udid.lowercased())"
        return runnerBases.contains { base in
            guard !base.isEmpty else { return false }
            let prefix = base.lowercased() + "/"
            var rest = needle[...]
            while let start = rest.range(of: prefix) {
                let path = rest[start.upperBound...].prefix { $0 != " " }
                if path.contains(device + "/") || path.hasSuffix(device) { return true }
                rest = rest[start.upperBound...]
            }
            return false
        }
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
        await terminate(&targets) { [killsXcodebuildAtOnce] in killsXcodebuildAtOnce && $0.kind == .webDriverAgent }
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
    /// Targets `killAtOnce` picks take SIGKILL without the SIGINT and grace.
    private func terminate(
        _ targets: inout [ReapedProcess], killAtOnce: (ReapedProcess) -> Bool = { _ in false }
    ) async {
        guard !targets.isEmpty else { return }
        let ownGroup = getpgrp()
        func send(_ sig: Int32, _ target: ReapedProcess) {
            signal(target.pid, sig)
            if target.processGroup == target.pid, target.processGroup > 1, target.processGroup != ownGroup {
                signal(-target.processGroup, sig)
            }
        }
        var graced = false
        for index in targets.indices {
            let now = killAtOnce(targets[index])
            graced = graced || !now
            send(now ? SIGKILL : SIGINT, targets[index])
            targets[index].killed = true
        }
        let pending = targets
        if await waitForExit(pending, timeout: graced ? gracePeriod : 2) { return }
        for target in pending where isAlive(target.pid) { send(SIGKILL, target) }
        _ = await waitForExit(pending, timeout: 2)
    }

    private func waitForExit(_ targets: [ReapedProcess], timeout: TimeInterval) async -> Bool {
        let deadline = min(Date().addingTimeInterval(timeout), self.deadline ?? .distantFuture)
        while targets.contains(where: { isAlive($0.pid) }) {
            if Date() >= deadline { return false }
            try? await Task.sleep(for: pollInterval)
        }
        return true
    }
}
