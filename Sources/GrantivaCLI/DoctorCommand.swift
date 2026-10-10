import ArgumentParser
import Foundation
import GrantivaCore

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check environment and dependencies."
    )

    @OptionGroup var options: GlobalOptions
    @OptionGroup var platformOptions: PlatformOptions

    func run() async throws {
        let selection = try Self.platformSelection(flag: platformOptions.platform)
        var checks = await DoctorRunner().runAllChecks(platforms: selection.platforms, required: selection.required)
        if let advice = selection.advice { checks.append(advice) }

        if options.json {
            Output.line(try JSONOutput.string(checks))
        } else {
            Output.line(DoctorFormatter().format(checks))
        }

        // `grantiva doctor || exit 1` is the intended CI preflight, and it could
        // never fire: every path exited 0. A failing required check exits
        // non-zero now, in both output modes.
        if DoctorRunner.hasFailures(checks) {
            throw ExitCode.failure
        }
    }

    /// Flag, then GRANTIVA_PLATFORM, then config files, then project files;
    /// nothing found means both platforms, reported as advice. An invalid
    /// GRANTIVA_PLATFORM is the same error `run` gives. Both project kinds
    /// with nothing to choose between them checks both toolchains as advice
    /// and adds an advisory check saying how to choose: doctor diagnoses, so
    /// it does not fail where `run` would ask.
    static func platformSelection(
        flag: Platform?,
        directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> (platforms: [Platform], required: Bool, advice: DoctorCheck?) {
        if let flag { return ([flag], true, nil) }
        let resolver = PlatformResolver(directory: directory, environment: environment)
        if let env = try resolver.environmentPlatform() {
            return ([env], true, nil)
        }
        let configs = resolver.existingConfigFiles()
        if !configs.isEmpty { return (Platform.allCases.filter(configs.contains), true, nil) }
        let detected = resolver.detectFromDirectory()
        if detected.count > 1 {
            let advice = DoctorCheck(
                name: "Platform", status: .warning,
                message: "Found both an Xcode project and Gradle settings",
                fix: "Pass --platform ios|android or set \(PlatformResolver.environmentKey).",
                section: .project
            )
            return (detected, false, advice)
        }
        if !detected.isEmpty { return (detected, true, nil) }
        return (Platform.allCases, false, nil)
    }
}
