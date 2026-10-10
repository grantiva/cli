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
/// A build that a device home produced first is promoted back into the shared
/// cache, so the next simulator clones it instead of building WDA again.
public enum WDADeviceHome {
    static let devicesDirectory = "devices"
    static let buildsDirectory = "cache/wda-builds"
    static let productsDirectory = "DerivedData/Build/Products"

    /// The runner home for `deviceID` under `runnerHome`.
    public static func path(runnerHome: String, deviceID: String) -> String {
        "\(runnerHome)/\(devicesDirectory)/\(deviceID)"
    }

    /// Creates or refreshes the device's runner home and returns its path.
    /// Returns nil when the home cannot be prepared (or `deviceID` is not a
    /// plain identifier), so the caller can fall back to the shared home.
    public static func prepare(runnerHome: String, deviceID: String, fileManager fm: FileManager = .default) -> String? {
        guard isPlainIdentifier(deviceID) else { return nil }
        let home = path(runnerHome: runnerHome, deviceID: deviceID)
        let sharedBuilds = "\(runnerHome)/\(buildsDirectory)"
        let deviceBuilds = "\(home)/\(buildsDirectory)"
        do {
            try fm.createDirectory(atPath: deviceBuilds, withIntermediateDirectories: true)
            let drivers = "\(home)/drivers"
            if (try? fm.destinationOfSymbolicLink(atPath: drivers)) == nil {
                try? fm.removeItem(atPath: drivers)
                try fm.createSymbolicLink(atPath: drivers, withDestinationPath: "\(runnerHome)/drivers")
            }
        } catch {
            return nil
        }

        promoteDeviceBuilds(runnerHome: runnerHome, into: sharedBuilds, fileManager: fm)

        // Refresh every cached build so this device never launches from a
        // stale or half-edited copy. The lease on this UDID guarantees no
        // other run is using this home right now.
        for config in subdirectories(of: sharedBuilds, fileManager: fm) {
            let source = "\(sharedBuilds)/\(config)/\(productsDirectory)"
            guard hasXctestrun(in: source, fileManager: fm) else { continue }
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

    /// Copies builds that exist only in some device home into the shared
    /// cache. Copies to a unique sibling first and renames, so a concurrent
    /// promotion of the same build never leaves a partial copy behind.
    static func promoteDeviceBuilds(runnerHome: String, into sharedBuilds: String, fileManager fm: FileManager) {
        let devices = "\(runnerHome)/\(devicesDirectory)"
        for device in subdirectories(of: devices, fileManager: fm) {
            let builds = "\(devices)/\(device)/\(buildsDirectory)"
            for config in subdirectories(of: builds, fileManager: fm) {
                let source = "\(builds)/\(config)/\(productsDirectory)"
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
