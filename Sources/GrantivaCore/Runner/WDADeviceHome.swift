import Foundation

/// A per-simulator runner home, so concurrent runs on different simulators
/// never share WebDriverAgent state.
///
/// The runner keeps one WDA build per runtime (`cache/wda-builds/<config>`)
/// and launches every session from it: it rewrites the build's `.xctestrun`
/// in place with the session's port, detects startup by reading the build's
/// `logs/runner.log`, and points `xcodebuild test-without-building` at the
/// build's DerivedData. Two runs on two simulators of the same runtime
/// therefore overwrite each other's port and startup log, and one of them
/// loses its WDA moments after it reports ready.
///
/// Grantiva points `MAESTRO_RUNNER_HOME` at `<runner>/devices/<udid>` instead.
/// That home links to the shared `drivers/` and carries an APFS clone of each
/// cached build's `Build/Products` (a few MB, cloned rather than rebuilt), so
/// every simulator launches WDA from its own xctestrun, log, and DerivedData.
/// A build the runner produced inside a device home is promoted back into the
/// shared cache when that run ends, so the next simulator clones it instead
/// of building WDA again.
public enum WDADeviceHome {
    static let devicesDirectory = "devices"
    static let buildsDirectory = "cache/wda-builds"
    static let productsDirectory = "DerivedData/Build/Products"
    static let lockFileName = ".lock"

    /// The runner home for `deviceID` under `runnerHome`.
    public static func path(runnerHome: String, deviceID: String) -> String {
        "\(runnerHome)/\(devicesDirectory)/\(deviceID)"
    }

    /// Simulator UDIDs known to `simctl`, or nil when they cannot be listed
    /// (in which case nothing is pruned).
    public static let liveDeviceIDs: @Sendable () -> Set<String>? = {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "-j"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let runtimes = json["devices"] as? [String: [[String: Any]]]
        else { return nil }
        return Set(runtimes.values.flatMap { $0.compactMap { $0["udid"] as? String } })
    }

    /// Creates or refreshes the device's runner home and returns its path.
    /// Returns nil when the home cannot be prepared (or `deviceID` is not a
    /// plain identifier), so the caller can fall back to the shared home.
    ///
    /// Homes of simulators `existingDeviceIDs` no longer lists are removed,
    /// and so is any build in this home that the shared cache lacks: a build
    /// deleted from `cache/wda-builds` stays deleted.
    public static func prepare(
        runnerHome: String,
        deviceID: String,
        existingDeviceIDs: () -> Set<String>? = liveDeviceIDs,
        leaseDirectory: String? = nil,
        fileManager fm: FileManager = .default
    ) -> String? {
        guard isPlainIdentifier(deviceID) else { return nil }
        let home = path(runnerHome: runnerHome, deviceID: deviceID)
        let sharedBuilds = "\(runnerHome)/\(buildsDirectory)"
        let deviceBuilds = "\(home)/\(buildsDirectory)"
        do {
            try fm.createDirectory(atPath: deviceBuilds, withIntermediateDirectories: true)
            try fm.createDirectory(atPath: sharedBuilds, withIntermediateDirectories: true)
            let drivers = "\(home)/drivers"
            if (try? fm.destinationOfSymbolicLink(atPath: drivers)) == nil {
                try? fm.removeItem(atPath: drivers)
                try fm.createSymbolicLink(atPath: drivers, withDestinationPath: "\(runnerHome)/drivers")
            }
        } catch {
            return nil
        }

        // An empty list is treated as "unknown": a CoreSimulatorService
        // hiccup can briefly list no devices, and pruning on it would wipe
        // the homes of runs in progress. A home whose simulator lease is
        // held belongs to a live run and is skipped too.
        if let existing = existingDeviceIDs(), !existing.isEmpty {
            let devices = "\(runnerHome)/\(devicesDirectory)"
            for other in subdirectories(of: devices, fileManager: fm)
            where other != deviceID && !existing.contains(other) {
                guard let lease = try? SimulatorLease.acquire(udid: other, directory: leaseDirectory) else { continue }
                try? fm.removeItem(atPath: "\(devices)/\(other)")
                lease.release()
            }
        }

        return withBuildsLock(sharedBuilds) { () -> String? in
            let sharedConfigs = Set(subdirectories(of: sharedBuilds, fileManager: fm).filter {
                hasXctestrun(in: "\(sharedBuilds)/\($0)/\(productsDirectory)", fileManager: fm)
            })
            for config in subdirectories(of: deviceBuilds, fileManager: fm) where !sharedConfigs.contains(config) {
                try? fm.removeItem(atPath: "\(deviceBuilds)/\(config)")
            }
            // Refresh every cached build so this device never launches from
            // a stale or half-edited copy. The lease on this UDID guarantees
            // no other run is using this home right now.
            for config in sharedConfigs.sorted() {
                let source = "\(sharedBuilds)/\(config)/\(productsDirectory)"
                let destination = "\(deviceBuilds)/\(config)/\(productsDirectory)"
                try? fm.removeItem(atPath: destination)
                do {
                    try fm.createDirectory(
                        atPath: (destination as NSString).deletingLastPathComponent,
                        withIntermediateDirectories: true
                    )
                    try fm.copyItem(atPath: source, toPath: destination)
                } catch {
                    return nil
                }
            }
            return home
        }
    }

