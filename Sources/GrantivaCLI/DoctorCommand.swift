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
        let selection = Self.platformSelection(flag: platformOptions.platform)
        let checks = await DoctorRunner().runAllChecks(platforms: selection.platforms, required: selection.required)

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
    /// nothing found means both platforms, reported as advice.
    static func platformSelection(
        flag: Platform?,
        directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> (platforms: [Platform], required: Bool) {
        if let flag { return ([flag], true) }
        let resolver = PlatformResolver(directory: directory, environment: environment)
        if let env = Platform(rawValue: (environment[PlatformResolver.environmentKey] ?? "").trimmingCharacters(in: .whitespaces).lowercased()) {
            return ([env], true)
        }
        let configs = resolver.existingConfigFiles()
        if !configs.isEmpty { return (Platform.allCases.filter(configs.contains), true) }
        let detected = resolver.detectFromDirectory()
        if !detected.isEmpty { return (Platform.allCases.filter(detected.contains), true) }
        return (Platform.allCases, false)
    }
}
