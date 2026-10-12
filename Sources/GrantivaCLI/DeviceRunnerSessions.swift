import Foundation
import GrantivaCore

/// Stops every runner session on a device that is being torn down (K15): a
/// `runner start` session (`.grantiva/session.json` in this directory, removed
/// when it names the device) and any `run --keep-alive` or `runner start`
/// session recorded in /tmp/grantiva-sessions for it.
struct DeviceRunnerSessions: Sendable {
    var loadSession: @Sendable () -> RunnerSessionInfo?
    var removeSession: @Sendable () -> Void
    /// Stops the recorded sessions; no wait outlasts `deadline`.
    var stopSessions: @Sendable (_ udid: String, _ runnerStart: RunnerSessionInfo?, _ deadline: Date) async -> [RunnerSessionStopper.Outcome]
    /// Writes a stop marker for every runner grantiva recorded on the device
    /// (`RunnerStopMarker`); returns the pids marked. Inert unless set.
    var markStops: @Sendable (_ udid: String) -> [Int32] = { _ in [] }
    /// Removes markers whose runner and holder are gone. Inert unless set.
    var sweepStops: @Sendable () -> Void = {}
    /// Waits (bounded, never past `deadline`) for a marked runner to exit;
    /// true once it has.
    var waitForExit: @Sendable (_ runnerPid: Int32, _ deadline: Date) async -> Bool = { _, _ in false }
    /// Ends the WebDriverAgent helpers still writing into a simulator's
    /// runner home once its runners are stopped (L63), by `deadline`. Inert
    /// unless set.
    var reapHelpers: @Sendable (_ udid: String, _ deadline: Date) async -> [ReapedProcess] = { _, _ in [] }
    /// The whole stop of one device (sessions, marked runners, helper reap)
    /// shares one deadline this far from its start (L63).
    var budget: TimeInterval = 30

    static let live = DeviceRunnerSessions(
        loadSession: { try? RunnerSessionInfo.load() },
        removeSession: { RunnerSessionInfo.remove() },
        stopSessions: { udid, runnerStart, deadline in
            await RunnerSessionStopper.live().stopSessions(udid: udid, runnerStartSession: runnerStart, deadline: deadline)
        },
        markStops: { udid in markLive(udid: udid) },
        sweepStops: { RunnerStopMarker().sweep() },
        waitForExit: { pid, deadline in await waitForExit(pid, timeout: RunnerSessionStopper.capped(10, by: deadline)) },
        reapHelpers: { udid, deadline in
            var reaper = RunnerHelperReaper.live()
            reaper.deadline = deadline
            return await reaper.reapDeviceHome(udid: udid)
        }
    )

    /// Up to `timeout` for `pid` to be gone.
    static func waitForExit(_ pid: Int32, timeout: TimeInterval = 10) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while KeepAliveSessionStore.processIsAlive(pid) {
            if Date() >= deadline { return false }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return true
    }

    /// Marks the foreground `runner start` runners recorded for `udid`
    /// beside their owner files in the shared session directory, whatever
    /// runner home this grantiva uses. A marker that cannot be written is
    /// one warning naming the pid; that runner is still stopped.
    static func markLive(
        udid: String,
        store: KeepAliveSessionStore = KeepAliveSessionStore(),
        marker: RunnerStopMarker? = nil,
        warn: (String) -> Void = { FileHandle.standardError.write(Data("Warning: \($0)\n".utf8)) }
    ) -> [Int32] {
        let marker = marker ?? store.stopMarkers
        var marked: [Int32] = []
        for owner in store.foregroundRunnerStarts(udid: udid) {
            do {
                if try marker.mark(runnerPid: owner.runnerPid, ownerPid: owner.grantivaPid) { marked.append(owner.runnerPid) }
            } catch {
                warn("Could not write the stop marker for runner pid \(owner.runnerPid) (\(error.localizedDescription)); it is stopped anyway, and the `grantiva runner start` holding it may report the stop as a failure.")
            }
        }
        return marked
    }

    /// Before any runner is signalled: the stop markers are written (a
    /// foreground `runner start` in any directory reads them and ends in
    /// order), and the session file in this directory is removed, as
    /// `runner stop` does (L36). Afterwards, markers nobody will read are
    /// swept.
    ///
    /// A marked foreground `runner start` also stops its runner itself when
    /// it reads the marker (L54), so the stop may find it already ending;
    /// once its runner has exited it counts as stopped by this teardown.
    /// On a simulator where a runner was stopped, the WebDriverAgent helpers
    /// left writing into its runner home are then ended and added to the
    /// last outcome's `reaped` (L63). All of it shares one deadline,
    /// `budget` from now.
    func stop(udid: String) async -> [RunnerSessionStopper.Outcome] {
        let deadline = Date().addingTimeInterval(budget)
        let marked = markStops(udid)
        let file = loadSession()
        if let file, file.udid.caseInsensitiveCompare(udid) == .orderedSame {
            removeSession()
        }
        var outcomes = await stopSessions(udid, file, deadline)
        for pid in marked where !outcomes.contains(where: { $0.runnerPid == pid }) {
            if await waitForExit(pid, deadline) { outcomes.append(.terminated(runnerPid: pid, udid: udid, killed: false)) }
        }
        // An interrupted WebDriverAgent run leaves `simctl diagnose` writing
        // into the device home, outside the runner's group and lineage
        // (L63): end it here, so the teardown that removes the home next
        // does not see it come back.
        if let last = outcomes.indices.last, !DeviceID.isAndroidSerial(udid) {
            let reaped = await reapHelpers(udid, deadline)
            if !reaped.isEmpty { outcomes[last] = outcomes[last].adding(reaped: reaped) }
        }
        sweepStops()
        return outcomes
    }

    static func render(_ outcome: RunnerSessionStopper.Outcome) -> String {
        "Stopped runner session (pid \(outcome.runnerPid)) for \(outcome.udid)."
    }
}
