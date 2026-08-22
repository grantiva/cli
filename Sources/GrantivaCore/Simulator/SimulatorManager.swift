import Foundation

public struct SimulatorManager: Sendable, Decodable {
    public static let live = SimulatorManager()

    public init() {}

    public func listDevices() async throws -> [SimulatorDevice] {
        let output = try await shell("xcrun simctl list devices --json")
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

    public func bootedUDID() async throws -> String {
        try await bootedDevice().udid
    }

    public func boot(nameOrUDID: String) async throws -> SimulatorDevice {
        let device = try await exactDevice(nameOrUDID: nameOrUDID)
        if !device.isBooted {
            let capacity = SimulatorCapacity.live
            _ = try await capacity.reserve(device: device, devices: { try await listDevices() }) { sessions, elapsed in
                guard Int(elapsed) % 10 == 0 else { return }
                let owners = sessions.map { "\($0.name) [\($0.sessionId)]" }.joined(separator: ", ")
                GrantivaLog.logger.info("Waiting for simulator capacity (\(sessions.count)/\(capacity.maximum)): \(owners)")
            }
            do {
                _ = try await shell("xcrun simctl boot \(device.udid)")
                _ = try await shell("xcrun simctl bootstatus \(device.udid) -b")
                try capacity.activate(udid: device.udid)
            } catch {
                try? capacity.releaseReservation(udid: device.udid)
                throw error
            }
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

    public func ensure(name: String, deviceType: String, runtime requestedRuntime: String, boot shouldBoot: Bool) async throws -> SimulatorProvisionResult {
        let catalog = try await simulatorCatalog()
        guard let type = catalog.deviceTypes.first(where: { $0.name == deviceType || $0.identifier == deviceType }) else {
            throw GrantivaError.invalidArgument("Simulator device type not found: \"\(deviceType)\"")
        }
        let availableRuntimes = catalog.runtimes.filter { $0.isAvailable && $0.identifier.contains("iOS") }
        let runtime: SimctlCatalog.Runtime
        if requestedRuntime.lowercased() == "latest" {
            guard let latest = availableRuntimes.max(by: { versionIsLess($0.version, $1.version) }) else {
                throw GrantivaError.invalidArgument("No available iOS simulator runtime is installed")
            }
            runtime = latest
        } else {
            guard let match = availableRuntimes.first(where: { $0.identifier == requestedRuntime || $0.name == requestedRuntime || $0.version == requestedRuntime }) else {
                throw GrantivaError.invalidArgument("Simulator runtime not found or unavailable: \"\(requestedRuntime)\"")
            }
            runtime = match
        }

        // The look-up/create pair runs under a cross-process lock so two
        // concurrent runs asking for the same name reuse one device instead of
        // both observing "not found" and creating duplicates.
        let (created, provisionedUDID): (Bool, String) = try await SimulatorProvenance.live.withProvisioningLock {
            let named = try await listDevices().filter { $0.name == name }
            if named.count > 1 { throw GrantivaError.invalidArgument("Multiple simulators are named \"\(name)\"; delete duplicates or use a unique name") }
            if let existing = named.first {
                guard existing.deviceTypeIdentifier == type.identifier && existing.runtime == runtime.shortName else {
                    throw GrantivaError.invalidArgument("Simulator \"\(name)\" exists with incompatible configuration (device type: \(existing.deviceTypeIdentifier ?? "unknown"), runtime: \(existing.runtime)); requested \(type.name), \(runtime.name)")
                }
                return (false, existing.udid)
            }
            let udid = try await shell("xcrun simctl create \(shellQuoted(name)) \(shellQuoted(type.identifier)) \(shellQuoted(runtime.identifier))")
            try SimulatorProvenance.live.register(udid: udid, name: name)
            return (true, udid)
        }
        let udid = provisionedUDID
        if shouldBoot {
            _ = try await boot(nameOrUDID: udid)
        }
        let device = try await exactDevice(nameOrUDID: udid)
        let geometry = shouldBoot ? try await displayGeometry(udid: udid) : nil
        if shouldBoot && (name == "APP-302 iPhone 393x852" || deviceType == "iPhone 15 Pro") {
            guard geometry?.points == [393, 852], geometry?.pixels == [1179, 2556], geometry?.scale == 3 else {
                throw GrantivaError.invalidArgument("Provisioned simulator has unexpected display geometry; expected 393x852 points, 1179x2556 pixels, 3x scale")
            }
        }
        return SimulatorProvisionResult(name: name, udid: udid, deviceType: type.name, runtime: runtime.name, created: created, state: device.state, pointWidth: geometry?.points[0], pointHeight: geometry?.points[1], pixelWidth: geometry?.pixels[0], pixelHeight: geometry?.pixels[1], displayScale: geometry?.scale)
    }

    public func delete(name: String) async throws -> SimulatorDevice {
        let device = try await exactDevice(nameOrUDID: name)
        _ = try await shell("xcrun simctl delete \(shellQuoted(device.udid))")
        try SimulatorCapacity.live.remove(udid: device.udid)
        try SimulatorProvenance.live.remove(udid: device.udid)
        return device
    }

    public func managedSessions() async throws -> [ManagedSimulatorSession] {
        try SimulatorCapacity.live.sessions(devices: try await listDevices())
    }

    /// Ends a session. Simulators Grantiva created are deleted outright;
    /// pre-existing devices the session merely booted are only shut down.
    public func teardown(sessionId: String) async throws -> [SimulatorTeardownOutcome] {
        let capacity = SimulatorCapacity.live
        let provenance = SimulatorProvenance.live
        let devices = try await listDevices()
        let records = try capacity.sessions(sessionId: sessionId, devices: devices)
        var outcomes: [SimulatorTeardownOutcome] = []
        for record in records {
            if devices.first(where: { $0.udid == record.udid })?.isBooted == true {
                _ = try await shell("xcrun simctl shutdown \(shellQuoted(record.udid))")
            }
            let created = try provenance.contains(udid: record.udid)
            if created {
                _ = try await shell("xcrun simctl delete \(shellQuoted(record.udid))")
                try provenance.remove(udid: record.udid)
            }
            try capacity.remove(udid: record.udid)
            outcomes.append(SimulatorTeardownOutcome(session: record, deleted: created))
        }
        return outcomes
    }

    /// Deletes every Grantiva-created simulator that is shut down and no
    /// longer part of an active managed session. Ledger entries for devices
    /// that no longer exist are pruned. Never touches user-created devices.
    public func cleanup() async throws -> [CreatedSimulatorRecord] {
        let provenance = SimulatorProvenance.live
        let devices = try await listDevices()
        let active = Set(try SimulatorCapacity.live.sessions(devices: devices).map(\.udid))
        var removed: [CreatedSimulatorRecord] = []
        for record in try provenance.all() {
            guard let device = devices.first(where: { $0.udid == record.udid }) else {
                try provenance.remove(udid: record.udid)
                continue
            }
            guard !device.isBooted, !active.contains(record.udid) else { continue }
            _ = try await shell("xcrun simctl delete \(shellQuoted(record.udid))")
            try provenance.remove(udid: record.udid)
            removed.append(record)
        }
        return removed
    }

    private func simulatorCatalog() async throws -> SimctlCatalog {
        let data = try await shell("xcrun simctl list devicetypes runtimes --json").data(using: .utf8) ?? Data()
        return try JSONDecoder().decode(SimctlCatalog.self, from: data)
    }

    public func displayGeometry(udid: String) async throws -> SimulatorDisplayGeometry {
        func value(_ key: String) async throws -> Double {
            guard let number = Double(try await shell("xcrun simctl getenv \(shellQuoted(udid)) \(key)")) else { throw GrantivaError.invalidArgument("Could not read simulator display metric \(key)") }
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

private func shellQuoted(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
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
    struct DeviceType: Decodable { let name: String; let identifier: String }
    struct Runtime: Decodable {
        let name: String; let identifier: String; let version: String; let isAvailable: Bool
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
