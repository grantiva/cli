# Task 8 force teardown marker semantics fix

## Finding

The preserved phase-07 force result truthfully reports `runnerSessionStopped: true` and `reclaimed: true`, with the exact runner PID and project/shared session state absent. It also records removal of the owned runner device-home directory. Those fields describe Grantiva-owned runtime resource reclaim.

They do not mean that CoreSimulator shut down or deleted the simulator. The preserved `08-final-cleanup/simulators-before.stdout` still lists owned UDID `B718468C-771F-47BC-9CD8-A1143D540AC5` (`smoke4-ios`) as Booted. The old `IOS-DEVICE-RECREATE-REQUIRED.json`, `ownedDeviceDestroyed`, and `destroyed-recreate-required` labels were therefore false harness claims. Raw phase-07 and phase-08 evidence remains unchanged.

## Correction

- The helper retains the force JSON requirements for `runnerSessionStopped: true`, `reclaimed: true`, and typed process arrays.
- It retains exact runner PID absence and project/shared session absence checks.
- Only after those checks pass, it writes `IOS-FORCE-RECLAIMED.json` with `resourcesReclaimed: true`, `physicalDeviceDeleted: false`, and `finalCleanupRequired: true`.
- Acceptance and ownership records now describe force resource reclaim without claiming physical device deletion.
- The explicit opt-in is named `--allow-force-reclaim-owned-ios`.
- Durable and mirrored lifecycle documentation, the harness phase table, manifest criteria/assertion, and prior preparation reports now state that final cleanup must explicitly shut down/delete the owned simulator and prove the UDID absent.

The force acceptance criterion was not weakened. Physical simulator deletion was moved to the phase that actually performs and verifies it.

## Snapshot and verification

Pre-edit files are preserved under `.superpowers/sdd/2026-10-13-round4-fix-wave/task8-force-marker-fix-base/`. A focused diff is recorded in `task8-force-marker-fix.diff`.

Device-free static checks passed:

- force reclaim marker creation occurs after JSON, runner PID, and session cleanup assertions;
- no active helper or README retains the destruction/recreate marker claims;
- both manifest copies parse and require `IOS-FORCE-RECLAIMED.json` plus the renamed opt-in;
- both lifecycle helper copies, lifecycle README copies, and manifest copies are byte-identical;
- both helpers compile with `python3 -m py_compile`;
- `git diff --check` passes.

Final SHA-256 values:

- lifecycle helper: `eae219b25ae5ba58768c993b3302743099c69c422b904ec73e8222f273f8e731`
- lifecycle README: `51a48807b65b9e3d3a27f9b63443b0b9c54184fd0580b5c092cc5aadcfadb452`
- manifest: `ce6d11200f995360be228b61d7065f6dd19389b1bb575b1bb5206028c8bed42a`

No device or product command was run for this correction.
