import Foundation

/// Manages the embedded grantiva-runner binary: extraction, caching, and version validation.
public struct RunnerManager: Sendable, Decodable {
    public init(from decoder: Decoder) throws { self = .live }

    public var ensureAvailable: @Sendable () async throws -> Void
    public var runnerPath: @Sendable () -> String
    public var runnerDir: @Sendable () -> String
    /// Where a run takes its simulator lease; nil is `<runner home>/locks`.
    /// Tests that inject a fake runner point it at a temp directory so they
    /// never write into the user's runner home.
    public var leaseDirectory: String?
    /// `ensureAvailable` that says what happened: true when the runner was
    /// extracted, false when the installed stamp was already current.
    /// `willExtract` runs just before an extraction starts, so a caller can
    /// narrate it only when it happens.
    public var install: @Sendable (_ willExtract: @escaping @Sendable () -> Void) async throws -> Bool

    public init(
        ensureAvailable: @escaping @Sendable () async throws -> Void,
        runnerPath: @escaping @Sendable () -> String,
        runnerDir: @escaping @Sendable () -> String,
        leaseDirectory: String? = nil,
        install: (@Sendable (_ willExtract: @escaping @Sendable () -> Void) async throws -> Bool)? = nil
    ) {
        self.ensureAvailable = ensureAvailable
        self.runnerPath = runnerPath
        self.runnerDir = runnerDir
        self.leaseDirectory = leaseDirectory
        self.install = install ?? { _ in
            try await ensureAvailable()
            return false
        }
    }
}

extension RunnerManager {
    public static let runnerVersion = "1.1.28-grantiva.16"

    /// What the version file holds. Bump the suffix whenever the tarball
    /// layout changes without a runner rebuild, so `installIfNeeded` sees a
    /// mismatch and re-extracts.
    public static let installStamp = runnerVersion + "+android-drivers-2"

    static let resourceBundleName = "grantiva_GrantivaCore"

    /// The resource bundle that carries the runner tarballs, or nil when it is
    /// missing (a binary copied away from its `.bundle`). `Bundle.module`
    /// cannot be tried first: its generated accessor traps instead of
    /// returning nil. So this checks the places the SwiftPM accessors look
    /// (the `PACKAGE_RESOURCE_BUNDLE_PATH` override, the main and module
    /// bundles' resource dirs, the executable's directory) plus the directory
    /// holding the module's own bundle, which is where `swift build` puts the
    /// resource bundle beside a test bundle (the older accessor finds it there
    /// through a compiled-in build path).
    static let resourceBundle: Bundle? = {
        final class BundleFinder {}
        let environment = ProcessInfo.processInfo.environment
        let override = (environment["PACKAGE_RESOURCE_BUNDLE_PATH"] ?? environment["PACKAGE_RESOURCE_BUNDLE_URL"])
            .map { URL(fileURLWithPath: $0) }
        let moduleBundle = Bundle(for: BundleFinder.self)
        return findResourceBundle(in: [
            override,
            Bundle.main.resourceURL,
            moduleBundle.resourceURL,
            Bundle.main.bundleURL,
            Bundle.main.executableURL?.resolvingSymlinksInPath().deletingLastPathComponent(),
            moduleBundle.bundleURL.deletingLastPathComponent(),
        ])
    }()

