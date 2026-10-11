# `runner stop` says "No active session found." and exits 0 while a `run --keep-alive` session is live

Severity: wrong-result
Component: cli
Platforms: both (confirmed on Android and iOS 26.0, N-01 in both slices)
Rows: N-01 (android), N-01 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix N-01 (plan N01; help runner_stop.txt "Stop the running runner session"): with a live `grantiva run --keep-alive`
session started from the same project directory, `runner stop` either
- stops it (runner exits, simulator lease released, ready file `interrupted`), or
- exits non-zero with an stderr message naming the live session (its pid and device) and saying to release it with
  Ctrl-C or `kill -INT <pid>`.
Today's `No active session found.` with exit 0 is called out as a fail in the matrix.

## Actual
Android (N-01/01.out, 01.err): keep-alive run pid 79723 alive before and after; its session files remain.
```
79723
rc=0
79723
79748-1791702867086124000.grantiva
79748.owner.json
No active session found.
```
iOS (N-01/runner-stop.err, after.out): same message, exit 0, keep-alive run pid 4163 still alive, session files in
`/tmp/grantiva-sessions/` remain:
```
No active session found.
 4163 /Users/kyle/.grantiva-qa/bin/grantiva run --no-build --simulator A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF --flow .maes
4267-1791703708426695000.grantiva
4267.owner.json
```

## Repro
iOS:
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k14
unset GRANTIVA_API_KEY
rm -rf /tmp/k14 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k14 && cd /tmp/k14/ios
UDID=$(grantiva simulator ensure --name "fix-k14 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
grantiva run --simulator "$UDID" --no-build --flow .maestro/01-browse.yaml --keep-alive --ready-file /tmp/k14/ready > /tmp/k14/ka.out 2> /tmp/k14/ka.err &
KA=$!; while [ ! -f /tmp/k14/ready ]; do sleep 1; done
grantiva runner stop; echo "runner stop exit $?"
ps -p $KA -o pid= && echo "keep-alive still running"; ls /tmp/grantiva-sessions/
kill -INT $KA; wait $KA
grantiva simulator teardown --udid "$UDID"; grantiva simulator delete --name "fix-k14 iPhone 17"
```
Android: same with the Android prelude (see K01), `cd android` and `--device "$SERIAL"` in place of `--simulator "$UDID"`.

## Evidence
- findings/evidence/cov-android/N-01/01.out, 01.err, commands.txt (keep-alive started with findings/evidence/cov-android/inputs/ka.sh)
- findings/evidence/cov-ios/N-01/runner-stop.out, runner-stop.err, after.out, commands.txt

## Suspected cause
- `Sources/GrantivaCLI/DriverCommand.swift:624-633` (`RunnerStopCommand.run`): only `dependencies.loadSession()` is
  consulted, which is `RunnerSessionInfo.load()` (:674) reading `.grantiva/session.json`
  (`Sources/GrantivaCore/Runner/RunnerSessionInfo.swift:14`). That file is written by `runner start`, not by
  `run --keep-alive`. On a miss it prints the note and returns, exit 0 (:630).
- `run --keep-alive` records its session through `KeepAliveSessionStore` (`/tmp/grantiva-sessions/<pid>.owner.json`
  plus the runner's `<pid>-<ts>.grantiva`; Sources/GrantivaCore/Runner/KeepAliveSessionStore.swift:69-110,
  `liveSessions()` :171, `locate(udid:)` :211), which `hierarchy` and the MCP server already read but `runner stop` does not.
- The keep-alive runner is a child of a foreground `grantiva run`; the clean release is SIGINT to that grantiva
  process (SignalRelay handles it), not a kill of the runner.

## Acceptance criteria
- With a keep-alive session from the current project directory live, `runner stop` either releases it (the
  `grantiva run` exits, ready file `interrupted`, `/tmp/grantiva-sessions/<pid>.*` removed, lease released) and prints
  `Stopped keep-alive session (pid <pid>, <device>)`, exit 0; or prints
  `A grantiva run --keep-alive session (pid <pid>, <device>) is live; release it with Ctrl-C or kill -INT <pid>.`
  on stderr and exits 1. Choose one and say it in `runner stop --help`.
- `runner stop --json` reports the same outcome as JSON (`status: "stopped"` or an error object), never `not_running`
  while a keep-alive session is live.
- With neither kind of session, today's behaviour stays (`No active session found.`, exit 0; `{"status":"not_running"}`).
- A keep-alive session started from another directory is not touched (or is only named, if the second option is chosen).
- GrantivaCLITests (RunnerLifecycleCommandTests): `RunnerStopCommand.run(dependencies:)` with no session.json and a
  stubbed live keep-alive session takes the chosen branch; with neither, it prints the existing note.

## Correction (round 2 coverage, 2026-10-12)

Withdrawn: the criterion that the ready file reads `interrupted` after `runner stop` releases a keep-alive session whose flows had already finished. README:83 and :419 (c65fc17) say the ready file is written once, at the terminal state, and keeps `passed`/`failed`. The slice (B2-K14, N-01) saw `runner stop` release the session fully (process gone, session files and lease removed, `Stopped keep-alive session (pid, udid)`, exit 0) with the ready file unchanged at `passed`. Corrected criterion: the ready file is left unchanged once terminal; `interrupted` applies only when the stop lands before the flows finish. The rest of K14 stands.
