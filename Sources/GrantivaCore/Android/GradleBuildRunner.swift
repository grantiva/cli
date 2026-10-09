import Foundation

/// Runs `assemble<Variant>` for one module and finds the APK it produced.
public struct GradleBuildRunner: Sendable {
    private let execute: @Sendable (String) async throws -> String
    /// FileManager is not Sendable, but its file queries are thread-safe and
    /// this runner only reads through it.
    nonisolated(unsafe) private let fileManager: FileManager

    public init(
        execute: @escaping @Sendable (String) async throws -> String = { try await shell($0) },
        fileManager: FileManager = .default
    ) {
        self.execute = execute
        self.fileManager = fileManager
    }

    /// `freeDebug` becomes `assembleFreeDebug`: only the first letter changes,
    /// the camel case inside the variant is already right.
    /// A module path without its leading colons: `:feature:app` and
    /// `feature:app` both become `feature:app`.
    static func normalizedModule(_ module: String) -> String {
        String(module.drop(while: { $0 == ":" }))
    }

    public static func taskName(module: String, variant: String) -> String {
        ":\(normalizedModule(module)):assemble\(variant.prefix(1).uppercased())\(variant.dropFirst())"
    }

    public static func command(
        projectRoot: String, module: String, variant: String, extraArgs: [String], javaHome: String?,
        fileManager: FileManager = .default
    ) -> String {
        var parts = ["cd \(shellQuoted(projectRoot)) &&"]
        if let javaHome { parts.append("JAVA_HOME=\(shellQuoted(javaHome))") }
        parts.append(fileManager.fileExists(atPath: "\(projectRoot)/gradlew") ? "./gradlew" : "gradle")
        parts.append(shellQuoted(taskName(module: module, variant: variant)))
        parts.append("--console=plain")
        parts += extraArgs.map(shellQuoted)
        return parts.joined(separator: " ")
    }

    /// `-PbuildDir=<path>` in the build arguments overrides `<module>/build`.
    public static func buildDirectory(projectRoot: String, module: String, extraArgs: [String]) -> String {
        if let override = extraArgs.first(where: { $0.hasPrefix("-PbuildDir=") })?.dropFirst("-PbuildDir=".count), !override.isEmpty {
            let path = String(override)
            return path.hasPrefix("/") ? path : "\(projectRoot)/\(path)"
        }
        let directory = normalizedModule(module).replacingOccurrences(of: ":", with: "/")
        return "\(projectRoot)/\(directory)/build"
    }

    public func build(
        projectRoot: String, module: String, variant: String, extraArgs: [String], javaHome: String?, deviceABI: String
    ) async throws -> BuildResult {
        let start = Date()
        let command = Self.command(projectRoot: projectRoot, module: module, variant: variant, extraArgs: extraArgs, javaHome: javaHome, fileManager: fileManager)
        let output: String
        do {
            output = try await execute(command)
        } catch let error as GrantivaError {
            guard case .commandFailed(let message, _) = error else { throw error }
            let lines = message.components(separatedBy: "\n")
            let errors = lines.filter { Self.isErrorLine($0) }
            return BuildResult(
                success: false, duration: Date().timeIntervalSince(start),
                warnings: lines.filter { Self.isWarningLine($0) },
                errors: errors.isEmpty ? [message] : errors, productPath: nil
            )
        }
        let warnings = output.components(separatedBy: "\n").filter { Self.isWarningLine($0) }
        let buildDirectory = Self.buildDirectory(projectRoot: projectRoot, module: module, extraArgs: extraArgs)
        guard let located = try APKOutputMetadata.find(buildDirectory: buildDirectory, variant: variant, fileManager: fileManager) else {
            throw GrantivaError.buildFailed(
                "The build succeeded but no \(APKOutputMetadata.fileName) for variant \(variant) was found under \(buildDirectory)/outputs/apk. "
                    + "Check module and variant in grantiva-android.yml, or set -PbuildDir in build_args if the build directory is custom."
            )
        }
        let apk = try located.metadata.apkPath(in: located.directory, deviceABI: deviceABI)
        return BuildResult(
            success: true, duration: Date().timeIntervalSince(start),
            warnings: warnings, errors: [], productPath: apk,
            applicationId: located.metadata.applicationId
        )
    }

    static func isWarningLine(_ line: String) -> Bool {
        line.hasPrefix("w: ") || line.contains("warning:")
    }

    static func isErrorLine(_ line: String) -> Bool {
        line.hasPrefix("e: ") || line.contains("error:") || line.hasPrefix("FAILURE:")
    }
}
