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
/// happens only on paths that spawn a runner or a log stream, leaving every
/// other command's Ctrl-C behaviour untouched.
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

    /// True once a SIGINT/SIGTERM has been received. Set before the runner's
    /// group is terminated, so a session that sees its runner die can tell an
    /// interrupt from a runner failure and record `interrupted`.
    public var isTerminating: Bool {
        lock.lock()
        defer { lock.unlock() }
        return terminating
    }

    /// Test seam: runs the registered cleanups without exiting the process.
    public func runCleanupsForTesting() {
        for cleanup in snapshotCleanups() { cleanup() }
    }

    private func snapshotCleanups() -> [@Sendable () -> Void] {
        lock.lock()
        defer { lock.unlock() }
        return cleanups.map(\.body)
    }

    /// Test seam: runs the whole interrupt sequence the signal handler runs —
    /// mark terminating, reap tracked groups, run cleanups — without exiting.
    /// Pair with `resetTerminationForTesting()`.
    public func simulateTerminationForTesting() {
        terminate(announcing: nil)
    }

    public func resetTerminationForTesting() {
        lock.lock()
        defer { lock.unlock() }
        terminating = false
    }

    private func handle(_ signalNumber: Int32) {
        // A signal arriving while cleanups run exits at once. In practice only
        // a different signal gets here (SIGTERM after SIGINT): a repeat of the
        // same signal on its DispatchSourceSignal is held until this handler
        // returns. RunCommand's 30 s cap on waiting for the relay is the real
        // guarantee against a hung cleanup.
        terminate(announcing: signalNumber == SIGINT ? "SIGINT" : "SIGTERM")
        exit(128 + signalNumber)
    }

    /// Returns false when a termination is already under way.
    @discardableResult
    private func terminate(announcing signalName: String?) -> Bool {
        lock.lock()
        if terminating {
            lock.unlock()
            return false
        }
        // Recorded before any group is signalled: the runner exits as a result
        // of the terminateGroup below, and the session that wakes up on that
        // exit must already see that this was an interrupt.
        terminating = true
        let trackedGroups = groups
        let pendingCleanups = cleanups.map(\.body)
        lock.unlock()

        if let signalName {
            FileHandle.standardError.write(Data(
                "\n[grantiva] received \(signalName) — releasing simulator and reaping child processes\n".utf8
            ))
        }

        for pgid in trackedGroups {
            ChildProcess.terminateGroup(pgid, gracePeriod: 5)
        }
        for cleanup in pendingCleanups { cleanup() }
        return true
    }
}
