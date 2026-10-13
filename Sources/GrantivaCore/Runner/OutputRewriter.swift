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
    private let displayPaths: Set<String>
    private static let cycleMarker = "circular dependency detected: "

    public init(replacements: [String: String]) {
        self.displayPaths = Set(replacements.values)
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
        return result.components(separatedBy: "\n").map { line in
            guard let marker = line.range(of: Self.cycleMarker) else { return line }
            var hops = String(line[marker.upperBound...]).components(separatedBy: " -> ")
            guard hops.count > 1 else { return line }
            for index in 1..<hops.count {
                let hop = hops[index]
                guard hop.hasPrefix("../") || hop.hasPrefix("./"), displayPaths.contains(hops[index - 1]) else { continue }
                let parent = (hops[index - 1] as NSString).deletingLastPathComponent
                guard let resolved = Self.resolving(hop, from: parent) else { continue }
                // Only known reachable flows can supply a canonical display name.
                if displayPaths.contains(resolved) { hops[index] = resolved }
            }
            return String(line[..<marker.upperBound]) + hops.joined(separator: " -> ")
        }.joined(separator: "\n")
    }

    private static func resolving(_ hop: String, from parent: String) -> String? {
        if parent.hasPrefix("/") {
            return URL(fileURLWithPath: parent, isDirectory: true).appendingPathComponent(hop).standardizedFileURL.path
        }
        var components = parent.split(separator: "/").map(String.init)
        for part in hop.split(separator: "/") {
            if part == ".." {
                // An operand escaping the project must not become a known
                // in-project path merely because a synthetic root clipped it.
                guard !components.isEmpty, components.last != ".." else { return nil }
                components.removeLast()
            } else if part != "." { components.append(String(part)) }
        }
        return components.joined(separator: "/")
    }

    /// Feeds a streamed chunk through the rewriter, returning the text that is
    /// safe to emit now. A trailing fragment that could still grow into one of
    /// the paths is held back so a substitution is never split across two
    /// writes; everything else is emitted immediately, so live runner output —
    /// including a keep-alive prompt with no trailing newline — is not delayed.
    public mutating func consume(_ chunk: String) -> String {
        pending += chunk
        // A cycle's relative hops depend on the preceding hop. Hold only its
        // unfinished diagnostic, keeping ordinary keep-alive output immediate.
        let lineStart = pending.lastIndex(of: "\n").map { pending.index(after: $0) } ?? pending.startIndex
        if let marker = pending.range(of: Self.cycleMarker, range: lineStart..<pending.endIndex) {
            let emit = rewrite(String(pending[..<marker.lowerBound]))
            pending = String(pending[marker.lowerBound...])
            return emit
        }
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
        for candidate in replacements.map(\.source) + [Self.cycleMarker] {
            let source = Array(candidate)
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
