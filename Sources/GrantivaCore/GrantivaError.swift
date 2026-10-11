import Foundation

public enum GrantivaError: Error, LocalizedError, Sendable {
    case simulatorNotRunning
    case simulatorWindowNotFound
    case elementNotFound(String)
    case buildFailed(String)
    case testFailed(String)
    case invalidImage
    case notAuthenticated
    case configNotFound
    case commandFailed(String, Int32)
    case invalidArgument(String)
    case diffSizeMismatch(baseline: String, current: String)
    case noCaptures(String)
    case runnerNotFound
    case networkError(String, Int)
    /// A local agent or device state problem whose message is the whole story.
    case unavailable(String)
    case baselineNotFound(String)
    case appNotFound(String)
    case invalidBinary(String)
    case ipaExtractionFailed(String)
    case permissionDenied(String)
    case notFound(String)
    /// A config file that loads but configures nothing the command can do
    /// (no screens, no flows). The message is the whole sentence.
    case configuration(String)
    case aborted

    public var errorDescription: String? {
        switch self {
        case .simulatorNotRunning:
            return "No simulator is running. Run: grantiva simulator ensure --name \"<device>\""
        case .simulatorWindowNotFound:
            return "Simulator window not found. Is the Simulator app visible?"
        case .elementNotFound(let label):
            return "Element not found: \"\(label)\". Run grantiva hierarchy (or the grantiva_a11y_tree MCP tool) to inspect the tree."
        case .buildFailed(let message):
            return "Build failed: \(message)"
        case .testFailed(let message):
            return "Tests failed: \(message)"
        case .invalidImage:
            return "Invalid or unreadable image file."
        case .notAuthenticated:
            return "Not authenticated. Run: grantiva auth login"
        case .configNotFound:
            return "grantiva.yml not found. Run: grantiva init"
        case .commandFailed(let message, _):
            // The message is the whole sentence; call sites that report a
            // subprocess exit say so themselves (see `shell`).
            return message
        case .invalidArgument(let msg):
            return "Invalid argument: \(msg)"
        case .diffSizeMismatch(let baseline, let current):
            return "Image size mismatch: baseline is \(baseline), current is \(current)"
        case .noCaptures(let dir):
            return "No captures found in \(dir). Run: grantiva diff capture"
        case .runnerNotFound:
            return "Runner binary not found. The embedded grantiva-runner could not be extracted."
        case .networkError(let message, let statusCode):
            return "Network error (\(statusCode)): \(message)"
        case .unavailable(let message):
            return message
        case .baselineNotFound(let screen):
            return "Baseline not found for screen \"\(screen)\""
        case .appNotFound(let path):
            return "App bundle not found at \"\(path)\". Verify the path exists or run a build first."
        case .invalidBinary(let reason):
            return "Invalid app binary: \(reason)"
        case .ipaExtractionFailed(let reason):
            return "IPA extraction failed: \(reason)"
        case .permissionDenied(let message):
            return message
        case .notFound(let message):
            return message
        case .configuration(let message):
            return message
        case .aborted:
            return "Aborted."
        }
    }

    /// The message without the "Invalid argument: " prefix, for a caller
    /// that reports it as a usage error (`Error: <message>`, exit 64).
    public var usageMessage: String {
        if case .invalidArgument(let message) = self { return message }
        return errorDescription ?? String(describing: self)
    }
}

extension GrantivaError {
    /// The one root sentence every "app is not on the device" message starts
    /// with (`run --no-build`, `build install --no-build`, a failed launch);
    /// each caller appends its own remedy.
    public static func notInstalledRoot(appID: String, device: String) -> String {
        "\(appID) is not installed on \(device)"
    }
}

extension GrantivaError {
    /// The one "no session" error (K46) for `hierarchy`, `runner
    /// dump-hierarchy` and the MCP session tools: what is missing, then how to
    /// start one. `sessionFile` and `directory` name where the MCP server
    /// looked; `orPassPort` adds dump-hierarchy's escape hatch; `ignored`
    /// counts keep-alive sessions passed over because they belong elsewhere.
    public static func noRunnerSession(
        sessionFile: String? = nil, directory: String? = nil, orPassPort: Bool = false, ignored: Int = 0
    ) -> GrantivaError {
        var text = "No active runner session"
        if let sessionFile { text += " at \(sessionFile)" }
        text += ". Start one with `grantiva runner start` or `grantiva run --keep-alive`"
        if let directory { text += " in \(directory)" }
        if orPassPort { text += ", or pass --port" }
        text += "."
        if ignored > 0 {
            text += " \(ignored) keep-alive session(s) started from another project directory or for another platform were ignored."
        }
        return .notFound(text)
    }
}
