import Foundation
import Logging

/// The log level every Grantiva logger reads.
///
/// `GrantivaLog.logger` is created once and lives for the process, so a level
/// stored on the handler instance would be fixed at the moment the logger was
/// first touched — before the command line has been consulted. Reading a shared
/// value instead makes `--verbose` / `--quiet` take effect no matter when the
/// logger happens to be initialised.
public enum GrantivaLogLevel {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var storage: Logger.Level = .info

    public static var current: Logger.Level {
        get { lock.lock(); defer { lock.unlock() }; return storage }
        set { lock.lock(); storage = newValue; lock.unlock() }
    }
}

/// A `LogHandler` shaped for an interactive CLI rather than a log aggregator.
///
/// swift-log's `StreamLogHandler` renders every line as
///
///     2026-08-29T14:33:17+0000 info com.grantiva.cli: [GrantivaCLI] Runner started
///
/// which is right for something being shipped to a log store and wrong for a
/// person watching a build. At the default level this handler prints the bare
/// message, so `Runner started (detached)` looks exactly as it did when it was
/// a `print`. Timestamps, the label, and metadata are what `--verbose` buys.
///
/// Everything here goes to **stderr**. Program output belongs on stdout, via
/// `Output` — see the note there.
public struct CLILogHandler: LogHandler {
    /// Where a formatted line is written. Injectable so tests can read it.
    public typealias Sink = @Sendable (String) -> Void

    public var metadata: Logger.Metadata = [:]

    /// Backed by `GrantivaLogLevel` so a level set after this handler was built
    /// still applies.
    public var logLevel: Logger.Level {
        get { GrantivaLogLevel.current }
        set { GrantivaLogLevel.current = newValue }
    }

    private let label: String
    private let sink: Sink
    /// True once an interrupt is under way (`SignalRelay.isTerminating`).
    private let interrupted: @Sendable () -> Bool

    public init(
        label: String,
        sink: @escaping Sink = CLILogHandler.standardError,
        interrupted: @escaping @Sendable () -> Bool = { SignalRelay.shared.isTerminating }
    ) {
        self.label = label
        self.sink = sink
        self.interrupted = interrupted
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata explicit: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        // Nothing follows the interrupt notice. Every progress line and every
        // `--verbose` line goes through here, so once an interrupt is under
        // way this one gate drops them all: the `stopped by SIGTERM: …
        // bootstatus …` of a child the relay ends, and the `Starting
        // runner...` / `Simulator booted: …` of a step that was already past
        // its interrupt check. Warnings and errors still print, and so does a
        // line marked as the command's outcome (`afterInterrupt`).
        if Self.isDroppedAfterInterrupt(level, metadata: explicit), interrupted() { return }
        var merged = self.metadata.merging(explicit ?? [:]) { _, new in new }
        merged[Self.afterInterruptKey] = nil
        sink(Self.format(
            level: level,
            message: "\(message)",
            metadata: merged,
            label: label,
            timestamp: Self.timestamp()
        ))
    }

    /// Renders one line. Pure, so the contract can be tested without a process.
    ///
    /// - `.info` / `.notice`: the bare message, indistinguishable from the
    ///   `print` it replaced.
    /// - `.warning`: `Warning: …`, the wording already used for advisory lines
    ///   (`grantiva run`'s log-stream failure).
    /// - `.error` / `.critical`: `Error: …`, the prefix already used for
    ///   per-screen failures in `diff` and `ci`.
    /// - `.debug` / `.trace`: prefixed and stamped. This is the only level that
    ///   carries a timestamp, a label, or metadata.
    public static func format(
        level: Logger.Level,
        message: String,
        metadata: Logger.Metadata = [:],
        label: String,
        timestamp: String
    ) -> String {
        switch level {
        case .info, .notice:
            return message
        case .warning:
            return "Warning: \(message)"
        case .error, .critical:
            return "Error: \(message)"
        case .debug, .trace:
            let rendered = metadata.isEmpty
                ? ""
                : " " + metadata.sorted { $0.key < $1.key }
                    .map { "\($0.key)=\($0.value)" }
                    .joined(separator: " ")
            return "[\(level)] \(timestamp) \(label): \(message)\(rendered)"
        }
    }

    /// The metadata key that lets a progress-level line through after the
    /// interrupt notice: the outcome the interrupt itself produced (a
    /// teardown's `Runner stopped by teardown …`), never narration.
    public static let afterInterruptKey = "grantiva.afterInterrupt"

    /// Metadata for `afterInterruptKey`.
    public static let afterInterrupt: Logger.Metadata = [afterInterruptKey: "true"]

    /// The lines an interrupt silences: progress narration (`.info`,
    /// `.notice`) and the `--verbose` levels, unless marked as the outcome.
    static func isDroppedAfterInterrupt(_ level: Logger.Level, metadata: Logger.Metadata? = nil) -> Bool {
        level < .warning && metadata?[afterInterruptKey] == nil
    }

    private static let stderrLock = NSLock()

    public static let standardError: Sink = { line in
        stderrLock.lock()
        defer { stderrLock.unlock() }
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }

    private static func timestamp() -> String {
        Date().ISO8601Format()
    }
}
