import Foundation

/// Process-wide switch for the runner's relayed output.
///
/// The runner's banner, setup lines, per-step lines, summary table and report
/// paths are progress narration. `--quiet` silences progress narration and
/// `--json` suppresses it (README), so a command sets `isSilenced` once from
/// its options and every relay of runner output goes through
/// `RunnerSession.narrate(_:)`, which honours it. Errors (grantiva's own
/// `Error:` line, which carries the failed step) are never routed here.
public enum RunnerNarration {
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var silenced = false
        var sink: @Sendable (String) -> Void = standardError
    }

    private static let state = State()

    /// True when runner output must not reach the terminal.
    public static var isSilenced: Bool {
        get { state.lock.withLock { state.silenced } }
        set { state.lock.withLock { state.silenced = newValue } }
    }

    /// The rule commands apply: `--json` or `--quiet` silence the runner,
    /// `--verbose` shows it anyway (it wins over `--quiet`, as for grantiva's
    /// own lines).
    public static func shouldSilence(json: Bool, quiet: Bool, verbose: Bool) -> Bool {
        (json || quiet) && !verbose
    }

    /// Where narration goes when it is not silenced.
    public static let standardError: @Sendable (String) -> Void = { text in
        FileHandle.standardError.write(Data(text.utf8))
    }

    /// The destination `narrate` writes to: stderr, or a test's collector.
    public static var sink: @Sendable (String) -> Void {
        get { state.lock.withLock { state.sink } }
        set { state.lock.withLock { state.sink = newValue } }
    }
}

extension RunnerSession {
    /// The single choke point for runner output on its way to the terminal.
    /// Silent while `RunnerNarration.isSilenced` is set, and once an
    /// interrupt is under way (the relay's notice is the last line).
    public static func narrate(_ text: String) {
        narrate(text, silenced: RunnerNarration.isSilenced, sink: RunnerNarration.sink)
    }

    static func narrate(
        _ text: String, silenced: Bool, sink: (String) -> Void,
        interrupted: () -> Bool = { SignalRelay.shared.isTerminating }
    ) {
        guard !silenced, !text.isEmpty, !interrupted() else { return }
        sink(text)
    }
}

/// Line-level edits to the runner's relayed output that the plain path
/// rewriter cannot make:
///
/// - With an ephemeral report directory (no `--report-dir`), the runner's
///   `Report directory:` line and its closing `Reports:`/`Paths:` block name a
///   temp directory grantiva deletes before it exits. They are dropped, and the
///   `Reports:` line becomes one sentence saying how to keep the report.
/// - A screens-config `wait: N` step is generated as an `evalScript` the runner
///   narrates by its type. `waitLabels` maps the generated flow's top-level
///   command index of each such step to its `Wait Ns` label (the one the
///   summary already uses); the filter counts the runner's top-level step
///   lines to know which command a line reports.
struct RunnerOutputFilter {
    static let reportNotKept = "  Report not kept; pass --report-dir <dir> to keep report.json, JUnit and Allure.\n"

    private let ephemeralDirs: [String]
    private let waitLabels: [Int: String]
    /// The top-level command the next step line reports, within the current
    /// `[n/m] <flow>` block.
    private var stepIndex = 0
    private var pending = ""
    private var inReportBlock = false
    private var droppedBlankInBlock = false

    init(ephemeralReportDir: String? = nil, waitLabels: [Int: String] = [:]) {
        if let dir = ephemeralReportDir, !dir.isEmpty {
            var spellings = [dir]
            if dir.hasPrefix("/private/") {
                spellings.append(String(dir.dropFirst("/private".count)))
            } else if dir.hasPrefix("/var/") || dir.hasPrefix("/tmp/") {
                spellings.append("/private" + dir)
            }
            ephemeralDirs = spellings
        } else {
            ephemeralDirs = []
        }
        self.waitLabels = waitLabels
    }

    var isEmpty: Bool { ephemeralDirs.isEmpty && waitLabels.isEmpty }

    /// Feeds a streamed chunk; returns what can be emitted now. Complete lines
    /// are edited; a trailing partial line is held only when it could still
    /// turn into a line this filter edits, so a prompt without a newline is
    /// not delayed.
    mutating func consume(_ chunk: String) -> String {
        pending += chunk
        var output = ""
        while let newline = pending.firstIndex(of: "\n") {
            let line = String(pending[pending.startIndex..<newline])
            pending = String(pending[pending.index(after: newline)...])
            output += process(line: line)
        }
        if !pending.isEmpty, !couldBecomeEditedLine(pending) {
            output += process(partial: pending)
            pending = ""
        }
        return output
    }

