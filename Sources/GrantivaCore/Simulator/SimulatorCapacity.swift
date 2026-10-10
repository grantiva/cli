import Darwin
import Foundation

public struct ManagedSimulatorSession: Codable, Equatable, Sendable {
    public enum State: String, Codable, Sendable { case pending, active }

    public let udid: String
    public let name: String
    public let sessionId: String
    public let ownerPID: Int32
    public let acquiredAt: Date
    public var state: State
    /// True only when Grantiva itself issued `simctl boot` for this device.
    /// Teardown shuts a device down only when this is true; nil (a record
    /// written by 2.0.1 or earlier) or false leaves the device running.
    public var bootedByGrantiva: Bool?
    /// True for a record taken by a single run (`grantiva run`, `diff`, ...)
    /// rather than by `simulator ensure`. Without a session ID, such a record
    /// lives only as long as its owner process. nil is a record written by
    /// 2.0.1 or earlier and is treated as ephemeral.
    public var ephemeral: Bool?

    public init(
        udid: String,
        name: String,
        sessionId: String,
        ownerPID: Int32,
        acquiredAt: Date,
        state: State,
        bootedByGrantiva: Bool? = nil,
        ephemeral: Bool? = nil
    ) {
        self.udid = udid
        self.name = name
        self.sessionId = sessionId
        self.ownerPID = ownerPID
        self.acquiredAt = acquiredAt
        self.state = state
        self.bootedByGrantiva = bootedByGrantiva
        self.ephemeral = ephemeral
    }

    /// Whether the record was taken by a run with no `GRANTIVA_SESSION_ID`.
    var isSessionless: Bool { sessionId == SimulatorCapacity.sessionlessOwner(udid: udid) }
}

/// A capacity record that `teardown --udid --force` left in place, and why.
public struct KeptCapacityRecord: Codable, Equatable, Sendable {
    public let udid: String
    public let sessionId: String
    public let reason: String

    public init(udid: String, sessionId: String, reason: String) {
        self.udid = udid
        self.sessionId = sessionId
        self.reason = reason
    }
}

/// Host-wide admission control for simulators booted by Grantiva.
///
/// Records persist after an individual CLI process exits because a simulator is
/// intentionally retained for the lifetime of its ticket session. All registry
/// mutations are serialized with `flock`, making admission atomic across agents.
public struct SimulatorCapacity: Sendable {
    public static let live = SimulatorCapacity()

    public let directory: String
    public let maximum: Int
    public let waitTimeout: TimeInterval
    public let pollInterval: TimeInterval

