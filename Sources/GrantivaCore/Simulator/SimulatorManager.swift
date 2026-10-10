import Foundation
import Logging

public struct SimulatorManager: Sendable, Decodable {
    public static let live = SimulatorManager()

    private let execute: @Sendable (String) async throws -> String
    private let capacity: SimulatorCapacity
    private let provenance: SimulatorProvenance

    public init() {
        self.init(execute: { try await shell($0) })
    }

    /// Test seam: a scripted `simctl` and private capacity/provenance stores.
    init(
        execute: @escaping @Sendable (String) async throws -> String,
        capacity: SimulatorCapacity = .live,
        provenance: SimulatorProvenance = .live
    ) {
        self.execute = execute
        self.capacity = capacity
        self.provenance = provenance
    }

    public init(from decoder: Decoder) throws {
        self.init()
    }

    public func listDevices() async throws -> [SimulatorDevice] {
        let output = try await execute("xcrun simctl list devices --json")
        guard let data = output.data(using: .utf8) else { return [] }
        let parsed = try JSONDecoder().decode(SimctlDeviceList.self, from: data)
        return parsed.allDevices
    }

    public func bootedDevice() async throws -> SimulatorDevice {
        let devices = try await listDevices()
        guard let booted = devices.first(where: { $0.isBooted }) else {
            throw GrantivaError.simulatorNotRunning
        }
        return booted
    }

    /// The only booted simulator. With several booted this is an error naming
    /// them, never a guess: the first booted device may be one the user is
    /// using, and capture would drive it.
    public func soleBootedDevice() async throws -> SimulatorDevice {
        try Self.soleBooted(in: try await listDevices())
    }

    static func soleBooted(in devices: [SimulatorDevice]) throws -> SimulatorDevice {
        let booted = devices.filter(\.isBooted)
        guard let first = booted.first else { throw GrantivaError.simulatorNotRunning }
        guard booted.count == 1 else {
            let names = booted.map { "\($0.name) (\($0.udid))" }.joined(separator: ", ")
            throw GrantivaError.invalidArgument(
                "\(booted.count) simulators are booted: \(names). Pass --simulator <name|UDID> or set simulator: in grantiva.yml."
            )
        }
        return first
    }

    public func bootedUDID() async throws -> String {
        try await bootedDevice().udid
    }

    /// The line emitted while a boot waits for host capacity, and the level it
    /// must go out at.
    ///
    /// `.warning`, not `.info`: this is the only explanation for a stall that
    /// runs to `GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS` — ten minutes by
    /// default — before failing. `--quiet` drops everything below `.warning`,
    /// and a silenced wait is indistinguishable from a hang. A host already at
    /// its simulator limit is an abnormal condition: the caller has to free a
    /// device or raise the cap, and can do neither without being told.
    static func capacityWait(
        sessions: [ManagedSimulatorSession],
        maximum: Int
    ) -> (level: Logger.Level, message: String) {
        let owners = sessions.map { "\($0.name) [\($0.sessionId)]" }.joined(separator: ", ")
        return (.warning, "Waiting for simulator capacity (\(sessions.count)/\(maximum)): \(owners)")
    }

    /// Boots a simulator and takes a capacity slot for it.
    ///
    /// Only simulators Grantiva boots count toward the limit. A device that is
    /// already booted with no Grantiva record was booted by someone else (Xcode,
    /// `simctl boot`): it is used as-is, takes no slot, and is therefore never
    /// listed by `simulator sessions` or shut down by `simulator teardown`.
    public func boot(nameOrUDID: String) async throws -> SimulatorDevice {
        let device = try await exactDevice(nameOrUDID: nameOrUDID)
        if device.isBooted {
            let devices = try await listDevices()
            guard try capacity.sessions(devices: devices).contains(where: { $0.udid == device.udid }) else {
                return device
            }
        }
        _ = try await capacity.reserve(device: device, devices: { try await listDevices() }) { sessions, elapsed in
            guard Int(elapsed) % 10 == 0 else { return }
            let wait = Self.capacityWait(sessions: sessions, maximum: capacity.maximum)
            GrantivaLog.logger.log(level: wait.level, "\(wait.message)")
        }
        do {
            if !device.isBooted {
                _ = try await execute("xcrun simctl boot \(device.udid)")
                _ = try await execute("xcrun simctl bootstatus \(device.udid) -b")
            }
            try capacity.activate(udid: device.udid)
        } catch {
            try? capacity.releaseReservation(udid: device.udid)
            throw error
        }
        return try await exactDevice(nameOrUDID: device.udid)
    }

