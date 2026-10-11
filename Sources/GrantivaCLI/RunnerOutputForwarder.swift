import Foundation

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
}

/// The foreground runner's stdout: echoed to stderr as it arrives, and fed to
/// the startup parser until `endStartup()`. Reading continues after startup,
/// so the runner never writes into a pipe nobody drains.
final class RunnerOutputForwarder: @unchecked Sendable {
    let chunks: AsyncStream<Data>
    private let continuation: AsyncStream<Data>.Continuation
    private let echo: Bool

    init(echo: Bool) {
        (chunks, continuation) = AsyncStream<Data>.makeStream()
        self.echo = echo
    }

    func attach(_ handle: FileHandle) {
        let continuation = continuation
        let echo = echo
        handle.readabilityHandler = { readable in
            let data = readable.availableData
            guard !data.isEmpty else {
                readable.readabilityHandler = nil
                continuation.finish()
                return
            }
            if echo { FileHandle.standardError.write(data) }
            continuation.yield(data)
        }
    }

    func endStartup() {
        continuation.finish()
    }
}
