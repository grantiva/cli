import Foundation

public enum ScreenArtifact {
    /// The file a screen's capture, baseline or diff is stored under: the
    /// screen name itself, with only what cannot appear in one path component
    /// (`/`, `:`, NUL) percent-encoded, plus `%` so decoding stays
    /// unambiguous. "Deep Links" is `Deep Links.png`.
    public static func fileName(for screenName: String, extension fileExtension: String = "png") -> String {
        var stem = ""
        for scalar in screenName.unicodeScalars {
            switch scalar {
            case "%": stem += "%25"
            case "/": stem += "%2F"
            case ":": stem += "%3A"
            case "\u{0}": stem += "%00"
            default: stem.unicodeScalars.append(scalar)
            }
        }
        return "\(stem).\(fileExtension)"
    }

    /// The name Grantiva 2.0.1 and earlier used: everything outside
    /// `urlPathAllowed` (spaces included) percent-encoded. Read as a fallback
    /// so existing baselines and captures keep working.
    public static func legacyFileName(for screenName: String, extension fileExtension: String = "png") -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove("/")
        let stem = screenName.addingPercentEncoding(withAllowedCharacters: allowed) ?? "screen"
        return "\(stem).\(fileExtension)"
    }

    /// Whether `fileName` is how this or an earlier version names `screenName`.
    public static func isCanonical(_ fileName: String, for screenName: String) -> Bool {
        fileName == Self.fileName(for: screenName) || fileName == legacyFileName(for: screenName)
    }

    /// The file present in `directory` for `screenName`: the current name, or
    /// the legacy one when only that exists. The current name when neither does.
    public static func existingFileName(for screenName: String, in directory: String, fileManager: FileManager = .default) -> String {
        let current = fileName(for: screenName)
        if fileManager.fileExists(atPath: "\(directory)/\(current)") { return current }
        let legacy = legacyFileName(for: screenName)
        if legacy != current, fileManager.fileExists(atPath: "\(directory)/\(legacy)") { return legacy }
        return current
    }

    /// Decodes both the current and the legacy form.
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
                let fileName = ScreenArtifact.fileName(for: screenName)
                let path = "\(dir)/\(fileName)"
                try data.write(to: URL(fileURLWithPath: path))
                // Approving migrates a baseline saved under the legacy name.
                let legacy = ScreenArtifact.legacyFileName(for: screenName)
                if legacy != fileName {
                    try? fm.removeItem(atPath: "\(dir)/\(legacy)")
                }
                return path
            },
            load: { screenName in
                let path = "\(dir)/\(ScreenArtifact.existingFileName(for: screenName, in: dir))"
                guard FileManager.default.fileExists(atPath: path) else { return nil }
                return try Data(contentsOf: URL(fileURLWithPath: path))
            },
            list: {
                let fm = FileManager.default
                guard fm.fileExists(atPath: dir) else { return [] }
                let files = try fm.contentsOfDirectory(atPath: dir)
                let names = files
                    .filter { $0.hasSuffix(".png") }
                    .compactMap { ScreenArtifact.screenName(from: $0) }
                return Array(Set(names)).sorted()
            },
            delete: { screenName in
                // Both the current and the legacy name, so no stale copy is
                // left to be found by the load fallback.
                let current = ScreenArtifact.fileName(for: screenName)
                let legacy = ScreenArtifact.legacyFileName(for: screenName)
                var removed = false
                var firstError: Error?
                for name in Set([current, legacy]) {
                    do {
                        try FileManager.default.removeItem(atPath: "\(dir)/\(name)")
                        removed = true
                    } catch {
                        firstError = firstError ?? error
                    }
                }
                if !removed, let firstError { throw firstError }
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