    public init(
        directory: String? = nil,
        maximum: Int? = nil,
        waitTimeout: TimeInterval? = nil,
        pollInterval: TimeInterval = 1
    ) {
        let environment = ProcessInfo.processInfo.environment
        self.directory = directory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".grantiva/simulator-capacity").path
        self.maximum = maximum ?? Self.positiveInt(environment["GRANTIVA_MAX_SIMULATORS"]) ?? 4
        self.waitTimeout = waitTimeout ?? Self.nonnegativeDouble(environment["GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS"]) ?? 600
        self.pollInterval = pollInterval
    }

    public var sessionId: String? {
        let value = ProcessInfo.processInfo.environment["GRANTIVA_SESSION_ID"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.flatMap { $0.isEmpty ? nil : $0 }
    }

    public func reserve(
        device: SimulatorDevice,
        ephemeral: Bool = false,
        devices: @Sendable () async throws -> [SimulatorDevice],
        onWait: @Sendable ([ManagedSimulatorSession], TimeInterval) -> Void = { _, _ in }
    ) async throws -> ManagedSimulatorSession {
        let owner = sessionId ?? Self.sessionlessOwner(udid: device.udid)
        let start = Date()

        while true {
            let currentDevices = try await devices()
            let outcome = try withRegistryLock { records in
                Self.prune(&records, devices: currentDevices)

                if let index = records.firstIndex(where: { $0.udid == device.udid }) {
                    // A durable holder (`ensure`) reusing a run's record keeps it.
                    if !ephemeral { records[index].ephemeral = false }
                    let existing = records[index]
                    guard existing.sessionId == owner else {
                        throw GrantivaError.commandFailed(
                            "Simulator \(device.name) (\(device.udid)) belongs to Grantiva session "
                                + "\(existing.sessionId). Teardown that session or select another simulator.",
                            1
                        )
                    }
                    if existing.state == .pending && existing.ownerPID != getpid() {
                        return ReservationOutcome.full(records)
                    }
                    return ReservationOutcome.acquired(existing)
                }

                if records.count < maximum {
                    let record = ManagedSimulatorSession(
                        udid: device.udid,
                        name: device.name,
                        sessionId: owner,
                        ownerPID: getpid(),
                        acquiredAt: Date(),
                        state: .pending,
                        ephemeral: ephemeral
                    )
                    records.append(record)
                    return ReservationOutcome.acquired(record)
                }
                return ReservationOutcome.full(records)
            }

            switch outcome {
            case .acquired(let record):
                return record
            case .full(let records):
                let elapsed = Date().timeIntervalSince(start)
                guard elapsed < waitTimeout else {
                    let owners = records.map { "\($0.name) [\($0.sessionId)]" }.joined(separator: ", ")
                    throw GrantivaError.commandFailed(
                        "Timed out after \(Int(waitTimeout))s waiting for a Grantiva simulator slot "
                            + "(limit \(maximum)). Active: \(owners). "
                            + "Release one with `grantiva simulator teardown --session-id <id>`.",
                        1
                    )
                }
                onWait(records, elapsed)
                try await Task.sleep(for: .seconds(pollInterval))
            }
        }
    }

    /// Marks the reservation active. `bootedByGrantiva` records that this
    /// process issued the boot; it never clears an earlier `true`.
    public func activate(udid: String, bootedByGrantiva: Bool = false) throws {
        try withRegistryLock { records in
            guard let index = records.firstIndex(where: { $0.udid == udid }) else { return }
            records[index].state = .active
            if bootedByGrantiva { records[index].bootedByGrantiva = true }
        }
    }

    /// Under the registry lock: when every record for `udid` belongs to this
    /// process, replaces them with one `pending` record owned by this process
    /// and returns true; otherwise changes nothing and returns false. The
    /// pending record makes any other `reserve` for the device wait until it
    /// is removed with `remove(udid:ownedBy:)`.
    public func claimForRemoval(udid: String, name: String) throws -> Bool {
        try withRegistryLock { records in
            let me = getpid()
            guard records.allSatisfy({ $0.udid != udid || $0.ownerPID == me }) else { return false }
            records.removeAll { $0.udid == udid }
            records.append(ManagedSimulatorSession(
                udid: udid, name: name, sessionId: sessionId ?? Self.sessionlessOwner(udid: udid),
                ownerPID: me, acquiredAt: Date(), state: .pending, ephemeral: true
            ))
            return true
        }
    }

    /// Every record for `udid`, without pruning.
    public func records(udid: String) throws -> [ManagedSimulatorSession] {
        try withRegistryLock { records in records.filter { $0.udid == udid } }
    }

    /// Removes the records for `udid` owned by process `pid`, leaving any
    /// other process's record in place.
    @discardableResult
    public func remove(udid: String, ownedBy pid: Int32) throws -> Int {
        try withRegistryLock { records in
            let before = records.count
            records.removeAll { $0.udid == udid && $0.ownerPID == pid }
            return before - records.count
        }
    }

    public func releaseReservation(udid: String) throws {
        try withRegistryLock { records in
            records.removeAll { $0.udid == udid && $0.state == .pending }
        }
    }

    /// Removes every record for `udid`, returning how many were dropped. Unlike
    /// `sessions(devices:)` this never prunes other records, so it is safe to
    /// call when the device list is unavailable.
    @discardableResult
    public func remove(udid: String) throws -> Int {
        try withRegistryLock { records in
            let before = records.count
            records.removeAll { $0.udid == udid }
            return before - records.count
        }
    }

    /// Removes the records for `udid` that are stale after a forced reclaim,
    /// and reports the ones kept and why. A record is stale when it is still
    /// `pending` (a reservation whose boot never finished), or when it has no
    /// session ID and its owner process is dead. A named session's record is
    /// never stale while its device is booted, whatever its owner pid: the
    /// session outlives the CLI process, and `teardown --session-id` must
    /// still find the device.
    public func removeStale(
        udid: String,
        isProcessAlive: (Int32) -> Bool = KeepAliveSessionStore.processIsAlive
    ) throws -> (cleared: Int, kept: [KeptCapacityRecord]) {
        try withRegistryLock { records in
            var kept: [KeptCapacityRecord] = []
            let before = records.count
            records.removeAll { record in
                guard record.udid == udid else { return false }
                guard let reason = Self.keepReason(for: record, isProcessAlive: isProcessAlive) else {
                    return true
                }
                kept.append(KeptCapacityRecord(udid: record.udid, sessionId: record.sessionId, reason: reason))
                return false
            }
            return (before - records.count, kept)
        }
    }

    /// Why a forced reclaim must keep `record`, or nil when it is stale.
    static func keepReason(
        for record: ManagedSimulatorSession,
        isProcessAlive: (Int32) -> Bool
    ) -> String? {
        if record.state == .pending { return nil }
        if record.isSessionless {
            guard isProcessAlive(record.ownerPID) else { return nil }
            return "owner pid \(record.ownerPID) is still running"
        }
        return "session \(record.sessionId) owns this simulator until `grantiva simulator teardown --session-id \(record.sessionId)`"
    }

    public func sessions(devices: [SimulatorDevice]) throws -> [ManagedSimulatorSession] {
        try withRegistryLock { records in
            Self.prune(&records, devices: devices)
            return records.sorted { $0.acquiredAt < $1.acquiredAt }
        }
    }

    public func sessions(sessionId: String, devices: [SimulatorDevice]) throws -> [ManagedSimulatorSession] {
        try sessions(devices: devices).filter { $0.sessionId == sessionId }
    }

    private enum ReservationOutcome {
        case acquired(ManagedSimulatorSession)
        case full([ManagedSimulatorSession])
    }

    private var registryPath: String { "\(directory)/sessions.json" }
    private var lockPath: String { "\(directory)/registry.lock" }

    @discardableResult
    private func withRegistryLock<T>(_ body: (inout [ManagedSimulatorSession]) throws -> T) throws -> T {
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let descriptor = Darwin.open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw GrantivaError.commandFailed("Could not open simulator capacity lock: \(String(cString: strerror(errno)))", 1)
        }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else {
            throw GrantivaError.commandFailed("Could not acquire simulator capacity lock: \(String(cString: strerror(errno)))", 1)
        }
        defer { flock(descriptor, LOCK_UN) }

        var records: [ManagedSimulatorSession] = []
        if let data = FileManager.default.contents(atPath: registryPath), !data.isEmpty {
            records = try JSONDecoder().decode([ManagedSimulatorSession].self, from: data)
        }
        let result = try body(&records)
        let data = try JSONEncoder().encode(records)
        try data.write(to: URL(fileURLWithPath: registryPath), options: .atomic)
        return result
    }

    static func prune(
        _ records: inout [ManagedSimulatorSession],
        devices: [SimulatorDevice],
        isProcessAlive: (Int32) -> Bool = { kill($0, 0) == 0 || errno == EPERM }
    ) {
        let states = Dictionary(uniqueKeysWithValues: devices.map { ($0.udid, $0.state) })
        records.removeAll { record in
            guard let state = states[record.udid] else { return true }
            if record.state == .pending && !isProcessAlive(record.ownerPID) { return true }
            // A run without GRANTIVA_SESSION_ID has no ticket that will ever
            // tear it down by name, so its record lives only as long as the
            // process that took it.
            // `ensure` without a session keeps its record until the device is
            // shut down, so the cap and `teardown --udid` still apply to it.
            if record.isSessionless && record.ephemeral != false && !isProcessAlive(record.ownerPID) { return true }
            if state == "Booted" { return false }
            if record.state == .pending { return false }
            return true
        }
    }

    /// The owner recorded for a run that set no `GRANTIVA_SESSION_ID`.
    static func sessionlessOwner(udid: String) -> String { "simulator:\(udid)" }

    private static func positiveInt(_ value: String?) -> Int? {
        guard let value, let parsed = Int(value), parsed > 0 else { return nil }
        return parsed
    }

    private static func nonnegativeDouble(_ value: String?) -> Double? {
        guard let value, let parsed = Double(value), parsed >= 0 else { return nil }
        return parsed
    }
}
