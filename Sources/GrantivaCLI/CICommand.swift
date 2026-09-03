import ArgumentParser
import Foundation
import GrantivaCore
import GrantivaAPI

struct CILogBuffer {
    private(set) var lines: [String] = []

    mutating func append(_ line: String) {
        lines.append(line)
    }

    mutating func flush(
        using send: (String) async throws -> Void
    ) async throws {
        while let line = lines.first {
            try await send(line)
            lines.removeFirst()
        }
    }
}

struct CIRunCompletionState {
    private(set) var resultsCompleted = false

    mutating func completeResults(
        _ upload: RunUpload,
        using complete: (RunUpload) async throws -> RunResponse
    ) async throws -> RunResponse {
        let response = try await complete(upload)
        resultsCompleted = true
        return response
    }

    func completeFailureIfNeeded(
        _ upload: RunUpload,
        using complete: (RunUpload) async throws -> RunResponse
    ) async {
        guard !resultsCompleted else { return }
        _ = try? await complete(upload)
    }

    /// Flush any pending diagnostics, but never let a logging outage prevent the
    /// run itself from being moved out of the backend's `running` state.
    func recoverFailure(
        _ upload: RunUpload,
        flushLogs: () async throws -> Void,
        complete: (RunUpload) async throws -> RunResponse
    ) async -> String? {
        let logUploadError: String?
        do {
            try await flushLogs()
            logUploadError = nil
        } catch {
            logUploadError = error.localizedDescription
        }

        await completeFailureIfNeeded(upload, using: complete)
        return logUploadError
    }
}

struct CIComparisonOutcome {
    let screens: [RunScreenUpload]
    let allPassed: Bool
}

/// Testable orchestration seam for turning this runner invocation's captures
/// into backend uploads.
struct CIComparisonPipeline {
    var validateCaptures: ([ScreenCapture]) throws -> [DiffCommand.CaptureArtifact]
    var loadCapture: (String) throws -> Data
    var loadBaseline: (String) async throws -> Data?
    var compare: (Data, Data) throws -> DiffOutput
    var writeDiff: (String, Data) throws -> Void

    func run(
        captures: [ScreenCapture],
        pixelThreshold: Double,
        perceptualThreshold: Double
    ) async throws -> CIComparisonOutcome {
        let artifacts = try validateCaptures(captures)
        let pathsByScreen = Dictionary(uniqueKeysWithValues: artifacts.compactMap { artifact in
            artifact.path.map { (artifact.screenName, $0) }
        })
        var uploads: [RunScreenUpload] = []
        var allPassed = true

        for capture in captures.sorted(by: {
            ScreenArtifact.fileName(for: $0.screenName) < ScreenArtifact.fileName(for: $1.screenName)
        }) {
            let steps = capture.steps.map {
                RunStepUpload(
                    action: $0.action, status: $0.status.rawValue,
                    duration: $0.duration, message: $0.message
                )
            }

            // RunnerSession deliberately returns an entry with an empty path
            // when a configured screenshot is absent. It is a failed result,
            // not an invitation to reuse a same-name file from an earlier run.
            guard !capture.path.isEmpty else {
                allPassed = false
                let message = capture.steps.first(where: { $0.status == .failed })?.message
                    ?? "Screenshot not found in runner output"
                uploads.append(RunScreenUpload(
                    name: capture.screenName, status: "error",
                    pixelThreshold: pixelThreshold,
                    perceptualThreshold: perceptualThreshold,
                    message: message, steps: steps
                ))
                continue
            }

            guard let capturePath = pathsByScreen[capture.screenName] else {
                throw GrantivaError.commandFailed(
                    "Runner capture was not in the validated invocation set: \(capture.screenName)",
                    1
                )
            }
            let captureData = try loadCapture(capturePath)
            let baselineData = try await loadBaseline(capture.screenName)
            if let baselineData {
                do {
                    let output = try compare(baselineData, captureData)
                    let passed = output.pixelDiffPercent <= pixelThreshold
                        && output.perceptualDistance <= perceptualThreshold
                    var diffData: Data?
                    if !passed {
                        allPassed = false
                        try writeDiff(capture.screenName, output.diffImageData)
                        diffData = output.diffImageData
                    }
                    let message = passed
                        ? "Passed"
                        : "Failed: pixel=\(String(format: "%.2f%%", output.pixelDiffPercent * 100)) perceptual=\(String(format: "%.1f", output.perceptualDistance))"
                    uploads.append(RunScreenUpload(
                        name: capture.screenName, status: passed ? "passed" : "failed",
                        pixelDiffPercent: output.pixelDiffPercent,
                        perceptualDistance: output.perceptualDistance,
                        pixelThreshold: pixelThreshold,
                        perceptualThreshold: perceptualThreshold,
                        message: message, captureData: captureData,
                        diffData: diffData, steps: steps
                    ))
                } catch {
                    allPassed = false
                    uploads.append(RunScreenUpload(
                        name: capture.screenName, status: "error",
                        pixelThreshold: pixelThreshold,
                        perceptualThreshold: perceptualThreshold,
                        message: "Error: \(error.localizedDescription)",
                        captureData: captureData, steps: steps
                    ))
                }
            } else {
                uploads.append(RunScreenUpload(
                    name: capture.screenName, status: "new_screen",
                    pixelThreshold: pixelThreshold,
                    perceptualThreshold: perceptualThreshold,
                    message: "New screen — no baseline",
                    captureData: captureData, steps: steps
                ))
            }
        }

        return CIComparisonOutcome(screens: uploads, allPassed: allPassed)
    }
}

