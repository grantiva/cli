import Darwin
import Foundation

public struct CreatedSimulatorRecord: Codable, Equatable, Sendable {
    public let udid: String
    public let name: String
    public let createdAt: Date

    public init(udid: String, name: String, createdAt: Date = Date()) {
        self.udid = udid
        self.name = name
        self.createdAt = createdAt
    }
}

public struct SimulatorTeardownOutcome: Codable, Equatable, Sendable {
    public let session: ManagedSimulatorSession
    public let deleted: Bool

    public init(session: ManagedSimulatorSession, deleted: Bool) {
        self.session = session
        self.deleted = deleted
    }
}

/// Durable record of every simulator Grantiva itself created.
///
/// The capacity registry intentionally forgets shutdown simulators, so it
/// cannot answer "did Grantiva create this device?" after a session ends.
/// This ledger persists that provenance so teardown and cleanup can safely
/// delete Grantiva-created simulators while never touching devices the user
/// created themselves. Mutations are serialized with `flock`, and the same
/// lock guards the ensure look-up/create critical section so two concurrent
/// agents can never create duplicate simulators with one name.
public struct SimulatorProvenance: Sendable {
    public static let live = SimulatorProvenance()

    public let directory: String

    public init(directory: String? = nil) {
        self.directory = directory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".grantiva/simulator-capacity").path
    }

    private var ledgerPath: String { "\(directory)/created.json" }

    public func register(udid: String, name: String) throws {
        try withLedgerLock { records in
            guard !records.contains(where: { $0.udid == udid }) else { return }
            records.append(CreatedSimulatorRecord(udid: udid, name: name))
        }
    }

    public func contains(udid: String) throws -> Bool {
        try withLedgerLock { records in records.contains { $0.udid == udid } }
    }

    public func remove(udid: String) throws {
        try withLedgerLock { records in records.removeAll { $0.udid == udid } }
    }

    public func all() throws -> [CreatedSimulatorRecord] {
        try withLedgerLock { $0 }
    }

    /// Serializes a provisioning critical section across processes. Unlike
    /// `withLedgerLock`, the body may suspend (it runs `simctl`), so the lock
    /// handle is held across awaits and released in `defer`. This uses a lock
    /// file distinct from the ledger's so the body can call `register` without
    /// self-deadlocking.
    public func withProvisioningLock<T>(_ body: () async throws -> T) async throws -> T {
        let descriptor = try acquireLock(path: "\(directory)/provisioning.lock")
        defer {
            flock(descriptor, LOCK_UN)
            Darwin.close(descriptor)
        }
        return try await body()
    }

    private func acquireLock(path lockPath: String) throws -> Int32 {
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let descriptor = Darwin.open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw GrantivaError.commandFailed("Could not open simulator provenance lock: \(String(cString: strerror(errno)))", 1)
        }
        guard flock(descriptor, LOCK_EX) == 0 else {
            let lockError = errno
            Darwin.close(descriptor)
            throw GrantivaError.commandFailed("Could not acquire simulator provenance lock: \(String(cString: strerror(lockError)))", 1)
        }
        return descriptor
    }

    @discardableResult
    private func withLedgerLock<T>(_ body: (inout [CreatedSimulatorRecord]) throws -> T) throws -> T {
        let descriptor = try acquireLock(path: "\(directory)/ledger.lock")
        defer {
            flock(descriptor, LOCK_UN)
            Darwin.close(descriptor)
        }
        var records: [CreatedSimulatorRecord] = []
        if let data = FileManager.default.contents(atPath: ledgerPath), !data.isEmpty {
            records = try JSONDecoder().decode([CreatedSimulatorRecord].self, from: data)
        }
        let result = try body(&records)
        let data = try JSONEncoder().encode(records)
        try data.write(to: URL(fileURLWithPath: ledgerPath), options: .atomic)
        return result
    }
}
