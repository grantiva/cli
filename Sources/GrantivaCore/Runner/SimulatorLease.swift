import Darwin
import Foundation

/// The durable record of who owns a simulator, written into the lease file.
///
/// The `flock` is the authority on ownership, but a lock alone cannot say
/// *who* holds it, which is why "already owned by another Grantiva run" used to
/// be a dead end: `simulator sessions` tracks boot capacity, not runner
/// ownership, so the two ledgers legitimately disagreed and neither named a
/// process to stop. The claim is written when the lease is taken and cleared
/// when it is released — including on signal.
public struct SimulatorLeaseClaim: Codable, Sendable, Equatable {
    public let pid: Int32
    public let udid: String
    public let startedAt: Date
    public var runnerPID: Int32?
    public var keepAlive: Bool

    public init(pid: Int32, udid: String, startedAt: Date, runnerPID: Int32? = nil, keepAlive: Bool = false) {
        self.pid = pid
        self.udid = udid
        self.startedAt = startedAt
        self.runnerPID = runnerPID
        self.keepAlive = keepAlive
    }

    /// True when the process that wrote the claim is gone.
    public var isStale: Bool {
        kill(pid, 0) != 0 && errno != EPERM
    }
}

/// A cross-process lease that prevents two Grantiva runner invocations from
/// managing WebDriverAgent on the same simulator at the same time.
///
/// The embedded runner owns WDA for the lifetime of a test process. Starting a
/// second runner against the same UDID can replace the first runner's WDA
/// session and then tear it down. An advisory file lock makes that ownership
/// explicit while still allowing full concurrency across distinct simulators.
public final class SimulatorLease: @unchecked Sendable {
    private let descriptor: Int32
    public let udid: String
    public let path: String
    private var released = false
    private var claim: SimulatorLeaseClaim
    private let stateLock = NSLock()

    public static func directory(_ override: String? = nil) -> String {
        override ?? RunnerManager.baseDir + "/locks"
    }

    public static func leasePath(udid: String, directory: String? = nil) -> String {
        let directory = Self.directory(directory)
        let safeUDID = udid.replacingOccurrences(
            of: "[^A-Za-z0-9._-]",
            with: "_",
            options: .regularExpression
        )
        return "\(directory)/\(safeUDID).lock"
    }

    public static func acquire(
        udid: String,
        directory: String? = nil
    ) throws -> SimulatorLease {
        let directory = Self.directory(directory)
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )

        let path = leasePath(udid: udid, directory: directory)
        // O_CLOEXEC so the descriptor can never reach a spawned child and keep
        // the lock alive past this process. Foundation's `Process` and
        // `ChildProcess` both spawn with POSIX_SPAWN_CLOEXEC_DEFAULT already,
        // so this is defence in depth against a future spawn path that does not.
        let descriptor = Darwin.open(path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw GrantivaError.commandFailed(
                "Could not create simulator lease at \(path): \(String(cString: strerror(errno)))",
                1
            )
        }

        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let lockError = errno
            let holder = Self.claim(udid: udid, directory: directory)
            Darwin.close(descriptor)
            if lockError == EWOULDBLOCK {
                throw GrantivaError.commandFailed(ownershipMessage(udid: udid, holder: holder), 1)
            }
            throw GrantivaError.commandFailed(
                "Could not lock simulator \(udid): \(String(cString: strerror(lockError)))",
                1
            )
        }

        // The lock is free, but `runner start` hands its lease to the runner
        // process it leaves behind (see `handOff(to:)`), and that process holds
        // no descriptor. A live handed-off claim is ownership all the same.
        if let holder = Self.claim(udid: udid, directory: directory),
           holder.keepAlive, holder.pid != getpid(), !holder.isStale {
            flock(descriptor, LOCK_UN)
            Darwin.close(descriptor)
            throw GrantivaError.commandFailed(ownershipMessage(udid: udid, holder: holder), 1)
        }

        let claim = SimulatorLeaseClaim(pid: getpid(), udid: udid, startedAt: Date())
        let lease = SimulatorLease(descriptor: descriptor, udid: udid, path: path, claim: claim)
        lease.persistClaim()
        return lease
    }

    /// The message shown when a simulator is already owned. It names the owning
    /// process and the exact command that frees it, because the situation this
    /// error describes is otherwise invisible: `simulator sessions` tracks boot
    /// capacity, not runner ownership.
    static func ownershipMessage(udid: String, holder: SimulatorLeaseClaim?) -> String {
        var message = "Simulator \(udid) is already owned by another Grantiva run"
        if let holder {
            let age = Int(Date().timeIntervalSince(holder.startedAt))
            message += " (pid \(holder.pid), started \(age)s ago"
            if let runnerPID = holder.runnerPID {
                message += ", grantiva-runner pid \(runnerPID)"
            }
            if holder.keepAlive {
                message += ", --keep-alive"
            }
            message += ")"
        }
        message += ". Release it with `grantiva simulator teardown --udid \(udid) --force`, "
            + "or run against a different simulator via `grantiva simulator ensure --name <unique-name>`."
        return message
    }

    private init(descriptor: Int32, udid: String, path: String, claim: SimulatorLeaseClaim) {
        self.descriptor = descriptor
        self.udid = udid
        self.path = path
        self.claim = claim
    }

    /// Records the runner subprocess in the claim so a later `teardown --force`
    /// (or a human reading the lease file) can see exactly what to stop.
    public func recordRunner(pid: Int32, keepAlive: Bool) {
        stateLock.lock()
        claim.runnerPID = pid
        claim.keepAlive = keepAlive
        stateLock.unlock()
        persistClaim()
    }

    /// Transfers ownership to a process that outlives this one. `runner start`
    /// returns to the shell as soon as WDA is up, so a lock tied to its own
    /// descriptor would vanish while the runner still owns the simulator. The
    /// claim is rewritten in the runner's name, marked keep-alive, and left on
    /// disk when the descriptor closes; `acquire` treats it as held until that
    /// pid is gone or `runner stop` / `teardown --force` clears it.
    public func handOff(to runnerPID: Int32) {
        stateLock.lock()
        claim = SimulatorLeaseClaim(
            pid: runnerPID, udid: claim.udid, startedAt: claim.startedAt,
            runnerPID: runnerPID, keepAlive: true
        )
        stateLock.unlock()
        persistClaim()
        stateLock.lock()
        released = true
        stateLock.unlock()
        _ = flock(descriptor, LOCK_UN)
        Darwin.close(descriptor)
    }

    private func persistClaim() {
        stateLock.lock()
        let snapshot = claim
        let released = self.released
        stateLock.unlock()
        guard !released else { return }
        guard let data = try? JSONEncoder.leaseEncoder.encode(snapshot) else { return }
        _ = ftruncate(descriptor, 0)
        _ = lseek(descriptor, 0, SEEK_SET)
        data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            _ = Darwin.write(descriptor, base, buffer.count)
        }
    }

    /// Reads the claim recorded in a lease file, if any. Does not take the lock,
    /// so it is safe to call while another process holds it.
    public static func claim(udid: String, directory: String? = nil) -> SimulatorLeaseClaim? {
        let path = leasePath(udid: udid, directory: directory)
        guard let data = FileManager.default.contents(atPath: path), !data.isEmpty else { return nil }
        return try? JSONDecoder.leaseDecoder.decode(SimulatorLeaseClaim.self, from: data)
    }

    /// True when some live process holds the lease for `udid`.
    public static func isHeld(udid: String, directory: String? = nil) -> Bool {
        let path = leasePath(udid: udid, directory: directory)
        guard FileManager.default.fileExists(atPath: path) else { return false }
        let descriptor = Darwin.open(path, O_RDWR | O_CLOEXEC)
        guard descriptor >= 0 else { return false }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { return true }
        flock(descriptor, LOCK_UN)
        return false
    }

    /// Breaks a lease regardless of who holds it. Only for `teardown --force`,
    /// after the owning processes have been reaped: the claim is cleared and the
    /// lock file unlinked, so any descriptor still open on the old inode can no
    /// longer block a fresh acquisition.
    @discardableResult
    public static func forceRelease(udid: String, directory: String? = nil) -> Bool {
        let path = leasePath(udid: udid, directory: directory)
        guard FileManager.default.fileExists(atPath: path) else { return false }
        try? FileManager.default.removeItem(atPath: path)
        return true
    }

    /// Test hook: the lease descriptor must carry FD_CLOEXEC so it can never be
    /// inherited by a spawned child and keep the lock alive past this process.
    var descriptorIsCloseOnExec: Bool {
        let flags = fcntl(descriptor, F_GETFD)
        return flags >= 0 && (flags & FD_CLOEXEC) != 0
    }

    public func release() {
        stateLock.lock()
        guard !released else {
            stateLock.unlock()
            return
        }
        released = true
        stateLock.unlock()
        // Clear the claim before unlocking so nobody reads a claim for a lease
        // that is already free.
        _ = ftruncate(descriptor, 0)
        _ = flock(descriptor, LOCK_UN)
        Darwin.close(descriptor)
    }

    deinit {
        release()
    }
}

extension JSONEncoder {
    static let leaseEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}

extension JSONDecoder {
    static let leaseDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
