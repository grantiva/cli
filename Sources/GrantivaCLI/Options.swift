import ArgumentParser
import Foundation
import GrantivaCore

/// Diagnostic verbosity. Split out of `GlobalOptions` so `grantiva init`, which
/// has no `--json` to offer, can still take `--verbose` / `--quiet`.
///
/// Both flags are declared here for `--help` and for parsing; the level itself
/// is resolved from the argument vector by `LogVerbosity`, because logging has
/// to be bootstrapped before any command is parsed.
struct VerbosityOptions: ParsableArguments {
    @Flag(name: .long, help: "Print diagnostic detail (timestamps, labels, metadata) to stderr.")
    var verbose = false

    @Flag(name: .long, help: "Silence progress diagnostics on stderr; warnings and errors still print. Program output on stdout is unaffected.")
    var quiet = false
}

struct GlobalOptions: ParsableArguments {
    @Flag(name: .long, help: "Output as JSON")
    var json = false

    @OptionGroup var verbosity: VerbosityOptions

    /// Progress narration for a human watching the command work. Goes to
    /// stderr, never stdout.
    ///
    /// Suppressed under `--json`, which is unchanged from before the split: a
    /// caller asking for a machine-readable result has not asked for a running
    /// commentary. Warnings and errors are not routed through here and are
    /// never suppressed.
    ///
    /// Once an interrupt is under way nothing narrated here prints: the log
    /// handler drops it (the interrupt notice is the last line).
    func note(_ message: @autoclosure () -> String) {
        guard !json else { return }
        GrantivaLog.logger.info("\(message())")
    }

    /// The command's outcome when the interrupt itself produced it (a
    /// teardown's stop of a foreground `runner start`): unlike `note`, it
    /// prints after the interrupt notice.
    func noteOutcome(_ message: String) {
        guard !json else { return }
        GrantivaLog.logger.info("\(message)", metadata: CLILogHandler.afterInterrupt)
    }

    /// Applies `--quiet`/`--json`/`--verbose` to the runner's relayed output
    /// (see `RunnerSession.narrate`). Commands that start the runner call
    /// this before they do.
    func applyRunnerNarration() {
        RunnerNarration.isSilenced = RunnerNarration.shouldSilence(
            json: json, quiet: verbosity.quiet, verbose: verbosity.verbose
        )
    }

    /// What a command that starts the runner does first: the narration
    /// switch, and the interrupt handler. Installed here, before the device
    /// is resolved or booted, a Ctrl-C in the first second ends the run
    /// through `SignalRelay` (its children and cleanups) instead of killing
    /// it silently by the default action (C14).
    func prepareRunnerCommand(relay: SignalRelay = .shared) {
        applyRunnerNarration()
        relay.install()
    }
}

struct BuildOptions: ParsableArguments {
    @Option(name: .long, help: "Path to a pre-built app: .app bundle or .ipa archive (iOS), .apk (Android). Skips the build step.")
    var appFile: String?

    @Flag(name: .long, help: "Skip building and installing — assume the app is already on the device. With --app-file, that file is installed (only the build is skipped).")
    var noBuild: Bool = false

    @Option(name: .long, help: "Write Xcode build products and intermediates to this DerivedData directory.")
    var derivedDataPath: String?

    /// True when the xcodebuild step should be skipped.
    var shouldSkipBuild: Bool { noBuild || appFile != nil }

    /// True when the install step should be skipped (app already on the
    /// device). An explicit `--app-file` wins over `--no-build`'s "assume it
    /// is installed": the file is installed.
    var shouldSkipInstall: Bool { noBuild && appFile == nil }

    /// Merges command-line build options with project configuration. An
    /// explicit CLI DerivedData path takes precedence over build_settings.
    func xcodeBuildSettings(merging configured: [String]) -> [String] {
        Self.xcodeBuildSettings(derivedDataPath: derivedDataPath, merging: configured)
    }

    static func xcodeBuildSettings(
        derivedDataPath: String?,
        merging configured: [String]
    ) -> [String] {
        guard let derivedDataPath else { return configured }

        var settings: [String] = []
        var index = 0
        while index < configured.count {
            let setting = configured[index]
            if setting == "-derivedDataPath" {
                index += min(2, configured.count - index)
                continue
            }
            if setting.hasPrefix("-derivedDataPath=") {
                index += 1
                continue
            }
            settings.append(setting)
            index += 1
        }
        settings += ["-derivedDataPath", derivedDataPath]
        return settings
    }

}

extension Platform: ExpressibleByArgument {}
extension LogStreamLevel: ExpressibleByArgument {}

/// Test seam a command can carry as a plain stored property. ArgumentParser
/// requires every stored property of a command to be Decodable; an existential
/// `any DevicePlatform` is not, so it rides in this box. Decoding always yields
/// an empty box, meaning "make the platform from the resolved `Platform`";
/// tests assign a fake before calling `run()`.
struct InjectedDevicePlatform: Decodable {
    var value: (any DevicePlatform)?

