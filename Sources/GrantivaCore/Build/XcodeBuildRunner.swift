import Foundation

public struct XcodeBuildRunner: Sendable {
    private let execute: @Sendable (String) async throws -> String

    public init(execute: @escaping @Sendable (String) async throws -> String = { try await shell($0) }) {
        self.execute = execute
    }

    public func build(
        scheme: String,
        workspace: String? = nil,
        project: String? = nil,
        destination: String,
        buildSettings: [String] = []
    ) async throws -> BuildResult {
        let start = Date()
        var args = ["xcodebuild", "-scheme", scheme]
        if let workspace {
            args += ["-workspace", workspace]
        } else if let project {
            args += ["-project", project]
        }
        args += ["-destination", "\(destination)", "build"]
        args += buildSettings

        let command = args.map(shellQuoted).joined(separator: " ")

        do {
            let output = try await execute(command)
            let duration = Date().timeIntervalSince(start)
            let warnings = output.components(separatedBy: "\n").filter { $0.contains("warning:") }
            let productPath = try? await resolveProductPath(
                scheme: scheme, workspace: workspace, project: project,
                destination: destination, buildSettings: buildSettings
            )
            return BuildResult(
                success: true, scheme: scheme, destination: destination,
                duration: duration, warnings: warnings, errors: [],
                productPath: productPath
            )
        } catch let error as GrantivaError {
            let duration = Date().timeIntervalSince(start)
            if case .commandFailed(let msg, _) = error {
                let errors = msg.components(separatedBy: "\n").filter { $0.contains("error:") }
                let warnings = msg.components(separatedBy: "\n").filter { $0.contains("warning:") }
                return BuildResult(
                    success: false, scheme: scheme, destination: destination,
                    duration: duration, warnings: warnings, errors: errors.isEmpty ? [msg] : errors,
                    productPath: nil
                )
            }
            throw error
        }
    }

    public func install(bundleId: String, productPath: String, udid: String) async throws {
        _ = try await execute("xcrun simctl install \(shellQuoted(udid)) \(shellQuoted(productPath))")
    }

    public func launch(bundleId: String, udid: String) async throws {
        _ = try await execute("xcrun simctl launch \(shellQuoted(udid)) \(shellQuoted(bundleId))")
    }

    public func dataContainerPath(bundleId: String, udid: String) async throws -> String {
        try await execute("xcrun simctl get_app_container \(shellQuoted(udid)) \(shellQuoted(bundleId)) data")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func terminate(bundleId: String, udid: String) async throws {
        _ = try await execute("xcrun simctl terminate \(shellQuoted(udid)) \(shellQuoted(bundleId))")
    }

    public func uninstall(bundleId: String, udid: String) async throws {
        _ = try await execute("xcrun simctl uninstall \(shellQuoted(udid)) \(shellQuoted(bundleId))")
    }

    public func test(
        scheme: String,
        workspace: String? = nil,
        project: String? = nil,
        destination: String
    ) async throws -> TestResult {
        let start = Date()
        var args = ["xcodebuild", "-scheme", scheme]
        if let workspace {
            args += ["-workspace", workspace]
        } else if let project {
            args += ["-project", project]
        }
        args += ["-destination", "\(destination)", "test"]

        let command = args.map(shellQuoted).joined(separator: " ")

        do {
            let output = try await execute(command)
            let duration = Date().timeIntervalSince(start)
            let (passed, failed) = parseTestCounts(from: output)
            return TestResult(
                success: true, scheme: scheme, duration: duration,
                testsPassed: passed, testsFailed: failed, output: output
            )
        } catch let error as GrantivaError {
            let duration = Date().timeIntervalSince(start)
            if case .commandFailed(let msg, _) = error {
                let (passed, failed) = parseTestCounts(from: msg)
                return TestResult(
                    success: false, scheme: scheme, duration: duration,
                    testsPassed: passed, testsFailed: failed, output: msg
                )
            }
            throw error
        }
    }

    public func resolveProductPath(
        scheme: String, workspace: String?, project: String?, destination: String,
        buildSettings: [String] = []
    ) async throws -> String {
        var args = ["xcodebuild", "-scheme", scheme]
        if let workspace {
            args += ["-workspace", workspace]
        } else if let project {
            args += ["-project", project]
        }
        args += ["-destination", "\(destination)", "-showBuildSettings"]
        args += buildSettings
        let command = args.map(shellQuoted).joined(separator: " ")
        let output = try await execute(command)

        var currentDir: String?
        for line in output.components(separatedBy: "\n") + [""] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("BUILT_PRODUCTS_DIR = ") {
                currentDir = String(trimmed.dropFirst("BUILT_PRODUCTS_DIR = ".count))
            }
            if trimmed.hasPrefix("FULL_PRODUCT_NAME = "), let currentDir {
                let name = String(trimmed.dropFirst("FULL_PRODUCT_NAME = ".count))
                if name.hasSuffix(".app") { return "\(currentDir)/\(name)" }
            }
            if trimmed.isEmpty {
                currentDir = nil
            }
        }
        throw GrantivaError.buildFailed("Could not resolve app product path from build settings")
    }

    private func parseTestCounts(from output: String) -> (passed: Int, failed: Int) {
        let pattern = #"Executed\s+(\d+)\s+tests?,\s+with\s+(\d+)\s+failures?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.matches(in: output, range: NSRange(output.startIndex..., in: output)).last,
              let totalRange = Range(match.range(at: 1), in: output),
              let failedRange = Range(match.range(at: 2), in: output),
              let total = Int(output[totalRange]),
              let failed = Int(output[failedRange]) else {
            return (0, 0)
        }
        return (max(0, total - failed), failed)
    }
}

public struct TestResult: Sendable, Codable {
    public let success: Bool
    public let scheme: String
    public let duration: TimeInterval
    public let testsPassed: Int
    public let testsFailed: Int
    public let output: String

    public init(
        success: Bool,
        scheme: String,
        duration: TimeInterval,
        testsPassed: Int,
        testsFailed: Int,
        output: String
    ) {
        self.success = success
        self.scheme = scheme
        self.duration = duration
        self.testsPassed = testsPassed
        self.testsFailed = testsFailed
        self.output = output
    }
}
