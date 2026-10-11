# `runner stop` sometimes leaves the runner's own `<pid>-<ts>.grantiva` session file in /tmp/grantiva-sessions

Severity: wrong-result
Component: cli
Platforms: ios (seen on iOS; `runner stop` is shared with Android, not tested there)
Rows: IOS-087 (ios; 1 of 5 start/stop cycles, observed after the N-05 MCP cycles)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
help: runner_stop.txt and matrix IOS-087: `runner stop` kills the runner, removes the owner sidecar and session files,
and releases the lease. After it, nothing in `/tmp/grantiva-sessions/` refers to the stopped runner.

## Actual
The directly observed cycle was clean (before.out → after.out: both session files and `.grantiva/session.json`
gone, lease released). But after the 5 `runner start --detach` / `runner stop` cycles of N-05 (mcp-5x-b, each stop
exit 0 in 0.2 s) one runner file remained (stale-session-file.txt):
```
-rw-r--r--@   1 kyle  wheel   210 Oct 11 01:33 15919-1791707634281100000.grantiva
{
  "version": "1.1.28-grantiva.9",
  "sessionId": "15919-1791707634281100000",
  "createdAt": "2026-10-11T01:33:54.281106-07:00",
  "pid": 15919,
  "port": 8235,
  "outputDir": "reports/2026-10-11_01-33-48"
}
  PID COMMAND
```
pid 15919 was dead and its `15919.owner.json` was gone. Readers ignore a dead pid's file, so the effect is clutter
and a misleading directory listing rather than a false live session; it is nondeterministic (1 of 5).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k87
unset GRANTIVA_API_KEY
rm -rf /tmp/k87 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k87 && cd /tmp/k87/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k87 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
for i in 1 2 3 4 5 6 7 8 9 10; do
  grantiva runner start --bundle-id com.kylebrowning.Landmarks --simulator "$UDID" --detach >/dev/null
  sleep 5; grantiva runner dump-hierarchy --format xml >/dev/null
  P=$(jq -r .pid .grantiva/session.json); grantiva runner stop >/dev/null; sleep 2
  ls /tmp/grantiva-sessions/ | grep "^$P-" && echo "cycle $i: stale file for $P"
done
grantiva simulator teardown --session-id fix-k87
```
Expected today: a stale file in some cycles (1 of 5 in the slice). Other sessions on the host also write to
`/tmp/grantiva-sessions/`; filter by the stopped pid as above.

## Evidence
- findings/evidence/cov-ios/IOS-087/commands.txt, before.out, after.out, stale-session-file.txt
- findings/evidence/cov-ios/N-05/mcp-5x-b/transcript.txt (the 5 start/stop cycles, `runner stop` lines 46, 93, 140,
  186, 232)

## Suspected cause
Not confirmed (the stopped runner's exit was not traced).
- `Sources/GrantivaCLI/DriverCommand.swift:624-658` (`RunnerStopCommand.run`): it terminates the runner's group with
  `ChildProcess.terminateGroup(pid, gracePeriod: 1)` (:677), then removes `.grantiva/session.json` and the owner
  sidecar (:648-649). It never removes the runner's own `<pid>-<ts>.grantiva`; that is left to the runner's clean
  exit.
- `Sources/GrantivaCore/Runner/ChildProcess.swift:171-186`: SIGINT, wait up to 1 s, SIGTERM, wait up to 1 s, SIGKILL.
  The runner's handler (`pkg/cli/test.go:942-972` in grantiva-runner) consumes only the first signal and releases the
  keep-alive session; if that teardown takes longer than about 2 s, the SIGKILL lands before the runner deletes its
  file.
- `KeepAliveSessionStore.removeSessions(udid:runnerPids:)` (KeepAliveSessionStore.swift:148-166) already removes a
  dead runner's files and is what `teardown --force` uses.

## Acceptance criteria
- Re-running the repro: no cycle leaves a `<pid>-*.grantiva` for the stopped pid (10 of 10).
- `runner stop` removes the stopped runner's session file itself once the process is gone (for example via
  `KeepAliveSessionStore().removeSessions(udid:runnerPids:[pid])`), and gives the runner enough time to release
  WDA before escalating, or reports when it had to SIGKILL.
- GrantivaCLITests/RunnerLifecycleCommandTests: `RunnerStopCommand.run(dependencies:)` with a fake runner that ignores
  SIGINT calls the session-file cleanup for that pid.
