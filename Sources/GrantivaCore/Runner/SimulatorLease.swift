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
    /// True when `runner start` handed the lease to the runner it left
    /// running: the holder is a session, released with `grantiva runner stop`,
    /// not a `run --keep-alive`. Absent in claims written by earlier versions.
    public var handedOff: Bool?
    /// The directory `runner start` ran in, where `runner stop` finds the
    /// session. Recorded on hand-off.
    public var projectDirectory: String?
    /// Temp directories the run created (its staged flows, its ephemeral
    /// report dir). A clean exit removes them; `simulator teardown --force`
    /// removes them for a run that was killed before it could.
    public var temporaryDirectories: [String]?

    public init(
        pid: Int32, udid: String, startedAt: Date, runnerPID: Int32? = nil, keepAlive: Bool = false,
        handedOff: Bool? = nil, projectDirectory: String? = nil, temporaryDirectories: [String]? = nil
    ) {
        self.pid = pid
        self.udid = udid
        self.startedAt = startedAt
        self.runnerPID = runnerPID
        self.keepAlive = keepAlive
        self.handedOff = handedOff
        self.projectDirectory = projectDirectory
        self.temporaryDirectories = temporaryDirectories
    }

    /// True when the process that wrote the claim is gone.
    public var isStale: Bool {
        !Self.isAlive(pid)
    }

    /// True while the claim's process or its runner is still running.
    public var isLive: Bool {
        Self.isAlive(pid) || runnerPID.map(Self.isAlive) == true
    }

    /// A `runner start` session's claim. Claims from before `handedOff`
    /// existed are recognised by their shape: the runner is its own owner.
    public var isRunnerStartSession: Bool {
        handedOff == true || (handedOff == nil && keepAlive && runnerPID == pid)
    }

    static func isAlive(_ pid: Int32) -> Bool {
        pid > 0 && (kill(pid, 0) == 0 || errno == EPERM)
    }
}

/// One run's temp directories in a device's ledger (B3-L35).
///
/// The lease claim names only the current holder's temp directories, and the
/// next run on the device overwrites it, so a force teardown after several
/// killed runs used to find only the last one's. Each run's directories are
/// therefore also kept in `<udid>.tmpdirs.json` beside the lease file, which
/// no claim overwrites; a teardown removes those of every run that is gone.
public struct TemporaryDirectoryRecord: Codable, Sendable, Equatable {
    public let pid: Int32
    public var runnerPID: Int32?
    public var paths: [String]

    public init(pid: Int32, runnerPID: Int32?, paths: [String]) {
        self.pid = pid
        self.runnerPID = runnerPID
        self.paths = paths
    }

    /// True while the run or its runner is still running.
    public var isLive: Bool {
        SimulatorLeaseClaim.isAlive(pid) || runnerPID.map(SimulatorLeaseClaim.isAlive) == true
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
    /// The interrupt cleanup that removes this run's temp directories (C14).
    private var temporaryDirectoryCleanup: UInt64?
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

    /// Test hook: runs between `open` and `flock` in `acquire`, where a
    /// holder releasing (and unlinking) the file is the race to survive.
    /// Unsynchronized: it assumes XCTest runs tests serially (the default
    /// for `swift test`), so only the test that sets it can observe it.
    nonisolated(unsafe) static var afterOpenForTesting: ((String) -> Void)?

    /// Test hook: called with the UDID whenever `acquire` is about to use the
    /// default directory (`<runner home>/locks`). Test bundles install one
    /// that fails the test and throws. Set once before tests run.
    nonisolated(unsafe) static var defaultDirectoryUseForTesting: ((String) throws -> Void)?

    /// Whether XCTest is loaded in this process. The grantiva binary never
    /// loads it; a test bundle always does. Only debug builds (the ones
    /// `swift test` runs) probe for it; a release build never evaluates it.
    #if DEBUG
    static let runningUnderXCTest = NSClassFromString("XCTestCase") != nil
    #else
    static let runningUnderXCTest = false
    #endif

    /// Under XCTest a lease without an explicit directory is refused, hook
    /// or not, so no test can take a lease in, or create, the user's runner
    /// home (K107-b) even when run alone with `--filter`.
    static func checkDefaultDirectoryUse(udid: String) throws {
        if let hook = defaultDirectoryUseForTesting {
            try hook(udid)
        } else if runningUnderXCTest {
            throw GrantivaError.commandFailed(
                "A test asked for the simulator lease for \(udid) in the default directory \(directory()); give it a temp lease directory.", 1
            )
        }
    }

    public static func acquire(
        udid: String,
        platform: Platform = .ios,
        directory: String? = nil
    ) throws -> SimulatorLease {
        if directory == nil { try checkDefaultDirectoryUse(udid: udid) }
        let directory = Self.directory(directory)
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )

        let path = leasePath(udid: udid, directory: directory)
        // `release()` unlinks the file. A process that opened it just before
        // can then lock an inode no longer at `path`, which nobody else will
        // ever contend for; it must let go and open the file anew.
        for _ in 0..<100 {
            if let lease = try acquireOnce(udid: udid, platform: platform, directory: directory, path: path) {
                return lease
            }
        }
        throw GrantivaError.commandFailed("Could not lock simulator \(udid): its lease file at \(path) kept changing.", 1)
    }

