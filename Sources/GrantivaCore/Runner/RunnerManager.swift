import Foundation

/// Manages the embedded grantiva-runner binary: extraction, caching, and version validation.
public struct RunnerManager: Sendable, Decodable {
    public init(from decoder: Decoder) throws { self = .live }

    public var ensureAvailable: @Sendable () async throws -> Void
    public var runnerPath: @Sendable () -> String
    public var runnerDir: @Sendable () -> String

    public init(
        ensureAvailable: @escaping @Sendable () async throws -> Void,
        runnerPath: @escaping @Sendable () -> String,
        runnerDir: @escaping @Sendable () -> String
    ) {
        self.ensureAvailable = ensureAvailable
        self.runnerPath = runnerPath
        self.runnerDir = runnerDir
    }
}

extension RunnerManager {
    public static let runnerVersion = "1.1.18-grantiva.7"

    /// What the version file holds. Bump the suffix whenever the tarball
    /// layout changes without a runner rebuild, so `installIfNeeded` sees a
    /// mismatch and re-extracts.
    public static let installStamp = runnerVersion + "+android-drivers-2"

    static let resourceBundleName = "grantiva_GrantivaCore"

    /// The resource bundle that carries the runner tarballs, or nil when it is
    /// missing (a binary copied away from its `.bundle`). Mirrors the
    /// SwiftPM-generated `Bundle.module` lookup, which traps instead of
    /// returning nil, so a missing bundle can surface as a `GrantivaError`.
    static let resourceBundle: Bundle? = {
        final class BundleFinder {}
        let candidates: [URL?] = [
            Bundle.main.resourceURL,
            Bundle(for: BundleFinder.self).resourceURL,
            Bundle.main.bundleURL,
            Bundle.main.executableURL?.resolvingSymlinksInPath().deletingLastPathComponent(),
        ]
        for candidate in candidates {
            if let url = candidate?.appendingPathComponent(resourceBundleName + ".bundle"),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return nil
    }()

    static func embeddedTarballURL(arch: String) -> URL? {
        resourceBundle?.url(forResource: "grantiva-runner-\(arch)", withExtension: "tar.gz")
    }

    static func embeddedDriversTarballURL() -> URL? {
        resourceBundle?.url(forResource: "android-drivers", withExtension: "tar.gz")
    }

    /// Extracts the arch runner tarball, then the shared Android drivers,
    /// into `destination`. Both unpack relative to `./`, so the result is
    /// `grantiva-runner`, `drivers/ios/…`, `drivers/android/*.apk`.
    static func extractEmbedded(into destination: String, bundle: Bundle? = resourceBundle) throws {
        guard let bundle else {
            throw GrantivaError.notFound(
                "The \(resourceBundleName).bundle resource bundle was not found next to the grantiva executable, "
                    + "so the embedded runner cannot be extracted. Reinstall grantiva, or keep the bundle beside the binary when copying it."
            )
        }
        guard let runner = bundle.url(forResource: "grantiva-runner-\(currentArch)", withExtension: "tar.gz"),
              let drivers = bundle.url(forResource: "android-drivers", withExtension: "tar.gz") else {
            throw GrantivaError.runnerNotFound
        }
        for tarball in [runner, drivers] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xzf", tarball.path, "-C", destination]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw GrantivaError.commandFailed("Failed to extract \(tarball.lastPathComponent)", process.terminationStatus)
            }
        }
    }

    /// Shared runner state: `locks/` (simulator leases), the WDA build
    /// `cache/`, and one install per stamp under `versions/`.
    /// `GRANTIVA_RUNNER_HOME` overrides the default `~/.grantiva/runner`.
    static let baseDir: String = resolveBaseDir(environment: ProcessInfo.processInfo.environment)

    /// `GRANTIVA_RUNNER_HOME` made absolute (a relative value would leave the
    /// cache symlink dangling), else `~/.grantiva/runner`.
    static func resolveBaseDir(environment: [String: String]) -> String {
        if let override = environment["GRANTIVA_RUNNER_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override).standardizedFileURL.path
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.grantiva/runner"
    }

    /// This version's install: the runner binary, its `version` stamp and
    /// `drivers/`. Each stamp gets its own directory so two grantiva versions
    /// on one host do not re-extract over each other.
    static func installDir(baseDir: String, stamp: String) -> String {
        "\(baseDir)/versions/\(stamp)"
    }

    static let currentInstallDir: String = {
        installDir(baseDir: baseDir, stamp: installStamp)
    }()

    public static let binaryPath: String = {
        "\(currentInstallDir)/grantiva-runner"
    }()

    static let versionFilePath: String = {
        "\(currentInstallDir)/version"
    }()

    static let cacheDir: String = {
        "\(baseDir)/cache"
    }()

    /// Returns the tarball arch suffix for the current CPU architecture.
    static var currentArch: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "amd64"
        #else
        return "arm64"
        #endif
    }

    public static let live = RunnerManager(
        ensureAvailable: {
            try installIfNeeded(
                baseDir: currentInstallDir,
                binaryPath: binaryPath,
                versionFilePath: versionFilePath,
                cacheDir: cacheDir,
                version: installStamp,
                lockPath: "\(baseDir)/locks/install-\(installStamp).lock",
                onInstalled: {
                    pruneStaleInstalls(
                        versionsDir: "\(baseDir)/versions",
                        keeping: installStamp,
                        locksDir: "\(baseDir)/locks",
                        isInUse: { runnerProcessExists(installDir: installDir(baseDir: baseDir, stamp: $0)) }
                    )
                },
                extract: { try extractEmbedded(into: $0) }
            )
        },
        runnerPath: { binaryPath },
        runnerDir: { currentInstallDir }
    )

    /// Installs the runner into `baseDir` unless `binaryPath` exists and the
    /// version file already holds `version`.
    ///
    /// The tarballs are extracted into a staging directory first; only when
    /// that succeeds are the extracted entries (the binary, `drivers/`) swapped
    /// into `baseDir`, one by one, and the version written last. Nothing else
    /// in `baseDir` is touched, and a failed extract leaves the previous
    /// install exactly as it was. When `cacheDir` lives outside `baseDir`, it
    /// is linked in as `cache` so the runner's WDA build cache is shared.
    ///
    /// With `lockPath`, the install runs under an exclusive `flock` on it and
    /// re-checks the stamp once the lock is held, so concurrent first runs of
    /// one stamp extract once instead of swapping entries under each other.
    /// Every call touches `baseDir/.last-used`; `onInstalled` runs after a
    /// fresh install.
    static func installIfNeeded(
        baseDir: String,
        binaryPath: String,
        versionFilePath: String,
        cacheDir: String,
        version: String,
        lockPath: String? = nil,
        onInstalled: () -> Void = {},
        extract: (String) throws -> Void
    ) throws {
        let fm = FileManager.default
        func isInstalled() -> Bool {
            fm.fileExists(atPath: binaryPath)
                && fm.contents(atPath: versionFilePath)
                    .flatMap { String(data: $0, encoding: .utf8) }?
                    .trimmingCharacters(in: .whitespacesAndNewlines) == version
        }
        if isInstalled() {
            try linkCache(cacheDir, into: baseDir)
            touchLastUsed(baseDir)
            return
        }

        var lockDescriptor: Int32 = -1
        if let lockPath {
            try fm.createDirectory(atPath: (lockPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            lockDescriptor = open(lockPath, O_RDWR | O_CREAT | O_CLOEXEC, 0o644)
            guard lockDescriptor >= 0 else {
                throw GrantivaError.commandFailed("Could not open the runner install lock \(lockPath)", errno)
            }
            while flock(lockDescriptor, LOCK_EX) != 0 && errno == EINTR {}
        }
        defer {
            if lockDescriptor >= 0 {
                flock(lockDescriptor, LOCK_UN)
                close(lockDescriptor)
            }
        }
        if lockPath != nil, isInstalled() {
            try linkCache(cacheDir, into: baseDir)
            touchLastUsed(baseDir)
            return
        }

        try installUnlocked(
            baseDir: baseDir, binaryPath: binaryPath, versionFilePath: versionFilePath,
            cacheDir: cacheDir, version: version, extract: extract
        )
        touchLastUsed(baseDir)
        onInstalled()
    }

    private static func installUnlocked(
        baseDir: String,
        binaryPath: String,
        versionFilePath: String,
        cacheDir: String,
        version: String,
        extract: (String) throws -> Void
    ) throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: baseDir, withIntermediateDirectories: true)
        let staging = "\(baseDir)/.staging-\(UUID().uuidString)"
        let backup = "\(baseDir)/.previous-\(UUID().uuidString)"
        try fm.createDirectory(atPath: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: staging) }

        try extract(staging)

        // Swap the extracted entries in, keeping the replaced ones aside until
        // every move has succeeded so a failure can put them back.
        // The tarball's `cache/` holds prebuilt WDA builds. It never replaces
        // the shared cache; configs the shared cache lacks are merged in below.
        let entries = try fm.contentsOfDirectory(atPath: staging).filter { $0 != "cache" }
        try fm.createDirectory(atPath: backup, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: backup) }
        var swapped: [(destination: String, previous: String?)] = []
        do {
            for entry in entries {
                let destination = "\(baseDir)/\(entry)"
                var previous: String?
                if (try? fm.attributesOfItem(atPath: destination)) != nil {
                    previous = "\(backup)/\(entry)"
                    try fm.moveItem(atPath: destination, toPath: previous!)
                }
                swapped.append((destination, previous))
                try fm.moveItem(atPath: "\(staging)/\(entry)", toPath: destination)
            }
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binaryPath)
        } catch {
            for item in swapped.reversed() {
                try? fm.removeItem(atPath: item.destination)
                if let previous = item.previous { try? fm.moveItem(atPath: previous, toPath: item.destination) }
            }
            throw error
        }

        try linkCache(cacheDir, into: baseDir)
        mergeMissing(from: "\(staging)/cache", into: cacheDir, depth: 1)
        try version.write(toFile: versionFilePath, atomically: true, encoding: .utf8)
    }

    static let lastUsedFileName = ".last-used"

    private static func touchLastUsed(_ installDir: String) {
        let path = "\(installDir)/\(lastUsedFileName)"
        let fm = FileManager.default
        if fm.fileExists(atPath: path) {
            try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: path)
        } else {
            fm.createFile(atPath: path, contents: Data())
        }
    }

    /// Deletes installs under `versionsDir` other than `keeping` whose
    /// `.last-used` (or, lacking one, `version`) is older than `maxAge` and
    /// that no running process uses. Installs with neither file, and staging
    /// or backup directories, are left alone. The legacy install at the
    /// runner root is never touched.
    static func pruneStaleInstalls(
        versionsDir: String,
        keeping current: String,
        locksDir: String? = nil,
        maxAge: TimeInterval = 30 * 24 * 60 * 60,
        now: Date = Date(),
        isInUse: (String) -> Bool
    ) {
        let fm = FileManager.default
        guard let stamps = try? fm.contentsOfDirectory(atPath: versionsDir) else { return }
        for stamp in stamps where stamp != current && !stamp.hasPrefix(".") {
            let dir = "\(versionsDir)/\(stamp)"
            func isStale() -> Bool {
                let marker = ["\(dir)/\(lastUsedFileName)", "\(dir)/version"].first { fm.fileExists(atPath: $0) }
                guard let marker,
                      let modified = (try? fm.attributesOfItem(atPath: marker))?[.modificationDate] as? Date else { return false }
                return now.timeIntervalSince(modified) > maxAge
            }
            guard isStale(), !isInUse(stamp) else { continue }
            // Skip a stamp that is being installed right now, and re-check the
            // marker in case a run passed its fast path since the first look.
            var descriptor: Int32 = -1
            if let locksDir {
                descriptor = open("\(locksDir)/install-\(stamp).lock", O_RDWR | O_CREAT | O_CLOEXEC, 0o644)
                guard descriptor >= 0 else { continue }
                guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { close(descriptor); continue }
            }
            if isStale() { try? fm.removeItem(atPath: dir) }
            if descriptor >= 0 {
                flock(descriptor, LOCK_UN)
                close(descriptor)
            }
        }
    }

    /// Whether any process runs `<installDir>/grantiva-runner`. Errs on the
    /// side of "in use" when pgrep cannot be run.
    static func runnerProcessExists(installDir: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", NSRegularExpression.escapedPattern(for: "\(installDir)/grantiva-runner")]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return true }
        process.waitUntilExit()
        return process.terminationStatus != 1
    }

    /// Creates the shared `cacheDir` and, when it lives outside `baseDir`,
    /// links it in as `baseDir/cache` (unless something is already there).
    private static func linkCache(_ cacheDir: String, into baseDir: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
        let link = "\(baseDir)/cache"
        guard (link as NSString).standardizingPath != (cacheDir as NSString).standardizingPath,
              (try? fm.attributesOfItem(atPath: link)) == nil else { return }
        try fm.createSymbolicLink(atPath: link, withDestinationPath: cacheDir)
    }

    /// Moves entries of `source` that `destination` lacks into it, descending
    /// `depth` levels into directories both sides have (`cache/wda-builds/<config>`),
    /// so an existing build is never mixed with a prebuilt one.
    private static func mergeMissing(from source: String, into destination: String, depth: Int) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: source) else { return }
        for entry in entries {
            let from = "\(source)/\(entry)", to = "\(destination)/\(entry)"
            var isDirectory: ObjCBool = false
            if fm.fileExists(atPath: to, isDirectory: &isDirectory) {
                if depth > 0, isDirectory.boolValue { mergeMissing(from: from, into: to, depth: depth - 1) }
            } else {
                try? fm.moveItem(atPath: from, toPath: to)
            }
        }
    }
}

extension RunnerManager {
    public static let failing = RunnerManager(
        ensureAvailable: { throw GrantivaError.runnerNotFound },
        runnerPath: { "" },
        runnerDir: { "" }
    )
}
