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

    public init(udid: String, processes: [ReapedProcess], leaseReleased: Bool, capacityRecordsCleared: Int) {
        self.udid = udid
        self.processes = processes
        self.leaseReleased = leaseReleased
        self.capacityRecordsCleared = capacityRecordsCleared
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
        let needle = udid.lowercased()
        var found: [ReapedProcess] = []

        for line in psOutput.split(separator: "\n", omittingEmptySubsequences: true) {
            let fields = line.split(maxSplits: 2, whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count == 3,
                  let pid = Int32(fields[0]),
                  let pgid = Int32(fields[1])
            else { continue }
            let command = String(fields[2])
            guard pid != excludingPID else { continue }
            let haystack = command.lowercased()
            guard haystack.contains(needle) else { continue }
            // Never match the teardown invocation that is doing the reaping.
            if haystack.contains("simulator teardown") { continue }

            let kind: ReapedProcess.Kind
            if haystack.contains("grantiva-runner") {
                guard haystack.contains("--device \(needle)") || haystack.contains("--device=\(needle)") else { continue }
                kind = .runner
            } else if haystack.contains("test-without-building") {
                guard haystack.contains("id=\(needle)") else { continue }
                kind = .webDriverAgent
            } else if haystack.contains("diagnose") && haystack.contains("simctl") {
                guard haystack.contains("--udid=\(needle)") || haystack.contains("--udid \(needle)")
                    || haystack.contains(needle)
                else { continue }
                kind = .diagnose
            } else if haystack.contains("grantiva ") || haystack.hasSuffix("grantiva") {
                // A live `grantiva run` still holding the lease. This is the
                // usual culprit when `kill -INT` was ignored by a backgrounded
                // run, and it is the process the lease names.
                kind = .grantiva
            } else {
                continue
            }

            found.append(ReapedProcess(pid: pid, processGroup: pgid, kind: kind, command: command))
        }

        return found.sorted { $0.pid < $1.pid }
    }

    /// Snapshot of the host's processes in the format `processes(owning:)` parses.
    public static func processSnapshot() async throws -> String {
        try await shell("/bin/ps -axo pid=,pgid=,command=")
    }

    /// Kills everything holding `udid`, breaks the lease, and reconciles the
    /// capacity registry so the ownership check and the ledger agree again.
    public static func forceTeardown(
        udid: String,
        capacity: SimulatorCapacity = .live,
        leaseDirectory: String? = nil,
        snapshot: (() async throws -> String)? = nil,
        gracePeriod: TimeInterval = 3
    ) async throws -> ForceTeardownResult {
        let psOutput: String
        if let snapshot {
            psOutput = try await snapshot()
        } else {
            psOutput = try await processSnapshot()
        }
        var targets = processes(owning: udid, psOutput: psOutput, excludingPID: getpid())

        // The lease names its owner even when the command line does not carry
        // the UDID (a run started via `grantiva.yml` names the simulator, not
        // its UDID), so fold that pid in too.
        if let claim = SimulatorLease.claim(udid: udid, directory: leaseDirectory),
           claim.pid != getpid(),
           !targets.contains(where: { $0.pid == claim.pid }),
           kill(claim.pid, 0) == 0 || errno == EPERM {
            targets.append(ReapedProcess(
                pid: claim.pid,
                processGroup: claim.pid,
                kind: .grantiva,
                command: "grantiva (lease holder for \(udid))"
            ))
        }

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

        if !targets.isEmpty {
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

        let leaseReleased = SimulatorLease.forceRelease(udid: udid, directory: leaseDirectory)

        // Drop any capacity record for this device so the ownership check and
        // the session ledger agree again. `remove` never prunes other records,
        // so this stays safe without a simctl round-trip.
        let cleared = (try? capacity.remove(udid: udid)) ?? 0

        return ForceTeardownResult(
            udid: udid,
            processes: targets,
            leaseReleased: leaseReleased,
            capacityRecordsCleared: cleared
        )
    }
}