struct CICommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ci",
        abstract: "CI pipeline — capture, compare, and upload results.",
        subcommands: [CIRunCommand.self]
    )

    // MARK: - ci run

    struct CIRunCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "run",
            abstract: "Run full CI pipeline: capture screenshots, compare against baselines, upload results."
        )

        @OptionGroup var options: GlobalOptions
        @OptionGroup var buildOptions: BuildOptions

        @Option(name: .long, help: "Scheme to build")
        var scheme: String?

        @Option(name: .long, help: "Simulator name")
        var simulator: String?

        @Option(name: .long, help: "Bundle identifier")
        var bundleId: String?

        var simulatorManager: SimulatorManager = .live
        var runnerManager: RunnerManager = .live
        var imageDiffer: ImageDiffer = .live

        /// Log a step locally and return the backend representation for buffering.
        @discardableResult
        func log(_ message: String) -> String {
            let line = "[grantiva] \(message)"
            options.note(message)
            return line
        }

        func run() async throws {
            let config = try? GrantivaConfig.load()
            let captureDir = ".grantiva/captures"
            let diffDir = ".grantiva/captures/diffs"
            let start = Date()

            // Resolve app binary first (if --app-file provided) so we can derive bundle ID
            let resolvedBinary = try buildOptions.resolveAppBinary()
            defer { resolvedBinary?.cleanup() }

            let appBundleId = resolvedBinary.flatMap { AppBinaryResolver.bundleId(from: $0.appPath) }

            // Resolve project
            let resolved = try await ResolvedProject.resolve(
                schemeFlag: scheme, simulatorFlag: simulator, bundleIdFlag: bundleId, config: config,
                skipBuild: buildOptions.shouldSkipBuild,
                appBundleId: appBundleId
            )
            log("Resolved: scheme=\(resolved.scheme ?? "(none)") simulator=\(resolved.simulator) screens=\(resolved.screens.count)")

            guard !resolved.screens.isEmpty else {
                throw GrantivaError.invalidArgument("No screens configured in grantiva.yml")
            }

            // Must be authenticated for CI
            guard let credentials = AuthStore.resolveCredentials() else {
                throw GrantivaError.notAuthenticated
            }
            log("Authenticated with \(credentials.baseURL)")

            let client = try RangeClient(apiKey: credentials.apiKey, baseURL: credentials.baseURL)
            let projectId = try await ProjectIdentifier.resolve()
            let project = projectId.projectSlug
            let branch = projectId.currentBranch
            log("Project: \(project) Branch: \(branch)")

            // Get commit SHA (best effort)
            let commitSHA = try? await shell("git rev-parse HEAD")
            let trimmedSHA = commitSHA?.trimmingCharacters(in: .whitespacesAndNewlines)

            // Determine trigger
            let trigger = ProcessInfo.processInfo.environment["CI"] != nil ? "ci" : "manual"

            // Start run immediately so it appears in the dashboard as "running"
            let startResponse = try await client.startRun(project, StartRunRequest(
                branch: branch, commitSHA: trimmedSHA, trigger: trigger
            ))
            let runId = startResponse.runId
            var remoteLogs = CILogBuffer()
            var completionState = CIRunCompletionState()
            remoteLogs.append(log("Run started: \(runId)"))

            // Buffer remote logs so completion cannot race fire-and-forget tasks.
            func rlog(_ message: String) {
                remoteLogs.append(log(message))
            }

            func flushLogs() async throws {
                try await remoteLogs.flush { line in
                    try await client.appendLog(project, runId, line)
                }
            }

            var ciVerdictFailed = false
            do {
                // 0. Preflight: ensure runner binary is extracted
                rlog("Preparing runner...")
                try await runnerManager.ensureAvailable()
                rlog("Runner ready")

                // 1. Boot → Build → Install → Launch → Capture
                rlog("Booting simulator: \(resolved.simulator)")
                let device = try await simulatorManager.boot(nameOrUDID: resolved.simulator)
                rlog("Simulator booted: \(device.name) (\(device.udid))")
                let destination = "platform=iOS Simulator,id=\(device.udid)"

                var productPath: String?

                if buildOptions.shouldSkipInstall {
                    rlog("Skipping build and install (--no-build)")
                } else if let resolvedBinary {
                    rlog("Using pre-built binary: \(URL(fileURLWithPath: resolvedBinary.appPath).lastPathComponent)")
                    productPath = resolvedBinary.appPath
                } else {
                    guard let buildScheme = resolved.scheme else {
                        throw GrantivaError.invalidArgument(
                            "No scheme specified. Pass --scheme, set it in grantiva.yml, or use --app-file to provide a pre-built binary."
                        )
                    }

                    rlog("Building \(buildScheme)...")

                    let buildResult = try await XcodeBuildRunner().build(
                        scheme: buildScheme,
                        workspace: resolved.workspace,
                        project: resolved.project,
                        destination: destination,
                        buildSettings: buildOptions.xcodeBuildSettings(merging: resolved.buildSettings)
                    )
                    rlog("Build finished: success=\(buildResult.success) duration=\(String(format: "%.1fs", buildResult.duration))")

                    guard buildResult.success else {
                        if options.json {
                            Output.line(try JSONOutput.string(buildResult))
                        } else {
                            Output.line(TableFormatter().formatBuild(buildResult))
                        }
                        throw ExitCode.failure
                    }
                    productPath = buildResult.productPath
                }

                if !buildOptions.shouldSkipInstall, let bid = resolved.bundleId {
                    if let productPath {
                        rlog("Installing \(bid)...")
                        try await XcodeBuildRunner().install(
                            bundleId: bid, productPath: productPath, udid: device.udid
                        )
                    }
                    rlog("Launching \(bid)...")
                    try await XcodeBuildRunner().launch(bundleId: bid, udid: device.udid)
                    try await Task.sleep(for: .seconds(2))
                }

                // Run the embedded runner for navigation + screenshots
                guard let bid = resolved.bundleId else {
                    throw GrantivaError.invalidArgument("Bundle ID is required for screen capture")
                }
                rlog("Capturing \(resolved.screens.count) screen(s)...")
                let geometry = try await simulatorManager.displayGeometry(udid: device.udid)
                let expectedPixels = SimulatorProvisionResult.Dimensions(
                    width: geometry.pixels[0],
                    height: geometry.pixels[1]
                )

                let screenCaptures = try await RunnerSession.run(
                    screens: resolved.screens,
                    bundleId: bid,
                    udid: device.udid,
                    runner: runnerManager,
                    outputDir: captureDir,
                    expectedPixels: expectedPixels
                )
                rlog("Capture complete")

                // Print step-by-step results (Maestro-style)
                if !options.json {
                    for capture in screenCaptures {
                        FileHandle.standardError.write(Data("\n  \(capture.screenName)\n".utf8))
                        for step in capture.steps {
                            let icon = step.status == .passed ? "\u{2713}" : "\u{2717}"
                            let line = "    \(icon) \(step.action)"
                            FileHandle.standardError.write(Data("\(line)\n".utf8))
                            if let msg = step.message {
                                FileHandle.standardError.write(Data("      \(msg)\n".utf8))
                            }
                        }
                    }
                    FileHandle.standardError.write(Data("\n".utf8))
                }

                // 2. Compare against baselines
                let diffConfig = config?.diff ?? .init()
                let fm = FileManager.default
                let store = client.asBaselineStore(project: project, branch: branch)
                let differ = imageDiffer

                if !fm.fileExists(atPath: diffDir) {
                    try fm.createDirectory(atPath: diffDir, withIntermediateDirectories: true)
                }

                rlog("Comparing \(screenCaptures.count) screen(s) against baselines...")
                let comparison = try await CIComparisonPipeline(
                    validateCaptures: {
                        try CICommand.currentInvocationArtifacts(from: $0, outputDir: captureDir)
                    },
                    loadCapture: { path in
                        try Data(contentsOf: URL(fileURLWithPath: path))
                    },
                    loadBaseline: store.load,
                    compare: differ.compare,
                    writeDiff: { screenName, data in
                        let captureFile = ScreenArtifact.fileName(for: screenName)
                        let stem = URL(fileURLWithPath: captureFile)
                            .deletingPathExtension().lastPathComponent
                        let path = "\(diffDir)/\(stem)_diff.png"
                        try data.write(to: URL(fileURLWithPath: path))
                    }
                ).run(
                    captures: screenCaptures,
                    pixelThreshold: diffConfig.threshold,
                    perceptualThreshold: diffConfig.perceptualThreshold
                )
                let screenUploads = comparison.screens
                let allPassed = comparison.allPassed

                // 3. Complete run with results
                let duration = Date().timeIntervalSince(start)
                let upload = RunUpload(
                    branch: branch,
                    commitSHA: trimmedSHA,
                    trigger: trigger,
                    duration: duration,
                    screens: screenUploads
                )

                rlog("Uploading results to \(credentials.baseURL)...")
                try await flushLogs()

                let runResponse = try await completionState.completeResults(upload) {
                    try await client.completeRun(project, runId, $0)
                }
                rlog("Upload complete: run=\(runResponse.runId)")
                try await flushLogs()

                // 4. Output results
                struct CIRunResult: Codable, Sendable {
                    let runId: String
                    let status: String
                    let url: String
                    let branch: String
                    let commitSha: String?
                    let trigger: String
                    let screenCount: Int
                    let passedCount: Int
                    let failedCount: Int
                    let newCount: Int
                    let duration: Double

                    enum CodingKeys: String, CodingKey {
                        case runId = "run_id"
                        case status, url, branch, trigger, duration
                        case commitSha = "commit_sha"
                        case screenCount = "screen_count"
                        case passedCount = "passed_count"
                        case failedCount = "failed_count"
                        case newCount = "new_count"
                    }
                }

                let result = CIRunResult(
                    runId: runResponse.runId,
                    status: runResponse.status,
                    url: runResponse.url,
                    branch: branch,
                    commitSha: trimmedSHA,
                    trigger: trigger,
                    screenCount: runResponse.screenCount,
                    passedCount: runResponse.passedCount,
                    failedCount: runResponse.failedCount,
                    newCount: runResponse.newCount,
                    duration: duration
                )

                if options.json {
                    Output.line(try JSONOutput.string(result))
                } else {
                    Output.line("")
                    Output.line("  Run:      \(result.runId)")
                    Output.line("  Status:   \(result.status)")
                    Output.line("  Branch:   \(result.branch)")
                    if let sha = result.commitSha {
                        Output.line("  Commit:   \(String(sha.prefix(8)))")
                    }
                    Output.line("  Trigger:  \(result.trigger)")
                    Output.line("  Screens:  \(result.screenCount) total, \(result.passedCount) passed, \(result.failedCount) failed, \(result.newCount) new")
                    Output.line("  Duration: \(String(format: "%.1fs", result.duration))")
                    Output.line("  URL:      \(result.url)")
                    Output.line("")
                }

                // A visual regression is a verdict, not a crash: the results are
                // already uploaded. Throwing inside this `do` would land in the
                // catch below and overwrite them with an empty completion.
                if !allPassed {
                    ciVerdictFailed = true
                }
            } catch {
                // Mark run as failed on the backend so it doesn't stay in "running" forever
                remoteLogs.append("[grantiva] Run failed: \(error)")
                let duration = Date().timeIntervalSince(start)
                let failUpload = RunUpload(
                    branch: branch,
                    commitSHA: trimmedSHA,
                    trigger: trigger,
                    duration: duration,
                    screens: []
                )
                let logUploadError = await completionState.recoverFailure(
                    failUpload,
                    flushLogs: flushLogs
                ) {
                    try await client.completeRun(project, runId, $0)
                }
                if let logUploadError {
                    throw GrantivaError.commandFailed(
                        "CI failed: \(error). Failed to upload CI logs: \(logUploadError)",
                        1
                    )
                }
                throw error
            }
            if ciVerdictFailed {
                throw ExitCode.failure
            }
        }
    }

    /// CI always captures before comparing, so its artifact set must come from
    /// that invocation rather than from the persistent capture directory.
    static func currentInvocationArtifacts(
        from captures: [ScreenCapture],
        outputDir: String
    ) throws -> [DiffCommand.CaptureArtifact] {
        try DiffCommand.currentInvocationArtifacts(from: captures, outputDir: outputDir)
    }
}
