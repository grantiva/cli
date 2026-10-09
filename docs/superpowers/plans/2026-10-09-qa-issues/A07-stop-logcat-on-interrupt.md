# Stop the `adb logcat` stream when a run is interrupted mid-flow

Severity: contract
Platforms: android
Found by: AND-F13 (matrix rows AND-075)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7+android-drivers-2, emulator-5554 (Pixel_8_API_35, API 35)

## Expected
No `logcat` process outlives the run, on success, failure or Ctrl-C. Source: help: run (`--logs`); CHANGELOG Unreleased
(keep-alive Ctrl-C "cleans up orphans"); matrix AND-075.

## Actual
`kill -INT` during the flow: exit 130, and the stream survives, reparented to launchd:
```
during: 47930 /Users/kyle/Library/Android/sdk/platform-tools/adb -s emulator-5554 logcat --uid=10210 -v time
ctrl-c exit 130
  PID  PPID ELAPSED COMMAND
47930     1   00:22 /Users/kyle/Library/Android/sdk/platform-tools/adb -s emulator-5554 logcat --uid=10210 -v time
```
Triage re-run: pid 90396, PPID 1, still alive 5 s after exit. Success, failure, and Ctrl-C of a `--keep-alive` run after
its flows finished all leave nothing.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=qa-android QA=/Users/kyle/Developer/grantiva-cli/.worktrees/qa-android
cd /Users/kyle/Developer/landmarks-demo/android
grantiva run --no-build --flow $QA/findings/evidence/flows/qa-longwait.yaml --device emulator-5554 --logs & pid=$!
sleep 12; kill -INT $pid; wait $pid; echo "exit $?"; sleep 5
ps -axo pid,ppid,command | grep "[a]db.*logcat"     # orphan; kill it by hand afterwards
```

## Evidence
- findings/evidence/AND-075/log.txt; findings/evidence/AND-060/log.txt (same SIGINT run in triage)

## Suspected cause
Sources/GrantivaCLI/RunCommand.swift:205-206 stops the streamer only in a `defer`. On SIGINT,
Sources/GrantivaCore/Runner/SignalRelay.swift:113-133 reaps the runner's group, runs registered cleanups and calls
`exit(128+sig)`, so the `defer` never runs. The logcat `Process` started in Sources/GrantivaCore/Runner/LogStreamer.swift:
101-149 is neither in a tracked process group nor registered with `SignalRelay.onTermination`. The iOS `log stream`
child takes the same path and is probably affected too (not tested).

## Acceptance criteria
- Re-running the repro: no `adb ... logcat` process remains after exit 130.
- LogStreamer registers its own `SignalRelay.onTermination` cleanup on `start` (removed on `stop`), or its process is
  tracked as a group.
- GrantivaCoreTests/LogStreamerTests (or SignalRelayTests): starting a streamer on a long-running dummy executable and
  firing the termination cleanups leaves the child dead.