    /// Resolves only the requested name or UDID. It never substitutes an arbitrary booted device.
    public func exactDevice(nameOrUDID: String) async throws -> SimulatorDevice {
        let matches = try await listDevices().filter { $0.name == nameOrUDID || $0.udid == nameOrUDID }
        guard matches.count == 1, let device = matches.first else {
            let message = matches.isEmpty ? "Simulator not found: \"\(nameOrUDID)\"" : "Multiple simulators are named \"\(nameOrUDID)\"; use a UDID"
            throw GrantivaError.invalidArgument(message)
        }
        return device
    }

    /// Creates or reuses a simulator named `name`.
    ///
    /// An existing device with that name is looked up first and reused, so
    /// `--name` alone is enough to reuse any simulator, whatever it is called.
    /// `deviceType` and `runtime` are checked against it only when given.
    /// Creating a new device needs a device type: `deviceType`, or a device
    /// model inferred from the name (so `--name "iPhone 17"` is enough); the
    /// runtime defaults to the newest installed one. The result reports the
    /// device's own type and runtime.
    public func ensure(
        name: String,
        deviceType: String? = nil,
        runtime requestedRuntime: String? = nil,
        boot shouldBoot: Bool
    ) async throws -> SimulatorProvisionResult {
        let catalog = try await simulatorCatalog()
        let requestedType: SimctlCatalog.DeviceType? = try deviceType.map { deviceType in
            guard let match = catalog.deviceTypes.first(where: {
                $0.name.caseInsensitiveCompare(deviceType) == .orderedSame || $0.identifier == deviceType
            }) else {
                throw GrantivaError.invalidArgument("Simulator device type not found: \"\(deviceType)\"")
            }
            return match
        }
        let availableRuntimes = catalog.runtimes.filter { $0.isAvailable && $0.identifier.contains("iOS") }
        func resolveRuntime(_ wanted: String) throws -> SimctlCatalog.Runtime {
            if wanted.lowercased() == "latest" {
                guard let latest = availableRuntimes.max(by: { versionIsLess($0.version, $1.version) }) else {
                    throw GrantivaError.invalidArgument("No available iOS simulator runtime is installed")
                }
                return latest
            }
            guard let match = availableRuntimes.first(where: { $0.identifier == wanted || $0.name == wanted || $0.version == wanted }) else {
                throw GrantivaError.invalidArgument("Simulator runtime not found or unavailable: \"\(wanted)\"")
            }
            return match
        }
        let pinnedRuntime = try requestedRuntime.map(resolveRuntime)

        // The look-up/create pair runs under a cross-process lock so two
        // concurrent runs asking for the same name reuse one device instead of
        // both observing "not found" and creating duplicates.
        let (created, provisionedUDID): (Bool, String) = try await provenance.withProvisioningLock {
            let named = try await listDevices().filter { $0.name == name }
            if named.count > 1 { throw GrantivaError.invalidArgument("Multiple simulators are named \"\(name)\"; delete duplicates or use a unique name") }
            if let existing = named.first {
                // Only enforce the configuration the caller actually asked for.
                let typeMatches = requestedType.map { existing.deviceTypeIdentifier == $0.identifier } ?? true
                let runtimeMatches = pinnedRuntime.map { existing.runtime == $0.shortName } ?? true
                guard typeMatches && runtimeMatches else {
                    let requested = [requestedType?.name, pinnedRuntime?.name].compactMap { $0 }.joined(separator: ", ")
                    throw GrantivaError.invalidArgument("Simulator \"\(name)\" exists with incompatible configuration (device type: \(existing.deviceTypeIdentifier ?? "unknown"), runtime: \(existing.runtime)); requested \(requested)")
                }
                return (false, existing.udid)
            }
            let type: SimctlCatalog.DeviceType
            if let requestedType {
                type = requestedType
            } else {
                guard let inferred = Self.inferDeviceType(fromName: name, in: catalog.deviceTypes.map { ($0.name, $0.identifier) }) else {
                    throw GrantivaError.invalidArgument(
                        "Could not infer a device type from the name \"\(name)\". "
                            + "Include a device model in the name (for example \"iPhone 17\") or pass --device-type."
                    )
                }
                guard let match = catalog.deviceTypes.first(where: { $0.identifier == inferred.identifier }) else {
                    throw GrantivaError.invalidArgument("Simulator device type not found: \"\(inferred.name)\"")
                }
                type = match
            }
            let runtime = try pinnedRuntime ?? resolveRuntime("latest")
            let udid = try await execute("xcrun simctl create \(shellQuoted(name)) \(shellQuoted(type.identifier)) \(shellQuoted(runtime.identifier))")
            try provenance.register(udid: udid, name: name)
            return (true, udid)
        }
        let udid = provisionedUDID
        if shouldBoot {
            do {
                _ = try await boot(nameOrUDID: udid)
            } catch {
                // A failed ensure (most often a capacity-wait timeout) leaves
                // the host as it found it: remove a device this call created.
                // A reused device is never touched.
                if created {
                    if (try? await exactDevice(nameOrUDID: udid))?.isBooted == true {
                        _ = try? await execute("xcrun simctl shutdown \(shellQuoted(udid))")
                    }
                    _ = try? await execute("xcrun simctl delete \(shellQuoted(udid))")
                    try? capacity.remove(udid: udid)
                    try? provenance.remove(udid: udid)
                }
                throw error
            }
        }
        let device = try await exactDevice(nameOrUDID: udid)
        let geometry = shouldBoot ? try await displayGeometry(udid: udid) : nil
        // Report what the device actually is, not what was requested or inferred.
        let typeName = catalog.deviceTypes.first { $0.identifier == device.deviceTypeIdentifier }?.name
            ?? device.deviceTypeIdentifier ?? "unknown"
        let runtimeName = catalog.runtimes.first { $0.shortName == device.runtime }?.name ?? device.runtime
        return SimulatorProvisionResult(name: name, udid: udid, deviceType: typeName, runtime: runtimeName, created: created, state: device.state, pointWidth: geometry?.points[0], pointHeight: geometry?.points[1], pixelWidth: geometry?.pixels[0], pixelHeight: geometry?.pixels[1], displayScale: geometry?.scale)
    }

