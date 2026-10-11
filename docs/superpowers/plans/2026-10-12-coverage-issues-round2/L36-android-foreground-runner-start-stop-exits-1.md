# On Android a foreground `runner start` ended by `runner stop` exits 1 with "The runner exited with status 1", because the stop reaches the runner before its keep-alive hold is armed

Severity: contract
Component: cli (and runner)
Platforms: android (1 of 1 stop ending, load 11.6; the cause is an ordering race, so it should not depend on load). iOS passes (N2-15 [ios]: `Runner stopped (pid 1514); the session has ended.`, exit 0).
Rows: N2-15 [android] (also cited by L37 / M31 for its SIGINT line)
Regresses/extends: K88 (docs/superpowers/plans/2026-10-11-coverage-issues/K88-foreground-runner-start-exits.md) incomplete on Android; fixing PR #194.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
docs/dump-hierarchy.md:59: without `--detach`, `runner start` "holds the session until Ctrl-C (exit 130) or
`grantiva runner stop` from another shell; either way it stops the runner, removes `.grantiva/session.json` and the
session files, and releases the device." On iOS a `runner stop` ending prints `Runner stopped (pid N); the session has
ended.` and exits 0. Android behaves the same.

## Actual
Cleanup is correct (session.json and session files removed, device released), but the command fails.
findings/evidence/cov2-android/N2-15/fg-stop.err (last lines):
```
  ✓ Session created

  [1/1] session-flow (session-flow.yaml)
────────────────────────────────────────────────────────────

Received interrupt, cleaning up...
Error: The runner exited with status 1; the session has ended.
```
The runner was still inside the session flow (no step line printed yet) when `runner stop` sent SIGINT. In the SIGINT
ending (fg-int.err) the runner took the same abort path (`✓ launchApp (4.4s)`, then `Received interrupt, cleaning
up...`); the CLI exits 130 there, so it is masked. On iOS the stop came after the hold was armed
(findings/evidence/cov2-ios/N2-15/fg-stop.out):
```
  GrantivaAgent keep-alive: port=8987 session=1514-1791746879002652000
  /tmp/grantiva-sessions/1514-1791746879002652000.grantiva
    Press Ctrl-C to release.

  Releasing GrantivaAgent session...
Runner stopped (pid 1514); the session has ended.
```

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l36
unset GRANTIVA_API_KEY
rm -rf /tmp/l36 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l36 && cd /tmp/l36/android
sed -i '' 's/^emulator: .*/emulator: fix-l36/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-l36)
grantiva build install --device "$SERIAL" --no-launch
grantiva runner start --device "$SERIAL" > /tmp/l36/fg.out 2> /tmp/l36/fg.err &
FG=$!
until grantiva runner dump-hierarchy --format json > /dev/null 2>&1; do sleep 0.5; done
grantiva runner stop
wait $FG; echo "foreground exit $?"          # expected 0; observed 1
tail -3 /tmp/l36/fg.err
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l36
```
To show the race, add `sleep 20` before `grantiva runner stop`: once the runner log shows `Press Ctrl-C to release.`
the stop should end with exit 0 (prediction, not run).

## Evidence
- findings/evidence/cov2-android/N2-15/fg-stop.out, fg-stop.err, fg-int.err, commands.txt (`02` is the stop ending)
- findings/evidence/cov2-ios/N2-15/fg-stop.out (iOS, stop after the hold is armed)

## Suspected cause
- CLI: the foreground path reports readiness as soon as UIAutomator2 answers with a session
  (`Sources/GrantivaCLI/DriverCommand.swift:449-456`, `waitForUIAutomator2Port` at `:302-309`). On Android the session
  exists before the runner has run the session flow (`launchApp`, `waitForAnimationToEnd`; `:204-210`) and armed its
  keep-alive hold. On iOS the WDA port appears later, after the flow, so the race does not show.
- Runner: `pkg/cli/test.go:977-1009`. The first SIGINT/SIGTERM is treated as a release only if `releaseKeepAlive()`
  (`pkg/cli/keepalive.go:145-154`) finds the hold armed, which happens in `holdKeepAliveSession` (`keepalive.go:165`,
  after all flows). Before that the handler prints `Received <sig>, cleaning up...` and calls `os.Exit(1)` (`:1008`).
- CLI: `isOrderlyRunnerExit` (`DriverCommand.swift:544-546`) accepts 0, SIGINT, SIGTERM, SIGKILL and 128+INT/TERM only,
  so the guard at `:519-521` turns the runner's 1 into `The runner exited with status 1; the session has ended.` and
  exit 1, although the stop was requested.

## Acceptance criteria
- The repro exits 0 and prints `Runner stopped (pid N); the session has ended.` 5 of 5 on Android, including when
  `runner stop` lands within a second of `runner dump-hierarchy` first answering. iOS unchanged.
- A runner that dies on its own (crash, `kill -9` of the runner only) still ends the foreground command with exit 1 and
  the status, as today.
- Pick the fix and say which in the PR: (a) the runner treats SIGINT/SIGTERM during a `--keep-alive` run's flows as an
  orderly release and exits 0 (or 130) rather than 1; or (b) the CLI records that `runner stop` asked for the stop (for
  example `runner stop` removes `.grantiva/session.json` before signalling, and the foreground path treats a missing
  session file plus a non-zero status as orderly); or (c) `runner start` on Android reports ready only after the
  runner's keep-alive session file (`/tmp/grantiva-sessions/<pid>-….grantiva`, written at `keepalive.go:182`) exists,
  so the hold is armed before anyone can stop it. (c) also fixes `--detach` readiness (see L38-b).
- Tests: GrantivaCLITests/RunnerLifecycleCommandTests: the foreground path with a fake child that exits 1 after a
  `runner stop`-style request reports the orderly line and exit 0, and a fake child that exits 1 unprompted still fails.
  If (a): runner test in `pkg/cli` (next to the keep-alive tests): a signal delivered before `holdKeepAliveSession` arms
  the hold, with `--keep-alive` set, leads to exit status 0 (or 130), not 1.
