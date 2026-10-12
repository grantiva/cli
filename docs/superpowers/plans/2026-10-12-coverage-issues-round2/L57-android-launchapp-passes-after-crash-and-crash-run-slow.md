# On Android `launchApp` passes 1-3 s after the app crashed, so 99-crash fails 3.2-4.3 s after the crash and takes 28-30 s

Severity: ux
Component: runner
Platforms: android (3 of 3, default `emulator ensure` AVD, software rendering, load 4.3-11.4). iOS passes (I4-crash: `✗ assertVisible "Landmarks"` 144-167 ms after a `✓ launchApp`, wall 9.0-10.1 s).
Rows: round3-smoke A3 (findings/evidence/round3-smoke/A3-crash/)
Regresses/extends: L02 (crash check during a held lookup), L05 (first find after launch; wall < 12 s), L24 (no step passes on a dead app), and round-3 runner #22 (cold launchApp waits for `Displayed`, pid-matched `am_crash`). The verdict is right now: every run fails at the first step with `app_crash` and nothing passes on the dead app. What is left is when the failure lands and how long the run takes.
Binary: grantiva 2.1.0 (main dc965716), grantiva-runner 1.1.28-grantiva.12

## Expected
Runner CHANGELOG (round 3): a crash during launchApp's first-frame wait fails the launch at once. Round-3 ruling
(coverage plan): 99-crash fails at `launchApp` or at the first step after it. L02 acceptance: the failure lands within
~2 s of the process dying. L05 acceptance: 99-crash wall under 12 s on this AVD.

## Actual
A3-crash/device-crash-times.txt (device and host clocks agree to the second) and crash-<i>-maestro-runner.log /
crash-<i>-client.log:

| run | step 0 start | `launch_app` returned | `FATAL EXCEPTION` | launchApp passed | step 1 failed | crash → failure | wall |
|---|---|---|---|---|---|---|---|
| 1 | 18:16:49.10 | 18:16:53.74 | 18:16:59.73 | 18:17:02.19 (13.1 s) | 18:17:03.99 (1.8 s) | 4.3 s | 30.1 s |
| 2 | 18:17:20.52 | 18:17:22.39 | 18:17:28.98 | 18:17:31.94 (11.4 s) | 18:17:33.17 (1.2 s) | 4.2 s | 28.2 s |
| 3 | 18:17:51.17 | 18:17:52.99 | 18:18:00.56 | 18:18:01.62 (10.5 s) | 18:18:03.75 (2.1 s) | 3.2 s | 30.2 s |

Where run 1's 30.1 s went (runs 2-3 are the same shape):
- 2.6 s CLI before the runner starts (18:16:42 → 44.6)
- 4.5 s runner start, UIAutomator2 server and session (→ 49.1)
- 4.6 s inside launchApp before the launch request returns (→ 53.74; 1.8-1.9 s in runs 2-3)
- 6.0 s app cold start until the demo's deliberate throw (→ 59.73; 6.6 s and 7.6 s in runs 2-3). The app throws 500 ms
  after `onCreate` (landmarks-demo `LandmarksApp.kt:9-16`, `MainActivity.kt:39`), so most of this is the app's own
  cold start on software rendering.
- 2.5 s from the crash until launchApp passed (3.0 s, 1.1 s)
- 1.8 s for `assertVisible "Landmarks"` to fail with `app_crash` (1.2 s, 2.1 s)
- 3.2 s failure capture after the failure (→ `Flow completed` 18:17:07.23), including 0.8 s of a Flutter tree probe on a
  native app (`Flutter fallback: failed to get trees`, 18:17:04.81) and `GET /source` (275 ms)
- 1.3 s runner shutdown and reports (→ 08.5)
- 3.5 s CLI after the runner (failure screenshot, summary; → 18:17:12.1)

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l57
unset GRANTIVA_API_KEY
rm -rf /tmp/l57 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l57 && cd /tmp/l57/android
SERIAL=$(grantiva emulator ensure --name fix-l57)          # default config: software rendering
grantiva build install --device "$SERIAL" --no-launch
for i in 1 2 3; do
  adb -s "$SERIAL" logcat -b all -c
  /usr/bin/time -p grantiva run --device "$SERIAL" --no-build --flow .maestro/99-crash.yaml --report-dir /tmp/l57/r$i > /tmp/l57/r$i.txt 2>&1
  adb -s "$SERIAL" logcat -d -b main,events,system,crash -v time | grep -E "Displayed com.kylebrowning.landmarks|am_crash|FATAL EXCEPTION|am_proc_died"
  grep -E "Step [01] |launch_app" /tmp/l57/r$i/maestro-runner.log /tmp/l57/r$i/client.log | cut -c1-160; grep real /tmp/l57/r$i.txt
