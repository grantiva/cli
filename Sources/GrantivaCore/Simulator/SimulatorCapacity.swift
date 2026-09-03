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

    public init(udid: String, name: String, sessionId: String, ownerPID: Int32, acquiredAt: Date, state: State) {
        self.udid = udid
        self.name = name
        self.sessionId = sessionId
        self.ownerPID = ownerPID
        self.acquiredAt = acquiredAt
        self.state = state
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
        devices: @Sendable () async throws -> [SimulatorDevice],
        onWait: @Sendable ([ManagedSimulatorSession], TimeInterval) -> Void = { _, _ in }
    ) async throws -> ManagedSimulatorSession {
        let owner = sessionId ?? "simulator:\(device.udid)"
        let start = Date()

        while true {
            let currentDevices = try await devices()
            let outcome = try withRegistryLock { records in
                Self.prune(&records, devices: currentDevices)

                if let existing = records.first(where: { $0.udid == device.udid }) {
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
                        state: .pending
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

    public func activate(udid: String) throws {
        try withRegistryLock { records in
            guard let index = records.firstIndex(where: { $0.udid == udid }) else { return }
            records[index].state = .active
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

    private static func prune(_ records: inout [ManagedSimulatorSession], devices: [SimulatorDevice]) {
        let states = Dictionary(uniqueKeysWithValues: devices.map { ($0.udid, $0.state) })
        records.removeAll { record in
            guard let state = states[record.udid] else { return true }
            if record.state == .pending {
                let ownerExists = kill(record.ownerPID, 0) == 0 || errno == EPERM
                return !ownerExists
            }
            return state != "Booted"
        }
    }

    private static func positiveInt(_ value: String?) -> Int? {
        guard let value, let parsed = Int(value), parsed > 0 else { return nil }
        return parsed
    }

    private static func nonnegativeDouble(_ value: String?) -> Double? {
        guard let value, let parsed = Double(value), parsed >= 0 else { return nil }
        return parsed
    }
}