    /// The first `<candidate>/grantiva_GrantivaCore.bundle` that exists, the
    /// override path itself counting when it names the bundle directly.
    static func findResourceBundle(in candidates: [URL?]) -> Bundle? {
        for candidate in candidates.compactMap({ $0 }) {
            let urls = candidate.lastPathComponent == resourceBundleName + ".bundle"
                ? [candidate]
                : [candidate.appendingPathComponent(resourceBundleName + ".bundle")]
            for url in urls {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue,
                   let bundle = Bundle(url: url) {
                    return bundle
                }
            }
        }
        return nil
    }

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
        if let problem = missingTarballsMessage(bundle: bundle) {
            throw GrantivaError.unavailable(problem + " Nothing was installed.")
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

    /// The tarballs this release's install needs, named by file.
    static var expectedTarballs: [String] {
        ["grantiva-runner-\(currentArch).tar.gz", "android-drivers.tar.gz"]
    }

    /// Why `bundle` cannot supply this release's runner: the tarballs it
    /// lacks. A bundle from before 2.1 has no `android-drivers.tar.gz`; this
    /// names the bundle and the missing file instead of the bare "Runner
    /// binary not found", which named neither.
    static func missingTarballsMessage(bundle: Bundle) -> String? {
        let missing = expectedTarballs.filter { name in
            let base = String(name.dropLast(".tar.gz".count))
            return bundle.url(forResource: base, withExtension: "tar.gz") == nil
        }
        guard !missing.isEmpty else { return nil }
        return "The resource bundle \(canonicalPath(bundle.bundlePath)) has no \(missing.joined(separator: " or ")): "
            + "it is from another grantiva release than this binary (which expects grantiva-runner \(runnerVersion)). "
            + "Reinstall grantiva so the binary and its bundle match."
    }

    /// Whether this release's runner is already installed: `ensureAvailable`
    /// then returns without looking at the resource bundle.
    public static func isCurrentInstallPresent() -> Bool {
        FileManager.default.fileExists(atPath: binaryPath)
            && FileManager.default.contents(atPath: versionFilePath)
                .flatMap { String(data: $0, encoding: .utf8) }?
                .trimmingCharacters(in: .whitespacesAndNewlines) == installStamp
    }

    /// A warning when the resource bundle beside the binary does not carry
    /// the runner the current install holds, or is missing. The install is
    /// used as it is (it is the right version); the bundle would fail the
    /// next fresh install, so say so now. nil when the bundle matches.
    public static func bundleMismatchWarning() -> String? {
        bundleMismatchWarning(bundle: resourceBundle, installed: runnerVersion, installDir: currentInstallDir)
    }

    private static let missingBundleWarned = NSLock()
    nonisolated(unsafe) private static var didWarnMissingBundle = false

    /// `bundleMismatchWarning`'s missing-bundle case, logged at most once per
    /// process, for commands that use the current install without reading
    /// the bundle. Cheap: it only checks that the bundle exists.
    static func warnOnceIfBundleMissing() {
        guard resourceBundle == nil else { return }
        let first = missingBundleWarned.withLock {
            defer { didWarnMissingBundle = true }
            return !didWarnMissingBundle
        }
        guard first, let warning = bundleMismatchWarning(bundle: nil, installed: runnerVersion, installDir: currentInstallDir) else { return }
        GrantivaLog.logger.warning("\(warning)")
    }

    static func bundleMismatchWarning(
        bundle: Bundle?, installed: String, installDir: String,
        reportedVersion: (String) -> Result<String, RunnerProbeFailure> = { reportedVersion(ofRunnerAt: $0) }
    ) -> String? {
        guard let bundle else {
            return "The \(resourceBundleName).bundle resource bundle was not found next to the grantiva executable. "
                + "The installed runner (\(installDir)) was left as it is, but a fresh install (a new runner home or another grantiva version) would fail. "
                + "Reinstall grantiva, or keep the bundle beside the binary when copying it."
        }
        if let problem = missingTarballsMessage(bundle: bundle) {
            return problem + " The installed runner (\(installDir)) was left as it is."
        }
        guard let tarball = bundle.url(forResource: "grantiva-runner-\(currentArch)", withExtension: "tar.gz") else { return nil }
        let fm = FileManager.default
        let scratch = fm.temporaryDirectory.appendingPathComponent("grantiva-bundle-check-\(UUID().uuidString)").path
        defer { try? fm.removeItem(atPath: scratch) }
        guard (try? fm.createDirectory(atPath: scratch, withIntermediateDirectories: true)) != nil else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xzf", tarball.path, "-C", scratch, "./grantiva-runner"]
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        let binary = "\(scratch)/grantiva-runner"
        guard process.terminationStatus == 0, fm.fileExists(atPath: binary),
              case .success(let found) = reportedVersion(binary), found != installed else { return nil }
        return "The grantiva-runner in \(canonicalPath(bundle.bundlePath)) reports version \(found), but the installed runner is \(installed) "
            + "(\(installDir)). The resource bundle beside the grantiva binary is from another release; "
            + "the installed runner was left as it is. Reinstall grantiva so the binary and its bundle match."
    }

    /// Shared runner state: `locks/` (simulator leases), the WDA build
    /// `cache/`, and one install per stamp under `versions/`.
    /// `GRANTIVA_RUNNER_HOME` overrides the default `~/.grantiva/runner`.
    static let baseDir: String = resolveBaseDir(environment: ProcessInfo.processInfo.environment)

    /// `GRANTIVA_RUNNER_HOME` made absolute (a relative value would leave the
    /// cache symlink dangling), else `~/.grantiva/runner`; spelled by
    /// `canonicalPath`, so the spelling does not depend on whether the home
    /// exists yet (L27).
    static func resolveBaseDir(
        environment: [String: String],
        currentDirectory: String = FileManager.default.currentDirectoryPath
    ) -> String {
        if let override = environment["GRANTIVA_RUNNER_HOME"], !override.isEmpty {
            let absolute = override.hasPrefix("/") ? override : "\(currentDirectory)/\(override)"
            return canonicalPath(absolute)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return canonicalPath("\(home)/.grantiva/runner")
    }

    /// `path` standardized, with its deepest existing ancestor resolved the
    /// way realpath(3) resolves it (`/tmp/x` becomes `/private/tmp/x`) and
    /// the rest appended. Foundation's standardization drops a leading
    /// `/private` only for paths that exist, which made one directory print
    /// two ways depending on whether it had been created yet.
    static func canonicalPath(_ path: String) -> String {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        var existing = standardized
        var rest: [String] = []
        while existing != "/", !FileManager.default.fileExists(atPath: existing) {
            rest.insert((existing as NSString).lastPathComponent, at: 0)
            existing = (existing as NSString).deletingLastPathComponent
        }
        var resolved = existing
        if let real = realpath(existing, nil) {
            resolved = String(cString: real)
            free(real)
        }
        guard !rest.isEmpty else { return resolved }
        return (resolved == "/" ? "" : resolved) + "/" + rest.joined(separator: "/")
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
            let extracted = try installLive(willExtract: {})
            // A current install is used without the bundle; a missing bundle
            // would fail the next fresh install, so say so now (L28).
            if !extracted { warnOnceIfBundleMissing() }
        },
        runnerPath: { binaryPath },
        runnerDir: { currentInstallDir },
        install: { willExtract in try installLive(willExtract: willExtract) }
    )

    @discardableResult
    static func installLive(willExtract: () -> Void) throws -> Bool {
        try installIfNeeded(
            baseDir: currentInstallDir,
            binaryPath: binaryPath,
            versionFilePath: versionFilePath,
            cacheDir: cacheDir,
            version: installStamp,
            lockPath: "\(baseDir)/locks/install-\(installStamp).lock",
            verify: {
                try verifyRunnerVersion(
                    at: $0, expected: runnerVersion,
                    bundlePath: resourceBundle.map { canonicalPath($0.bundlePath) } ?? "\(resourceBundleName).bundle"
                )
            },
            onInstalled: {
                pruneStaleInstalls(
                    versionsDir: "\(baseDir)/versions",
                    keeping: installStamp,
                    locksDir: "\(baseDir)/locks",
                    isInUse: { runnerProcessExists(installDir: installDir(baseDir: baseDir, stamp: $0)) }
                )
            },
            willExtract: willExtract,
            extract: { try extractEmbedded(into: $0) }
        )
    }

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
    /// `verify` is handed the extracted runner binary while it is still in
    /// staging; when it throws, nothing is swapped in and no stamp is written.
    /// Every call touches `baseDir/.last-used`; `onInstalled` runs after a
    /// fresh install.
    /// Returns true when it extracted, false when the stamp was current;
    /// `willExtract` runs just before an extraction.
    @discardableResult
    static func installIfNeeded(
        baseDir: String,
        binaryPath: String,
        versionFilePath: String,
        cacheDir: String,
        version: String,
        lockPath: String? = nil,
        verify: (String) throws -> Void = { _ in },
        onInstalled: () -> Void = {},
        willExtract: () -> Void = {},
        extract: (String) throws -> Void
    ) throws -> Bool {
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
            return false
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
            return false
        }

        willExtract()
        try installUnlocked(
            baseDir: baseDir, binaryPath: binaryPath, versionFilePath: versionFilePath,
            cacheDir: cacheDir, version: version, verify: verify, extract: extract
        )
        touchLastUsed(baseDir)
        onInstalled()
        return true
    }