    /// One attempt; nil when the file locked was unlinked meanwhile.
    private static func acquireOnce(
        udid: String, platform: Platform, directory: String, path: String
    ) throws -> SimulatorLease? {
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
        afterOpenForTesting?(path)

        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let lockError = errno
            let holder = Self.claim(udid: udid, directory: directory)
            Darwin.close(descriptor)
            if lockError == EWOULDBLOCK {
                throw GrantivaError.commandFailed(ownershipMessage(udid: udid, holder: holder, platform: platform), 1)
            }
            throw GrantivaError.commandFailed(
                "Could not lock simulator \(udid): \(String(cString: strerror(lockError)))",
                1
            )
        }

        guard isFile(descriptor, at: path) else {
            flock(descriptor, LOCK_UN)
            Darwin.close(descriptor)
            return nil
        }

        // The lock is free, but `runner start` hands its lease to the runner
        // process it leaves behind (see `handOff(to:)`), and that process holds
        // no descriptor. A live handed-off claim is ownership all the same.
        if let holder = Self.claim(udid: udid, directory: directory),
           holder.keepAlive, holder.pid != getpid(), !holder.isStale {
            flock(descriptor, LOCK_UN)
            Darwin.close(descriptor)
            throw GrantivaError.commandFailed(ownershipMessage(udid: udid, holder: holder, platform: platform), 1)
        }