    public func delete(name: String) async throws -> SimulatorDevice {
        let device = try await exactDevice(nameOrUDID: name)
        _ = try await execute("xcrun simctl delete \(shellQuoted(device.udid))")
        try capacity.remove(udid: device.udid)
        try provenance.remove(udid: device.udid)
        WDADeviceHome.remove(runnerHome: RunnerManager.baseDir, deviceID: device.udid)
        return device
    }

    public func managedSessions() async throws -> [ManagedSimulatorSession] {
        try capacity.sessions(devices: try await listDevices())
    }

    /// Ends a session. Simulators Grantiva created are deleted outright;
    /// pre-existing devices the session merely booted are only shut down.
    public func teardown(sessionId: String) async throws -> [SimulatorTeardownOutcome] {
        let devices = try await listDevices()
        let records = try capacity.sessions(sessionId: sessionId, devices: devices)
        var outcomes: [SimulatorTeardownOutcome] = []
        for record in records {
            if devices.first(where: { $0.udid == record.udid })?.isBooted == true {
                _ = try await execute("xcrun simctl shutdown \(shellQuoted(record.udid))")
            }
            let created = try provenance.contains(udid: record.udid)
            if created {
                _ = try await execute("xcrun simctl delete \(shellQuoted(record.udid))")
                try provenance.remove(udid: record.udid)
            }
            try capacity.remove(udid: record.udid)
            WDADeviceHome.remove(runnerHome: RunnerManager.baseDir, deviceID: record.udid)
            outcomes.append(SimulatorTeardownOutcome(session: record, deleted: created))
        }
        return outcomes
    }

    /// Ends whatever session owns `udid`. Used by
    /// `teardown --udid` when the caller knows the device but not the ticket.
    public func teardown(udid: String) async throws -> [SimulatorTeardownOutcome] {
        let devices = try await listDevices()
        let records = try capacity.sessions(devices: devices).filter { $0.udid == udid }
        var outcomes: [SimulatorTeardownOutcome] = []
        for record in records {
            if devices.first(where: { $0.udid == record.udid })?.isBooted == true {
                _ = try await execute("xcrun simctl shutdown \(shellQuoted(record.udid))")
            }
            let created = try provenance.contains(udid: record.udid)
            if created {
                _ = try await execute("xcrun simctl delete \(shellQuoted(record.udid))")
                try provenance.remove(udid: record.udid)
            }
            try capacity.remove(udid: record.udid)
            WDADeviceHome.remove(runnerHome: RunnerManager.baseDir, deviceID: record.udid)
            outcomes.append(SimulatorTeardownOutcome(session: record, deleted: created))
        }
        return outcomes
    }

    /// Deletes every Grantiva-created simulator that is shut down and no
    /// longer part of an active managed session. Ledger entries for devices
    /// that no longer exist are pruned. Never touches user-created devices.
    public func cleanup() async throws -> [CreatedSimulatorRecord] {
        let devices = try await listDevices()
        let active = Set(try capacity.sessions(devices: devices).map(\.udid))
        var removed: [CreatedSimulatorRecord] = []
        for record in try provenance.all() {
            guard let device = devices.first(where: { $0.udid == record.udid }) else {
                try provenance.remove(udid: record.udid)
                continue
            }
            guard !device.isBooted, !active.contains(record.udid) else { continue }
            _ = try await execute("xcrun simctl delete \(shellQuoted(record.udid))")
            try provenance.remove(udid: record.udid)
            removed.append(record)
        }
        return removed
    }

