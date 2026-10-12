# `runner stop` during a `run --keep-alive` run's flows prints "No active session found." and the run goes on to its hold, because the session is only discoverable once the hold is armed

Severity: contract
Component: cli
Platforms: ios (1 of 1, load 5.6), android (1 of 1, load 3.7). An ordering gap, not load. Ctrl-C (`kill -INT` of the run) during the flows is correct on both (exit 130).
Rows: round3-smoke KA-stop-during (findings/evidence/round3-smoke/I-keepalive/during-*.txt, A-keepalive/during-*.txt)
Regresses/extends: L36 ruling (a stop during a keep-alive run's flows ends it interrupted, exit 130). Same unpublished-session window as L54 (teardown) and L52 (`hierarchy` says "no session" instead of `starting`).
Binary: grantiva 2.1.0 (main dc965716), grantiva-runner 1.1.28-grantiva.12

## Expected
`runner stop --help` (Sources/GrantivaCLI/DriverCommand.swift:945-952) and docs/dump-hierarchy.md:59: without a
`runner start` session, `runner stop` "releases a `grantiva run --keep-alive` session started from this directory …
the way Ctrl-C would, by sending that grantiva process SIGINT". L36 ruling (ledger, Task 2 review): a stop during a
keep-alive run's flows ends it interrupted, exit 130, ready file `interrupted`. So `runner stop` from the run's
project directory at any point after the run spawned its runner prints `Stopped keep-alive session (pid N, <device>)`,
exits 0, and the run exits 130 at once, as the Ctrl-C row does.

## Actual
Flow `.maestro/coverage/18-long-wait.yaml` (a 45 s `extendedWaitUntil`), `runner stop` from the run's project dir 8 s
after the `launchApp` line:
- I-keepalive/during-stop.txt (18:17:34) and A-keepalive/during-stop.txt (18:37:27):
  ```
  No active session found.
  # exit 0
  ```
- At that moment the run's owner sidecar existed (I-keepalive/during-during.txt: `13923.owner.json` only; Android
  `26531.owner.json` only), recording `grantivaPid` and that `projectDirectory`; the runner's `<pid>-*.grantiva` did
  not exist yet.
- The flow ran on to its failure, the run printed `Press Ctrl-C to release.` and held (I-keepalive/during-run.txt).
  A second `runner stop` during the hold released it (`Stopped keep-alive session (pid 13816, DACD2CF4-…)`,
  during-stop2.txt) and the run exited 130.
- Ctrl-C during the flow (`kill -INT` of the run, I-keepalive/sigint-during-run.txt, A-keepalive/sigint-during-run.txt):
  `[grantiva] received SIGINT — releasing simulator and reaping child processes`, exit 130, sessions dir empty: right.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l55
unset GRANTIVA_API_KEY
rm -rf /tmp/l55 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l55 && cd /tmp/l55/ios
UDID=$(grantiva simulator ensure --name fix-l55 --device-type "iPhone 17" --runtime "iOS 26.0")
grantiva build install --simulator "$UDID" --no-launch
grantiva run --simulator "$UDID" --no-build --flow .maestro/coverage/18-long-wait.yaml --keep-alive \
  --ready-file /tmp/l55/ready.json > /tmp/l55/run.txt 2>&1 &
RUN=$!
until grep -q launchApp /tmp/l55/run.txt; do sleep 0.5; done; sleep 8
ls /tmp/grantiva-sessions                 # <pid>.owner.json only
grantiva runner stop; echo "stop exit $?" # expected: Stopped keep-alive session (pid $RUN, $UDID); observed: No active session found.
wait $RUN; echo "run exit $?"            # expected 130 within ~10 s; observed: holds until a second stop
cat /tmp/l55/ready.json                  # expected status interrupted
grantiva simulator teardown --udid "$UDID"
# Android: cd /tmp/l55/android, SERIAL=$(grantiva emulator ensure --name fix-l55), --device "$SERIAL".
```

## Evidence
- findings/evidence/round3-smoke/I-keepalive/commands.txt, during-run.txt, during-during.txt, during-stop.txt,
  during-stop2.txt, during-after.txt, sigint-during-*.txt
- findings/evidence/round3-smoke/A-keepalive/ (same names)
- findings/evidence/round3-smoke/keepalive.sh, keepalive-sig.sh (driver scripts)

## Suspected cause
CLI, main dc965716. Confirmed from the code.
- With no `.grantiva/session.json`, `runner stop` looks for keep-alive sessions started here
  (`RunnerStopCommand.perform`, DriverCommand.swift:1003-1016) through `dependencies.keepAliveSessions`, which is
  `KeepAliveSessionStore().liveSessions(includingOrphans: true)` (:1163).
- `liveSessions` (Sources/GrantivaCore/Runner/KeepAliveSessionStore.swift:264-303) enumerates only the runner's own
  `<pid>-<ts>.grantiva` files (:276-280). The runner writes that file in `holdKeepAliveSession` (runner
  `pkg/cli/keepalive.go:181-182`), after every flow has finished. During the flows only the CLI's owner sidecar exists
  (written at spawn, `recordOwner`, :149-183), so the list is empty and the command returns `.notRunning`
  (DriverCommand.swift:1008, rendered at :1061).
- The stop itself would work once found: `RunnerSessionStopper.stop` (RunnerSessionStopper.swift:111-133) interrupts
  the holding grantiva process, which is exactly the Ctrl-C path that already exits 130 here.
- Same window as L54 (teardown uses the same `liveSessions`) and L52 (`hierarchy` / `dump-hierarchy` read it too and
  say "no session" rather than `starting`); `KeepAliveSessionStore.startingSessions` (:309-319) already lists these
  owners for MCP (L38-a).

## Acceptance criteria
- The repro's first `runner stop` prints `Stopped keep-alive session (pid N, <device>)` and exits 0; the run exits 130
  within 10 s with the SIGINT narration; the ready file says `interrupted`; `/tmp/grantiva-sessions` is empty
  afterwards. 5 of 5 on each platform, with the stop sent 1 s, 8 s and 30 s into the flow.
- `runner stop --json` during the flows returns the `stopped` document with `port: null` when the runner has not
  published one (L13 keys unchanged).
- A run started from another directory is still left alone; a stop with nothing running still prints
  `No active session found.` and exits 0.
- One lookup serves `runner stop`, both teardowns (L54) and `hierarchy` (L52): a session is a live owner sidecar
  whose holder is alive, with or without the runner's published file; the published file adds port and session ID.
- Tests: GrantivaCLITests/RunnerLifecycleCommandTests (next to the existing `runner stop` keep-alive tests): with an
  owner sidecar for this directory and no `.grantiva` file, `perform` stops it (fake stopper called with the holder
  pid) instead of returning `.notRunning`; GrantivaCoreTests/KeepAliveSessionStoreTests: the shared lookup returns
  owner-only sessions and skips owners whose holder is dead (orphans still included for `runner stop`/teardown).
