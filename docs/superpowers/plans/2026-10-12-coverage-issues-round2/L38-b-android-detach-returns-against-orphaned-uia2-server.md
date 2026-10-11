# On Android `runner start --detach` can return in about a second by attaching to a UIAutomator2 server left by an earlier, killed session, then the new runner restarts that server and every client fails for ~15 s

Severity: contract
Component: cli
Platforms: android. **Intermittent, unconfirmed**: 1 sighting (B2-K79/03, load 10.3); fix round 1 did not reproduce it (0 of 3, load 5.6-6.3) but ran without the precondition named below. Not a load effect on this reading.
Rows: AND2-OBS-03 [android], AND2-OBS-03 rerun [android] (pass); seen also in D2-30 [android]'s note
Regresses/extends: new (the M32 "detach half"); `runner start --help` says `--detach` "returns once the driver is up". Split from L38-a.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11
Triage note: the cluster map keeps this as a single unconfirmed sighting. The evidence below points to a deterministic precondition (a UIAutomator2 server orphaned by a `kill -9`'d keep-alive run) that the fix-round re-run did not set up. Confirm with the repro before fixing; if it does not reproduce, close as not reproducible.

## Expected
`runner start --help` (`Sources/GrantivaCLI/DriverCommand.swift:109-110`): "With --detach it returns once the driver is
up and the runner keeps the session until `grantiva runner stop`". A `hierarchy` or `runner dump-hierarchy` run right
after `--detach` returns answers. In the re-run (findings/evidence/cov2-android/FIX1-detach/01.out):
```
detach returned after 5.9s; first successful dump 1.5s after return (0 failed tries)
```

## Actual
Sequence in findings/evidence/cov2-android/B2-K79/ (load 10.3):
- `01`: the keep-alive `grantiva run` (pid 37602) is `kill -9`'d; its runner (37639) exits with it.
- `02.out`: the runner is gone, but the device still runs one UIAutomator2 process and the dead session's forward stays:
```
runner-gone
       0
emulator-5554 localfilesystem:/tmp/uia2-emulator-5554.sock tcp:6790

1
```
- `03` (`runner start --detach; sleep 1; hierarchy --format json; runner dump-hierarchy --format json`): the whole
  command line took 1.5 s, `--detach` printed `Runner started (detached)` with `UIAutomator2 port: 62621`, and both
  reads failed (`03.err`):
```
Error: No active runner session. Start one with `grantiva runner start` or `grantiva run --keep-alive`.
Error: The UIAutomator2 server on emulator-5554 is not answering on local port 62675: The network connection was lost.
```
- `04` (15 s later): session.json holds `wdaPort: 62621`, the runner is alive, both reads succeed.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l38b
unset GRANTIVA_API_KEY
rm -rf /tmp/l38b && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l38b && cd /tmp/l38b/android
sed -i '' 's/^emulator: .*/emulator: fix-l38b/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-l38b)
grantiva build install --device "$SERIAL" --no-launch
for i in 1 2 3; do
  rm -f /tmp/l38b/ready
  nohup grantiva run --device "$SERIAL" --no-build --flow .maestro/01-browse.yaml --keep-alive --ready-file /tmp/l38b/ready > /tmp/l38b/ka.out 2>&1 &
  KA=$!; for s in $(seq 1 180); do [ -f /tmp/l38b/ready ] && break; sleep 1; done
  kill -9 $KA; sleep 1
  adb -s "$SERIAL" shell ps -A | grep -c uiautomator        # precondition: 1 (orphaned server)
  t0=$(python3 -I -c 'import time;print(time.time())'); grantiva runner start --detach --device "$SERIAL" > /dev/null
  t1=$(python3 -I -c 'import time;print(time.time())')
  grantiva runner dump-hierarchy --format json > /dev/null; rc=$?
  python3 -I -c "print('detach %.1fs dump-exit=$rc' % ($t1-$t0))"
  grantiva runner stop > /dev/null
done
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l38b
```
Expected after the fix: `detach` ≥ the runner's own start time (4-8 s on this AVD) and `dump-exit=0` every time.

## Evidence
- findings/evidence/cov2-android/B2-K79/01.out, 02.out, 03.out, 03.err, 04.out, dump.json, commands.txt
- findings/evidence/cov2-android/FIX1-detach/01-03.out (re-run, 0 of 3, after a clean `runner stop`)
- findings/evidence/cov2-android/D2-30/ (the same race noted: `hierarchy` 2 s after `--detach` said `No active runner session`)

## Suspected cause
- `--detach` readiness on Android is "any UIAutomator2 server on the device answers with a session":
  `DriverCommand.swift:302-309` (`waitForUIAutomator2Port`, 90 s) polls `AndroidPlatform.attachDriver`
  (`Sources/GrantivaCore/Android/AndroidPlatform.swift:276-301`), which makes a fresh forward to device port 6790 and
  accepts the first session `GET /wd/hub/sessions` reports (`UIAutomator2Client.swift:38-68`, `:72-78`). Nothing ties
  that session to the runner just spawned.
- After a `kill -9` of a keep-alive run, the runner dies with its parent (K79) but the on-device server and its
  session survive (02.out above), so the first probe, made before the new runner reaches the device, succeeds at once.
- The new runner then calls `StopUIAutomator2` before starting its own server (runner
  `pkg/device/uiautomator.go:65-68`), which kills the server the CLI just attached to. Until the new server is up
  (~15 s here) every client gets "not answering" or "No active runner session".
- The fix round re-ran after a clean `runner stop`, which clears the server (AND-082: "UIAutomator2 processes 1 -> 0"),
  so the precondition was absent.

## Acceptance criteria
- With an orphaned UIAutomator2 server on the device (repro above), `runner start --detach` returns only after the new
  runner's own session is up, and `runner dump-hierarchy` right after it succeeds, 3 of 3.
- Readiness is tied to this runner: e.g. record the session id (if any) the device reports before spawning and accept
  only a different one; or wait for the runner's keep-alive session file `/tmp/grantiva-sessions/<runnerPid>-….grantiva`
  (runner `keepalive.go:182`), which names the runner pid; or have the CLI clear a leftover server before spawning.
- The same rule applies to the foreground path (`DriverCommand.swift:452`).
- The wait gives up as soon as the spawned runner exits (see L48), not after 90 s.
- Test in GrantivaCLITests/RunnerLifecycleCommandTests.swift: with a fake attach that returns session "old" first and
  "new" after three polls, the detach wait returns the "new" attachment (or waits for the fake runner's session file),
  not the first one.
