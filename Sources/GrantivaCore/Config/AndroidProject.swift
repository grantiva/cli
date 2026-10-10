import Foundation

/// The Gradle-side half of `grantiva-android.yml`. Mirrors the Xcode fields
/// that live directly on `GrantivaConfig` for iOS.
public struct AndroidProject: Sendable, Codable, Equatable {
    public var module: String
    public var variant: String
    public var applicationId: String?
    public var emulator: String?
    public var systemImage: String?
    public var buildArgs: [String]

    public init(
        module: String = "app",
        variant: String = "debug",
        applicationId: String? = nil,
        emulator: String? = nil,
        systemImage: String? = nil,
        buildArgs: [String] = []
    ) {
        self.module = module
        self.variant = variant
        self.applicationId = applicationId
        self.emulator = emulator
        self.systemImage = systemImage
        self.buildArgs = buildArgs
    }

    /// The application ID a run installs and tests. The app's own ID (read
    /// from the APK or the Gradle output metadata) wins over `application_id`
    /// in the config, so the run tests the app it installed. An explicit
    /// override (`--application-id`) still wins; a disagreement either way is
    /// returned as a warning naming both IDs.
    public static func applicationID(override: String?, binary: String?, configured: String?) -> (id: String?, warning: String?) {
        if let override {
            guard let binary, binary != override else { return (override, nil) }
            return (override, "--application-id \(override) differs from the app's own application ID \(binary); testing \(override). Drop --application-id to test \(binary).")
        }
        if let binary {
            guard let configured, configured != binary else { return (binary, nil) }
            return (binary, "application_id \(configured) in grantiva-android.yml differs from the app's own application ID \(binary); testing \(binary). Update application_id or pass --application-id to override.")
        }
        return (configured, nil)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case module, variant, emulator
        case applicationId = "application_id"
        case systemImage = "system_image"
        case buildArgs = "build_args"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        module = try c.decodeIfPresent(String.self, forKey: .module) ?? "app"
        variant = try c.decodeIfPresent(String.self, forKey: .variant) ?? "debug"
        applicationId = try c.decodeIfPresent(String.self, forKey: .applicationId)
        emulator = try c.decodeIfPresent(String.self, forKey: .emulator)
        systemImage = try c.decodeIfPresent(String.self, forKey: .systemImage)
        buildArgs = try c.decodeIfPresent([String].self, forKey: .buildArgs) ?? []
    }
}