    init(_ value: (any DevicePlatform)? = nil) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        value = nil
    }

    func make(_ platform: Platform, android: AndroidPlatform.Options = .init()) throws -> any DevicePlatform {
        try value ?? DevicePlatformFactory.make(platform, android: android)
    }
}

/// Test seam for the live `runner start` session a command may capture
/// through, carried as a plain stored property like `InjectedDevicePlatform`.
struct RunnerSessionLookup: Decodable, Sendable {
    private let lookup: (@Sendable (Platform) async -> RunnerSessionInfo?)?

    init(_ lookup: (@Sendable (Platform) async -> RunnerSessionInfo?)? = nil) {
        self.lookup = lookup
    }

    init(from decoder: Decoder) throws {
        lookup = nil
    }

    func find(_ platform: Platform) async -> RunnerSessionInfo? {
        if let lookup { return await lookup(platform) }
        return await DiffCommand.liveSession(for: platform)
    }
}

/// Test seam for a command's progress notes, carried as a plain stored
/// property like `InjectedDevicePlatform`. Decoded (the real command), it
/// forwards to `GlobalOptions.note`; made with `init()` in a test, it keeps
/// the lines instead.
final class NoteSink: Decodable, @unchecked Sendable {
    private let lock = NSLock()
    private let collecting: Bool
    private var collected: [String] = []

    init() { collecting = true }
    init(from decoder: Decoder) throws { collecting = false }

    var lines: [String] { lock.withLock { collected } }

    func note(_ message: String, options: GlobalOptions) {
        guard collecting else { return options.note(message) }
        lock.withLock { collected.append(message) }
    }
}

struct PlatformOptions: ParsableArguments {
    @Option(name: .long, help: "Target platform: ios or android. Defaults to whichever of grantiva.yml / grantiva-android.yml exists, else the project files in this directory. GRANTIVA_PLATFORM also sets it.")
    var platform: Platform?

    /// Resolves the platform. When nothing at all points anywhere (no flag, no
    /// GRANTIVA_PLATFORM, no config file, no project files in this directory)
    /// the answer is iOS: before Android support every command was iOS and ran
    /// fine without a project here (`--app-file` + `--bundle-id`, a project in
    /// a subdirectory, `diff compare` over existing captures). A command
    /// given an Android-only target (`--device`, `--emulator`) passes
    /// `fallback: .android` so that target decides instead (D2-12).
    func resolve(
        directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fallback: Platform = .ios
    ) throws -> Platform {
        try PlatformResolver(directory: directory, environment: environment).resolveOrDefault(flag: platform, fallback: fallback)
    }

    /// Resolves the platform and loads its config file. A missing file yields
    /// nil config; a malformed one throws. An explicit choice (`--platform` or
    /// GRANTIVA_PLATFORM) whose config file is missing while the other
    /// platform's file is present also throws: that is a wrong directory or a
    /// skipped `init`, not a config-less run.
    ///
    /// `includeMaestroDirectory: false` (a run given `--flow`) skips the
    /// `.maestro/` fallback so unrelated flow files are never parsed.
    func loadConfig(
        directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        includeMaestroDirectory: Bool = true,
        fallback: Platform = .ios
    ) throws -> (Platform, GrantivaConfig?) {
        let resolver = PlatformResolver(directory: directory, environment: environment)
        let resolved = try resolve(directory: directory, environment: environment, fallback: fallback)
        let envValue = environment[PlatformResolver.environmentKey] ?? ""
        let source: String? = platform != nil
            ? "--platform \(resolved.rawValue)"
            : (envValue.isEmpty ? nil : "\(PlatformResolver.environmentKey)=\(resolved.rawValue)")
        if let source {
            let existing = resolver.existingConfigFiles()
            if !existing.contains(resolved), let other = existing.first {
                let advice = "Create \(resolved.configFileName) with grantiva init --platform \(resolved.rawValue)."
                throw GrantivaError.invalidArgument(
                    "\(source) was given but \(resolved.configFileName) does not exist here. "
                        + "Found \(other.configFileName). \(advice)"
                )
            }
        }
        let config = try GrantivaConfig.loadIfPresent(
            platform: resolved, from: directory, includeMaestroDirectory: includeMaestroDirectory
        )
        return (resolved, config)
    }
}

/// Runs a `validate()` check whose `GrantivaError` is a usage error. Every
/// usage error reads `Error: <message>` and exits 64; a GrantivaError thrown
/// from `validate()` as is, or wrapped with its description, carried the
/// runtime "Invalid argument:" prefix instead.
func usageCheck<T>(_ check: () throws -> T) throws -> T {
    do {
        return try check()
    } catch let error as GrantivaError {
        throw ValidationError(error.usageMessage)
    }
}
