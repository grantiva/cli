import Foundation
import GrantivaCore

/// Runs a cleanup at most once, from whichever path gets there first.
final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var body: (@Sendable () -> Void)?

    init(_ body: @escaping @Sendable () -> Void) { self.body = body }

    func run() {
        let pending: (@Sendable () -> Void)? = lock.withLock {
            defer { body = nil }
            return body
        }
        pending?()
    }

    /// A flag set from one task and read from another.
    final class Flag: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false
        func set() { lock.withLock { value = true } }
        var isSet: Bool { lock.withLock { value } }
    }
}

/// The foreground runner's output. Both streams go to the terminal through
/// `RunnerSession.narrate` (so `--json` and `--quiet` silence them), whole
/// lines at a time; stdout is also fed to the startup parser until
/// `endStartup()`. Reading continues after startup, so the runner never
/// writes into a pipe nobody drains.
final class RunnerOutputForwarder: @unchecked Sendable {
    let chunks: AsyncStream<Data>
    private let continuation: AsyncStream<Data>.Continuation
    private let narrate: @Sendable (String) -> Void
    private let recentLock = NSLock()
    private var recent = ""

    /// The last few kilobytes of both streams, for the runner's own reason
    /// when it exits during start-up (L48).
    var recentText: String { recentLock.withLock { recent } }

    private func remember(_ text: String) {
        recentLock.withLock {
            recent += text
            if recent.utf8.count > 16_384 { recent = String(recent.suffix(8_192)) }
        }
    }

    init(narrate: @escaping @Sendable (String) -> Void = { RunnerSession.narrate($0) }) {
        (chunks, continuation) = AsyncStream<Data>.makeStream()
        self.narrate = narrate
    }

    /// The runner's stdout: narrated and parsed.
    func attachOutput(_ handle: FileHandle) {
        let continuation = continuation
        attach(handle, onData: { continuation.yield($0) }, onEnd: { continuation.finish() })
    }

    /// The runner's stderr: narrated only.
    func attachErrors(_ handle: FileHandle) {
        attach(handle, onData: { _ in }, onEnd: {})
    }

    private func attach(_ handle: FileHandle, onData: @escaping @Sendable (Data) -> Void, onEnd: @escaping @Sendable () -> Void) {
        let lines = LineBuffer()
        let narrate = narrate
        handle.readabilityHandler = { [weak self] readable in
            let data = readable.availableData
            guard !data.isEmpty else {
                readable.readabilityHandler = nil
                if let rest = lines.finish() {
                    self?.remember(rest)
                    narrate(rest)
                }
                onEnd()
                return
            }
            if let complete = lines.consume(data) {
                self?.remember(complete)
                narrate(complete)
            }
            onData(data)
        }
    }

    func endStartup() {
        continuation.finish()
    }
}

/// Bytes in, whole lines out, so a UTF-8 scalar split across two reads is
/// never decoded in halves.
final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = Data()

    /// Every complete line received so far (with their newlines), or nil.
    func consume(_ data: Data) -> String? {
        lock.withLock {
            pending.append(data)
            guard let last = pending.lastIndex(of: 0x0A) else { return nil }
            let complete = pending[...last]
            pending = Data(pending[pending.index(after: last)...])
            return String(decoding: complete, as: UTF8.self)
        }
    }

    /// Whatever is left, once the stream has ended.
    func finish() -> String? {
        lock.withLock {
            defer { pending = Data() }
            return pending.isEmpty ? nil : String(decoding: pending, as: UTF8.self) + "\n"
        }
    }
}
