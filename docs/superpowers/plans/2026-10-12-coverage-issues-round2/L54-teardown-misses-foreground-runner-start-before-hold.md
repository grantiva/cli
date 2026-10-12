# `simulator teardown` / `emulator teardown` do not stop a foreground `runner start` whose runner has not armed its keep-alive hold: the runner keeps running on the deleted device until someone runs `runner stop`

Severity: wrong-result
Component: cli
Platforms: ios (1 of 1, load 7.5), android (1 of 1, load 3.1). The cause is an ordering gap, not load.
Rows: round3-smoke TD-ios (findings/evidence/round3-smoke/teardown/ios-*.txt), round3-smoke TD-android (findings/evidence/round3-smoke/teardown/android-*.txt)
Regresses/extends: L36 (teardown stop marker, CLI #201) and K15 (teardown stops runner sessions). Same unpublished-session window as L55 and L52.
Binary: grantiva 2.1.0 (main dc965716), grantiva-runner 1.1.28-grantiva.12

## Expected
`simulator teardown --help` (Sources/GrantivaCLI/SimulatorCommand.swift:103): "A runner session on a torn-down
simulator (`grantiva runner start` or `grantiva run --keep-alive`) is stopped first and its session files are removed;
--json reports it as runnerSessionStopped." `emulator teardown --help` (EmulatorCommand.swift:120) says the same.
Round-3 ruling (ledger, Task 5 fix rounds 2-3): teardown writes `<pid>.stop.json` beside the owner file in
`/tmp/grantiva-sessions`, and a foreground `runner start` torn down from any directory exits 0 with
`Runner stopped by teardown (pid N); the session has ended.` So: run from an empty directory, the teardown stops the
runner, reports `runnerSessionStopped: true`, the start exits 0 with that line within seconds, and
`/tmp/grantiva-sessions` is empty afterwards.

## Actual
Both platforms, teardown from an empty directory 3-7 s after the start's `.grantiva/session.json` said `ready`:
- iOS (teardown/ios-teardown.txt): `deleted: true`, `runnerSessionStopped: false`, three `leftoverProcesses` with
  `killed: false` (the `grantiva runner start`, the runner, WebDriverAgent's xcodebuild), each also a stderr
  `Warning: … is still held by … which this teardown did not start`.
- Android (teardown/android-teardown.txt): `killed: true`, `runnerSessionStopped: false`, `sessionFilesRemoved: []`.
- The marker was written: teardown/ios-sessions-dir-poll.txt
  ```
  18:47:33 30577.owner.json
  18:47:33 30577.stop.json
  18:47:37 30577-1791769657775230000.grantiva
  ```
  (Android: `34287.stop.json` at 18:53:08, the runner's `.grantiva` file only at 18:53:39.) The runner's own session
  file appeared 4 s (iOS) and 31 s (Android) after the teardown, when its session flow had failed against the dead
  device and the hold armed.
- Five minutes later (teardown/ios-5min-after.txt, android-5min-after.txt) the start and its runner were still
  running against the deleted UDID / killed serial, and `owner.json`, the `.grantiva` descriptor and `.stop.json` were
  still in `/tmp/grantiva-sessions`. On iOS the orphaned runner re-created an empty
  `devices/DACD2CF4…/cache/wda-builds/...` folder in the runner home the teardown had just removed (HOST/after.txt).
- Only the smoke's own `runner stop --json` from the project directory (teardown/ios-cleanup-runner-stop.txt,
  android-cleanup-runner-stop.txt) ended it; the start then printed the right line and exit code
  (teardown/ios-fg-start.txt tail):
  ```
    Releasing GrantivaAgent session...
  Runner stopped by teardown (pid 30577); the session has ended.
  # exit 0  end 18:52:47
  ```

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l54
unset GRANTIVA_API_KEY
rm -rf /tmp/l54 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l54 && mkdir -p /tmp/l54/empty
# iOS
cd /tmp/l54/ios
UDID=$(grantiva simulator ensure --name fix-l54 --device-type "iPhone 17" --runtime "iOS 26.0")
grantiva build install --simulator "$UDID" --no-launch
grantiva runner start --simulator "$UDID" > /tmp/l54/ios-fg.txt 2>&1 &
FG=$!
until grep -q '"state":"ready"' .grantiva/session.json 2>/dev/null; do sleep 0.5; done
ls /tmp/grantiva-sessions                                   # owner.json only: no <pid>-*.grantiva yet
(cd /tmp/l54/empty && grantiva simulator teardown --udid "$UDID" --json)   # expect runnerSessionStopped: true
sleep 15; kill -0 $FG 2>/dev/null && echo "start still running (bug)"; ls /tmp/grantiva-sessions
grantiva runner stop                                        # the only thing that ends it today
wait $FG; echo "start exit $?"; tail -1 /tmp/l54/ios-fg.txt
# Android: same with `cd /tmp/l54/android`, SERIAL=$(grantiva emulator ensure --name fix-l54),
# `grantiva runner start --device "$SERIAL"` and `grantiva emulator teardown --serial "$SERIAL" --json`.
grantiva emulator delete --name fix-l54 2>/dev/null
```
Prediction (not run): with `sleep 40` before the teardown (the runner's `<pid>-*.grantiva` present), the teardown stops
the session, as round 3's Task 5 device check saw.

## Evidence
- findings/evidence/round3-smoke/teardown/commands.txt, ios-*.txt, android-*.txt (fg-start, before-teardown,
  sessions-dir-poll, teardown, 5min-after, cleanup-runner-stop, after), host-before-teardown.txt
- findings/evidence/round3-smoke/fg-teardown.sh (driver script); HOST/after.txt (re-created device-home folder)

## Suspected cause
CLI, main dc965716. Confirmed from the code; the evidence fits each step.
- Teardown marks, then stops: `DeviceRunnerSessions.stop` (Sources/GrantivaCLI/DeviceRunnerSessions.swift:55-64)
  writes the markers from the owner files (`markLive`, :32-48, via `KeepAliveSessionStore.foregroundRunnerStarts`,
  KeepAliveSessionStore.swift:325-334, which reads `<pid>.owner.json`), so `30577.stop.json` exists. It then calls
  `RunnerSessionStopper.stopSessions` (RunnerSessionStopper.swift:159-175).
- `stopSessions` finds sessions only through `store.liveSessions(includingOrphans: true)` (:161), and `liveSessions`
  (KeepAliveSessionStore.swift:264-303) enumerates only the runner's own `<pid>-<ts>.grantiva` files (:276-280); the
  owner file merely annotates them. The runner writes that file in `holdKeepAliveSession` (runner
  `pkg/cli/keepalive.go:181-182`), after its session flow, so a start whose flow is still running is invisible here.
  The fallback for a `runner start` (:170-173) needs `.grantiva/session.json` in the teardown's working directory
  (`DeviceRunnerSessions.live.loadSession`, DeviceRunnerSessions.swift:19), which an empty directory does not have.
  So no session is found, nothing is signalled, `runnerSessionStopped` is false (SimulatorCommand.swift:140-145, 214-224, 232;
  EmulatorCommand.swift:182-186).
- The start reads the marker only when its runner exits: `startForeground` checks `requestedStop()` after
  `child.wait()` returns (DriverCommand.swift:729-742) or when startup fails (:651-660, :679-689). Nothing makes the
  runner exit: it is in its keep-alive hold, which the runner releases only on SIGINT/SIGTERM
  (`pkg/cli/keepalive.go:247-251`), and neither the runner nor the start watches for its device disappearing. That is
  why the marker, owner file and descriptor stay until `runner stop` (which reads `.grantiva/session.json` in the
  project directory, DriverCommand.swift:1004-1056) signals the runner; the start then reads the marker and prints
  the teardown line.
- Without `--force` the leftover check (SimulatorCommand.swift:153-161, 179-198) only warns about the processes it found, by
  design; with the session stop above working they would be gone before it runs.

## Acceptance criteria
- From an empty directory, both teardowns stop a foreground `runner start` at any point after `runner start` printed
  `Runner started` (session flow running or hold armed): `runnerSessionStopped: true`, no `leftoverProcesses` naming
  the start or its runner, the start exits 0 with `Runner stopped by teardown (pid N); the session has ended.` within
  10 s of the teardown, and `/tmp/grantiva-sessions` holds nothing for that pid afterwards. 5 of 5 on each platform,
  with the teardown sent 0-2 s after `session.json` says `ready`, and again 5 of 5 after the hold is armed.
- The same holds for a `run --keep-alive` run torn down during its flows (it ends `interrupted`, exit 130, per the L36
  ruling) and after its hold (earned status, see L56).
- A teardown of a different device leaves the session alone; `--force` behaviour unchanged.
- Fix direction (pick and say which in the PR): the stopper's session list includes runners that have a live owner
  sidecar but no published `.grantiva` file yet (`KeepAliveSessionStore.startingSessions`, :309-319, already finds
  them for L38-a), so `RunnerSessionStopper.stop` sends the holder SIGINT as for a published session; share that
  lookup with `runner stop` (L55) and `hierarchy` (L52) rather than adding a third. As a second line of defence, the
  foreground start may poll its own marker while it holds (e.g. once a second in `holdForeground`) and stop its runner
  when one appears, so a marker never sits unread.
- Tests: GrantivaCoreTests (next to the `RunnerSessionStopper` tests): an owner sidecar with live runner and holder
  and no `.grantiva` file is stopped by `stopSessions(udid:runnerStartSession: nil)` (holder interrupted); a sidecar
  for another UDID is not. GrantivaCLITests: teardown with only an owner file reports `runnerSessionStopped: true`.
