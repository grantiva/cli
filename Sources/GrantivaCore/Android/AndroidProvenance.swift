import Darwin
import Foundation

public struct StartedEmulatorRecord: Codable, Equatable, Sendable {
    public let serial: String
    public let avd: String
    public let pid: Int32
    public let startedAt: Date
    /// The process's own start time (seconds since 1970, from the kernel), so
    /// a pid the system reused for another process is not mistaken for this
    /// emulator. Absent in records written before it existed.
    public let processStartTime: Int64?

    public init(serial: String, avd: String, pid: Int32, startedAt: Date = Date(), processStartTime: Int64? = nil) {
        self.serial = serial
        self.avd = avd
        self.pid = pid
        self.startedAt = startedAt
        self.processStartTime = processStartTime
    }
}

/// Which emulators Grantiva itself booted. `emulator teardown` (Plan 3)
/// kills only these; nothing else ever touches an emulator the user started.
public struct AndroidProvenance: Sendable {
    public static let live = AndroidProvenance()

    public let directory: String

    public init(directory: String? = nil) {
        self.directory = directory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".grantiva/android").path
    }

    private var ledgerPath: String { "\(directory)/started.json" }

    /// A serial can be reused after an emulator exits, so a new record for
    /// the same serial replaces the old one instead of being dropped.
    public func register(_ record: StartedEmulatorRecord) throws {
        try withLedgerLock { records in
            records.removeAll { $0.serial == record.serial }
            records.append(record)
        }
    }

    public func contains(serial: String) throws -> Bool {
        try withLedgerLock { $0.contains { $0.serial == serial } }
    }

    public func remove(serial: String) throws {
        try withLedgerLock { $0.removeAll { $0.serial == serial } }
    }

    /// Removes the record for `serial` only when it is the one for `pid`: a
    /// boot that failed drops its own record, never one another process holds
    /// for the same serial.
    public func remove(serial: String, pid: Int32) throws {
        try withLedgerLock { $0.removeAll { $0.serial == serial && $0.pid == pid } }
    }

    /// Serialises choosing a serial, spawning the emulator and recording it
    /// across processes, so two boots cannot pick the same port before either
    /// is listed by adb or binds its console. The body may suspend; it must
    /// not wait for the boot itself. Its own lock file, so the body can
    /// `register`.
    public func withBootLock<T>(_ body: () async throws -> T) async throws -> T {
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let descriptor = Darwin.open("\(directory)/boot.lock", O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw GrantivaError.commandFailed("Could not open the emulator boot lock: \(String(cString: strerror(errno)))", 1)
        }
        defer { Darwin.close(descriptor) }
        while flock(descriptor, LOCK_EX) != 0 {
            guard errno == EINTR else {
                throw GrantivaError.commandFailed("Could not lock the emulator boot lock: \(String(cString: strerror(errno)))", 1)
            }
        }
        defer { flock(descriptor, LOCK_UN) }
        return try await body()
    }

    public func all() throws -> [StartedEmulatorRecord] {
        try withLedgerLock { $0 }
    }

    // MARK: Created AVDs

    private var createdPath: String { "\(directory)/created-avds.json" }

    /// AVDs `emulator ensure` created. `emulator delete` refuses any other
    /// AVD without `--force`.
    public func registerCreatedAVD(_ name: String) throws {
        try withCreatedLock { names in
            guard !names.contains(name) else { return }
            names.append(name)
        }
    }

    public func createdAVDs() throws -> [String] {
        try withCreatedLock { $0 }
    }

    /// Drops the names in `candidates` that are not in `existing`; returns
    /// the ones dropped. `candidates` is the ledger as read before `existing`
    /// was listed, so a name another process registered after the listing
    /// is never dropped for missing from it.
    @discardableResult
    public func pruneCreatedAVDs(keeping existing: [String], among candidates: [String]) throws -> [String] {
        try withCreatedLock { names in
            let gone = names.filter { candidates.contains($0) && !existing.contains($0) }
            names.removeAll { gone.contains($0) }
            return gone
        }
    }

    public func removeCreatedAVD(_ name: String) throws {
        try withCreatedLock { $0.removeAll { $0 == name } }
    }

    @discardableResult
    private func withCreatedLock<T>(_ body: (inout [String]) throws -> T) throws -> T {
        try withLockedJSON(at: createdPath, body)
    }

    @discardableResult
    private func withLedgerLock<T>(_ body: (inout [StartedEmulatorRecord]) throws -> T) throws -> T {
        try withLockedJSON(at: ledgerPath, body)
    }

    /// Both ledgers serialise on the same `ledger.lock`, read the JSON array
    /// at `path`, let `body` mutate it, and write it back atomically.
    @discardableResult
    private func withLockedJSON<E: Codable, T>(at path: String, _ body: (inout [E]) throws -> T) throws -> T {
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let descriptor = Darwin.open("\(directory)/ledger.lock", O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw GrantivaError.commandFailed("Could not open the emulator ledger lock: \(String(cString: strerror(errno)))", 1)
        }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else {
            throw GrantivaError.commandFailed("Could not lock the emulator ledger: \(String(cString: strerror(errno)))", 1)
        }
        defer { flock(descriptor, LOCK_UN) }
        var elements: [E] = []
        if let data = FileManager.default.contents(atPath: path), !data.isEmpty {
            elements = try JSONDecoder().decode([E].self, from: data)
        }
        let result = try body(&elements)
        try JSONEncoder().encode(elements).write(to: URL(fileURLWithPath: path), options: .atomic)
        return result
    }
}
