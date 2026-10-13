# Task 8 candidate 2 packaged joint-forward review

Scope: completed evidence under `findings/evidence/round4-smoke-candidate2/03b-joint-forward`, the retained executed helper/controller, the approved candidate 2 helper review, and the original Task 8 runner/MCP cleanup criteria. This was a bounded read-only evidence review. No live, device, build, test, or cleanup command was run.

## Verdicts

- **Specification/evidence verdict: APPROVED for the packaged candidate 2 joint-forward phase.** All four required cases have the required outcomes, both unrelated controls survive every case, owned forwards/processes/sessions/PIDs are absent immediately and after one second, and final control cleanup restores the exact empty device baseline.
- **Quality/integration verdict: APPROVED.** The executed helper is byte-identical to the independently approved helper, its invocation completed with exit 0, and the retained raw records support its acceptance summary. No product or controller failure was found.

## Frozen candidate binding

- `invocation/start.json` binds the run to frozen candidate manifest SHA-256 `6c0a8bd9da5cff886baf9aceb58394e6ca1632b5b3b10f6aa1bb066aa50be14e`, the candidate 2 release checkout, QA binary and bundle, packaged runner, fresh runner home, owned project, session `fix4-8`, and an unset API environment. `result.json` repeats that binding and records exit 0.
- `helper/candidate.json` retains the successful approved identity validation: clean CLI source `22055ff981ae1ffd5aaae69190d7af180f239162`, CLI version `2.1.0`, binary and bundle identities, runner source `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, packaged and installed runner SHA-256 `9342b8a3d17b9063c399ecab6cd8681cefa3bce91a21de65473147b54ef9a37b`, and install stamp `1.1.28-grantiva.15+android-drivers-2`. `runner-native-version.stdout` independently reports `.15`, commit `ba9008f`, and `source-status.stdout` is empty.
- The retained `executed-helper.py`, approved SDD helper, and copied findings helper have the same SHA-256 `8b5d048186a6f38da049a6aa4bc51e50ce5c956aa2a9c70c69ce808e287a2161`. Thus this evidence used the reviewed implementation, including the complete spawned-plus-observed PID propagation.
- `avd-identity.stdout` identifies owned `smoke4-android` on `emulator-5580`; the identity record binds the same Android ownership manifest and AVD.

## Four cases and cleanup

- **Interrupt:** ready state binds runner PID `27771`, serial/UDID `emulator-5580`, and owned port `56695`; ready inventory contains the two controls plus the owned socket/forward. The command exits 130 and stderr contains the exact approved SIGINT cleanup notice. PID, exact runner process, project/global session, and owned forward absence are retained immediately and after one second.
- **Normal stop:** ready state similarly binds PID `27855` and owned port `56874`; the stop request succeeds and the foreground command exits 0. Both cleanup checkpoints retain the same complete absence checks.
- **Absent application:** CLI start for `com.grantiva.task8.absent` exits 1. The helper records spawned PID `27932` and observed exact installed-runner PID `27938`; both receive the approved PID/session checks, while exact installed-runner process and session inventories are empty at the immediate and one-second checkpoints.
- **Healthy stock:** the installed `.15` runner executes the attempt-local copied healthy fixture and exits 0. Spawned/observed PID `28023`, exact process, sessions, and owned forwards are absent at both checkpoints.

`helper/acceptance.json` accurately summarizes these four outcomes as 130, 0, 1, and 0. For the absent-app case, the loop's shared checkpoint PID filename retains only the last write, but this does not create an evidence gap: the executed reviewed helper's exit 0 proves every PID assertion ran successfully at both checkpoints, both PIDs also have distinct successful post-case checks, and the immediate/delayed exact-executable/device process inventories are independently empty.

## Forward controls and baseline

- `baseline.stdout` is empty for the owned device. `controls-before.stdout` contains exactly `emulator-5580 tcp:6790 tcp:16790` and dynamically allocated `emulator-5580 tcp:56555 tcp:16791`.
- Every immediate and delayed inventory for interrupt, normal stop, absent app, and healthy stock contains exactly those two rows. The foreground ready inventories additionally contain only their case-owned socket and TCP forward, which disappear at the cleanup checkpoints.
- `cleanup-before.stdout` still contains exactly both unrelated controls, proving no case removed them. The helper then removes those exact recorded controls; `cleanup-after.stdout` is empty and therefore equals the original device baseline. Cleanup was scoped to recorded controls and tracked owned ports.

This approval is limited to the completed packaged joint-forward phase. It does not grade the independently running MCP/iOS phase, the pending Android/lifecycle helper correction, final device cleanup, or overall Task 8 completion.
