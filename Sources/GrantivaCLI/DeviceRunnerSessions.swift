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

    static let live = DeviceRunnerSessions(
        loadSession: { try? RunnerSessionInfo.load() },
        removeSession: { RunnerSessionInfo.remove() },
        stopSessions: { udid, runnerStart in
            await RunnerSessionStopper.live().stopSessions(udid: udid, runnerStartSession: runnerStart)
        },
        markStops: { udid in markLive(udid: udid) }
    )

    /// Marks the live runners recorded for `udid`, in the default runner home.
    static func markLive(udid: String, store: KeepAliveSessionStore = KeepAliveSessionStore(), marker: RunnerStopMarker = RunnerStopMarker()) -> [Int32] {
        store.runnerPids(udid: udid).filter { marker.mark(runnerPid: $0) }
    }

    /// Before any runner is signalled: the stop markers are written (a
    /// foreground `runner start` in any directory reads them and ends in
    /// order), and the session file in this directory is removed, as
    /// `runner stop` does (L36).
    func stop(udid: String) async -> [RunnerSessionStopper.Outcome] {
        _ = markStops(udid)
        let file = loadSession()
        if let file, file.udid.caseInsensitiveCompare(udid) == .orderedSame {
            removeSession()
        }
        return await stopSessions(udid, file)
    }

    static func render(_ outcome: RunnerSessionStopper.Outcome) -> String {
        "Stopped runner session (pid \(outcome.runnerPid)) for \(outcome.udid)."
    }
}