done
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l57
```
The logcat line settles the ordering the cause below depends on: is `Displayed com.kylebrowning.landmarks/…` logged
before the `FATAL EXCEPTION`, and when does `am_proc_died` come?

## Evidence
- findings/evidence/round3-smoke/A3-crash/commands.txt, device-crash-times.txt, crash-1..3.txt,
  crash-1..3-maestro-runner.log, crash-1..3-client.log, crash-1..3-flow-000.json
- findings/evidence/round3-smoke/I4-crash/ (iOS comparison)

## Suspected cause
Runner, grantiva/main 2d1b625.
- **launchApp passes after the crash: the first frame masks it.** `confirmLaunch`
  (`pkg/driver/uiautomator2/commands.go:1875-1925`) polls every `alivePoll` (250 ms) plus the cost of `pidof` and a
  three-buffer `logcat -d` (`launchProgress`, :1937-1949). `launchProgress` returns `crashed && !drawn` (:1948): once
  `Displayed <app>/` is in the log, a pid-matched `am_crash` no longer counts, and `confirmLaunch` returns success as
  soon as `drawn` is seen while the pid still answers (:1896-1908). All three passes came 8.4-9.6 s after the launch
  request, inside the 10 s `firstFrame` bound (:1826), so they came from `drawn`, not from the bound. The demo draws
  its first frame and then throws 500 ms after `onCreate`; a crashed process lingers while the system handles the
  crash, so the poll after `Displayed` sees a live pid, a drawn frame, and a crash it is told to ignore. Inference;
  the repro's logcat confirms or refutes it.
- **The first step then waits for the crash poll.** With launchApp passed, the watch is armed (`watchLaunch`,
  :1725-1731) and the element wait checks for a crash at most once per `crashPoll` (1 s, :1825; wait_crash.go:17-29,
  211), so the step fails 1.2-2.1 s later. 2.5 + 1.8 s = run 1's 4.3 s.
- **launchApp's own preamble.** Before the launch request: `clearExitHistory`, `am force-stop`, an `appProcessAlive`
  check, then `applyPermissions` with the default `all: allow` (:1683-1688), which runs one `adb shell pm grant` per
  entry of `getAllPermissions` (27 entries, :2275-2299, :2328-2333, :2349), then `deviceLogTimestamp`. 1.8-4.6 s here
  at load 4-11; the same cost shows in every launchApp (L58's 03-edit: 2.5-5 s before `launch_app`).
- **After the failure.** The failure capture runs a Flutter tree probe on a native app (`pkg/flutter/wrapper.go:293`,
  0.8 s) and a `GET /source`; 3.2-3.7 s in all.
- **Not the runner.** 6.0-7.6 s of each run is the app's cold start to its deliberate throw, and ~6-7 s is CLI and
  runner startup and shutdown. With those alone the 12 s wall from L05 is out of reach on this AVD at load 4-11; the
  round-3 implementer's 5.5-6.3 s figure (ledger, Task 1) cannot have included CLI startup or the app's cold start.

## Acceptance criteria
- 99-crash on the default `emulator ensure` AVD, 3 of 3: fails at `launchApp` (preferred) or at the first step, with
  `error.type` `app_crash` and the `LANDMARKS_CRASH_ON_LAUNCH` cause; the failure is reported within 2 s of the
  `FATAL EXCEPTION` line (device clock), measured as in the table above.
- `launchApp` never passes when an `am_crash` (or a FATAL EXCEPTION for the app) of one of the launch's pids is in the
  log before it returns, whether or not `Displayed` was logged first; a crash after launchApp returned is still
  caught by the post-launch watch.
- The pre-launch preamble is bounded: `all: allow` permissions in one shell call (or skipped when nothing is
  requested), so a launchApp's work before the launch request is under 1 s at load < 10; the runner log records it.
- No Flutter probe on a failure in an app that is not a Flutter app (or it is bounded to ~100 ms).
- Wall time: the controller re-baselines L05's "< 12 s" for this AVD (open question below); until then, report the
  runner-side share (step 0 start → `Flow completed`) and keep it under 12 s with the app's cold start included.
- Runner tests in `pkg/driver/uiautomator2` (next to the round-3 confirmLaunch tests,
  `TestCrashThenRestartBeforeSettleFailsLaunch`): a fake device whose logcat shows `Displayed` and then an `am_crash`
  of the launched pid while `pidof` still answers makes `launchApp` fail with `ErrAppCrashed`; `Displayed` without a
  crash still passes at once; the permission preamble issues one shell call for `all`.