    private static func installUnlocked(
        baseDir: String,
        binaryPath: String,
        versionFilePath: String,
        cacheDir: String,
        version: String,
        verify: (String) throws -> Void,
        extract: (String) throws -> Void
    ) throws {
        let fm = FileManager.default
        // A failed first install of this stamp must not leave an empty
        // `versions/<stamp>/` behind; one that replaces an earlier install
        // keeps the directory (and that install) as it was.
        let createdBaseDir = !fm.fileExists(atPath: baseDir)
        var installed = false
        defer { if createdBaseDir, !installed { try? fm.removeItem(atPath: baseDir) } }
        try fm.createDirectory(atPath: baseDir, withIntermediateDirectories: true)
        let staging = "\(baseDir)/.staging-\(UUID().uuidString)"
        let backup = "\(baseDir)/.previous-\(UUID().uuidString)"
        try fm.createDirectory(atPath: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: staging) }

        try extract(staging)

        // A stale resource bundle beside the binary carries another release's
        // runner. Check what was extracted before anything is swapped in, so
        // a mismatch leaves the previous install and its stamp as they were.
        let stagedBinary = "\(staging)/\((binaryPath as NSString).lastPathComponent)"
        if fm.fileExists(atPath: stagedBinary) {
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stagedBinary)
        }
        try verify(stagedBinary)

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
        installed = true
    }

    /// Why `<runner> --version` gave no version.
    struct RunnerProbeFailure: Error, Equatable {
        let reason: String
    }

    /// Throws unless the runner at `path` reports `expected` from
    /// `--version`. A runner that reports another version came from a stale
    /// resource bundle, and the message names `bundlePath`. A runner that
    /// cannot be run at all says why, without blaming the bundle.
    static func verifyRunnerVersion(
        at path: String,
        expected: String,
        bundlePath: String,
        reportedVersion: (String) -> Result<String, RunnerProbeFailure> = { reportedVersion(ofRunnerAt: $0) }
    ) throws {
        switch reportedVersion(path) {
        case .success(expected):
            return
        case .success(let found):
            throw GrantivaError.unavailable(
                "The grantiva-runner in \(bundlePath) reports version \(found), but this grantiva expects \(expected). "
                    + "The resource bundle beside the grantiva binary is from another release. "
                    + "Reinstall grantiva so the binary and its bundle match. The installed runner was left as it was."
            )
        case .failure(let failure):
            throw GrantivaError.unavailable(
                "Could not run \(path): \(failure.reason). "
                    + "It was extracted from \(bundlePath); reinstall grantiva if this persists. The installed runner was left as it was."
            )
        }
    }

    /// The version `<path> --version` prints on its first line
    /// (`grantiva-runner 1.1.28-grantiva.15`), or why there is none: the
    /// binary could not be launched, exited non-zero, printed nothing, or did
    /// not exit within `timeout`.
    static func reportedVersion(ofRunnerAt path: String, timeout: TimeInterval = 30) -> Result<String, RunnerProbeFailure> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do {
            try process.run()
        } catch {
            return .failure(.init(reason: error.localizedDescription))
        }
        // `--version` prints a few lines, well under the pipe buffer, so
        // waiting for exit before reading cannot deadlock.
        if exited.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return .failure(.init(reason: "it did not exit within \(timeout.formatted()) seconds"))
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            return .failure(.init(reason: "it exited with status \(process.terminationStatus)"))
        }
        let words = String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline).first?
            .split(whereSeparator: \.isWhitespace) ?? []
        guard let last = words.last else { return .failure(.init(reason: "it printed no version")) }
        return .success(words.count >= 2 ? String(words[1]) : String(last))
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