    mutating func flush() -> String {
        guard !pending.isEmpty else { return closeBlockIfNeeded() }
        let line = pending
        pending = ""
        return process(partial: line) + closeBlockIfNeeded()
    }

    /// Applies the filter to a whole text (a failure message, say).
    func apply(_ text: String) -> String {
        var copy = self
        return copy.consume(text) + copy.flush()
    }

    private mutating func process(partial: String) -> String {
        let result = process(line: partial)
        // `process(line:)` appends a newline; a partial line has none yet.
        return result.hasSuffix("\n") && !partial.hasSuffix("\n") ? String(result.dropLast()) : result
    }

    private mutating func process(line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if !ephemeralDirs.isEmpty {
            if inReportBlock {
                if trimmed.isEmpty {
                    droppedBlankInBlock = true
                    return ""
                }
                if isReportBlockLine(trimmed) || mentionsEphemeralDir(line) {
                    return ""
                }
                inReportBlock = false
                let spacer = droppedBlankInBlock ? "\n" : ""
                droppedBlankInBlock = false
                return spacer + line + "\n"
            }
            if trimmed.hasPrefix("Reports:"), mentionsEphemeralDir(line) {
                inReportBlock = true
                droppedBlankInBlock = false
                return Self.reportNotKept
            }
            // Any other line naming the deleted directory (the runner's
            // `✓ Report directory: <dir>` setup line) points at nothing once
            // the command returns, so it is dropped rather than rewritten.
            if mentionsEphemeralDir(line) {
                return ""
            }
        }
        if !waitLabels.isEmpty {
            if isFlowHeader(trimmed) {
                stepIndex = 0
            } else if let index = topLevelStepIndex(line) {
                if let label = waitLabels[index], let relabelled = relabelWait(line, label: label) {
                    return relabelled + "\n"
                }
            }
        }
        return line + "\n"
    }

    private mutating func closeBlockIfNeeded() -> String {
        guard inReportBlock else { return "" }
        inReportBlock = false
        droppedBlankInBlock = false
        return ""
    }

    private func mentionsEphemeralDir(_ line: String) -> Bool {
        ephemeralDirs.contains { line.contains($0) }
    }

    private func isReportBlockLine(_ trimmed: String) -> Bool {
        ["├──", "└──", "│", "Paths:", "JSON:", "JUnit:", "Allure:"].contains { trimmed.hasPrefix($0) }
    }

    static let stepGlyphs: Set<Character> = ["✓", "✗", "⚠", "-", "○"]

    /// `[1/1] screens (grantiva.yml)`: a flow's step lines start again at 0.
    private func isFlowHeader(_ trimmed: String) -> Bool {
        trimmed.wholeMatch(of: /\[\d+\/\d+\] .*/) != nil
    }

    /// A step line at the flow's top level (four-space indent, then a step
    /// glyph) reports the next top-level command; nested sub-flow steps are
    /// indented further and are not counted. Returns that command's index.
    private mutating func topLevelStepIndex(_ line: String) -> Int? {
        let indentation = line.prefix { $0 == " " }
        guard indentation.count == 4, let glyph = line.dropFirst(4).first, Self.stepGlyphs.contains(glyph) else { return nil }
        defer { stepIndex += 1 }
        return stepIndex
    }

    /// `    ✓ evalScript (3.0s)` → `    ✓ Wait 3s (3.0s)`.
    private func relabelWait(_ line: String, label: String) -> String? {
        let indentation = line.prefix { $0 == " " }
        let rest = line.dropFirst(indentation.count)
        guard let glyph = rest.first, Self.stepGlyphs.contains(glyph) else { return nil }
        let afterGlyph = rest.dropFirst().drop { $0 == " " }
        guard afterGlyph.hasPrefix("evalScript") else { return nil }
        let tail = afterGlyph.dropFirst("evalScript".count)
        guard tail.isEmpty || tail.hasPrefix(" (") else { return nil }
        return "\(indentation)\(glyph) \(label)\(tail)"
    }

    private func couldBecomeEditedLine(_ partial: String) -> Bool {
        let trimmed = partial.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return !isEmpty }
        if !ephemeralDirs.isEmpty {
            if inReportBlock { return true }
            let markers = ["Reports:", "✓ Report directory:"]
            if markers.contains(where: { $0.hasPrefix(trimmed) || trimmed.hasPrefix($0) }) { return true }
        }
        // Step lines are counted, so any partial line that could become one
        // waits for its newline.
        if !waitLabels.isEmpty {
            if let first = trimmed.first, Self.stepGlyphs.contains(first) || first == "[" { return true }
        }
        return false
    }
}
