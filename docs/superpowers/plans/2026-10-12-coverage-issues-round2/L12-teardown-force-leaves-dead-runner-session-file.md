# A keep-alive runner that died on its own leaves `/tmp/grantiva-sessions/<pid>-*.grantiva` behind, and `simulator teardown --udid --force` does not remove it

Severity: contract
Component: cli
Platforms: ios (seen on iOS; the session store and the `run` cleanup are shared, so Android `emulator teardown` is expected to have the same gap, not exercised)
Rows: N2-18 [ios] (part b; the row is counted once, under L11)
Regresses/extends: K87 (runner stop leaves the session file) and K79 (killed keep-alive runner survives), both fixed by CLI #194. Those fixes cover a runner that `runner stop` or teardown kills, not one that is already dead.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
README (`simulator teardown --udid --force`): it "removes the killed runner's keep-alive session files". README `hierarchy`
treats sessions whose runner has exited as dead. After a keep-alive runner dies, and at the latest after a force teardown
of its device, no `<pid>-*.grantiva` file of a dead runner for that device remains in `/tmp/grantiva-sessions`.

## Actual
After L11's SIGHUP killed runner 12109, grantiva exited (SIGINT, exit 1). `simulator teardown --udid <cov2-ios-1>
--force` reaped the orphaned WDA and diagnose (findings/evidence/cov2-ios/N2-18/cleanup-reclaim.out):
```
Killed webDriverAgent pid 12197 holding 7E846901-F93F-4220-A153-7043061033D7.
Killed diagnose pid 13163 holding 7E846901-F93F-4220-A153-7043061033D7.
```
It left the dead runner's file (findings/evidence/cov2-ios/N2-18/leftover-session.out):
```
-rw-r--r--@   1 kyle  wheel   285 Oct 11 12:35 12109-1791747326192132000.grantiva
  "sessionId": "12109-1791747326192132000",
  "pid": 12109,
  "port": 8987,
12109 not running
```
The slice removed it by hand. 1 run.

## Repro
Continue from L11's repro after `kill -HUP "$RUNNER"` (or kill the runner with `kill -9 "$RUNNER"` on any keep-alive run,
which also kills it without grantiva's help):
```
kill -INT "$NOHUP"; wait "$NOHUP"                       # grantiva exits; its owner sidecar is removed
ls /tmp/grantiva-sessions/"$RUNNER"-*.grantiva          # bug: still there
grantiva simulator teardown --udid "$UDID" --force --json | jq .sessionFilesRemoved   # bug: []
ls /tmp/grantiva-sessions/"$RUNNER"-*.grantiva          # bug: still there
grantiva simulator teardown --session-id fix-l11
```

## Evidence
- findings/evidence/cov2-ios/N2-18/cleanup-reclaim.out, leftover-session.out, nohup-hup.out, commands.txt
- docs/superpowers/plans/2026-10-11-coverage-issues/K87-runner-stop-leaves-session-file.md, K79-killed-keepalive-runner-survives.md

## Suspected cause
Two gaps that add up:
- `run`'s cleanup removes only the owner sidecar. `Sources/GrantivaCore/Runner/RunnerExecution.swift:90-100` records
  `<runnerPid>.owner.json` (udid → runner pid) and in its `defer` calls `sessions.removeOwner(runnerPid:)` only. A
  runner that exits normally removes its own `<pid>-*.grantiva`, but one killed by a signal never does. grantiva then
  drops the only record linking that file to a device.
- Teardown finds runner files only through sidecars or pids it just killed.
  `Sources/GrantivaCore/Simulator/SimulatorReaper.swift:222-224` passes `targets.filter { $0.kind == .runner }` (runners
  reaped in this teardown) to `KeepAliveSessionStore.removeSessions(udid:runnerPids:)`
  (`Sources/GrantivaCore/Runner/KeepAliveSessionStore.swift:200-218`), which also collects pids from `*.owner.json`
  with that udid. The runner file itself carries no udid (`RunnerExecution.swift:85-88`). With the sidecar gone and the
  runner already dead, nothing matches.
- `SimulatorReaperTests.testForceTeardownRemovesTheKilledRunnersSessionFiles`
  (`Tests/GrantivaCoreTests/SimulatorReaperTests.swift:246-262`) keeps the sidecar in place, so it does not cover this
  order.

Fix direction: in the `RunnerExecution` defer, when the runner is no longer alive, call
`sessions.removeSessionFiles(runnerPid: child.pid)` (`KeepAliveSessionStore.swift:180`), not only `removeOwner`. Also
let teardown (or any reader) drop `<pid>-*.grantiva` files whose pid is dead and that have no sidecar.

## Acceptance criteria
- After a keep-alive runner is killed by any signal while grantiva lives, grantiva's exit leaves no `<runnerPid>-*.grantiva`
  and no `<runnerPid>.owner.json`.
- `simulator teardown --udid <udid> --force` removes a dead runner's file even when its sidecar is gone, and lists it in
  `sessionFilesRemoved`. A runner file carries no udid, so a dead pid with no sidecar belongs to no live session and is
  safe to drop. It never removes a live runner's file, or a file whose sidecar names another device.
- Tests: GrantivaCoreTests/SimulatorReaperTests, a variant of the existing test with no owner sidecar, the runner file's
  pid dead, and `isProcessAlive` false: force teardown removes it. GrantivaCoreTests (RunnerExecution or
  KeepAliveSessionStoreTests): the keep-alive cleanup with a dead child pid removes both files.
