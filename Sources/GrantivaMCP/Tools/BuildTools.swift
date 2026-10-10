import Foundation
import GrantivaCore
import MCP

/// Build, run, and test tools using XcodeBuildRunner.
@available(macOS 15, *)
enum BuildTools {

    // MARK: - Tool Definitions

    static let definitions: [Tool] = [
        Tool(
            name: "grantiva_build",
            description: "Build the project: xcodebuild on iOS, Gradle on Android. Returns build result with success status, duration, warnings, and errors.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "scheme": .object([
                        "type": .string("string"),
                        "description": .string("Xcode scheme to build (uses grantiva.yml if omitted)"),
                    ]),
                    "simulator": .object([
                        "type": .string("string"),
                        "description": .string("Simulator name for destination (default: 'iPhone 16')"),
                    ]),
                    "module": .object([
                        "type": .string("string"),
                        "description": .string("Gradle module to assemble (Android; uses grantiva-android.yml, default app)"),
                    ]),
                    "variant": .object([
                        "type": .string("string"),
                        "description": .string("Gradle build variant, e.g. debug or freeDebug (Android; default debug)"),
                    ]),
                    "emulator": .object([
                        "type": .string("string"),
                        "description": .string("AVD name to use, booting it if needed (Android; uses grantiva-android.yml)"),
                    ]),
                ]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_run",
            description: "Build, install, and launch the app on the simulator or emulator.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "scheme": .object([
                        "type": .string("string"),
                        "description": .string("Xcode scheme to build (uses grantiva.yml if omitted)"),
                    ]),
                    "simulator": .object([
                        "type": .string("string"),
                        "description": .string("Simulator name (default: 'iPhone 16')"),
                    ]),
                    "module": .object([
                        "type": .string("string"),
                        "description": .string("Gradle module to assemble (Android; uses grantiva-android.yml, default app)"),
                    ]),
                    "variant": .object([
                        "type": .string("string"),
                        "description": .string("Gradle build variant, e.g. debug or freeDebug (Android; default debug)"),
                    ]),
                    "emulator": .object([
                        "type": .string("string"),
                        "description": .string("AVD name to use, booting it if needed (Android; uses grantiva-android.yml)"),
                    ]),
                ]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_test",
            description: "Run the project's test suite using xcodebuild test (iOS only). Returns pass/fail counts and output.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "scheme": .object([
                        "type": .string("string"),
                        "description": .string("Xcode scheme to test (uses grantiva.yml if omitted)"),
                    ]),
                    "simulator": .object([
                        "type": .string("string"),
                        "description": .string("Simulator name for destination (default: 'iPhone 16')"),
                    ]),
                ]),
            ]),
            // Not read-only: `xcodebuild test` boots a simulator, writes build
            // products into DerivedData, and installs/runs the test bundle.
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
    ]

    // MARK: - Handlers

    /// What the platform builds: scheme and simulator on iOS, module and
    /// variant on Android. Arguments win over the config file.
    static func resolvedProject(platform: Platform, config: GrantivaConfig?, arguments: [String: Value]) throws -> ResolvedProject {
        switch platform {
        case .ios:
            guard let scheme = arguments["scheme"]?.stringValue ?? config?.scheme else {
                throw GrantivaError.invalidArgument("no scheme specified. Pass 'scheme' or set it in grantiva.yml.")
            }
            return ResolvedProject(
                scheme: scheme, project: config?.project, workspace: config?.workspace,
                bundleId: config?.bundleId, buildSettings: config?.buildSettings ?? [],
                simulator: arguments["simulator"]?.stringValue ?? config?.simulator ?? "iPhone 16"
            )
        case .android:
            let configured = config?.android ?? AndroidProject()
            let android = AndroidProject(
                module: arguments["module"]?.stringValue ?? configured.module,
                variant: arguments["variant"]?.stringValue ?? configured.variant,
                applicationId: configured.applicationId,
                emulator: arguments["emulator"]?.stringValue ?? configured.emulator,
                systemImage: configured.systemImage,
                buildArgs: configured.buildArgs
            )
            return ResolvedProject(
                bundleId: configured.applicationId, buildSettings: configured.buildArgs,
                simulator: android.emulator ?? "", android: android
            )
        }
    }

    private static func toolError(_ message: String) -> CallTool.Result {
        CallTool.Result(content: [.text(text: "Error: \(message)", annotations: nil, _meta: nil)], isError: true)
    }

    static func build(
        device: any DevicePlatform,
        platform: Platform,
        config: GrantivaConfig?,
        arguments: [String: Value]
    ) async throws -> CallTool.Result {
        let resolved: ResolvedProject
        do {
            resolved = try resolvedProject(platform: platform, config: config, arguments: arguments)
        } catch let error as GrantivaError {
            return toolError(error.errorDescription ?? "\(error)")
        }
        let booted = try await device.bootDevice(named: resolved.simulator)
        let result = try await device.build(PlatformBuildRequest(
            config: config ?? GrantivaConfig(), resolved: resolved, deviceID: booted.udid, extraBuildSettings: resolved.buildSettings
        ))
        var summary = """
            Build \(result.success ? "succeeded" : "FAILED")
            Scheme: \(result.scheme ?? "(none)")
            Duration: \(String(format: "%.1fs", result.duration))
            Warnings: \(result.warnings.count)
            Errors: \(result.errors.count)\(result.errors.isEmpty ? "" : "\n" + result.errors.joined(separator: "\n"))
            """
        if let productPath = result.productPath {
            summary += "\nProduct: \(productPath)"
        }
        return CallTool.Result(
            content: [.text(text: summary, annotations: nil, _meta: nil)],
            isError: !result.success ? true : nil
        )
    }

    static func run(
        device: any DevicePlatform,
        platform: Platform,
        config: GrantivaConfig?,
        arguments: [String: Value]
    ) async throws -> CallTool.Result {
        let resolved: ResolvedProject
        do {
            resolved = try resolvedProject(platform: platform, config: config, arguments: arguments)
        } catch let error as GrantivaError {
            return toolError(error.errorDescription ?? "\(error)")
        }
        if platform == .ios, resolved.bundleId == nil {
            return toolError("no bundle_id in grantiva.yml. Cannot launch app.")
        }

        let booted = try await device.bootDevice(named: resolved.simulator)
        let buildResult = try await device.build(PlatformBuildRequest(
            config: config ?? GrantivaConfig(), resolved: resolved, deviceID: booted.udid, extraBuildSettings: resolved.buildSettings
        ))
        guard buildResult.success else {
            return CallTool.Result(
                content: [.text(text: "Build failed:\n\(buildResult.errors.joined(separator: "\n"))", annotations: nil, _meta: nil)],
                isError: true
            )
        }
        guard let appID = resolved.bundleId ?? buildResult.applicationId else {
            return toolError("no application_id in grantiva-android.yml and the build did not report one. Cannot launch app.")
        }
        if let productPath = buildResult.productPath {
            try await device.install(appID: appID, productPath: productPath, deviceID: booted.udid)
        }
        try await device.launch(appID: appID, deviceID: booted.udid)

        let text: String
        switch platform {
        case .ios:
            text = "App built and launched.\nScheme: \(resolved.scheme ?? "")\nBundle ID: \(appID)\nSimulator: \(booted.name)"
        case .android:
            let android = resolved.android ?? AndroidProject()
            text = "App built and launched.\nModule: \(android.module) (\(android.variant))\nApplication ID: \(appID)\nDevice: \(booted.name) (\(booted.udid))"
        }
        return CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)])
    }

    static func test(
        runner: XcodeBuildRunner,
        platform: Platform,
        config: GrantivaConfig?,
        simManager: SimulatorManager,
        arguments: [String: Value]
    ) async throws -> CallTool.Result {
        guard platform == .ios else {
            return toolError("grantiva_test runs xcodebuild test and is iOS-only; run ./gradlew connectedAndroidTest yourself.")
        }
        let scheme = arguments["scheme"]?.stringValue ?? config?.scheme
        guard let scheme else {
            return CallTool.Result(
                content: [.text(text: "Error: no scheme specified. Pass 'scheme' or set it in grantiva.yml.", annotations: nil, _meta: nil)],
                isError: true
            )
        }

        let simName = arguments["simulator"]?.stringValue ?? config?.simulator ?? "iPhone 16"
        let device = try await simManager.boot(nameOrUDID: simName)
        let destination = "platform=iOS Simulator,id=\(device.udid)"

        let result = try await runner.test(
            scheme: scheme,
            workspace: config?.workspace,
            project: config?.project,
            destination: destination
        )

        return CallTool.Result(
            content: [.text(text: testSummary(result), annotations: nil, _meta: nil)],
            isError: !result.success ? true : nil
        )
    }

    /// Counts on success. On failure, also the reason: xcodebuild's `error:`
    /// lines and failing test cases, then the tail of the output, bounded so a
    /// long log does not flood the model's context.
    static func testSummary(_ result: TestResult, tailLines: Int = 40, maxTailBytes: Int = 4096) -> String {
        var summary = """
            Tests \(result.success ? "passed" : "FAILED")
            Scheme: \(result.scheme)
            Duration: \(String(format: "%.1fs", result.duration))
            Passed: \(result.testsPassed)
            Failed: \(result.testsFailed)
            """
        guard !result.success else { return summary }

        let lines = result.output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var reasons: [String] = []
        for line in lines where line.contains("error:") || isFailedTestLine(line) {
            if !reasons.contains(line) { reasons.append(line) }
        }
        if !reasons.isEmpty {
            summary += "\n\nErrors:\n" + reasons.prefix(20).joined(separator: "\n")
            if reasons.count > 20 { summary += "\n... \(reasons.count - 20) more" }
        }

        var tail = lines.suffix(tailLines).joined(separator: "\n")
        if tail.utf8.count > maxTailBytes {
            tail = "..." + String(decoding: Array(tail.utf8.suffix(maxTailBytes)), as: UTF8.self)
        }
        if !tail.isEmpty {
            summary += "\n\nOutput (last \(min(lines.count, tailLines)) lines):\n" + tail
        }
        return summary
    }

    /// XCTest (`Test Case '-[A b]' failed`) and Swift Testing (`✘ Test b() failed`).
    private static func isFailedTestLine(_ line: String) -> Bool {
        (line.hasPrefix("Test Case '") && line.contains("' failed"))
            || (line.hasPrefix("✘ Test ") && line.contains(" failed"))
    }
}
