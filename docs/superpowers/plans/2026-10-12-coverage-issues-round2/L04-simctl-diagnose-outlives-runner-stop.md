# On iOS a `simctl diagnose` started while the runner shuts down outlives `runner stop` and keeps holding the simulator

Severity: contract
Component: cli (runner stop; the process is started below the runner, see Suspected cause)
Platforms: ios (iOS-only: WebDriverAgent's xcodebuild session; Android `runner stop` left nothing behind)
Rows: round2-X-d2 (with round2-X-d-detach and round2-I3-teardown)
Binary: grantiva 2.1.0 (main 5eab55d), grantiva-runner 1.1.28-grantiva.10

## Expected
`grantiva runner stop` documents that the runner gets SIGINT, then SIGTERM and SIGKILL, and that its session files and
device lease are removed. When it returns, no process that the runner or its WebDriverAgent session started for that
simulator is still alive: no grantiva-runner, no `xcodebuild test-without-building`, no `simctl diagnose`. A following
`grantiva simulator teardown` without `--force` finds nothing holding the device.

## Actual
1 of 1 iOS `runner start --detach` / `runner stop` cycle. `runner stop` reported a clean stop
(round2-X-d-detach/ios.txt):
```
{
  "killed" : false,
  "pid" : 61488,
  "platform" : "ios",
  "runnerPid" : 61488,
  "status" : "stopped",
  "udid" : "F7DCF106-9DDF-491B-BB72-68D90CFFE1AB"
}
```
The runner's own log (grantiva-runner-1791726228.log) ends `Received interrupt, cleaning up...`. The next teardown of
that simulator still found a holder (round2-I3-teardown/teardown.txt:3-4):
```
$ $GRANTIVA simulator teardown --udid F7DCF106-9DDF-491B-BB72-68D90CFFE1AB --force
Killed diagnose pid 61570 holding F7DCF106-9DDF-491B-BB72-68D90CFFE1AB.
```
Pid 61570 falls between the iOS runner (61488) and the Android runner started right after (61616), so it was spawned
around the iOS `runner stop`. Its command line, parent and process group were not captured; `kind = .diagnose` means the
reaper matched "simctl" + "diagnose" + the UDID in its command line (SimulatorReaper.swift:119-123). The smoke notes
put the gap at ~9 minutes; the evidence file times (ios.txt 06:43, teardown.txt 06:44) suggest the teardown came
within a few minutes. Either way it outlived `runner stop`, and the CLI's own comments describe `simctl diagnose` as a
600-second process (SignalRelay.swift:21).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l04
unset GRANTIVA_API_KEY
rm -rf /tmp/l04 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l04 && cd /tmp/l04/ios
UDID=$(grantiva simulator ensure --name fix-l04 --device-type "iPhone 17" --runtime 26.0 | tail -1)
grantiva build install --simulator "$UDID"
for i in 1 2 3; do
  grantiva runner start --detach --json --simulator "$UDID" --bundle-id com.kylebrowning.Landmarks
  grantiva runner stop --json
  for t in 0 5 30 60; do sleep $t; echo "+${t}s"; ps -axo pid=,ppid=,pgid=,lstart=,command= | grep -i "$UDID" | grep -v grep; done
done
grantiva simulator teardown --udid "$UDID"            # without --force: must not be blocked or leave a diagnose behind
ps -axo pid=,command= | grep -i "$UDID" | grep -v grep # expect nothing
grantiva simulator teardown --session-id fix-l04
```
Record the `ppid`/`pgid` of any `simctl diagnose` line: that settles who starts it (see below).

## Evidence
- findings/evidence/round2-smoke/round2-X-d-detach/ios.txt (start pid 61488, stop JSON `killed: false`), android.txt (pid 61616), commands.txt
- findings/evidence/round2-smoke/round2-I3-teardown/teardown.txt:3-4 (`Killed diagnose pid 61570 ...`), teardown-2.txt
- Runner log of the detached session: /var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-runner-1791726228.log (host temp, not copied into evidence)

## Suspected cause
Who spawns it: neither the CLI nor the runner invokes `simctl diagnose`. `git grep -i diagnose` at 5eab55d finds only
comments and the reaper's matcher; the runner tree (56224e1) has no `simctl diagnose` call. The most likely parent is
WebDriverAgent's `xcodebuild test-without-building`, which can collect simulator diagnostics when its test session is
interrupted (inference, not captured).
- Runner (56224e1): `pkg/driver/wda/runner.go:390-396` starts that xcodebuild through `r.command` (`:811-816`,
  `exec.CommandContext`, no own process group), so it shares the runner's group and receives the CLI's SIGINT
  directly; `Stop()` (`:515-537`) then SIGKILLs it and waits only for xcodebuild itself, not for anything it started.
- CLI (5eab55d): `Sources/GrantivaCLI/DriverCommand.swift:748-782` (`RunnerStopCommand.perform`) calls
  `terminateGroup(session.pid)` (`:765`, live grace 5 s at `:866`; `ChildProcess.swift:217-232`), which stops waiting as
  soon as `kill(-pgid, 0)` fails. `killed: false` means group 61488 emptied, so pid 61570 was not (or no longer) in that
  group: it was started in another group/session or by a non-descendant, and nothing in `runner stop` looks for it by
  UDID. Only `simulator teardown --force` does (`SimulatorReaper.forceTeardown`, second pass for late diagnose
  processes at `SimulatorReaper.swift:199-208`); the non-force teardown path (`SimulatorCommand.swift:140-158`) does not.
- The worktree's Sources (coverage-campaign, d57997f) predates 5eab55d; read the files at 5eab55d.

## Acceptance criteria
- After `runner stop` returns on iOS, `ps -axo command= | grep -i <UDID>` shows no grantiva-runner, xcodebuild or
  `simctl diagnose` process, immediately and 60 s later, in 3 of 3 start/stop cycles. `runner stop` does this by
  reaping, after the group stop, every process whose command line names the session's UDID and matches the reaper's
  runner/WebDriverAgent/diagnose kinds (one late pass like forceTeardown's), or by preventing the diagnose being started.
- The stop result reports what it reaped beyond the runner (e.g. `"reaped": [{"kind": "diagnose", "pid": ...}]` in
  `--json`, one line in text), so a leftover is visible rather than silent.
- `grantiva simulator teardown --udid <UDID>` / `--session-id` without `--force` is not blocked by a leftover diagnose:
  it reaps diagnose processes for the device it is deleting (or `runner stop` guarantees none exist), and deletes the
  simulator.
- The runner's WebDriverAgent `Stop()` ends xcodebuild in a way that does not leave a diagnostics process behind, or
  waits for/kills what it started for that UDID before returning.
- Tests: GrantivaCLITests — `RunnerStopCommand.perform` with a fake process snapshot that still lists
  `xcrun simctl diagnose ... <UDID>` after `terminateGroup` returns `.interrupted` reaps that pid and reports it;
  GrantivaCoreTests — `SimulatorReaper.processes(owning:)` matches the exact diagnose command line captured by the repro.
  Runner (pkg/driver/wda, runner_lifecycle_test.go): `Stop()` with a fake command that spawns a child leaves no child alive.
