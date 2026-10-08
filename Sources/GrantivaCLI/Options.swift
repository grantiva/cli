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
    func note(_ message: @autoclosure () -> String) {
        guard !json else { return }
        GrantivaLog.logger.info("\(message())")
    }
}

struct BuildOptions: ParsableArguments {
    @Option(name: .long, help: "Path to a pre-built .app bundle or .ipa archive. Skips the build step.")
    var appFile: String?

    @Flag(name: .long, help: "Skip building and installing — assume the app is already on the simulator.")
    var noBuild: Bool = false

    @Option(name: .long, help: "Write Xcode build products and intermediates to this DerivedData directory.")
    var derivedDataPath: String?

    /// True when the xcodebuild step should be skipped.
    var shouldSkipBuild: Bool { noBuild || appFile != nil }

    /// True when the install/launch step should be skipped (app already on sim).
    var shouldSkipInstall: Bool { noBuild }

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

    /// Resolves the product path for the app binary.
    /// - When `--app-file` is set: resolves the binary (extracting IPA if needed), validates it.
    /// - When `--no-build` is set: returns nil (no binary to install).
    /// - Otherwise: returns nil (caller should build normally).
    func resolveAppBinary() throws -> ResolvedBinary? {
        guard let appFile else { return nil }
        return try AppBinaryResolver.resolve(appFile)
    }

}

extension Platform: ExpressibleByArgument {}

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

    func make(_ platform: Platform) -> any DevicePlatform {
        value ?? DevicePlatformFactory.make(platform)
    }
}

struct PlatformOptions: ParsableArguments {
    @Option(name: .long, help: "Target platform: ios or android. Defaults to whichever of grantiva.yml / grantiva-android.yml exists, else the project files in this directory. GRANTIVA_PLATFORM also sets it.")
    var platform: Platform?

    /// Resolves the platform. When nothing at all points anywhere (no flag, no
    /// GRANTIVA_PLATFORM, no config file, no project files in this directory)
    /// the answer is iOS: before Android support every command was iOS and ran
    /// fine without a project here (`--app-file` + `--bundle-id`, a project in
    /// a subdirectory, `diff compare` over existing captures).
    func resolve(
        directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> Platform {
        let resolver = PlatformResolver(directory: directory, environment: environment)
        if platform == nil,
           (environment[PlatformResolver.environmentKey] ?? "").isEmpty,
           resolver.existingConfigFiles().isEmpty,
           resolver.detectFromDirectory().isEmpty {
            return .ios
        }
        return try resolver.resolve(flag: platform)
    }

    /// Resolves the platform and loads its config file. A missing file yields
    /// nil config; a malformed one throws. An explicit choice (`--platform` or
    /// GRANTIVA_PLATFORM) whose config file is missing while the other
    /// platform's file is present also throws: that is a wrong directory or a
    /// skipped `init`, not a config-less run.
    func loadConfig(
        directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> (Platform, GrantivaConfig?) {
        let resolver = PlatformResolver(directory: directory, environment: environment)
        let resolved = try resolve(directory: directory, environment: environment)
        let envValue = environment[PlatformResolver.environmentKey] ?? ""
        let source: String? = platform != nil
            ? "--platform \(resolved.rawValue)"
            : (envValue.isEmpty ? nil : "\(PlatformResolver.environmentKey)=\(resolved.rawValue)")
        if let source {
            let existing = resolver.existingConfigFiles()
            if !existing.contains(resolved), let other = existing.first {
                throw GrantivaError.invalidArgument(
                    "\(source) was given but \(resolved.configFileName) does not exist here. "
                        + "Found \(other.configFileName). Create \(resolved.configFileName) with grantiva init --platform \(resolved.rawValue)."
                )
            }
        }
        // DevicePlatformFactory traps on Android until AndroidPlatform lands;
        // stop here with a message instead of crashing.
        if resolved == .android {
            throw GrantivaError.invalidArgument(
                "Android support arrives in the next release. Pass --platform ios to run this directory as an iOS project."
            )
        }
        let config = try GrantivaConfig.loadIfPresent(platform: resolved, from: directory)
        return (resolved, config)
    }
}
