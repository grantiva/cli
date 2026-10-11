# `runner start` without `--detach` returns after about 4 s and the runner dies with it, leaving a stale session behind

Severity: wrong-result
Component: cli
Platforms: ios (iOS-only per the cluster map; the foreground code path also serves Android and was not tested there)
Rows: IOS-139 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
help: runner_start.txt: "Start the runner with WDA and keep it alive for interactive use"; `--detach`: "Detach the
runner process from this terminal". Without `--detach` the command stays in the foreground and holds the session
until Ctrl-C, then cleans up as `runner stop` does. Matrix IOS-139.

## Actual
Three tries (background job, stdin held open by a pipe, `timeout -s INT 30`). foreground-timeout.out/.err
(exit 0 after 3.8 s, long before the 30 s INT):
```
Starting runner...
  Bundle ID: com.kylebrowning.Landmarks
  Simulator: cov-ios-1 (A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF)
Runner started
  WDA port: 8235
  PID:      67062
  Session:  .grantiva/session.json

Use 'grantiva runner dump-hierarchy' to inspect the view hierarchy.
Use 'grantiva runner stop' to stop the session.
exit=0
67062.owner.json
.grantiva/session.json
```
The runner (pid 67062) is already gone, yet `.grantiva/session.json` and `67062.owner.json` remain. A later
`runner stop` reports `Runner stopped (pid 67062)` for the dead pid (cleanup3.out). foreground.out shows the
background-job try: `alive_after_20s=no`, `runners=0`, files left.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k88
unset GRANTIVA_API_KEY
rm -rf /tmp/k88 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k88 && cd /tmp/k88/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k88 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
time timeout -s INT 30 grantiva runner start --bundle-id com.kylebrowning.Landmarks --simulator "$UDID"; echo "exit=$?"
P=$(jq -r .pid .grantiva/session.json); ps -p "$P" >/dev/null && echo alive || echo "runner $P gone"
ls /tmp/grantiva-sessions/ | grep "^$P"; ls .grantiva/session.json
grantiva runner stop                     # today: "Runner stopped (pid …)" for a dead pid
grantiva simulator teardown --session-id fix-k88
```
Today: returns in about 4 s with exit 0; runner gone; session.json and owner file left.

## Evidence
- findings/evidence/cov-ios/IOS-139/commands.txt, foreground.out/.err, foreground-stdin.out/.err,
  foreground-timeout.out/.err, stale-cleanup.out, cleanup2.out, cleanup3.out

## Suspected cause
- `Sources/GrantivaCLI/DriverCommand.swift:365-436` (`startForeground`): after WDA's port appears it records the
  session, prints `Runner started …` and returns the child pid; `run()` (:183-189) then hands the lease off and
  returns, so the process exits. Nothing waits on the child or relays Ctrl-C.
- The runner's stdout is a pipe read by this process (:366-375, `outputStream`); once grantiva exits, the next write
  by the runner hits a closed pipe (SIGPIPE), which explains the runner dying within seconds. Hypothesis, not traced.
- The session file and owner sidecar (`recordKeepAliveOwner`, :376) are written but nothing removes them when the
  runner dies.

## Acceptance criteria
- Re-running the repro: `runner start` stays in the foreground, `runner dump-hierarchy` from another shell answers
  while it runs, and at the 30 s SIGINT it stops the runner, removes `.grantiva/session.json`, the owner sidecar and
  the runner's session file, releases the lease, and exits 0 (or 130, documented).
- Ctrl-C in a terminal behaves the same; the runner's output keeps streaming to the terminal meanwhile.
- `--detach` is unchanged (returns after start; runner survives; `runner stop` cleans up).
- `runner stop` on a session whose pid is dead says so (`No running runner (pid N had exited); cleaned up its
  session.`) instead of `Runner stopped (pid N)`.
- GrantivaCLITests/RunnerLifecycleCommandTests: the foreground path with a fake child does not return until the child
  exits or a signal arrives, and cleans the session files on either.
