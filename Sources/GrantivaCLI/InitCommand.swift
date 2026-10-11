import ArgumentParser
import Foundation
import GrantivaCore

struct InitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Generate grantiva.yml (iOS) or grantiva-android.yml (Android) in the current directory."
    )

    @OptionGroup var verbosity: VerbosityOptions
    @OptionGroup var platformOptions: PlatformOptions

    @Option(name: .long, help: "Scheme name")
    var scheme: String?

    @Option(name: .long, help: "Bundle identifier")
    var bundleId: String?

    @Option(name: .long, help: "Application ID (Android)")
    var applicationId: String?

    func run() async throws {
        try await run(environment: ProcessInfo.processInfo.environment)
    }

    func run(environment: [String: String]) async throws {
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath

        let platform = try Self.platform(
            flag: platformOptions.platform,
            environment: environment,
            detected: PlatformResolver(directory: URL(fileURLWithPath: cwd, isDirectory: true)).detectFromDirectory()
        )
        try Self.checkFlags(for: platform, scheme: scheme, bundleId: bundleId, applicationId: applicationId)
        if platform == .android {
            let configPath = "\(cwd)/grantiva-android.yml"
            if fm.fileExists(atPath: configPath) {
                GrantivaLog.logger.info("grantiva-android.yml already exists — skipping")
                return
            }
            let yaml = Self.androidTemplate(
                module: Self.detectModule(in: cwd),
                applicationId: applicationId,
                emulator: "Pixel_8_API_35"
            )
            try yaml.write(toFile: configPath, atomically: true, encoding: .utf8)
            GrantivaLog.logger.info("Created grantiva-android.yml")
            return
        }

        // Generate grantiva.yml
        let configPath = "\(cwd)/grantiva.yml"
        if fm.fileExists(atPath: configPath) {
            GrantivaLog.logger.info("grantiva.yml already exists — skipping")
        } else {
            let (yaml, templateWarnings) = Self.iosTemplate(
                scheme: scheme, detected: scheme == nil ? await Self.detectSchemes(in: cwd) : nil, bundleId: bundleId
            )
            var warnings = templateWarnings
            if let devices = try? await SimulatorManager.live.listDevices(),
               let warning = Self.existingSimulatorWarning(
                   name: DefaultSimulator.name, devices: devices,
                   createdByGrantiva: Set(((try? SimulatorProvenance.live.all()) ?? []).map(\.udid))
               ) {
                warnings.append(warning)
            }
            try yaml.write(toFile: configPath, atomically: true, encoding: .utf8)
            GrantivaLog.logger.info("Created grantiva.yml")
            for warning in warnings { GrantivaLog.logger.warning("\(warning)") }
        }

    }

    /// Which platform to initialize. An explicit flag wins, then
    /// GRANTIVA_PLATFORM (an invalid value is an error, as for `run`);
    /// otherwise the project files decide, and a directory with none of them
    /// stays iOS, as `init` always was.
    static func platform(flag: Platform?, environment: [String: String] = [:], detected: [Platform]) throws -> Platform {
        if let flag { return flag }
        if let platform = try PlatformResolver(environment: environment).environmentPlatform() {
            return platform
        }
        switch detected.count {
        case 2:
            throw GrantivaError.invalidArgument(
                "Found both an Xcode project and Gradle settings. Pass --platform ios|android or set \(PlatformResolver.environmentKey)."
            )
        case 1:
            return detected[0]
        default:
            return .ios
        }
    }

    /// The iOS config, plus a warning for each value that is a guess rather
    /// than something read from the project or the host.
    /// What scheme detection found in the directory: the Xcode container's
    /// name and the schemes `xcodebuild -list` reports (empty when listing
    /// failed). nil means no Xcode project.
    struct DetectedSchemes: Equatable {
        var container: String
        var schemes: [String]
    }

    static func iosTemplate(
        scheme: String?, detected: DetectedSchemes?, bundleId: String?, newestIPhone: String? = DefaultSimulator.resolved
    ) -> (yaml: String, warnings: [String]) {
        var warnings: [String] = []
        let schemeName: String
        // Several schemes: write none rather than guess, as `run` refuses to
        // guess for the same project. The commented line keeps the file
        // loadable and shows where the choice goes.
        var schemeLine: String?
        if let scheme {
            schemeName = scheme
        } else if let detected, detected.schemes.count == 1 {
            schemeName = detected.schemes[0]
        } else if let detected, detected.schemes.count > 1 {
            schemeName = detected.schemes[0]
            let found = detected.schemes.joined(separator: ", ")
            schemeLine = "# scheme: \(schemeName)   # several schemes found (\(found)); set one"
            warnings.append("Several schemes found: \(found). Set scheme in grantiva.yml or pass --scheme.")
        } else if let detected {
            schemeName = detected.container
            warnings.append(
                "Could not list the schemes of the Xcode project; scheme \"\(schemeName)\" is a guess. Edit grantiva.yml or pass --scheme."
            )
        } else {
            schemeName = "MyApp"
            warnings.append("No Xcode project found; scheme \"MyApp\" is a placeholder. Edit grantiva.yml or pass --scheme.")
        }
        let simulator: String
        if let newestIPhone {
            simulator = newestIPhone
        } else {
            simulator = DefaultSimulator.fallback
            warnings.append("No installed iPhone simulator type found; simulator \"\(simulator)\" is a placeholder. Edit grantiva.yml.")
        }
        let bundleLine = bundleId.map { "bundle_id: \($0)" } ?? "# bundle_id: com.example.myapp"
        let yaml = """
        # Generated by grantiva init — commit this file
        \(schemeLine ?? "scheme: \(schemeName)")
        # workspace: \(detected?.container ?? schemeName).xcworkspace
        simulator: \(simulator)
        \(bundleLine)

        screens:
          - name: Home
            path: launch

        diff:
          # both must pass: threshold is a 0-1 fraction of differing pixels, perceptual_threshold is the mean CIE76 distance over differing pixels
          threshold: 0.02
          perceptual_threshold: 5.0

        # a11y:
        #   rules:
        #     - missing_label
        #     - small_tap_target
        """
        return (yaml, warnings)
    }

    /// The default is a stock device-type name, so the user may already have
    /// a simulator called that for something else; `run` would boot and
    /// drive it. Says so, naming it, unless Grantiva created it.
    static func existingSimulatorWarning(
        name: String, devices: [SimulatorDevice], createdByGrantiva: Set<String>
    ) -> String? {
        let theirs = devices.filter { $0.name == name && !createdByGrantiva.contains($0.udid) }
        guard !theirs.isEmpty else { return nil }
        let listed = theirs.map { "\"\($0.name)\" (\($0.udid))" }.joined(separator: ", ")
        return "A simulator named \(listed) already exists and was not created by Grantiva; runs from this directory will boot and drive it. "
            + "To keep them off it, set simulator: in grantiva.yml to a name of your own, for example \"Grantiva \(name)\" "
            + "(created on first use with `grantiva simulator ensure --name \"Grantiva \(name)\"`)."
    }

    /// Rejects a flag from the other platform by name, as `run` does,
    /// instead of writing a config file that silently drops it.
    static func checkFlags(for platform: Platform, scheme: String?, bundleId: String?, applicationId: String?) throws {
        let wrong: [(String, Bool)] = platform == .ios
            ? [("--application-id", applicationId != nil)]
            : [("--scheme", scheme != nil), ("--bundle-id", bundleId != nil)]
        if let offending = wrong.first(where: { $0.1 })?.0 {
            throw TargetOptions.otherPlatformFlagError(offending, platform: platform)
        }
    }

    static func androidTemplate(module: String, applicationId: String?, emulator: String) -> String {
        let idLine = applicationId.map { "application_id: \($0)" } ?? "# application_id: com.example.myapp   # read from the build when omitted"
        return """
        # Generated by grantiva init — commit this file
        platform: android
        module: \(module)
        variant: debug
        \(idLine)
        emulator: \(emulator)
        system_image: "system-images;android-35;google_apis;arm64-v8a"
        # Intel Macs: use "system-images;android-35;google_apis;x86_64"
        # build_args: ["-PsomeFlag=1"]

        screens:
          - name: Home
            path: launch

        diff:
          # both must pass: threshold is a 0-1 fraction of differing pixels, perceptual_threshold is the mean CIE76 distance over differing pixels
          threshold: 0.02
          perceptual_threshold: 5.0

        # a11y:
        #   rules:
        #     - missing_label
        #     - small_tap_target

        """
    }

    /// `app` when it has a build file, else the first module whose build
    /// file applies `com.android.application`, else `app`.
    static func detectModule(in directory: String) -> String {
        let fm = FileManager.default
        func buildFile(_ module: String) -> String? {
            ["build.gradle.kts", "build.gradle"].map { "\(directory)/\(module)/\($0)" }.first { fm.fileExists(atPath: $0) }
        }
        if buildFile("app") != nil { return "app" }
        let entries = ((try? fm.contentsOfDirectory(atPath: directory)) ?? []).sorted()
        for entry in entries where !entry.hasPrefix(".") {
            guard let file = buildFile(entry), let contents = try? String(contentsOfFile: file, encoding: .utf8),
                  contents.contains("com.android.application") else { continue }
            return entry
        }
        return "app"
    }

    /// The project's schemes, from the same `xcodebuild -list` detection
    /// the resolver uses (`ProjectDetector.listSchemes`), so `init` and
    /// `run` never disagree. nil when the directory has no Xcode project.
    static func detectSchemes(in directory: String) async -> DetectedSchemes? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory) else { return nil }
        let container = contents.sorted().first { $0.hasSuffix(".xcworkspace") && !$0.hasPrefix(".") }
            ?? contents.sorted().first { $0.hasSuffix(".xcodeproj") && !$0.hasPrefix(".") }
        guard let container else { return nil }
        let name = (container as NSString).deletingPathExtension
        let schemes = (try? await ProjectDetector.listSchemes(inDirectory: directory).schemes) ?? []
        return DetectedSchemes(container: name, schemes: schemes)
    }
}
