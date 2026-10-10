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
    static let baseDir: String = {
        if let override = ProcessInfo.processInfo.environment["GRANTIVA_RUNNER_HOME"], !override.isEmpty {
            return override
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.grantiva/runner"
    }()

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
    static func installIfNeeded(
        baseDir: String,
        binaryPath: String,
        versionFilePath: String,
        cacheDir: String,
        version: String,
        extract: (String) throws -> Void
    ) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: binaryPath),
           let versionData = fm.contents(atPath: versionFilePath),
           String(data: versionData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == version {
            try linkCache(cacheDir, into: baseDir)
            return
        }

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
