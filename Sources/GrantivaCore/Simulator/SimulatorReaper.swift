import Darwin
import Foundation

/// A process found to be holding a simulator.
public struct ReapedProcess: Codable, Equatable, Sendable {
    /// What the process is, for human-readable output.
    public enum Kind: String, Codable, Sendable {
        case grantiva
        case runner
        case webDriverAgent
        case diagnose
    }

    public let pid: Int32
    public let processGroup: Int32
    public let kind: Kind
    public let command: String
    public var killed: Bool

    public init(pid: Int32, processGroup: Int32, kind: Kind, command: String, killed: Bool = false) {
        self.pid = pid
        self.processGroup = processGroup
        self.kind = kind
        self.command = command
        self.killed = killed
    }
}

public struct ForceTeardownResult: Codable, Equatable, Sendable {
    public let udid: String
    public var processes: [ReapedProcess]
    public var leaseReleased: Bool
    public var capacityRecordsCleared: Int
    /// Records for the device that were left in place because their session
    /// is still live, with the reason.
    public var capacityRecordsKept: [KeptCapacityRecord]
    /// Keep-alive session files of the reaped runner that were deleted.
    public var sessionFilesRemoved: [String]
    /// The device's runner homes (`<runner home>/versions/<runner version>/devices/<udid>`) that were removed.
    public var deviceHomesRemoved: [String]
    /// One "<path>: <reason>" line per runner home that could not be removed.
    public var deviceHomeFailures: [String]
    /// Temp directories of the killed run (staged flows, ephemeral report
    /// dir) that its lease claim named and that were removed.
    public var temporaryDirectoriesRemoved: [String]
    /// Whether the preliminary orderly stop ended a live runner session.
    public var runnerSessionStopped: Bool = false
    /// Whether this teardown actually took something back. A `--force` run that
    /// found nothing is a success — the device was already free — but it is not
    /// the same event as one that killed a stranded runner, and a script that
    /// expected to reclaim a busy device has no other way to tell them apart
    /// (the exit code is 0 either way, deliberately).
    public var reclaimed: Bool
    /// Helpers the stopped runner left on the device that the teardown's
    /// runner-session stop ended before this force pass (L63); same fields
    /// as `processes`, `killed: true`.
    public var reapedProcesses: [ReapedProcess] = []

    public init(
        udid: String,
        processes: [ReapedProcess],
        leaseReleased: Bool,
        capacityRecordsCleared: Int,
        capacityRecordsKept: [KeptCapacityRecord] = [],
        sessionFilesRemoved: [String] = [],
        deviceHomesRemoved: [String] = [],
        deviceHomeFailures: [String] = [],
        temporaryDirectoriesRemoved: [String] = []
    ) {
        self.udid = udid
        self.processes = processes
        self.leaseReleased = leaseReleased
        self.capacityRecordsCleared = capacityRecordsCleared
        self.capacityRecordsKept = capacityRecordsKept
        self.sessionFilesRemoved = sessionFilesRemoved
        self.deviceHomesRemoved = deviceHomesRemoved
        self.deviceHomeFailures = deviceHomeFailures
        self.temporaryDirectoriesRemoved = temporaryDirectoriesRemoved
        self.reclaimed = !processes.isEmpty || leaseReleased || capacityRecordsCleared > 0
    }
}

