import Foundation

/// Shape validation for simulator UDIDs.
///
/// The case that motivates this is an unset shell variable:
///
///     grantiva simulator teardown --udid "$UDID" --force
///
/// With `UDID` unset that reaches the CLI as `--udid ""`. An empty string is
/// non-nil, so it satisfied every "did you pass a target?" check, matched no
/// process, released no lease, and exited 0 — the script concluded it had
/// reclaimed the device and the real failure surfaced much later.
public enum SimulatorUDID {
    /// True when `value` has the 8-4-4-4-12 hex shape simctl issues.
    ///
    /// Matching is case-insensitive even though simctl prints uppercase: the
    /// process-inspection path already lowercases before comparing, so a
    /// lowercased UDID works, and rejecting it would break scripts that pass
    /// one through `tr`. This checks shape only — it deliberately does not
    /// require the device to still exist, because reclaiming a *deleted*
    /// simulator (killing the processes it stranded, breaking its lease,
    /// clearing its capacity record) is precisely what `--force` is for.
    public static func isWellFormed(_ value: String) -> Bool {
        let groups = value.split(separator: "-", omittingEmptySubsequences: false)
        guard groups.count == 5 else { return false }
        let expected = [8, 4, 4, 4, 12]
        for (group, length) in zip(groups, expected) {
            guard group.count == length,
                  group.allSatisfy({ $0.isHexDigit && $0.isASCII })
            else { return false }
        }
        return true
    }

    /// Returns `value` trimmed, or throws an error naming what was wrong.
    public static func validate(_ value: String, flag: String = "--udid") throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GrantivaError.invalidArgument(
                "\(flag) is empty. Pass a simulator UDID — if this came from a shell variable, it was unset."
            )
        }
        guard isWellFormed(trimmed) else {
            throw GrantivaError.invalidArgument(
                "\(flag) \(trimmed) is not a simulator UDID. Expected the 8-4-4-4-12 hex form simctl prints, "
                    + "for example 921A0945-7157-4533-BA1F-21E8132D3E40."
            )
        }
        return trimmed
    }

    /// Returns `value` trimmed, or throws when it is blank.
    ///
    /// Session identifiers are caller-chosen, so only emptiness is checkable —
    /// but that is the failure mode that matters, for the same unset-variable
    /// reason.
    public static func validateSessionID(_ value: String, flag: String = "--session-id") throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GrantivaError.invalidArgument(
                "\(flag) is empty. Pass a session identifier — if this came from a shell variable, it was unset."
            )
        }
        return trimmed
    }
}
