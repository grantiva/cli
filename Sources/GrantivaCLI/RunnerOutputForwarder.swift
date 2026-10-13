import Foundation
import GrantivaCore

/// Runs a cleanup once and waits for it to finish on every calling path.
/// Bodies must not call back into this same Once; lifecycle cleanups only
/// remove their owned files and release their lease.
final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var body: (@Sendable () -> Void)?

    init(_ body: @escaping @Sendable () -> Void) { self.body = body }

    func run() {
        lock.lock()
        defer { lock.unlock() }
        let pending = body
        body = nil
        // The signal handler may exit as soon as this returns. Keep it waiting
        // when the foreground task is already removing the session and lease.
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

/// Owns the driver attachment discovered during foreground startup until the
/// foreground session ends. SignalRelay cleanups are synchronous, so release
/// waits briefly for the attachment's asynchronous platform cleanup.
final class ForegroundDriverAttachment: @unchecked Sendable {
    private let condition = NSCondition()
    private var attachment: DriverAttachment?
    private var acquiring = true
    private var releaseRequested = false

    /// Completes startup's ownership handoff. If cleanup already started,
    /// reject and release the late attachment before waking that cleanup.
    func retain(_ attachment: DriverAttachment, timeout: TimeInterval = 15) -> Bool {
        condition.lock()
        if !releaseRequested {
            self.attachment = attachment
            acquiring = false
            condition.broadcast()
            condition.unlock()
            return true
        }
        condition.unlock()

        detach(attachment, timeout: timeout)
        condition.lock()
        acquiring = false
        condition.broadcast()
        condition.unlock()
        return false
    }

    /// Completes startup when no attachment was acquired, so an interrupt
    /// waiting at the ownership boundary can finish.
    func finishAcquiring() {
        condition.lock()
        acquiring = false
        condition.broadcast()
        condition.unlock()
    }

    func release(timeout: TimeInterval = 15, onRequested: @Sendable () -> Void = {}) {
        let deadline = Date().addingTimeInterval(timeout)
        condition.lock()
        releaseRequested = true
        condition.unlock()
        onRequested()
        condition.lock()
        while acquiring, condition.wait(until: deadline) {}
        let owned = attachment
        attachment = nil
        condition.unlock()
        if let owned {
            detach(owned, timeout: max(0, deadline.timeIntervalSinceNow))
        }
    }

    private func detach(_ owned: DriverAttachment, timeout: TimeInterval) {
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            await owned.detach()
            done.signal()
        }
        _ = done.wait(timeout: .now() + timeout)
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