/// Reclaims a simulator by live process inspection, without consulting any
/// ledger.
///
/// `teardown --session-id` can only act on what the capacity registry recorded,
/// which is exactly nothing in the case that matters: a run whose CLI was killed
/// (or whose SIGINT was ignored) leaves grantiva-runner, WebDriverAgent's
/// `xcodebuild test-without-building` and a long `simctl diagnose` alive and
/// owning the device while `sessions.json` reads `[]`. This finds those
/// processes the way a human would — by their command lines — and reaps them.
public enum SimulatorReaper {
    /// Parses `ps -axo pid=,pgid=,command=` output and returns the processes
    /// that own `udid`. Pure, so the matching rules are unit-testable.
    ///
    /// `excludingPID` keeps the running teardown command from matching itself.
    public static func processes(
        owning udid: String,
        psOutput: String,
        excludingPID: Int32 = 0
    ) -> [ReapedProcess] {
        var found: [ReapedProcess] = []

        for line in psOutput.split(separator: "\n", omittingEmptySubsequences: true) {
            let fields = line.split(maxSplits: 2, whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count == 3,
                  let pid = Int32(fields[0]),
                  let pgid = Int32(fields[1])
            else { continue }
            let command = String(fields[2])
            guard pid != excludingPID, let kind = kind(of: command, owning: udid) else { continue }
            found.append(ReapedProcess(pid: pid, processGroup: pgid, kind: kind, command: command))
        }

        return found.sorted { $0.pid < $1.pid }
    }

    /// What `command` is when it is a process holding `udid`, or nil. The
    /// matching rules of `processes(owning:)`, for one command line.
    static func kind(of command: String, owning udid: String) -> ReapedProcess.Kind? {
        let needle = udid.lowercased()
        let haystack = command.lowercased()
        guard haystack.contains(needle) else { return nil }
        // Never match the teardown invocation that is doing the reaping.
        if haystack.contains("simulator teardown") { return nil }

        let executable = haystack.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? ""
        let name = URL(fileURLWithPath: executable).lastPathComponent
        if name == "grantiva-runner" {
            guard haystack.contains("--device \(needle)") || haystack.contains("--device=\(needle)") else { return nil }
            return .runner
        } else if haystack.contains("test-without-building") {
            guard haystack.contains("id=\(needle)") else { return nil }
            return .webDriverAgent
        } else if haystack.contains("diagnose") && haystack.contains("simctl") {
            return .diagnose
        } else if name == "grantiva" {
            // A live `grantiva run` still holding the lease. This is the
            // usual culprit when `kill -INT` was ignored by a backgrounded
            // run, and it is the process the lease names.
            return .grantiva
        }
        return nil
    }

    /// Snapshot of the host's processes in the format `processes(owning:)` parses.
    public static func processSnapshot() async throws -> String {
        try await shell("/bin/ps -axo pid=,pgid=,command=")
    }

    /// Confirms that a persisted lease PID still names a Grantiva executable.
    /// PIDs are reusable, so liveness alone is not proof of ownership.
    static func isGrantivaProcess(pid: Int32, psOutput: String) -> Bool {
        for line in psOutput.split(separator: "\n", omittingEmptySubsequences: true) {
            let fields = line.split(maxSplits: 2, whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count == 3, Int32(fields[0]) == pid else { continue }
            let executable = fields[2].split(whereSeparator: { $0 == " " || $0 == "\t" }).first
            guard let executable else { return false }
            let name = URL(fileURLWithPath: String(executable)).lastPathComponent.lowercased()
            return name == "grantiva" || name == "grantiva-runner"
        }
        return false
    }

    /// Kills everything holding `udid`, breaks the lease, and reconciles the
    /// capacity registry so the ownership check and the ledger agree again.
    public static func forceTeardown(
        udid: String,
        capacity: SimulatorCapacity = .live,
        leaseDirectory: String? = nil,
        runnerBase: String? = nil,
        sessions: KeepAliveSessionStore = KeepAliveSessionStore(),
        snapshot: (() async throws -> String)? = nil,
        gracePeriod: TimeInterval = 3,
        isProcessAlive: (Int32) -> Bool = KeepAliveSessionStore.processIsAlive
    ) async throws -> ForceTeardownResult {
        func takeSnapshot() async throws -> String {
            if let snapshot { return try await snapshot() }
            return try await processSnapshot()
        }
        let psOutput = try await takeSnapshot()
        var targets = processes(owning: udid, psOutput: psOutput, excludingPID: getpid())
        let helperOwnership = RunnerHelperReaper.live(runnerBase: runnerBase ?? RunnerManager.baseDir)
        // A device can have an unrelated developer xcodebuild or simctl
        // diagnose at the same time. Force teardown may reclaim only helpers
        // writing into Grantiva's device home; the UDID alone is insufficient
        // ownership proof. Runner/grantiva processes retain their exact argv
        // ownership checks in `kind(of:owning:)` above.
        targets.removeAll { target in
            (target.kind == .webDriverAgent || target.kind == .diagnose)
                && !helperOwnership.writesIntoDeviceHome(target.command, udid: udid)
        }
        // Before anything is reaped: whether the lease is held is a question
        // about the processes that are about to be killed.
        let leaseHeld = SimulatorLease.isHeld(udid: udid, directory: leaseDirectory)
        let claim = SimulatorLease.claim(udid: udid, directory: leaseDirectory)

        // The lease names its owner even when the command line does not carry
        // the UDID (a run started via `grantiva.yml` names the simulator, not
        // its UDID), so fold that pid in too.
        if let claim,
           claim.pid != getpid(),
           !targets.contains(where: { $0.pid == claim.pid }),
           isGrantivaProcess(pid: claim.pid, psOutput: psOutput),
           kill(claim.pid, 0) == 0 || errno == EPERM {
            targets.append(ReapedProcess(
                pid: claim.pid,
                processGroup: claim.pid,
                kind: .grantiva,
                command: "grantiva (lease holder for \(udid))"
            ))
        }

        reap(&targets, gracePeriod: gracePeriod)

        // A dying runner can start a `simctl diagnose` for the device after
        // the first snapshot was taken. Look once more and reap new diagnose
        // processes only: a fresh `grantiva run` started in the grace window
        // is someone else's and must survive.
        if !targets.isEmpty {
            let known = Set(targets.map(\.pid))
            var late = processes(owning: udid, psOutput: try await takeSnapshot(), excludingPID: getpid())
                .filter {
                    $0.kind == .diagnose && !known.contains($0.pid)
                        && helperOwnership.writesIntoDeviceHome($0.command, udid: udid)
                }
            reap(&late, gracePeriod: gracePeriod)
            targets += late
        }

        // `leaseHeld` was read before reaping; the file goes either way.
        SimulatorLease.removeLeaseFile(udid: udid, directory: leaseDirectory)
        let leaseReleased = leaseHeld

        // A killed run never ran its cleanup: remove the temp dirs its claim
        // named, once the run and its runner are gone.
        let temporaryDirectoriesRemoved = claim.map(removeTemporaryDirectories(of:)) ?? []

        // Clear only stale capacity records for this device. The record of a
        // session that still owns other simulators is not stale: dropping it
        // would hide a booted device from `teardown --session-id`.
        let (cleared, kept) = (try? capacity.removeStale(udid: udid, isProcessAlive: isProcessAlive)) ?? (0, [])

        // The killed keep-alive runner never got to remove its session files.
        let runnerPids = targets.filter { $0.kind == .runner }.map(\.pid)
        let removedFiles = sessions.removeSessions(udid: udid, runnerPids: runnerPids)

        // The device's WDA state; the runners using it were reaped above.
        let homes = WDADeviceHome.removeAll(runnerBase: runnerBase ?? RunnerManager.baseDir, deviceID: udid)

        return ForceTeardownResult(
            udid: udid,
            processes: targets,
            leaseReleased: leaseReleased,
            capacityRecordsCleared: cleared,
            capacityRecordsKept: kept,
            sessionFilesRemoved: removedFiles,
            deviceHomesRemoved: homes.removed,
            deviceHomeFailures: homes.failures,
            temporaryDirectoriesRemoved: temporaryDirectoriesRemoved
        )
    }

    /// Removes the temp directories `claim` recorded when neither its process
    /// nor its runner is alive. Only directories Grantiva creates in the temp
    /// directory (`grantiva-…`) are touched, so a claim can never name a
    /// preserved `--report-dir` or anything else for removal.
    static func removeTemporaryDirectories(of claim: SimulatorLeaseClaim) -> [String] {
        guard !claim.isLive else { return [] }
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.resolvingSymlinksInPath().path
        var removed: [String] = []
        for path in claim.temporaryDirectories ?? [] {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            let resolved = url.resolvingSymlinksInPath().path
            guard url.lastPathComponent.hasPrefix("grantiva-"),
                  resolved.hasPrefix(temp + "/"),
                  fm.fileExists(atPath: path),
                  (try? fm.removeItem(atPath: path)) != nil
            else { continue }
            removed.append(path)
        }
        return removed
    }

    /// SIGINT each target (and its process group, unless it is ours), wait up
    /// to `gracePeriod` for them to exit, then SIGKILL the survivors.
    private static func reap(_ targets: inout [ReapedProcess], gracePeriod: TimeInterval) {
        let ownGroup = getpgrp()
        for index in targets.indices {
            let target = targets[index]
            guard target.pid != getpid() else { continue }
            // SIGINT first so grantiva-runner gets the chance to release
            // WebDriverAgent cleanly, exactly as Ctrl-C would.
            kill(target.pid, SIGINT)
            if target.processGroup > 1, target.processGroup != ownGroup {
                kill(-target.processGroup, SIGINT)
            }
            targets[index].killed = true
        }

        guard !targets.isEmpty else { return }
        let deadline = Date().addingTimeInterval(gracePeriod)
        while Date() < deadline {
            if targets.allSatisfy({ kill($0.pid, 0) != 0 }) { break }
            usleep(100_000)
        }
        for target in targets where kill(target.pid, 0) == 0 {
            kill(target.pid, SIGKILL)
            if target.processGroup > 1, target.processGroup != ownGroup {
                kill(-target.processGroup, SIGKILL)
            }
        }
    }
}
