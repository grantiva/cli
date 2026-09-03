import Darwin
import Foundation

// MARK: - Defaults

public enum GrantivaDefaults {
    public static let apiBaseURL = "https://api.grantiva.io"
}

/// Parses a configured API origin without allowing malformed credentials to
/// reach force-unwrapped request construction.
public func validatedAPIBaseURL(_ value: String) throws -> URL {
    let normalized = value.hasSuffix("/") ? String(value.dropLast()) : value
    guard let url = URL(string: normalized),
          ["http", "https"].contains(url.scheme?.lowercased()),
          url.host != nil
    else {
        throw GrantivaError.invalidArgument("Configured API URL must be a valid http or https URL")
    }
    return url
}

// MARK: - AuthCredentials

public struct AuthCredentials: Codable, Sendable {
    public var apiKey: String
    public var baseURL: String
    public var email: String?

    public init(apiKey: String, baseURL: String, email: String? = nil) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.email = email
    }
}

// MARK: - AuthStore

public struct AuthStore: Sendable, Decodable {
    public init(from decoder: Decoder) throws { self = .live }
    public var load: @Sendable () -> AuthCredentials?
    public var save: @Sendable (AuthCredentials) throws -> Void
    public var delete: @Sendable () throws -> Void

    public init(
        load: @escaping @Sendable () -> AuthCredentials?,
        save: @escaping @Sendable (AuthCredentials) throws -> Void,
        delete: @escaping @Sendable () throws -> Void
    ) {
        self.load = load
        self.save = save
        self.delete = delete
    }
}

// MARK: - Live

extension AuthStore {
    static let authDir: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.grantiva"
    }()

    static let authPath: String = {
        "\(authDir)/auth.json"
    }()

    public static let live = AuthStore(
        load: {
            guard let data = FileManager.default.contents(atPath: authPath) else { return nil }
            return try? JSONDecoder().decode(AuthCredentials.self, from: data)
        },
        save: { credentials in
            try saveSecurely(credentials, directory: authDir, path: authPath)
        },
        delete: {
            let fm = FileManager.default
            guard fm.fileExists(atPath: authPath) else { return }
            try fm.removeItem(atPath: authPath)
        }
    )

    static func saveSecurely(_ credentials: AuthCredentials, directory: String, path: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(credentials)
        let temporary = "\(directory)/.auth-\(UUID().uuidString).tmp"
        let descriptor = Darwin.open(temporary, O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else {
            throw GrantivaError.commandFailed("Could not create secure auth file: \(String(cString: strerror(errno)))", 1)
        }
        var writeError: Int32?
        data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            var offset = 0
            while offset < buffer.count {
                let written = Darwin.write(descriptor, base.advanced(by: offset), buffer.count - offset)
                if written > 0 { offset += written; continue }
                if written < 0 && errno == EINTR { continue }
                writeError = errno
                break
            }
        }
        if writeError == nil && fsync(descriptor) != 0 { writeError = errno }
        Darwin.close(descriptor)
        if let writeError {
            try? fm.removeItem(atPath: temporary)
            throw GrantivaError.commandFailed("Could not write secure auth file: \(String(cString: strerror(writeError)))", 1)
        }
        guard Darwin.rename(temporary, path) == 0 else {
            let renameError = errno
            try? fm.removeItem(atPath: temporary)
            throw GrantivaError.commandFailed("Could not install secure auth file: \(String(cString: strerror(renameError)))", 1)
        }
    }
}

// MARK: - Failing

extension AuthStore {
    public static let failing = AuthStore(
        load: { nil },
        save: { _ in throw GrantivaError.commandFailed("AuthStore.failing: save", 1) },
        delete: { throw GrantivaError.commandFailed("AuthStore.failing: delete", 1) }
    )
}

// MARK: - Resolve

extension AuthStore {
    /// Resolves credentials from environment variables or auth.json file.
    /// Resolution order:
    /// 1. GRANTIVA_API_KEY env var (with GRANTIVA_API_URL or default)
    /// 2. ~/.grantiva/auth.json file
    /// 3. nil
    public static func resolveCredentials() -> AuthCredentials? {
        let env = ProcessInfo.processInfo.environment

        // 1. Environment variable
        if let apiKey = env["GRANTIVA_API_KEY"], !apiKey.isEmpty {
            let baseURL = env["GRANTIVA_API_URL"] ?? GrantivaDefaults.apiBaseURL
            return AuthCredentials(apiKey: apiKey, baseURL: baseURL)
        }

        // 2. Auth file
        if let stored = live.load() {
            return stored
        }

        // 3. Not authenticated
        return nil
    }
}