    /// Copies builds the runner just produced in `deviceID`'s home into the
    /// shared cache. Call once the runner exits. Only configs the shared
    /// cache lacks are copied; `prepare` has already dropped every device
    /// config the shared cache lacked, so anything left is this run's build.
    public static func promote(runnerHome: String, deviceID: String, fileManager fm: FileManager = .default) {
        guard isPlainIdentifier(deviceID) else { return }
        let deviceBuilds = "\(path(runnerHome: runnerHome, deviceID: deviceID))/\(buildsDirectory)"
        let sharedBuilds = "\(runnerHome)/\(buildsDirectory)"
        guard (try? fm.createDirectory(atPath: sharedBuilds, withIntermediateDirectories: true)) != nil else { return }
        withBuildsLock(sharedBuilds) {
            for config in subdirectories(of: deviceBuilds, fileManager: fm) {
                let source = "\(deviceBuilds)/\(config)/\(productsDirectory)"
                let destination = "\(sharedBuilds)/\(config)/\(productsDirectory)"
                guard hasXctestrun(in: source, fileManager: fm),
                      !hasXctestrun(in: destination, fileManager: fm) else { continue }
                let parent = (destination as NSString).deletingLastPathComponent
                let staging = "\(parent)/.Products-\(UUID().uuidString)"
                do {
                    try fm.createDirectory(atPath: parent, withIntermediateDirectories: true)
                    try fm.copyItem(atPath: source, toPath: staging)
                    try? fm.removeItem(atPath: destination)
                    try fm.moveItem(atPath: staging, toPath: destination)
                } catch {
                    try? fm.removeItem(atPath: staging)
                }
            }
        }
    }

    /// Removes `deviceID`'s runner home. Called when the simulator is torn
    /// down or deleted.
    public static func remove(runnerHome: String, deviceID: String, fileManager fm: FileManager = .default) {
        guard isPlainIdentifier(deviceID) else { return }
        try? fm.removeItem(atPath: path(runnerHome: runnerHome, deviceID: deviceID))
    }

    /// Runs `body` holding an exclusive `flock` on `cache/wda-builds/.lock`,
    /// so a promotion never races another run's clone. Runs `body` unlocked
    /// if the lock file cannot be opened.
    @discardableResult
    static func withBuildsLock<T>(_ sharedBuilds: String, _ body: () -> T) -> T {
        let descriptor = open("\(sharedBuilds)/\(lockFileName)", O_CREAT | O_RDWR | O_CLOEXEC, 0o644)
        guard descriptor >= 0 else { return body() }
        defer { close(descriptor) }
        flock(descriptor, LOCK_EX)
        defer { flock(descriptor, LOCK_UN) }
        return body()
    }

    static func hasXctestrun(in products: String, fileManager fm: FileManager) -> Bool {
        let entries = (try? fm.contentsOfDirectory(atPath: products)) ?? []
        return entries.contains { $0.hasSuffix(".xctestrun") }
    }

    private static func subdirectories(of path: String, fileManager fm: FileManager) -> [String] {
        let entries = (try? fm.contentsOfDirectory(atPath: path)) ?? []
        return entries.filter { entry in
            guard !entry.hasPrefix(".") else { return false }
            var isDirectory: ObjCBool = false
            return fm.fileExists(atPath: "\(path)/\(entry)", isDirectory: &isDirectory) && isDirectory.boolValue
        }.sorted()
    }

    private static func isPlainIdentifier(_ id: String) -> Bool {
        !id.isEmpty && id != "." && id != ".."
            && id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." }
    }
}
