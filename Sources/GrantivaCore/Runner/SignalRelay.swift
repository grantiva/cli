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
    private var noun = "simulator"
    /// Runner groups whose keep-alive hold is armed: their flows are over
    /// and the runner holds the device until it is released (L56).
    private var armedGroups: Set<pid_t> = []
    private var releasing = false

    private init() {}

    /// What the interrupt notice says is being released: `simulator` on iOS,
    /// `emulator` on Android. Set by `track(group:deviceNoun:)`, so every
    /// entry point that hands the relay a runner names its device (L37).
    public var deviceNoun: String {
        get { lock.withLock { noun } }
        set { lock.withLock { noun = newValue } }
    }

    /// The noun for `platform`'s device in the interrupt notice.
    public static func deviceNoun(for platform: Platform) -> String {
        platform == .android ? "emulator" : "simulator"
    }

    static func announcement(signalName: String, deviceNoun: String) -> String {
        "\n[grantiva] received \(signalName) — releasing \(deviceNoun) and reaping child processes\n"
    }

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

    /// Tracks a process group to be signalled when grantiva is interrupted;
    /// `deviceNoun` is what the interrupt notice says is being released.
    public func track(group pgid: pid_t, deviceNoun: String) {
        install()
        lock.lock()
        defer { lock.unlock() }
        noun = deviceNoun
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
        releasing = false
        armedGroups = []
    }

    // MARK: - Keep-alive hold (L56)

    /// Marks the keep-alive hold of the runner in `pgid` armed: every flow
    /// has finished and the runner has published its session, so the run's
    /// verdict is settled. `RunnerExecution`'s readiness watcher calls this.
    /// The first SIGINT or SIGTERM after that is a release, not an
    /// interrupt: it is forwarded to the runner, nothing else runs, and the
    /// run ends through its normal path with the status the runner returns
    /// (0 for passed flows, 1 for a failure). A second signal while the
    /// release is under way interrupts as before (exit 130).
    public func armHold(group pgid: pid_t) {
        lock.withLock { _ = armedGroups.insert(pgid) }
    }

    /// The runner in `pgid` has exited (or was never armed).
    public func disarmHold(group pgid: pid_t) {
        lock.withLock { _ = armedGroups.remove(pgid) }
    }

    /// True once a signal has released an armed hold.
    public var isReleasingHold: Bool {
        lock.withLock { releasing }
    }

    static func releaseAnnouncement(signalName: String) -> String {
        "\n[grantiva] received \(signalName) — releasing the keep-alive hold\n"
    }

    /// How a released runner is asked to end: SIGINT to its group, which the
    /// runner reads as "release the hold", escalating only if it does not
    /// exit in time. Off the signal queue, so a second signal is handled.
    public static let releaseGroup: @Sendable (pid_t) -> Void = { pgid in
        DispatchQueue.global(qos: .userInitiated).async { _ = ChildProcess.terminateGroup(pgid, gracePeriod: 15) }
    }

    /// What a signal does: release an armed hold (returns false: the
    /// process goes on), or run the interrupt sequence (returns true: the
    /// caller exits `128 + signal`).
    func respond(to signalNumber: Int32, release: @Sendable (pid_t) -> Void = SignalRelay.releaseGroup) -> Bool {
        let signalName = signalNumber == SIGINT ? "SIGINT" : "SIGTERM"
        lock.lock()
        let held = armedGroups.intersection(groups)
        if !terminating, !releasing, !held.isEmpty {
            releasing = true
            lock.unlock()
            FileHandle.standardError.write(Data(Self.releaseAnnouncement(signalName: signalName).utf8))
            held.sorted().forEach(release)
            return false
        }
        lock.unlock()
        terminate(announcing: signalName)
        return true
    }

    /// Test seam: delivers `signalNumber` as the handler would, without
    /// exiting. Returns whether the handler would have exited.
    public func simulateSignalForTesting(_ signalNumber: Int32, release: @Sendable (pid_t) -> Void = SignalRelay.releaseGroup) -> Bool {
        respond(to: signalNumber, release: release)
    }

    private func handle(_ signalNumber: Int32) {
        // A signal arriving while cleanups run exits at once. In practice only
        // a different signal gets here (SIGTERM after SIGINT): a repeat of the
        // same signal on its DispatchSourceSignal is held until this handler
        // returns. RunCommand's 30 s cap on waiting for the relay is the real
        // guarantee against a hung cleanup. A release of an armed hold
        // returns at once, so a second Ctrl-C during it interrupts.
        guard respond(to: signalNumber) else { return }
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
            FileHandle.standardError.write(Data(Self.announcement(signalName: signalName, deviceNoun: deviceNoun).utf8))
        }

        for pgid in trackedGroups {
            ChildProcess.terminateGroup(pgid, gracePeriod: 5)
        }
        for cleanup in pendingCleanups { cleanup() }
        return true
    }
}
