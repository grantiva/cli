# Task 8 candidate 2 final cleanup helper preparation

## Scope

Created `candidate2_cleanup.py` from the accepted candidate-1 cleanup and verification patterns. This is preparation only: the helper was not executed, and no process, device, session, forward, lease, AVD, simulator, or product state was changed.

The helper resolves `initial-state.json`, `candidate.json`, and `provision/ownership.json` beneath an explicit candidate-2 evidence root, with an optional distinct output path. Cleanup depends on frozen candidate and ownership identity, not on an overall smoke PASS or on force-teardown JSON claiming physical deletion.

## Target authentication and actions

- Requires the ownership schema/session, candidate runner home, exact owned iOS name/runtime/create command, and exact owned Android serial `emulator-5580`, AVD/name `smoke4-android`, runtime, create command, Java 21 home, and single provision-recorded PID.
- Inventories project and global sessions under only the candidate scratch/global registry. It accepts files containing the exact owned device IDs, scratch path, or a PID claimed by an authenticated project session. Unknown project sessions are recorded and refused.
- Parses the full process table but signals only recognized candidate-owned commands: the manifest-installed runner with an owned device argument; WDA/log/simctl commands carrying the owned iOS/scratch marker; the manifest CLI when its PID is claimed by an owned session; and the provision PID only when its emulator/AVD/port argv is exact. Marker-bearing processes outside those shapes are recorded and never signaled.
- Sends TERM only to exact runner/WDA/log/CLI processes, records every command/result, waits for each exact PID to disappear, and refuses session/lease unlink if targeted process cleanup remains live. It removes only authenticated owned project/global session files and the two exact device lease paths. Ordinary install and registry locks are untouched.
- Treats force teardown as resource reclamation only. The physical iOS simulator is independently found by exact UUID/name/runtime before targeted shutdown/delete.
- Before Android action, verifies the live serial's AVD identity and the provision PID's exact emulator `-avd smoke4-android -port 5580` command when present. It removes only forwards belonging to that serial, stops only that serial or exact PID, and deletes only the authenticated AVD using explicit Java 21. No global emulator, ADB, simulator, or process teardown exists.
- The provision PID is re-read from a fresh process inventory immediately before Android actions and re-evaluated with the full executable, PID, AVD, and port predicate. An absent PID may proceed to authenticated AVD deletion; a reused PID with any mismatched argv is recorded as a refusal and is never signaled. The fallback TERM repeats the fresh-row predicate at its call site.
- Every command writes argv, environment identity, times, exit/exception, stdout, and stderr before continuation. Failures accumulate in evidence; unknown ownership never broadens cleanup.

## Final verification

The helper requires the owned iOS UUID, Android serial/AVD/PID markers, forwards, project/global sessions, and exact device leases to be absent. It compares the two protected simulator records with the provision baseline while excluding only dynamic `dataPathSize` and `logPathSize`. It also requires the protected Pixel AVD to remain listed and its config SHA-256 to equal `provision/protected-android.json`.

The acceptance result explicitly records that force teardown physical deletion was not assumed, every targeted action/failure, protected metadata, and remaining owned resources. It exits nonzero if any authentication, action, refusal, or final verification failed.

## Static verification

- Python source compiled in memory and parsed as an AST.
- Required exact ownership constants, Java 21 binding, iOS shutdown/delete, Android serial stop, AVD delete, protected metadata normalization/hash, and action order were found.
- Static refusal checks confirmed marker-bearing unknown processes are separated from recognized exact targets.
- Focused synthetic predicate checks accepted the exact current emulator row, accepted absence without producing a signal target, and rejected reused-PID rows with a wrong executable, AVD, port, or truncated flag.
- No `killall`, `pkill`, simulator-all, ADB-server, wipe-data, or other broad teardown command is present.

The full candidate-1-cleanup-to-candidate-2-helper diff is `task8-candidate2-cleanup.diff`.
