import Foundation

// MARK: - DetectedProject

public struct DetectedProject: Codable, Sendable {
    public var scheme: String
    public var project: String?
    public var workspace: String?
    public var bundleId: String?
    public var detectedAt: Date

    public init(
        scheme: String,
        project: String? = nil,
        workspace: String? = nil,
        bundleId: String? = nil,
        detectedAt: Date = Date()
    ) {
        self.scheme = scheme
        self.project = project
        self.workspace = workspace
        self.bundleId = bundleId
        self.detectedAt = detectedAt
    }
}

// MARK: - ProjectDetector

public struct ProjectDetector: Sendable {
    public var detect: @Sendable () async throws -> DetectedProject

    public init(detect: @escaping @Sendable () async throws -> DetectedProject) {
        self.detect = detect
    }
}

// MARK: - Live

extension ProjectDetector {
    public static let live = ProjectDetector {
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath
        guard let contents = try? fm.contentsOfDirectory(atPath: cwd) else {
            throw GrantivaError.invalidArgument("Cannot read current directory")
        }

        return try await detect(contents: contents) { command in
            try await shell(command)
        }
    }

    static func detect(
        contents: [String],
        runShell: @escaping @Sendable (String) async throws -> String
    ) async throws -> DetectedProject {
        // Find workspace or project
        let sortedContents = contents.sorted()
        let workspace = sortedContents.first { $0.hasSuffix(".xcworkspace") && !$0.hasPrefix(".") }
        let project = sortedContents.first { $0.hasSuffix(".xcodeproj") && !$0.hasPrefix(".") }

        // Run xcodebuild -list to get schemes
        var listCmd = "xcodebuild -list -json"
        if let workspace {
            listCmd += " -workspace \(shellQuoted(workspace))"
        } else if let project {
            listCmd += " -project \(shellQuoted(project))"
        } else {
            throw GrantivaError.invalidArgument("No .xcworkspace or .xcodeproj found in current directory")
        }

        let listOutput = try await runShell(listCmd)
        guard let listData = listOutput.data(using: .utf8) else {
            throw GrantivaError.invalidArgument("Could not parse xcodebuild -list output")
        }

        let listJSON = try JSONSerialization.jsonObject(with: listData) as? [String: Any]
        let schemes: [String]
        if let ws = listJSON?["workspace"] as? [String: Any] {
            schemes = ws["schemes"] as? [String] ?? []
        } else if let proj = listJSON?["project"] as? [String: Any] {
            schemes = proj["schemes"] as? [String] ?? []
        } else {
            schemes = []
        }

        guard let scheme = schemes.first else {
            throw GrantivaError.invalidArgument("No schemes found in Xcode project")
        }

        // Get bundle ID from build settings
        var settingsCmd = "xcodebuild -scheme \(shellQuoted(scheme)) -showBuildSettings"
        if let workspace {
            settingsCmd += " -workspace \(shellQuoted(workspace))"
        } else if let project {
            settingsCmd += " -project \(shellQuoted(project))"
        }

        var bundleId: String?
        if let settingsOutput = try? await runShell(settingsCmd) {
            for line in settingsOutput.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("PRODUCT_BUNDLE_IDENTIFIER = ") {
                    bundleId = String(trimmed.dropFirst("PRODUCT_BUNDLE_IDENTIFIER = ".count))
                    break
                }
            }
        }

        return DetectedProject(
            scheme: scheme,
            project: project,
            workspace: workspace,
            bundleId: bundleId
        )
    }
}

// MARK: - Cache

extension ProjectDetector {
    private static let cachePath = ".grantiva/config.json"

    public static func loadCache() -> DetectedProject? {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        return loadCache(
            cacheURL: cwd.appendingPathComponent(cachePath),
            projectDirectory: cwd
        )
    }

    static func loadCache(
        cacheURL: URL,
        projectDirectory: URL,
        fileManager fm: FileManager = .default
    ) -> DetectedProject? {
        guard fm.fileExists(atPath: cacheURL.path),
              let data = fm.contents(atPath: cacheURL.path),
              let cached = try? JSONDecoder().decode(DetectedProject.self, from: data) else {
            return nil
        }

        guard let cacheDate = try? fm.attributesOfItem(atPath: cacheURL.path)[.modificationDate] as? Date else {
            return cached
        }

        if let contents = try? fm.contentsOfDirectory(atPath: projectDirectory.path) {
            for item in contents where
                !item.hasPrefix(".") && (item.hasSuffix(".xcodeproj") || item.hasSuffix(".xcworkspace")) {
                let containerURL = projectDirectory.appendingPathComponent(item)
                if let modificationDate = try? fm.attributesOfItem(atPath: containerURL.path)[.modificationDate] as? Date,
                   modificationDate > cacheDate {
                    return nil // Cache invalidated
                }
            }
        }

        return cached
    }

    public static func saveCache(_ project: DetectedProject) {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        try? writeCache(project, cacheURL: cwd.appendingPathComponent(cachePath))
    }

    static func writeCache(
        _ project: DetectedProject,
        cacheURL: URL,
        fileManager fm: FileManager = .default
    ) throws {
        let directory = cacheURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: directory.path) {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let data = try JSONEncoder().encode(project)
        try data.write(to: cacheURL, options: .atomic)
    }
}

// MARK: - Failing

extension ProjectDetector {
    public static let failing = ProjectDetector {
        throw GrantivaError.invalidArgument("ProjectDetector.failing")
    }
}
