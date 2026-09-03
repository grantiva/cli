import Foundation

public enum ScreenArtifact {
    /// Keeps a display name reversible while guaranteeing one filesystem component.
    public static func fileName(for screenName: String, extension fileExtension: String = "png") -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove("/")
        let stem = screenName.addingPercentEncoding(withAllowedCharacters: allowed) ?? "screen"
        return "\(stem).\(fileExtension)"
    }

    public static func screenName(from fileName: String, extension fileExtension: String = "png") -> String? {
        let suffix = ".\(fileExtension)"
        guard fileName.hasSuffix(suffix) else { return nil }
        let stem = String(fileName.dropLast(suffix.count))
        return stem.removingPercentEncoding
    }
}

public struct BaselineStore: Sendable {
    public var save: @Sendable (String, Data) async throws -> String
    public var load: @Sendable (String) async throws -> Data?
    public var list: @Sendable () async throws -> [String]
    public var delete: @Sendable (String) async throws -> Void
    public var baselineDirectory: @Sendable () -> String

    public init(
        save: @escaping @Sendable (String, Data) async throws -> String,
        load: @escaping @Sendable (String) async throws -> Data?,
        list: @escaping @Sendable () async throws -> [String],
        delete: @escaping @Sendable (String) async throws -> Void,
        baselineDirectory: @escaping @Sendable () -> String
    ) {
        self.save = save
        self.load = load
        self.list = list
        self.delete = delete
        self.baselineDirectory = baselineDirectory
    }
}

// MARK: - Local

extension BaselineStore {
    public static func local(directory: String = ".grantiva/baselines") -> BaselineStore {
        let dir = directory
        return BaselineStore(
            save: { screenName, data in
                let fm = FileManager.default
                if !fm.fileExists(atPath: dir) {
                    try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
                }
                let path = "\(dir)/\(ScreenArtifact.fileName(for: screenName))"
                try data.write(to: URL(fileURLWithPath: path))
                return path
            },
            load: { screenName in
                let path = "\(dir)/\(ScreenArtifact.fileName(for: screenName))"
                guard FileManager.default.fileExists(atPath: path) else { return nil }
                return try Data(contentsOf: URL(fileURLWithPath: path))
            },
            list: {
                let fm = FileManager.default
                guard fm.fileExists(atPath: dir) else { return [] }
                let files = try fm.contentsOfDirectory(atPath: dir)
                return files
                    .filter { $0.hasSuffix(".png") }
                    .compactMap { ScreenArtifact.screenName(from: $0) }
                    .sorted()
            },
            delete: { screenName in
                let path = "\(dir)/\(ScreenArtifact.fileName(for: screenName))"
                try FileManager.default.removeItem(atPath: path)
            },
            baselineDirectory: { dir }
        )
    }
}

// MARK: - Failing

extension BaselineStore {
    public static let failing = BaselineStore(
        save: { _, _ in throw GrantivaError.commandFailed("BaselineStore.failing: save", 1) },
        load: { _ in throw GrantivaError.commandFailed("BaselineStore.failing: load", 1) },
        list: { throw GrantivaError.commandFailed("BaselineStore.failing: list", 1) },
        delete: { _ in throw GrantivaError.commandFailed("BaselineStore.failing: delete", 1) },
        baselineDirectory: { "/dev/null" }
    )
}
