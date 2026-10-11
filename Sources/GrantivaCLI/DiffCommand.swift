import ArgumentParser
import Foundation
import GrantivaCore
import GrantivaAPI
import GrantivaMCP

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
        var runnerManager: RunnerManager = .live
        var notes = NoteSink()
        /// The live `runner start` session in this directory; tests inject one.
        var sessionLookup = RunnerSessionLookup()

        func run() async throws {
            options.applyRunnerNarration()
            let (platform, config) = try platformOptions.loadConfig()
            try target.checkFlags(for: platform, derivedDataPath: buildOptions.derivedDataPath)
            // No config means no screens: say so before scheme resolution,
            // with the same sentence `run` gives.
            if config == nil {
                throw DiffCommand.noScreensError(platform: platform, config: nil)
            }
            let device = try devicePlatform.make(platform, android: target.androidOptions)

            // Resolve the app binary first (if provided) so we can derive bundle ID
            let resolvedBinary: ResolvedBinary? = if let appFile = buildOptions.appFile { try await device.resolveBinary(appFile) } else { nil }
            defer { resolvedBinary?.cleanup() }

            let appBundleId = resolvedBinary?.appID

            let resolved = try await target.resolve(
                platform: platform, config: config, skipBuild: buildOptions.shouldSkipBuild, appID: appBundleId
            )

            guard !resolved.screens.isEmpty else {
                throw DiffCommand.noScreensError(platform: platform, config: config)
            }

            let outputDir = DiffCommand.captureDirectory(for: platform)
            let start = Date()

            var booted: BootedDevice
            var builtAppID: String?
            var appID: String?
            /// The `runner start` session holding the device, when there is one.
            var holdingSession: RunnerSessionInfo?

            if !buildOptions.shouldSkipInstall {
                // Full lifecycle: boot → build → install → launch → capture
                // OR: boot → install pre-built → launch → capture
                booted = try await device.bootDevice(for: resolved)

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
                appID = target.installedAppID(platform: platform, config: config, resolved: resolved, binaryID: builtAppID ?? appBundleId, warn: { GrantivaLog.logger.warning("\($0)") })
                if let bid = appID {
                    if let productPath {
                        try await device.install(appID: TargetOptions.installAppID(platform: platform, testID: bid, binaryID: builtAppID ?? appBundleId), productPath: productPath, deviceID: booted.udid)
                    }
                    try await device.launch(appID: bid, deviceID: booted.udid)
                    try await Task.sleep(for: .seconds(2))
                }
            } else {
                // --no-build honours flag > config > runner session, and only
                // then the platform default, which on iOS refuses to pick among
                // several booted simulators. The session is looked up at most
                // once: for the session tier, and then to learn whether it
                // holds the device being captured (a named device can be the
                // session's too). Without `.grantiva/session.json` the lookup
                // returns at once, with no `ps`.
                let session = SessionOnce(lookup: sessionLookup, platform: platform)
                booted = try await DiffCommand.noBuildDevice(
                    platform: platform,
                    explicit: target.simulator ?? target.device ?? target.emulator,
                    config: config,
                    sessionUDID: { DiffCommand.sessionUDID(await session.value()?.udid, for: platform) },
                    device: device
                )
                holdingSession = DiffCommand.session(await session.value(), holding: booted.udid)
                appID = target.installedAppID(platform: platform, config: config, resolved: resolved, binaryID: builtAppID ?? appBundleId, warn: { GrantivaLog.logger.warning("\($0)") })
            }

            guard let bid = appID else {
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

            notes.note("Capturing \(resolved.screens.count) screen(s)...", options: options)

            let captures: [ScreenCapture]
            if let holdingSession {
                // The session's runner holds the device lease; a second
                // runner would be refused, so capture through the session.
                notes.note("Capturing through the runner session (grantiva-runner pid \(holdingSession.pid)).", options: options)
                let port = holdingSession.wdaPort > 0 ? holdingSession.wdaPort : nil
                let attachment = try await device.attachDriver(deviceID: booted.udid, port: port)
                do {
                    captures = try await SessionScreenCapture.capture(
                        screens: resolved.screens, appID: bid, udid: booted.udid, platform: platform,
                        driver: attachment.client, device: device, outputDir: outputDir,
                        expectedPixels: captureTarget.pixelDimensions,
                        timeoutSeconds: SessionScreenCapture.defaultTimeoutSeconds
                    )
                } catch {
                    await attachment.detach()
                    throw error
                }
                await attachment.detach()
            } else {
                captures = try await RunnerSession.run(
                    screens: resolved.screens,
                    bundleId: bid,
                    udid: booted.udid,
                    platform: device,
                    runner: runnerManager,
                    outputDir: outputDir,
                    expectedPixels: captureTarget.pixelDimensions
                )
            }

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

            let result = DiffCommand.captureResult(
                screens: captures, directory: outputDir, duration: Date().timeIntervalSince(start),
                target: captureTarget, platform: platform
            )

            if options.json {
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line(TableFormatter().formatCapture(result, platform: platform))
            }
        }
    }

    static func captureResult(
        screens: [ScreenCapture], directory: String, duration: Double, target: CaptureSimulatorTarget, platform: Platform
    ) -> CaptureResult {
        CaptureResult(screens: screens, directory: directory, duration: duration, target: target, platform: platform)
    }

    // MARK: - --no-build device

    /// The device a `--no-build` capture drives: the flag, else the config's
    /// `simulator:` (iOS) or `emulator:` (Android), else the live runner
    /// session's device, else the platform default.
    static func noBuildDevice(
        platform: Platform, explicit: String?, config: GrantivaConfig?,
        sessionUDID: () async -> String?, device: any DevicePlatform
    ) async throws -> BootedDevice {
        let configured = platform == .ios ? config?.simulator : config?.android?.emulator
        if let named = [explicit, configured].compactMap({ $0 }).first(where: { !$0.isEmpty }) {
            return try await device.bootDevice(named: named)
        }
        // Read session.json and run `ps` only when nothing else names a device.
        if let session = await sessionUDID() {
            return try await device.bootDevice(named: session)
        }
        return try await device.defaultDevice()
    }

    /// The runner session in this directory, if its runner is still the
    /// process that owns it and it drives `platform`.
    static func liveSession(for platform: Platform) async -> RunnerSessionInfo? {
        guard let session = try? RunnerSessionInfo.load(), session.isAlive, session.isReady, session.drivesPlatform(platform),
              let snapshot = try? await SimulatorReaper.processSnapshot(),
              session.ownsRunnerProcess(in: snapshot) else { return nil }
        return session
    }

    /// A session lookup run at most once per command.
    actor SessionOnce {
        private let lookup: RunnerSessionLookup
        private let platform: Platform
        private var result: RunnerSessionInfo??

        init(lookup: RunnerSessionLookup, platform: Platform) {
            self.lookup = lookup
            self.platform = platform
        }

        func value() async -> RunnerSessionInfo? {
            if let result { return result }
            let found = await lookup.find(platform)
            result = .some(found)
            return found
        }
    }

    /// `session`, when the device it holds is `udid`.
    static func session(_ session: RunnerSessionInfo?, holding udid: String) -> RunnerSessionInfo? {
        guard let session, !session.udid.isEmpty, session.udid == udid else { return nil }
        return session
    }

    static func sessionUDID(_ udid: String?, for platform: Platform) -> String? {
        guard let udid, !udid.isEmpty else { return nil }
        return DeviceID.isAndroidSerial(udid) == (platform == .android) ? udid : nil
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
            options.applyRunnerNarration()
            // Only --capture loads the config strictly. A bare compare resolves
            // the platform (iOS when nothing points anywhere) and surfaces an
            // ambiguous directory or a bad GRANTIVA_PLATFORM rather than
            // silently comparing the wrong platform's captures.
            let platform: Platform
            let config: GrantivaConfig?
            if capture {
                (platform, config) = try platformOptions.loadConfig()
            } else {
                platform = try platformOptions.resolve()
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
                    throw DiffCommand.noScreensError(platform: platform, config: config)
                }

                let booted = try await device.bootDevice(for: resolved)
                var builtAppID: String?
                var appID: String?

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

                    appID = target.installedAppID(platform: platform, config: config, resolved: resolved, binaryID: builtAppID ?? appBundleId, warn: { GrantivaLog.logger.warning("\($0)") })
                    if let bid = appID {
                        if let productPath {
                            try await device.install(appID: TargetOptions.installAppID(platform: platform, testID: bid, binaryID: builtAppID ?? appBundleId), productPath: productPath, deviceID: booted.udid)
                        }
                        try await device.launch(appID: bid, deviceID: booted.udid)
                        try await Task.sleep(for: .seconds(2))
                    }
                }

                if buildOptions.shouldSkipInstall {
                    appID = target.installedAppID(platform: platform, config: config, resolved: resolved, binaryID: builtAppID ?? appBundleId, warn: { GrantivaLog.logger.warning("\($0)") })
                }
                guard let bid = appID else {
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
            let differ = imageDiffer

            // Find capture files before creating or resolving anything: a
            // compare with nothing to compare leaves the project as it was.
            guard fm.fileExists(atPath: captureDir) else {
                throw GrantivaError.noCaptures(captureDir)
            }
            let captureArtifacts: [CaptureArtifact]
            var ignored: [String] = []
            if let invocationCaptures {
                captureArtifacts = try DiffCommand.currentInvocationArtifacts(
                    from: invocationCaptures,
                    outputDir: captureDir
                )
            } else {
                let captureFiles = try fm.contentsOfDirectory(atPath: captureDir)
                    .filter { $0.hasSuffix(".png") }
                let screens = config.map { $0.screens.map(\.name) }
                let selection = DiffCommand.configuredArtifacts(
                    try DiffCommand.captureArtifacts(from: captureFiles), screens: screens
                )
                DiffCommand.noteIgnored(selection.ignored, in: captureDir, options: options)
                try DiffCommand.requireConfiguredCaptures(selection, screens: screens, directory: captureDir)
                captureArtifacts = selection.kept
                ignored = selection.ignored.map(\.screenName)
            }

            guard !captureArtifacts.isEmpty else {
                throw GrantivaError.noCaptures(captureDir)
            }

            let store = try await DiffCommand.resolveBaselineStore(platform: platform)
            if !fm.fileExists(atPath: diffDir) {
                try fm.createDirectory(atPath: diffDir, withIntermediateDirectories: true)
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
                duration: Date().timeIntervalSince(start),
                ignored: ignored
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
            let platform = try platformOptions.resolve()
            let config = try DiffCommand.approveConfig(platform: platform)
            let captureDir = DiffCommand.captureDirectory(for: platform)
            let fm = FileManager.default

            guard fm.fileExists(atPath: captureDir) else {
                throw GrantivaError.noCaptures(captureDir)
            }

            let allCaptures = try fm.contentsOfDirectory(atPath: captureDir)
                .filter { $0.hasSuffix(".png") }

            guard !allCaptures.isEmpty else {
                throw GrantivaError.noCaptures(captureDir)
            }
            // Approving everything means every configured screen; a file
            // that is not one (an old run's shot) is listed and left alone.
            // A screen named on the command line is approved as asked.
            var captureArtifacts = try DiffCommand.captureArtifacts(from: allCaptures)
            var ignored: [String] = []
            if screenNames.isEmpty {
                let screens = config.map { $0.screens.map(\.name) }
                let selection = DiffCommand.configuredArtifacts(captureArtifacts, screens: screens)
                DiffCommand.noteIgnored(selection.ignored, in: captureDir, options: options)
                try DiffCommand.requireConfiguredCaptures(selection, screens: screens, directory: captureDir)
                captureArtifacts = selection.kept
                ignored = selection.ignored.map(\.screenName)
            }
            let store = try await DiffCommand.resolveBaselineStore(platform: platform)

            let approved = try await DiffCommand.approve(
                screenNames,
                availableArtifacts: captureArtifacts,
                captureDirectory: captureDir,
                store: store
            )

            let result = ApproveResult(
                approvedScreens: approved,
                baselineDirectory: store.baselineDirectory(),
                ignored: ignored
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
    /// Files named the 2.0.1-and-earlier way (`Deep%20Links.png`) are accepted; when
    /// both forms exist for one screen, the current one is used.
    static func captureArtifacts(from fileNames: [String]) throws -> [CaptureArtifact] {
        let artifacts = try fileNames.sorted().map { fileName in
            guard
                let screenName = ScreenArtifact.screenName(from: fileName),
                ScreenArtifact.isCanonical(fileName, for: screenName)
            else {
                throw GrantivaError.invalidArgument(
                    "Invalid capture filename \"\(fileName)\". Capture files are named after the screen, with only /, :, NUL and % percent-encoded."
                )
            }
            return CaptureArtifact(fileName: fileName, screenName: screenName)
        }
        let current = Set(artifacts.filter { $0.fileName == ScreenArtifact.fileName(for: $0.screenName) }.map(\.screenName))
        return artifacts.filter { $0.fileName == ScreenArtifact.fileName(for: $0.screenName) || !current.contains($0.screenName) }
    }

    /// The visual-diff set is the configured screens. Other files in the
    /// capture directory (left by an older `grantiva run`, or by a screen
    /// since removed from the config) are reported, never compared or
    /// approved. With no config file, or one without screens, every capture
    /// counts, as before.
    static func configuredArtifacts(
        _ artifacts: [CaptureArtifact], screens: [String]?
    ) -> (kept: [CaptureArtifact], ignored: [CaptureArtifact]) {
        guard let screens, !screens.isEmpty else { return (artifacts, []) }
        let configured = Set(screens)
        return (artifacts.filter { configured.contains($0.screenName) }, artifacts.filter { !configured.contains($0.screenName) })
    }

    static func noteIgnored(_ ignored: [CaptureArtifact], in directory: String, options: GlobalOptions) {
        guard !ignored.isEmpty else { return }
        let names = ignored.map(\.screenName).joined(separator: ", ")
        options.note("Ignoring \(ignored.count) file\(ignored.count == 1 ? "" : "s") in \(directory) that \(ignored.count == 1 ? "is not a configured screen" : "are not configured screens"): \(names)")
    }

    /// When the directory holds captures but none of a configured screen,
    /// "No captures found" would be wrong: name the screens that have no
    /// capture and the files that were set aside.
    static func requireConfiguredCaptures(
        _ selection: (kept: [CaptureArtifact], ignored: [CaptureArtifact]), screens: [String]?, directory: String
    ) throws {
        guard selection.kept.isEmpty, !selection.ignored.isEmpty, let screens, !screens.isEmpty else { return }
        let others = selection.ignored.map(\.screenName)
        throw GrantivaError.notFound(
            "No capture found for the configured screens (\(screens.joined(separator: ", "))) in \(directory); "
                + "its \(others.count) other file\(others.count == 1 ? " is not a configured screen" : "s are not configured screens") "
                + "(\(others.joined(separator: ", "))). Run: grantiva diff capture"
        )
    }

    /// `diff approve` reads the config only for the configured screens; a
    /// file it cannot parse still stops it, and the message says which file
    /// and why.
    static func approveConfig(
        platform: Platform,
        directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) throws -> GrantivaConfig? {
        do {
            return try GrantivaConfig.loadIfPresent(platform: platform, from: directory)
        } catch {
            let reason = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            throw GrantivaError.unavailable(
                "diff approve reads \(platform.configFileName) for the configured screens and could not parse it: \(reason). "
                    + "Fix \(platform.configFileName) and run grantiva diff approve again."
            )
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
                    let passed = DiffVerdict.passes(
                        pixelDiffPercent: output.pixelDiffPercent, perceptualDistance: output.perceptualDistance,
                        pixelThreshold: config.threshold, perceptualThreshold: config.perceptualThreshold
                    )
                    var diffImagePath: String?
                    if !passed {
                        allPassed = false
                        let captureFile = ScreenArtifact.fileName(for: screenName)
                        let stem = URL(fileURLWithPath: captureFile).deletingPathExtension().lastPathComponent
                        let path = "\(diffDirectory)/\(stem)_diff.png"
                        try output.diffImageData.write(to: URL(fileURLWithPath: path))
                        diffImagePath = path
                    }

                    let message = DiffVerdict.message(
                        pixelDiffPercent: output.pixelDiffPercent, perceptualDistance: output.perceptualDistance,
                        pixelThreshold: config.threshold, perceptualThreshold: config.perceptualThreshold
                    )
                    screenDiffs.append(ScreenDiff(
                        screenName: screenName,
                        status: passed ? .passed : .failed,
                        pixelDiffPercent: output.pixelDiffPercent,
                        perceptualDistance: output.perceptualDistance,
                        pixelThreshold: config.threshold,
                        perceptualThreshold: config.perceptualThreshold,
                        baselinePath: "\(store.baselineDirectory())/\(ScreenArtifact.existingFileName(for: screenName, in: store.baselineDirectory()))",
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
                // Nothing was compared for this screen, so the run cannot
                // have passed it (K89); the headline says what to approve.
                allPassed = false
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
        // Resolve every screen first: an approve that fails names every
        // missing screen and saves nothing (L16).
        let resolved = screenNames.map { screenName in
            (screenName, "\(captureDirectory)/\(ScreenArtifact.existingFileName(for: screenName, in: captureDirectory, fileManager: fileManager))")
        }
        let missing = resolved.filter { !fileManager.fileExists(atPath: $0.1) }.map(\.0)
        if let message = missingCapturesMessage(missing, captureDirectory: captureDirectory) {
            throw GrantivaError.notFound(message)
        }
        var approved: [String] = []
        for (screenName, capturePath) in resolved {
            let data = try Data(contentsOf: URL(fileURLWithPath: capturePath))
            _ = try await store.save(screenName, data)
            approved.append(screenName)
        }

        return approved
    }

    /// One sentence for the screens `approve` found no capture for: K49's
    /// sentence for one, every name for several; nil when none is missing.
    static func missingCapturesMessage(_ missing: [String], captureDirectory: String) -> String? {
        switch missing.count {
        case 0: return nil
        case 1: return "No capture found for \"\(missing[0])\" in \(captureDirectory). Run: grantiva diff capture"
        default:
            let names = missing.map { "\"\($0)\"" }.joined(separator: ", ")
            return "No captures found for \(names) in \(captureDirectory). Run: grantiva diff capture"
        }
    }

    static let androidLocalOnlyMessage =
        "Android baselines are local only until the Grantiva backend supports platforms; use local baselines"

    /// Why there is nothing to capture: no config file (named, with its
    /// path), or a file without screens.
    static func noScreensError(
        platform: Platform, config: GrantivaConfig?,
        directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    ) -> GrantivaError {
        guard config != nil else {
            return .notFound(GrantivaConfig.missingFileMessage(platform: platform, directory: directory))
        }
        return .configuration("No screens configured in \(platform.configFileName)")
    }

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
        SimulatorDisplayGeometry(geometry)
    }
}
