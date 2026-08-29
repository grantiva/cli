import Darwin
import Dispatch
import Foundation

/// Forwards SIGINT/SIGTERM from grantiva to the process groups it spawned, then
/// runs the registered cleanups before exiting.
///
/// Two problems this solves:
///
/// 1. **A backgrounded run cannot be interrupted at all.** A shell running a
///    script starts asynchronous commands (`grantiva run … &`) with SIGINT and
///    SIGQUIT set to `SIG_IGN`, and a child inherits that disposition. So the
///    documented "release with Ctrl-C" — `kill -INT <pid>` against a
///    backgrounded keep-alive run — is a no-op: grantiva keeps running, keeps
///    holding the simulator lease, and the next run is refused as "already
///    owned by another Grantiva run". Registering an explicit handler replaces
///    the inherited `SIG_IGN`, so the signal is delivered again.
///
/// 2. **Descendants outlive the signal.** Even when grantiva does die, nothing
///    reaps grantiva-runner, WebDriverAgent's `xcodebuild test-without-building`
///    or a 600-second `simctl diagnose`. The relay signals the runner's whole
///    process group (see `ChildProcess`) so the tree goes down together.
///
/// A `DispatchSourceSignal` observes the signal on a queue rather than in
/// signal context, so cleanups can do real work. Installation is idempotent and
/// happens only on paths that spawn a runner, leaving every other command's
/// Ctrl-C behaviour untouched.
public final class SignalRelay: @unchecked Sendable {
    public static let shared = SignalRelay()

    private let lock = NSLock()
    private var installed = false
    private var sources: [DispatchSourceSignal] = []
    private var groups: [pid_t] = []
    private var cleanups: [(id: UInt64, body: @Sendable () -> Void)] = []
    private var nextID: UInt64 = 1
    private var terminating = false

    private init() {}

    /// Installs handlers for SIGINT and SIGTERM. Safe to call repeatedly.
    public func install() {
        lock.lock()
        guard !installed else {
            lock.unlock()
            return
        }
        installed = true
        lock.unlock()

        for signalNumber in [SIGINT, SIGTERM] {
            // The dispatch source observes delivery; the default action must be
            // suppressed first or the process dies before cleanups can run.
            // This also overrides an inherited SIG_IGN.
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .global())
            source.setEventHandler { [weak self] in
                self?.handle(signalNumber)
            }
            source.resume()
            lock.lock()
            sources.append(source)
            lock.unlock()
        }
    }

    /// Tracks a process group to be signalled when grantiva is interrupted.
    public func track(group pgid: pid_t) {
        install()
        lock.lock()
        defer { lock.unlock() }
        if !groups.contains(pgid) { groups.append(pgid) }
    }

    public func untrack(group pgid: pid_t) {
        lock.lock()
        defer { lock.unlock() }
        groups.removeAll { $0 == pgid }
    }

    /// Registers work to run when grantiva is interrupted — releasing a lease,
    /// clearing a ledger entry, writing a terminal ready-file. Returns a token
    /// for `removeCleanup(_:)`.
    @discardableResult
    public func onTermination(_ body: @escaping @Sendable () -> Void) -> UInt64 {
        install()
        lock.lock()
        defer { lock.unlock() }
        let id = nextID
        nextID += 1
        cleanups.append((id: id, body: body))
        return id
    }

    public func removeCleanup(_ id: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        cleanups.removeAll { $0.id == id }
    }

    /// Test seam: runs the same sequence the signal handler runs, without
    /// exiting the process.
    public func runCleanupsForTesting() {
        for cleanup in snapshotCleanups() { cleanup() }
    }

    private func snapshotCleanups() -> [@Sendable () -> Void] {
        lock.lock()
        defer { lock.unlock() }
        return cleanups.map(\.body)
    }

    private func handle(_ signalNumber: Int32) {
        lock.lock()
        if terminating {
            lock.unlock()
            return
        }
        terminating = true
        let trackedGroups = groups
        let pendingCleanups = cleanups.map(\.body)
        lock.unlock()

        FileHandle.standardError.write(Data(
            "\n[grantiva] received \(signalNumber == SIGINT ? "SIGINT" : "SIGTERM") — releasing simulator and reaping child processes\n".utf8
        ))

        for pgid in trackedGroups {
            ChildProcess.terminateGroup(pgid, gracePeriod: 5)
        }
        for cleanup in pendingCleanups { cleanup() }

        exit(128 + signalNumber)
    }
}