        let claim = SimulatorLeaseClaim(pid: getpid(), udid: udid, startedAt: Date())
        let lease = SimulatorLease(descriptor: descriptor, udid: udid, path: path, claim: claim)
        lease.persistClaim()
        return lease
    }

    /// Whether `descriptor` is the file currently at `path` (same device and
    /// inode); false when the path is gone or now names another file.
    private static func isFile(_ descriptor: Int32, at path: String) -> Bool {
        var open = stat()
        var current = stat()
        guard fstat(descriptor, &open) == 0, stat(path, &current) == 0 else { return false }
        return open.st_dev == current.st_dev && open.st_ino == current.st_ino
    }

    /// True when `error` is the refusal `ownershipMessage` builds: the device
    /// belongs to another run or session, so this run never touched it (no
    /// failure screenshot of it).
    public static func isOwnershipRefusal(_ error: Error) -> Bool {
        guard case GrantivaError.commandFailed(let message, _)? = error as? GrantivaError else { return false }
        return message.contains(ownershipMarker) || message.contains(sessionMarker)
    }

    private static let ownershipMarker = " is already owned by another Grantiva run"
    private static let sessionMarker = " is held by a `grantiva runner start` session"

    /// The message shown when a simulator is already owned. It names the owning
    /// process and the exact command that frees it, because the situation this
    /// error describes is otherwise invisible: `simulator sessions` tracks boot
    /// capacity, not runner ownership. A `runner start` session is named as
    /// one and released with `runner stop`, not reclaimed by force.
    ///
    /// "started Ns ago" is the holder process's age: the claim is written
    /// when the lease is taken, which can be well after the process started
    /// (it boots the device first), so the earlier of the two is used. A
    /// process younger than its claim (a reused pid, or the runner a
    /// `runner start` handed off to) never shortens the age.
    static func ownershipMessage(
        udid: String, holder: SimulatorLeaseClaim?, platform: Platform = .ios,
        processStart: (Int32) -> Date? = ProcessLookup.startTime(of:)
    ) -> String {
        func age(_ holder: SimulatorLeaseClaim) -> Int {
            let started = processStart(holder.pid).map { min($0, holder.startedAt) } ?? holder.startedAt
            return max(0, Int(Date().timeIntervalSince(started)))
        }
        if let holder, holder.isRunnerStartSession {
            let age = age(holder)
            var message = "\(platform == .ios ? "Simulator" : "Emulator") \(udid)\(sessionMarker) "
                + "(grantiva-runner pid \(holder.runnerPID ?? holder.pid), started \(age)s ago). "
                + "Stop it with `grantiva runner stop`"
            if let directory = holder.projectDirectory { message += " (from \(directory))" }
            message += platform == .ios
                ? ", or use another simulator via `grantiva simulator ensure --name <unique-name>`."
                : ", or use another emulator via `grantiva emulator ensure --name <unique-name>`."
            return message
        }
        var message = platform == .ios
            ? "Simulator \(udid)\(ownershipMarker)"
            : "Emulator \(udid)\(ownershipMarker)"
        if let holder {
            let age = age(holder)
            message += " (pid \(holder.pid), started \(age)s ago"
            if let runnerPID = holder.runnerPID {
                message += ", grantiva-runner pid \(runnerPID)"
            }
            if holder.keepAlive {
                message += ", --keep-alive"
            }
            message += ")"
        }
        if platform == .ios {
            message += ". Release it with `grantiva simulator teardown --udid \(udid) --force`, "
                + "or run against a different simulator via `grantiva simulator ensure --name <unique-name>`."
        } else {
            message += ". Release it with `grantiva emulator teardown --serial \(udid) --force`, "
                + "or run against a different emulator via `grantiva emulator ensure --name <unique-name>`."
        }
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

    /// Records a temp directory this run created, so a reclaim after the run
    /// was killed can remove it (see `SimulatorLeaseClaim.temporaryDirectories`).
    ///
    /// An interrupt (SIGINT/SIGTERM through `SignalRelay`) removes them too,
    /// as the run's own `defer`s would have: the process exits from the
    /// relay, so those never run (C14).
    public func recordTemporaryDirectory(_ path: String) {
        stateLock.lock()
        claim.temporaryDirectories = (claim.temporaryDirectories ?? []) + [path]
        let needsCleanup = temporaryDirectoryCleanup == nil && !released
        stateLock.unlock()
        if needsCleanup {
            let token = SignalRelay.shared.onTermination { [weak self] in self?.removeTemporaryDirectories() }
            stateLock.lock()
            temporaryDirectoryCleanup = token
            stateLock.unlock()
        }
        persistClaim()
    }

    /// Removes the temp directories this run recorded.
    func removeTemporaryDirectories() {
        stateLock.lock()
        let paths = released ? [] : (claim.temporaryDirectories ?? [])
        stateLock.unlock()
        for path in paths { try? FileManager.default.removeItem(atPath: path) }
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
            runnerPID: runnerPID, keepAlive: true, handedOff: true,
            projectDirectory: FileManager.default.currentDirectoryPath
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
        if let directories = snapshot.temporaryDirectories, !directories.isEmpty {
            Self.recordTemporaryDirectories(
                directories, pid: snapshot.pid, runnerPID: snapshot.runnerPID, ledgerPath: Self.ledgerPath(forLeasePath: path)
            )
        }
    }

    // MARK: - The device's temp directory ledger (B3-L35)

    static func ledgerPath(forLeasePath leasePath: String) -> String {
        (leasePath.hasSuffix(".lock") ? String(leasePath.dropLast(".lock".count)) : leasePath) + ".tmpdirs.json"
    }

    /// Where `udid`'s ledger of run temp directories lives, beside its lease.
    public static func temporaryDirectoryLedgerPath(udid: String, directory: String? = nil) -> String {
        ledgerPath(forLeasePath: leasePath(udid: udid, directory: directory))
    }

    /// The runs whose temp directories `udid`'s ledger names.
    public static func temporaryDirectoryRecords(udid: String, directory: String? = nil) -> [TemporaryDirectoryRecord] {
        loadLedger(temporaryDirectoryLedgerPath(udid: udid, directory: directory))
    }

    /// Records that run `pid` (with runner `runnerPID`) created `paths` on
    /// `udid`, replacing that run's earlier record.
    public static func recordTemporaryDirectories(
        _ paths: [String], pid: Int32, runnerPID: Int32?, udid: String, directory: String? = nil
    ) {
        recordTemporaryDirectories(
            paths, pid: pid, runnerPID: runnerPID, ledgerPath: temporaryDirectoryLedgerPath(udid: udid, directory: directory)
        )
    }

    static func recordTemporaryDirectories(_ paths: [String], pid: Int32, runnerPID: Int32?, ledgerPath: String) {
        var records = loadLedger(ledgerPath).filter { $0.pid != pid }
        records.append(TemporaryDirectoryRecord(pid: pid, runnerPID: runnerPID, paths: paths))
        saveLedger(pruned(records, keeping: pid), to: ledgerPath)
    }

    /// Drops records whose directories are all gone (a run that ended
    /// cleanly removed them), except `pid`'s.
    static func pruned(_ records: [TemporaryDirectoryRecord], keeping pid: Int32? = nil) -> [TemporaryDirectoryRecord] {
        records.filter { record in
            record.pid == pid || record.paths.contains { FileManager.default.fileExists(atPath: $0) }
        }
    }

    static func loadLedger(_ path: String) -> [TemporaryDirectoryRecord] {
        guard let data = FileManager.default.contents(atPath: path), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([TemporaryDirectoryRecord].self, from: data)) ?? []
    }

    /// Writes `records`, or removes the ledger when there are none.
    static func saveLedger(_ records: [TemporaryDirectoryRecord], to path: String) {
        guard !records.isEmpty else {
            try? FileManager.default.removeItem(atPath: path)
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(records) else { return }
        try? FileManager.default.createDirectory(
            atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true
        )
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    /// Replaces `udid`'s ledger with `records` (empty removes it).
    public static func saveTemporaryDirectoryRecords(_ records: [TemporaryDirectoryRecord], udid: String, directory: String? = nil) {
        saveLedger(records, to: temporaryDirectoryLedgerPath(udid: udid, directory: directory))
    }

    /// Reads the claim recorded in a lease file, if any. Does not take the lock,
    /// so it is safe to call while another process holds it.
    public static func claim(udid: String, directory: String? = nil) -> SimulatorLeaseClaim? {
        let path = leasePath(udid: udid, directory: directory)
        guard let data = FileManager.default.contents(atPath: path), !data.isEmpty else { return nil }
        return try? JSONDecoder.leaseDecoder.decode(SimulatorLeaseClaim.self, from: data)
    }

    /// Breaks a lease regardless of who holds it. Only for `teardown --force`
    /// and `runner stop`: the claim is cleared and the lock file unlinked, so
    /// any descriptor still open on the old inode can no longer block a fresh
    /// acquisition. Returns whether the lease was held (see `isHeld`); a file
    /// left by a run that ended is removed too, but freeing it is no release.
    @discardableResult
    public static func forceRelease(udid: String, directory: String? = nil) -> Bool {
        let held = isHeld(udid: udid, directory: directory)
        removeLeaseFile(udid: udid, directory: directory)
        return held
    }

    /// Unlinks the lease file whoever holds it (see `forceRelease`).
    static func removeLeaseFile(udid: String, directory: String? = nil) {
        try? FileManager.default.removeItem(atPath: leasePath(udid: udid, directory: directory))
    }

    /// Why a device is in use, for commands that leave a busy device alone:
    /// who holds it and how that holder is ended, never a forced reclaim.
    static func inUseMessage(udid: String, holder: SimulatorLeaseClaim?) -> String {
        guard let holder else {
            return "Simulator \(udid) is in use by another Grantiva run; it was left as it is. Run teardown again once that run ends."
        }
        if holder.isRunnerStartSession {
            var message = "Simulator \(udid) is in use by a `grantiva runner start` session (grantiva-runner pid \(holder.runnerPID ?? holder.pid)); it was left as it is. "
                + "Stop it with `grantiva runner stop`"
            if let directory = holder.projectDirectory { message += " (from \(directory))" }
            return message + ", then run teardown again."
        }
        var owner = "grantiva pid \(holder.pid)"
        if let runnerPID = holder.runnerPID { owner += ", grantiva-runner pid \(runnerPID)" }
        if holder.keepAlive { owner += ", --keep-alive" }
        return "Simulator \(udid) is in use by a Grantiva run (\(owner)); it was left as it is. "
            + "End that run (Ctrl-C), then run teardown again."
    }

    /// Whether someone holds the lease: its `flock` is taken by another open
    /// file, or the file carries a claim whose process or runner is alive
    /// (a `runner start` hand-off holds no descriptor).
    public static func isHeld(udid: String, directory: String? = nil) -> Bool {
        if claim(udid: udid, directory: directory)?.isLive == true { return true }
        let descriptor = Darwin.open(leasePath(udid: udid, directory: directory), O_RDWR | O_CLOEXEC)
        guard descriptor >= 0 else { return false }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { return errno == EWOULDBLOCK }
        flock(descriptor, LOCK_UN)
        return false
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
        let cleanup = temporaryDirectoryCleanup
        temporaryDirectoryCleanup = nil
        stateLock.unlock()
        if let cleanup { SignalRelay.shared.removeCleanup(cleanup) }
        // Clear the claim and unlink the file before unlocking, so nobody
        // reads a claim for a lease that is already free and no lock file
        // outlives its run. A process that opened the file before the unlink
        // sees, once it gets the lock, that the path no longer names it and
        // retries (see `acquire`). A file that `forceRelease` already replaced
        // belongs to someone else and is left alone.
        _ = ftruncate(descriptor, 0)
        if Self.isFile(descriptor, at: path) {
            _ = unlink(path)
        }
        // A run that ended cleanly has removed its temp directories: its
        // ledger record (and any other whose directories are gone) goes.
        let ledger = Self.ledgerPath(forLeasePath: path)
        if FileManager.default.fileExists(atPath: ledger) {
            Self.saveLedger(Self.pruned(Self.loadLedger(ledger)), to: ledger)
        }
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
