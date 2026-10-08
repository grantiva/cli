import ArgumentParser
import Foundation
import GrantivaCore
import GrantivaAPI

struct DiffCommand: AsyncParsableCommand {
    struct ComparisonOutcome {
        let screens: [ScreenDiff]
        let passed: Bool
    }

    struct CaptureArtifact: Equatable {
        let fileName: String
        let screenName: String
        let path: String?

        init(fileName: String, screenName: String, path: String? = nil) {
            self.fileName = fileName
            self.screenName = screenName
            self.path = path
        }
    }

    static let configuration = CommandConfiguration(
        commandName: "diff",
        abstract: "Visual regression testing — capture, compare, and approve screenshots.",
        subcommands: [CaptureCommand.self, CompareCommand.self, ApproveCommand.self]
    )

    // MARK: - Capture

    struct CaptureCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "capture",
            abstract: "Navigate to configured screens and capture screenshots."
        )

        @OptionGroup var options: GlobalOptions
        @OptionGroup var buildOptions: BuildOptions
        @OptionGroup var platformOptions: PlatformOptions
        @OptionGroup var target: TargetOptions

        /// Empty means "make one from the resolved platform"; tests inject a fake.
        var devicePlatform = InjectedDevicePlatform()

        func run() async throws {
            let (platform, config) = try platformOptions.loadConfig()
            try target.checkFlags(for: platform, derivedDataPath: buildOptions.derivedDataPath)
            let device = try devicePlatform.make(platform, android: target.androidOptions)

            // Resolve the app binary first (if provided) so we can derive bundle ID
            let resolvedBinary: ResolvedBinary? = if let appFile = buildOptions.appFile { try await device.resolveBinary(appFile) } else { nil }
            defer { resolvedBinary?.cleanup() }

            let appBundleId = resolvedBinary?.appID

            let resolved = try await target.resolve(
                platform: platform, config: config, skipBuild: buildOptions.shouldSkipBuild, appID: appBundleId
            )

            guard !resolved.screens.isEmpty else {
                throw GrantivaError.invalidArgument("No screens configured in grantiva.yml")
            }

            let outputDir = DiffCommand.captureDirectory(for: platform)
            let start = Date()

            var booted: BootedDevice
            var builtAppID: String?

            if !buildOptions.shouldSkipInstall {
                // Full lifecycle: boot → build → install → launch → capture
                // OR: boot → install pre-built → launch → capture
                booted = try await device.bootDevice(named: resolved.simulator)

                var productPath: String?

                if let resolvedBinary {
                    // Pre-built binary provided via --app-file
                    options.note("Using pre-built binary: \(URL(fileURLWithPath: resolvedBinary.appPath).lastPathComponent)")
                    productPath = resolvedBinary.appPath
                } else {
                    // Build from source. A missing scheme is rejected by the
                    // platform's build with the same message as before.
                    if let buildScheme = resolved.scheme {
                        options.note("Building \(buildScheme)...")
                    }

                    let buildResult = try await device.build(PlatformBuildRequest(
                        config: config ?? GrantivaConfig(),
                        resolved: resolved,
                        deviceID: booted.udid,
                        extraBuildSettings: target.extraBuildSettings(
                            platform: platform, derivedDataPath: buildOptions.derivedDataPath, resolved: resolved
                        )
                    ))

                    guard buildResult.success else {
                        if options.json {
                            Output.line(try JSONOutput.string(buildResult))
                        } else {
                            Output.line(TableFormatter().formatBuild(buildResult))
                        }
                        throw ExitCode.failure
                    }
                    productPath = buildResult.productPath
                    builtAppID = buildResult.applicationId
                }

                // Install and launch
                if let bid = resolved.bundleId ?? builtAppID {
                    if let productPath {
                        try await device.install(appID: bid, productPath: productPath, deviceID: booted.udid)
                    }
                    try await device.launch(appID: bid, deviceID: booted.udid)
                    try await Task.sleep(for: .seconds(2))
                }

                options.note("Capturing \(resolved.screens.count) screen(s)...")
            } else {
                // --no-build still honors an explicit target. This matters on
                // hosts where an iPad is already booted while the evidence
                // command asks for an iPhone by name/UDID.
                booted = if let explicit = target.simulator ?? target.device ?? target.emulator {
                    try await device.bootDevice(named: explicit)
                } else {
                    try await device.defaultDevice()
                }
            }

            guard let bid = resolved.bundleId ?? builtAppID else {
                throw GrantivaError.invalidArgument(
                    platform == .ios ? "Bundle ID is required for screen capture" : TargetOptions.appIDMessage(for: .android)
                )
            }

            let geometry = try await device.displayGeometry(deviceID: booted.udid)
            let captureTarget = CaptureSimulatorTarget(
                name: booted.name,
                udid: booted.udid,
                geometry: DiffCommand.simulatorGeometry(geometry)
            )

            options.note("Capturing \(resolved.screens.count) screen(s)...")

            let captures = try await RunnerSession.run(
                screens: resolved.screens,
                bundleId: bid,
                udid: booted.udid,
                platform: device,
                outputDir: outputDir,
                expectedPixels: captureTarget.pixelDimensions
            )

            // Print step-by-step results
            if !options.json {
                for capture in captures {
                    Output.line("\n  \(capture.screenName)")
                    for step in capture.steps {
                        let icon = step.status == .passed ? "\u{2713}" : "\u{2717}"
                        Output.line("    \(icon) \(step.action)")
                        if let msg = step.message {
                            Output.line("      \(msg)")
                        }
                    }
                }
                Output.line("")
            }

            let result = CaptureResult(
                screens: captures,
                directory: outputDir,
                duration: Date().timeIntervalSince(start),
                simulator: captureTarget
            )

            if options.json {
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line(TableFormatter().formatCapture(result))
            }
        }
    }

    // MARK: - Compare

    struct CompareCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "compare",
            abstract: "Diff current captures against baselines."
        )

        @OptionGroup var options: GlobalOptions
        @OptionGroup var buildOptions: BuildOptions
        @OptionGroup var platformOptions: PlatformOptions
        @OptionGroup var target: TargetOptions

        @Flag(name: .long, help: "Capture screenshots before comparing (runs full lifecycle)")
        var capture = false

        /// Empty means "make one from the resolved platform"; tests inject a fake.
        var devicePlatform = InjectedDevicePlatform()
        var imageDiffer: ImageDiffer = .live

        func run() async throws {
            // Only --capture touches a device, so only it insists on a platform.
            // A bare compare reads the resolved platform's config, falling back
            // to grantiva.yml, and is not blocked by an ambiguous directory or
            // a bad GRANTIVA_PLATFORM.
            let platform: Platform
            let config: GrantivaConfig?
            if capture {
                (platform, config) = try platformOptions.loadConfig()
            } else {
                platform = (try? platformOptions.resolve()) ?? .ios
                config = try GrantivaConfig.loadIfPresent(platform: platform)
            }
            let captureDir = DiffCommand.captureDirectory(for: platform)
            let diffDir = "\(captureDir)/diffs"
            let start = Date()
            var invocationCaptures: [ScreenCapture]?

            // Optionally capture first (with full lifecycle)
            if capture {
                try target.checkFlags(for: platform, derivedDataPath: buildOptions.derivedDataPath)
                let device = try devicePlatform.make(platform, android: target.androidOptions)

                let resolvedBinary: ResolvedBinary? = if let appFile = buildOptions.appFile { try await device.resolveBinary(appFile) } else { nil }
                defer { resolvedBinary?.cleanup() }

                let appBundleId = resolvedBinary?.appID

                let resolved = try await target.resolve(
                    platform: platform, config: config, skipBuild: buildOptions.shouldSkipBuild, appID: appBundleId
                )

                guard !resolved.screens.isEmpty else {
                    throw GrantivaError.invalidArgument("No screens configured in grantiva.yml")
                }

                let booted = try await device.bootDevice(named: resolved.simulator)
                var builtAppID: String?

                if !buildOptions.shouldSkipInstall {
                    var productPath: String?

                    if let resolvedBinary {
                        options.note("Using pre-built binary: \(URL(fileURLWithPath: resolvedBinary.appPath).lastPathComponent)")
                        productPath = resolvedBinary.appPath
                    } else {
                        // A missing scheme is rejected by the platform's build
                        // with the same message as before.
                        if let buildScheme = resolved.scheme {
                            options.note("Building \(buildScheme)...")
                        }

                        let buildResult = try await device.build(PlatformBuildRequest(
                            config: config ?? GrantivaConfig(),
                            resolved: resolved,
                            deviceID: booted.udid,
                            extraBuildSettings: target.extraBuildSettings(
                                platform: platform, derivedDataPath: buildOptions.derivedDataPath, resolved: resolved
                            )
                        ))

                        guard buildResult.success else {
                            if options.json {
                                Output.line(try JSONOutput.string(buildResult))
                            } else {
                                Output.line(TableFormatter().formatBuild(buildResult))
                            }
                            throw ExitCode.failure
                        }
                        productPath = buildResult.productPath
                        builtAppID = buildResult.applicationId
                    }

                    if let bid = resolved.bundleId ?? builtAppID {
                        if let productPath {
                            try await device.install(appID: bid, productPath: productPath, deviceID: booted.udid)
                        }
                        try await device.launch(appID: bid, deviceID: booted.udid)
                        try await Task.sleep(for: .seconds(2))
                    }
                }

                guard let bid = resolved.bundleId ?? builtAppID else {
                    throw GrantivaError.invalidArgument(
                        platform == .ios ? "Bundle ID is required for screen capture" : TargetOptions.appIDMessage(for: .android)
                    )
                }

                options.note("Capturing \(resolved.screens.count) screen(s)...")
                let geometry = try await device.displayGeometry(deviceID: booted.udid)
                let expectedPixels = geometry.dimensions

                let captures = try await RunnerSession.run(
                    screens: resolved.screens,
                    bundleId: bid,
                    udid: booted.udid,
                    platform: device,
                    outputDir: captureDir,
                    expectedPixels: expectedPixels
                )
                invocationCaptures = captures

                // Print step-by-step results
                if !options.json {
                    for capture in captures {
                        Output.line("\n  \(capture.screenName)")
                        for step in capture.steps {
                            let icon = step.status == .passed ? "\u{2713}" : "\u{2717}"
                            Output.line("    \(icon) \(step.action)")
                            if let msg = step.message {
                                Output.line("      \(msg)")
                            }
                        }
                    }
                    Output.line("")
                }
            }

            let diffConfig = config?.diff ?? .init()
            let fm = FileManager.default
            let store = try await DiffCommand.resolveBaselineStore(platform: platform)
            let differ = imageDiffer

            // Create diffs directory
            if !fm.fileExists(atPath: diffDir) {
                try fm.createDirectory(atPath: diffDir, withIntermediateDirectories: true)
            }

            // Find capture files
            guard fm.fileExists(atPath: captureDir) else {
                throw GrantivaError.noCaptures(captureDir)
            }
            let captureArtifacts: [CaptureArtifact]
            if let invocationCaptures {
                captureArtifacts = try DiffCommand.currentInvocationArtifacts(
                    from: invocationCaptures,
                    outputDir: captureDir
                )
            } else {
                let captureFiles = try fm.contentsOfDirectory(atPath: captureDir)
                    .filter { $0.hasSuffix(".png") }
                captureArtifacts = try DiffCommand.captureArtifacts(from: captureFiles)
            }

            guard !captureArtifacts.isEmpty else {
                throw GrantivaError.noCaptures(captureDir)
            }

            let comparison = try await DiffCommand.compare(
                captureArtifacts,
                captureDirectory: captureDir,
                diffDirectory: diffDir,
                config: diffConfig,
                store: store,
                differ: differ
            )

            let result = CompareResult(
                screens: comparison.screens,
                passed: comparison.passed,
                duration: Date().timeIntervalSince(start)
            )

            if options.json {
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line(TableFormatter().formatCompare(result))
            }

            if !comparison.passed {
                throw ExitCode.failure
            }
        }
    }

    // MARK: - Approve

    struct ApproveCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "approve",
            abstract: "Promote current captures to baselines."
        )

        @OptionGroup var options: GlobalOptions
        @OptionGroup var platformOptions: PlatformOptions

        @Argument(help: "Screen names to approve (default: all)")
        var screenNames: [String] = []

        func run() async throws {
            let platform = (try? platformOptions.resolve()) ?? .ios
            let captureDir = DiffCommand.captureDirectory(for: platform)
            let fm = FileManager.default
            let store = try await DiffCommand.resolveBaselineStore(platform: platform)

            guard fm.fileExists(atPath: captureDir) else {
                throw GrantivaError.noCaptures(captureDir)
            }

            let allCaptures = try fm.contentsOfDirectory(atPath: captureDir)
                .filter { $0.hasSuffix(".png") }

            guard !allCaptures.isEmpty else {
                throw GrantivaError.noCaptures(captureDir)
            }
            let captureArtifacts = try DiffCommand.captureArtifacts(from: allCaptures)

            let approved = try await DiffCommand.approve(
                screenNames,
                availableArtifacts: captureArtifacts,
                captureDirectory: captureDir,
                store: store
            )

            let result = ApproveResult(
                approvedScreens: approved,
                baselineDirectory: store.baselineDirectory()
            )

            if options.json {
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line(TableFormatter().formatApprove(result))
            }
        }
    }

    // MARK: - Baseline Store Resolution

    /// Returns canonical screenshot artifacts in deterministic order. Treating an
    /// undecodable filename as absent can make a comparison succeed without
    /// evaluating every capture that was discovered on disk.
    static func captureArtifacts(from fileNames: [String]) throws -> [CaptureArtifact] {
        try fileNames.sorted().map { fileName in
            guard
                let screenName = ScreenArtifact.screenName(from: fileName),
                ScreenArtifact.fileName(for: screenName) == fileName
            else {
                throw GrantivaError.invalidArgument(
                    "Invalid capture filename \"\(fileName)\". Capture files must use canonical percent-encoded screen names."
                )
            }
            return CaptureArtifact(fileName: fileName, screenName: screenName)
        }
    }

    /// Returns only screenshots explicitly produced by this runner invocation.
    /// A persistent capture directory may also contain captures from previous
    /// configurations, including a stale file for a screenshot that failed now.
    static func currentInvocationArtifacts(
        from captures: [ScreenCapture],
        outputDir: String
    ) throws -> [CaptureArtifact] {
        let fileManager = FileManager.default
        let outputURL = URL(fileURLWithPath: outputDir, isDirectory: true).standardizedFileURL
        var seenNames: Set<String> = []

        return try captures.compactMap { capture in
            guard !capture.path.isEmpty else { return nil }

            let fileName = ScreenArtifact.fileName(for: capture.screenName)
            let expectedURL = outputURL.appendingPathComponent(fileName).standardizedFileURL
            let captureURL = URL(fileURLWithPath: capture.path).standardizedFileURL
            guard captureURL == expectedURL else {
                throw GrantivaError.commandFailed(
                    "Runner returned capture outside the invocation output set: \(capture.path)",
                    1
                )
            }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: captureURL.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else {
                throw GrantivaError.commandFailed(
                    "Runner-reported capture is missing: \(capture.path)",
                    1
                )
            }
            guard seenNames.insert(fileName).inserted else {
                throw GrantivaError.commandFailed(
                    "Runner returned duplicate capture for \(capture.screenName)",
                    1
                )
            }

            return CaptureArtifact(
                fileName: fileName,
                screenName: capture.screenName,
                path: captureURL.path
            )
        }.sorted { $0.fileName < $1.fileName }
    }

    static func compare(
        _ artifacts: [CaptureArtifact],
        captureDirectory: String,
        diffDirectory: String,
        config: GrantivaConfig.DiffConfig,
        store: BaselineStore,
        differ: ImageDiffer
    ) async throws -> ComparisonOutcome {
        var screenDiffs: [ScreenDiff] = []
        var allPassed = true

        for artifact in artifacts {
            let screenName = artifact.screenName
            let capturePath = artifact.path ?? "\(captureDirectory)/\(artifact.fileName)"
            let captureData = try Data(contentsOf: URL(fileURLWithPath: capturePath))

            if let baselineData = try await store.load(screenName) {
                do {
                    let output = try differ.compare(baselineData, captureData)
                    let passed = output.pixelDiffPercent <= config.threshold
                        && output.perceptualDistance <= config.perceptualThreshold
                    var diffImagePath: String?
                    if !passed {
                        allPassed = false
                        let captureFile = ScreenArtifact.fileName(for: screenName)
                        let stem = URL(fileURLWithPath: captureFile).deletingPathExtension().lastPathComponent
                        let path = "\(diffDirectory)/\(stem)_diff.png"
                        try output.diffImageData.write(to: URL(fileURLWithPath: path))
                        diffImagePath = path
                    }

                    let message = passed
                        ? "Passed"
                        : "Failed: pixel=\(String(format: "%.2f%%", output.pixelDiffPercent * 100)) perceptual=\(String(format: "%.1f", output.perceptualDistance))"
                    screenDiffs.append(ScreenDiff(
                        screenName: screenName,
                        status: passed ? .passed : .failed,
                        pixelDiffPercent: output.pixelDiffPercent,
                        perceptualDistance: output.perceptualDistance,
                        pixelThreshold: config.threshold,
                        perceptualThreshold: config.perceptualThreshold,
                        baselinePath: "\(store.baselineDirectory())/\(ScreenArtifact.fileName(for: screenName))",
                        capturePath: capturePath,
                        diffImagePath: diffImagePath,
                        message: message
                    ))
                } catch {
                    allPassed = false
                    screenDiffs.append(ScreenDiff(
                        screenName: screenName,
                        status: .error,
                        pixelThreshold: config.threshold,
                        perceptualThreshold: config.perceptualThreshold,
                        capturePath: capturePath,
                        message: "Error: \(error.localizedDescription)"
                    ))
                }
            } else {
                screenDiffs.append(ScreenDiff(
                    screenName: screenName,
                    status: .newScreen,
                    pixelThreshold: config.threshold,
                    perceptualThreshold: config.perceptualThreshold,
                    capturePath: capturePath,
                    message: "New screen — no baseline. Run: grantiva diff approve"
                ))
            }
        }

        return ComparisonOutcome(screens: screenDiffs, passed: allPassed)
    }

    static func approve(
        _ requestedScreenNames: [String],
        availableArtifacts: [CaptureArtifact],
        captureDirectory: String,
        store: BaselineStore,
        fileManager: FileManager = .default
    ) async throws -> [String] {
        let screenNames = requestedScreenNames.isEmpty
            ? availableArtifacts.map(\.screenName)
            : requestedScreenNames
        var approved: [String] = []

        for screenName in screenNames {
            let capturePath = "\(captureDirectory)/\(ScreenArtifact.fileName(for: screenName))"
            guard fileManager.fileExists(atPath: capturePath) else {
                throw GrantivaError.noCaptures("No capture found for \"\(screenName)\"")
            }
            let data = try Data(contentsOf: URL(fileURLWithPath: capturePath))
            _ = try await store.save(screenName, data)
            approved.append(screenName)
        }

        return approved
    }

    static let androidLocalOnlyMessage =
        "Android baselines are local only until the Grantiva backend supports platforms; use local baselines"

    static func captureDirectory(for platform: Platform) -> String {
        platform == .ios ? ".grantiva/captures" : ".grantiva/captures/android"
    }

    static func baselineDirectory(for platform: Platform) -> String {
        platform == .ios ? ".grantiva/baselines" : ".grantiva/baselines/android"
    }

    /// Remote when authenticated, local otherwise; Android is always local
    /// and says so once when a login would otherwise have picked remote.
    static func resolveBaselineStore(
        platform: Platform,
        credentials: AuthCredentials? = AuthStore.resolveCredentials()
    ) async throws -> BaselineStore {
        if platform == .android {
            if credentials != nil {
                GrantivaLog.logger.warning("\(androidLocalOnlyMessage)")
            }
            return .local(directory: baselineDirectory(for: .android))
        }
        if let credentials {
            let client = try RangeClient(apiKey: credentials.apiKey, baseURL: credentials.baseURL)
            let projectId = try await ProjectIdentifier.resolve()
            return client.asBaselineStore(project: projectId.projectSlug, branch: projectId.currentBranch, baseURL: credentials.baseURL)
        }
        return .local()
    }

    /// The capture report's simulator geometry, derived the same way
    /// `SimulatorManager.displayGeometry` derives it: points are pixels over
    /// scale, rounded.
    static func simulatorGeometry(_ geometry: DeviceGeometry) -> SimulatorDisplayGeometry {
        SimulatorDisplayGeometry(
            points: [
                Int((Double(geometry.pixelWidth) / geometry.scale).rounded()),
                Int((Double(geometry.pixelHeight) / geometry.scale).rounded()),
            ],
            pixels: [geometry.pixelWidth, geometry.pixelHeight],
            scale: geometry.scale
        )
    }
}
