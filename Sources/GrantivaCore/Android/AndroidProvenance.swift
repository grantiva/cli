import Darwin
import Foundation

public struct StartedEmulatorRecord: Codable, Equatable, Sendable {
    public let serial: String
    public let avd: String
    public let pid: Int32
    public let startedAt: Date

    public init(serial: String, avd: String, pid: Int32, startedAt: Date = Date()) {
        self.serial = serial
        self.avd = avd
        self.pid = pid
        self.startedAt = startedAt
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

    public func register(_ record: StartedEmulatorRecord) throws {
        try withLedgerLock { records in
            guard !records.contains(where: { $0.serial == record.serial }) else { return }
            records.append(record)
        }
    }

    public func contains(serial: String) throws -> Bool {
        try withLedgerLock { $0.contains { $0.serial == serial } }
    }

    public func remove(serial: String) throws {
        try withLedgerLock { $0.removeAll { $0.serial == serial } }
    }

    public func all() throws -> [StartedEmulatorRecord] {
        try withLedgerLock { $0 }
    }

    @discardableResult
    private func withLedgerLock<T>(_ body: (inout [StartedEmulatorRecord]) throws -> T) throws -> T {
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
        var records: [StartedEmulatorRecord] = []
        if let data = FileManager.default.contents(atPath: ledgerPath), !data.isEmpty {
            records = try JSONDecoder().decode([StartedEmulatorRecord].self, from: data)
        }
        let result = try body(&records)
        try JSONEncoder().encode(records).write(to: URL(fileURLWithPath: ledgerPath), options: .atomic)
        return result
    }
}
