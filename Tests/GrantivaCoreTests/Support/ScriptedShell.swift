import Foundation
@testable import GrantivaCore

/// Records every command line and answers from a script, in order.
/// Shared by the Android unit tests so each file does not redefine it.
final class ScriptedShell: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<String, Error>]
    private var recorded: [String] = []

    init(_ results: [Result<String, Error>] = []) { self.results = results }

    /// Every call succeeds with this answer when the script runs out.
    var fallback: String = ""

    func execute(_ command: String) async throws -> String {
        try lock.withLock {
            recorded.append(command)
            guard !results.isEmpty else { return fallback }
            return try results.removeFirst().get()
        }
    }

    var commands: [String] { lock.withLock { recorded } }
}