    /// Picks the device type a simulator name refers to: the longest catalog
    /// device-type name contained in `name`, matched case-insensitively. The
    /// longest match wins so "BLE iPhone 17 Pro" resolves to "iPhone 17 Pro"
    /// rather than "iPhone 17".
    static func inferDeviceType(
        fromName name: String,
        in deviceTypes: [(name: String, identifier: String)]
    ) -> (name: String, identifier: String)? {
        let haystack = name.lowercased()
        return deviceTypes
            .filter { haystack.contains($0.name.lowercased()) }
            .max { $0.name.count < $1.name.count }
    }

    /// The newest iPhone device type an installed iOS runtime can run, for
    /// suggestions such as doctor's fix line and `init`'s default; nil when
    /// simctl is unavailable or no iOS runtime is installed.
    public func newestIPhone() async -> String? {
        guard let output = try? await shell("xcrun simctl list devicetypes runtimes --json") else { return nil }
        return Self.newestIPhone(catalogJSON: Data(output.utf8))
    }

    /// The iPhone type with the highest minimum runtime that the newest
    /// available iOS runtime satisfies; ties go to simctl's order, which lists
    /// the newest models first.
    static func newestIPhone(catalogJSON: Data) -> String? {
        guard let catalog = try? JSONDecoder().decode(SimctlCatalog.self, from: catalogJSON) else { return nil }
        let installed = catalog.runtimes
            .filter { $0.isAvailable && ($0.platform == "iOS" || $0.identifier.contains(".iOS-")) }
            .map(\.version)
            .max(by: versionIsLess)
        guard let installed else { return nil }
        var best: (name: String, min: String)?
        for type in catalog.devicetypes where type.productFamily == "iPhone" || type.name.hasPrefix("iPhone") {
            let min = type.minRuntimeVersionString ?? "0"
            guard !versionIsLess(installed, min) else { continue }
            if best == nil || versionIsLess(best!.min, min) { best = (type.name, min) }
        }
        return best?.name
    }

    private func simulatorCatalog() async throws -> SimctlCatalog {
        let data = try await execute("xcrun simctl list devicetypes runtimes --json").data(using: .utf8) ?? Data()
        return try JSONDecoder().decode(SimctlCatalog.self, from: data)
    }

    public func displayGeometry(udid: String) async throws -> SimulatorDisplayGeometry {
        func value(_ key: String) async throws -> Double {
            guard let number = Double(try await execute("xcrun simctl getenv \(shellQuoted(udid)) \(key)")) else { throw GrantivaError.invalidArgument("Could not read simulator display metric \(key)") }
            return number
        }
        let pixelWidth = try await value("SIMULATOR_MAINSCREEN_WIDTH")
        let pixelHeight = try await value("SIMULATOR_MAINSCREEN_HEIGHT")
        let scale = try await value("SIMULATOR_MAINSCREEN_SCALE")
        return Self.geometry(pixelWidth: pixelWidth, pixelHeight: pixelHeight, scale: scale)
    }

    static func geometry(pixelWidth: Double, pixelHeight: Double, scale: Double) -> SimulatorDisplayGeometry {
        SimulatorDisplayGeometry(
            points: [Int((pixelWidth / scale).rounded()), Int((pixelHeight / scale).rounded())],
            pixels: [Int(pixelWidth.rounded()), Int(pixelHeight.rounded())],
            scale: scale
        )
    }
}

private func versionIsLess(_ lhs: String, _ rhs: String) -> Bool {
    let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
    let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
    for index in 0..<max(left.count, right.count) {
        let l = index < left.count ? left[index] : 0
        let r = index < right.count ? right[index] : 0
        if l != r { return l < r }
    }
    return false
}

private struct SimctlCatalog: Decodable {
    struct DeviceType: Decodable {
        let name: String; let identifier: String
        var minRuntimeVersionString: String? = nil
        var productFamily: String? = nil
    }
    struct Runtime: Decodable {
        let name: String; let identifier: String; let version: String; let isAvailable: Bool
        var platform: String? = nil
        var shortName: String { identifier.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "") }
    }
    let devicetypes: [DeviceType]
    let runtimes: [Runtime]
    var deviceTypes: [DeviceType] { devicetypes }
}

// MARK: - simctl JSON Parsing

struct SimctlDeviceList: Decodable {
    let devices: [String: [SimctlDevice]]

    struct SimctlDevice: Decodable {
        let name: String
        let udid: String
        let state: String
        let isAvailable: Bool
        let deviceTypeIdentifier: String?
    }

    var allDevices: [SimulatorDevice] {
        devices.flatMap { (runtime, devs) in
            devs.map { dev in
                SimulatorDevice(
                    name: dev.name,
                    udid: dev.udid,
                    state: dev.state,
                    runtime: runtime.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: ""),
                    isAvailable: dev.isAvailable,
                    deviceTypeIdentifier: dev.deviceTypeIdentifier
                )
            }
        }
        .sorted { $0.name < $1.name }
    }
}
