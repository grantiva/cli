import Foundation

/// Rewrites the staged temp paths grantiva hands the runner back into the paths
/// the user actually typed.
///
/// Each flow is copied into `/var/folders/…/grantiva-<UUID>/<name>.yaml` so the
/// resolved bundle ID and any `--env` values can be injected without touching
/// the user's file. The runner then reports failures against that copy, which
/// is a path the user has never seen and cannot open. Substituting on the way
/// out keeps the staging invisible.
public struct OutputRewriter: Sendable {
    /// Ordered longest-source-first so a path that is a prefix of another
    /// cannot shadow it.
    private let replacements: [(source: String, target: String)]
    private var pending = ""

    public init(replacements: [String: String]) {
        self.replacements = replacements
            .map { (source: $0.key, target: $0.value) }
            .sorted { $0.source.count > $1.source.count }
    }

    public var isEmpty: Bool { replacements.isEmpty }

    /// Applies every substitution to a complete string.
    public func rewrite(_ text: String) -> String {
        var result = text
        for replacement in replacements {
            result = result.replacingOccurrences(of: replacement.source, with: replacement.target)
        }
        return result
    }

    /// Feeds a streamed chunk through the rewriter, returning the text that is
    /// safe to emit now. A trailing fragment that could still grow into one of
    /// the paths is held back so a substitution is never split across two
    /// writes; everything else is emitted immediately, so live runner output —
    /// including a keep-alive prompt with no trailing newline — is not delayed.
    public mutating func consume(_ chunk: String) -> String {
        pending += chunk
        let rewritten = rewrite(pending)
        let holdback = longestPartialMatchSuffix(of: rewritten)
        let emitEnd = rewritten.index(rewritten.endIndex, offsetBy: -holdback)
        let emit = String(rewritten[rewritten.startIndex..<emitEnd])
        pending = String(rewritten[emitEnd...])
        return emit
    }

    /// Emits anything still held back. Call at end of stream.
    public mutating func flush() -> String {
        let remainder = rewrite(pending)
        pending = ""
        return remainder
    }

    /// Length of the longest suffix of `text` that is a proper prefix of one of
    /// the sources — the only fragment that could still complete into a match.
    private func longestPartialMatchSuffix(of text: String) -> Int {
        var longest = 0
        for replacement in replacements {
            let source = Array(replacement.source)
            let characters = Array(text)
            let maximum = min(source.count - 1, characters.count)
            guard maximum > 0 else { continue }
            for length in stride(from: maximum, through: 1, by: -1) {
                if Array(characters.suffix(length)) == Array(source.prefix(length)) {
                    longest = max(longest, length)
                    break
                }
            }
        }
        return longest
    }
}
