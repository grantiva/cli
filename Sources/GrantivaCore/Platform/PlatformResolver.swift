import Foundation

/// Decides which platform a command is operating on. Order: `--platform`,
/// `GRANTIVA_PLATFORM`, whichever config file exists, then the project files
/// in the directory. See the spec, section 1, "Resolution order".
public struct PlatformResolver: Sendable {
    public static let environmentKey = "GRANTIVA_PLATFORM"

    private let directory: URL
    private let environment: [String: String]
    // FileManager is not Sendable; it is only used for read-only lookups.
    nonisolated(unsafe) private let fileManager: FileManager

    public init(
        directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.environment = environment
        self.fileManager = fileManager
    }

    public func resolve(flag: Platform?) throws -> Platform {
        // An explicit flag always wins. Whether its config file exists is the
        // command layer's concern (e.g. `grantiva init --platform android`).
        if let flag {
            return flag
        }

        if let platform = try environmentPlatform() {
            return platform
        }

        let configs = existingConfigFiles()
        switch configs.count {
        case 1:
            return configs[0]
        case 2:
            throw GrantivaError.invalidArgument(
                "Both grantiva.yml and grantiva-android.yml exist. Pass --platform ios|android or set \(Self.environmentKey)."
            )
        default:
            break
        }

        let detected = detectFromDirectory()
        switch detected.count {
        case 1:
            return detected[0]
        case 2:
            throw GrantivaError.invalidArgument(
                "Found both an Xcode project and Gradle settings. Pass --platform ios|android or set \(Self.environmentKey)."
            )
        default:
            throw GrantivaError.invalidArgument(
                "No project found. Expected grantiva.yml or an .xcodeproj/.xcworkspace for iOS, "
                    + "or grantiva-android.yml or settings.gradle(.kts) for Android."
            )
        }
    }

    /// The platform `GRANTIVA_PLATFORM` names, nil when it is unset or empty;
    /// any other value is an error.
    public func environmentPlatform() throws -> Platform? {
        guard let raw = environment[Self.environmentKey], !raw.isEmpty else { return nil }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let platform = Platform(rawValue: normalized) else {
            throw GrantivaError.invalidArgument(
                "\(Self.environmentKey) is \"\(raw)\"; expected ios or android."
            )
        }
        return platform
    }

    /// `resolve(flag:)`, except that when nothing at all points anywhere (no
    /// flag, no GRANTIVA_PLATFORM, no config file, no project files) the
    /// answer is iOS: before Android support every command was iOS and ran
    /// fine without a project here.
    public func resolveOrDefault(flag: Platform?) throws -> Platform {
        if flag == nil,
           (environment[Self.environmentKey] ?? "").isEmpty,
           existingConfigFiles().isEmpty,
           detectFromDirectory().isEmpty {
            return .ios
        }
        return try resolve(flag: flag)
    }

    /// Platforms whose config file exists, in `Platform.allCases` order.
    public func existingConfigFiles() -> [Platform] {
        Platform.allCases.filter {
            fileManager.fileExists(atPath: directory.appendingPathComponent($0.configFileName).path)
        }
    }

    /// Platforms implied by project files in the directory, in `Platform.allCases` order.
    public func detectFromDirectory() -> [Platform] {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return [] }
        let visible = entries.filter { !$0.hasPrefix(".") }
        var found: [Platform] = []
        if visible.contains(where: { $0.hasSuffix(".xcworkspace") || $0.hasSuffix(".xcodeproj") }) {
            found.append(.ios)
        }
        if visible.contains("settings.gradle") || visible.contains("settings.gradle.kts") {
            found.append(.android)
        }
        return found
    }
}
