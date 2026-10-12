# iOS `simulator teardown` of a foreground `runner start` leaves xcodebuild's `simctl diagnose` running; it re-creates the device home the teardown removed

Severity: wrong-result (teardown reports a leftover and tells the user to use `--force`; the removed device home comes back, 9 MB)
Component: cli
Platforms: ios
Rows: round3-smoke TD-ios (re-smoke on runner .13 / CLI 2f4d8381, 3 of 3); evidence findings/evidence/round3-resmoke/TD-ios/
Regresses/extends: L04 (RunnerHelperReaper reaps `simctl diagnose` after `runner stop`), L54 (teardown reaches a runner still in its flows), K106 (teardown removes the device home)
Binary: grantiva 2.1.0 @ main 2f4d8381, grantiva-runner 1.1.28-grantiva.13

## Expected
Tearing down a simulator whose foreground `runner start` is mid-WDA-run ends the runner and every helper xcodebuild spawned
for it (including `simctl diagnose`, which xcodebuild starts when a test run is cut off), reports `leftoverProcesses: []`
and `killed: true`, prints no `--force` warning, and the device home under `<runner home>/versions/<stamp>/devices/<udid>`
stays removed.

## Actual
The runner is stopped (exit 0, "Runner stopped by teardown", sessions dir empty) but every teardown lists a leftover
`simctl diagnose` (`killed: false`) with a Warning recommending `--force`. In one of three runs the diagnose output re-created
the removed device home (9.1 MB under `devices/<udid>/cache/wda-builds/…`) after the teardown finished.

## Reproduce
`runner start --simulator <udid>` in the foreground in dir A; from dir B, `simulator teardown --udid <udid> --json` within
a few seconds; inspect `leftoverProcesses`, `ps` for `simctl diagnose`, and the device home a few seconds later.

## Fix direction
Apply the L04 reaper on the teardown path: after signalling the runner's process group, wait for and reap `simctl diagnose`
(and any xcodebuild child) whose arguments name the UDID or the device home, with the same bounded wait `runner stop` uses;
remove the device home after the reap, not before; a helper that outlives the bound is killed, not reported as a `--force`
suggestion. Test with a fake `simctl diagnose` child writing into the device home.

## Acceptance criteria
- 5 of 5 teardowns of a mid-run foreground start: `leftoverProcesses: []`, `killed: true`, no Warning, device home absent
  10 s later.
- `runner stop` behaviour unchanged (its reaper tests still pass).
