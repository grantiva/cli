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
