import Foundation
import GrantivaCore

/// Stops every runner session on a device that is being torn down (K15): a
/// `runner start` session (`.grantiva/session.json` in this directory, removed
/// when it names the device) and any `run --keep-alive` or `runner start`
/// session recorded in /tmp/grantiva-sessions for it.
struct DeviceRunnerSessions: Sendable {
    var loadSession: @Sendable () -> RunnerSessionInfo?
    var removeSession: @Sendable () -> Void
    var stopSessions: @Sendable (_ udid: String, _ runnerStart: RunnerSessionInfo?) async -> [RunnerSessionStopper.Outcome]
    /// Writes a stop marker for every runner grantiva recorded on the device
    /// (`RunnerStopMarker`); returns the pids marked. Inert unless set.
    var markStops: @Sendable (_ udid: String) -> [Int32] = { _ in [] }
    /// Removes markers whose runner and holder are gone. Inert unless set.
    var sweepStops: @Sendable () -> Void = {}

    static let live = DeviceRunnerSessions(
        loadSession: { try? RunnerSessionInfo.load() },
        removeSession: { RunnerSessionInfo.remove() },
        stopSessions: { udid, runnerStart in
            await RunnerSessionStopper.live().stopSessions(udid: udid, runnerStartSession: runnerStart)
        },
        markStops: { udid in markLive(udid: udid) },
        sweepStops: { RunnerStopMarker().sweep() }
    )

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
    func stop(udid: String) async -> [RunnerSessionStopper.Outcome] {
        _ = markStops(udid)
        let file = loadSession()
        if let file, file.udid.caseInsensitiveCompare(udid) == .orderedSame {
            removeSession()
        }
        let outcomes = await stopSessions(udid, file)
        sweepStops()
        return outcomes
    }

    static func render(_ outcome: RunnerSessionStopper.Outcome) -> String {
        "Stopped runner session (pid \(outcome.runnerPid)) for \(outcome.udid)."
    }
}
