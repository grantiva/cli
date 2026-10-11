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

    static let live = DeviceRunnerSessions(
        loadSession: { try? RunnerSessionInfo.load() },
        removeSession: { RunnerSessionInfo.remove() },
        stopSessions: { udid, runnerStart in
            await RunnerSessionStopper.live().stopSessions(udid: udid, runnerStartSession: runnerStart)
        }
    )

    /// The session file is removed before any runner is signalled, as
    /// `runner stop` does: a foreground `runner start` holding it reads the
    /// missing file as a requested stop and ends in order (L36).
    func stop(udid: String) async -> [RunnerSessionStopper.Outcome] {
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
