# On a software-rendered Android emulator the first element lookup after launchApp blocks 5-10 s in every flow, and the failure capture of a crashed launch queues behind it

Severity: ux
Component: runner
Platforms: android (seen on the default `emulator ensure` AVD, API 35, `hw.gpu.enabled=no`, software rendering; not measured on a GPU AVD)
Rows: round2-A1-03edit, round2b-A1-03edit, round2-A3, round2b-A3; addendum device check (PR #20 review, task-A1-report.md "Concerns" 1-2)
Binary: grantiva 2.1.0 (main e02e30a), grantiva-runner 1.1.28-grantiva.10 + PR #20 branch af369f1

## Expected
The first `POST /element` after `launchApp` answers as fast as later ones (later lookups on the same screen take
70-430 ms): under 2 s when the element is on screen, a prompt 404 when it is not. A crashed launch (99-crash) fails and
finishes its post-mortem (screenshot, hierarchy) within the L02 target: wall under 12 s on this AVD.

## Actual
The first lookup after launch is held server-side in every flow, passing ones included; later lookups on the same
screen are fast. round2b-A1-03edit/run-1-client.log:6-11 (.10, element present but not clickable, so 404 is right):
```
06:51:37.409442 POST .../appium/device/launch_app [84.165959ms] OK body={"appId":"com.kylebrowning.landmarks"}
06:51:45.286946 POST .../element [5.323385917s] ERR:404 body={"strategy":"-android uiautomator","selector":"new UiSelector().text(\"Deep Links\").clickable(true)...
06:51:45.646261 POST .../element [359.196ms] ERR:404 body=... description(\"Deep Links\").clickabl...
06:51:46.026042 POST .../element [379.6915ms] ERR:404 body=... textMatches(\"(?ims)(?:Deep Links)\"...
06:51:46.317870 POST .../element [144.115916ms] OK body=... new UiSelector().text(\"Deep Links\")
```
- 03-edit, first lookup: 5.32 / 5.28 / 5.43 s (round2b-A1-03edit run-1..3-client.log:7), 5.52 s
  (round2-A1-03edit/run-1-client.log:7); `tapOn: text="Deep Links" (7.2s, slow)` (round2b-A1-03edit/run-1.txt:33).
  With af369f1 the reviewer's device check reports the same step at ~15 s.
- 99-crash, first lookup: 10.001 / 10.003 / 10.002 s, cut by the client
  (`context deadline exceeded (Client.Timeout exceeded while awaiting headers)`, round2b-A3/crash-1..3-client.log:7).
- 99-crash with af369f1 (task-A1-report.md, fix3-android): the assert now fails with `app_crash` 0.5-1.4 s after
  `am_crash` (L02 fixed), but wall time is 30.76 / 25.35 / 21.79 s. After the failure the runner waits ~10 s more:
  the failure screenshot/hierarchy capture queues behind the cancelled first lookup, which the server keeps working on.
- Not a client floor: with af369f1 a wait's lookups carry the wait's deadline, not the 10 s request floor, so the hold
  is the server's. The first request after launch in 10-seed-many is `GET /source`, and it answers in 209-271 ms
  (round2b-A-K07/run-1..3-client.log:7), so the hold looks specific to a UiSelector lookup (or to the first one).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l05
unset GRANTIVA_API_KEY
rm -rf /tmp/l05 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l05 && cd /tmp/l05/android
SERIAL=$(grantiva emulator ensure --name fix-l05)       # default config: hw.gpu.enabled=no
grantiva build install --device "$SERIAL"
for f in 03-edit 99-crash; do for i in 1 2 3; do
  /usr/bin/time -p grantiva run --device "$SERIAL" --no-build --flow .maestro/$f.yaml --report-dir /tmp/l05/$f-$i > /tmp/l05/$f-$i.txt 2>&1
  grep -E 'launch_app|POST .*/element ' /tmp/l05/$f-$i/client.log | head -3 | cut -c1-200; grep real /tmp/l05/$f-$i.txt
done; done
adb -s "$SERIAL" logcat -d | grep -iE 'appium|uiautomator|idle' | tail -80   # server's own view of the held request
grantiva emulator teardown --serial "$SERIAL"; avdmanager delete avd -n fix-l05
```
Check: the first `POST /element` after `launch_app` takes 5-10 s while later ones take < 0.5 s; 99-crash wall > 20 s.
For the server-side cause, compare with `waitForIdleTimeout: 0` in the flow config and with a lookup sent 10 s after
launch (does the hold follow the launch, or the first UiSelector query of the session?).

## Evidence
- findings/evidence/round2-smoke/round2b-A1-03edit/run-1..3-client.log:6-7, run-1.txt:33; round2-A1-03edit/run-1-client.log:7
- findings/evidence/round2-smoke/round2b-A3/crash-1..3-client.log:1-8 (session settings, launch_app, 10 s first lookup)
- findings/evidence/round2-smoke/round2b-A-K07/run-1..3-client.log:6-7 (first request `GET /source`, ~0.2 s)
- .superpowers/sdd/2026-10-11-round2-fix-wave/task-A1-report.md "fix3-android" (99-crash wall 21.8-30.8 s, 03-edit) and "Concerns" 1-2
- Related: L01 (request floor), L02 (crash check during a lookup)

## Suspected cause
Runner (af369f1, /Users/kyle/Developer/maestro-runner/.worktrees/fix3-uia2). The server-side cause is not confirmed.
- Session settings sent at start (`pkg/cli/android.go:240-245`): `waitForIdleTimeout` = `cfg.WaitForIdleTimeout`
  (flag default 200 ms, `pkg/cli/test.go:151-156`; the CLI passes no `--wait-for-idle-timeout` on Android, only on iOS,
  Sources/GrantivaCore/Platform/IOSPlatform.swift:99) and `enableMultiWindows: true`; then `implicitWait: 100`
  (`android.go:250`, `pkg/uiautomator2/client.go:308-316`). The flow runner sends `waitForIdleTimeout` again per flow
  (`pkg/executor/flow_runner.go:129-136`, `pkg/driver/uiautomator2/driver.go:260-267`). The logs confirm
  `{"enableMultiWindows":true,"waitForIdleTimeout":200}` and `{"implicitWait":100}` (crash-1-client.log:2-3, 5).
- `waitForSelectorTimeout` and `actionAcknowledgmentTimeout` are never sent (`SetAppiumSettings` doc,
  client.go:318-321, names `waitForSelectorTimeout` but nothing sets it), so the server's own defaults apply. Session
  capabilities carry only platformName and deviceName (`pkg/uiautomator2/types.go:17-20`, `android.go:215-219`).
  Candidates to measure: the server's selector wait or idle wait on the first UiSelector query while the app's first
  frames are still drawing (software rendering), or the all-windows traversal `enableMultiWindows` turns on.
- The queued capture: a crash-cancelled lookup is cancelled client-side only (`watchedAttempt`,
  `pkg/driver/uiautomator2/wait_crash.go:77-115`, cancels the attempt context at :86 and returns the crash at :108-111;
  the lookup is `FindElementCtx`, `pkg/uiautomator2/element.go:84-86`);
  the server keeps running the query. The failure capture then goes to the same server: `captureArtifacts`
  (`pkg/executor/flow_runner.go:1915-1929`) calls `Driver.Hierarchy` -> `client.Source()` (`pkg/driver/uiautomator2/driver.go:438-439`), and
  `Screenshot` falls back to the server when adb screencap fails (driver.go:428-436). Those requests wait for the held
  lookup.

## Acceptance criteria
- On the default `emulator ensure` AVD (software rendering), the first find after `launchApp` completes in under 2 s
  when the element is present (03-edit `tapOn "Deep Links"` under ~3 s, 3 of 3), and returns 404 in under 2 s when it
  is not; no other first-lookup in the stock flows takes over 2 s.
- 99-crash wall time under 12 s on that AVD, 3 of 3, still failing at the first assert with `app_crash`.
- Failure capture does not wait behind a cancelled lookup: after a crash-cancelled lookup, the screenshot and
  hierarchy are taken within ~2 s (abort the lookup server-side, or capture over a fresh connection / adb
  `uiautomator dump` + `screencap` that does not queue behind it).
- The settings sent at session start are the ones the fix relies on (for example an explicit `waitForSelectorTimeout`
  if that is the cause) and are logged in client.log; a flow's `waitForIdleTimeout` still overrides.
- Runner tests in pkg/driver/uiautomator2 / pkg/uiautomator2 with a fake server that delays its first response:
  (a) first `POST /element` held 10 s, then answers -> the session-start settings / first-lookup handling keeps the
  step under 2 s, or the test asserts the settings sent; (b) a held first lookup cancelled by a crash -> the following
  `Hierarchy()` / `Screenshot()` return within 2 s instead of after the held request; (c) a slow but healthy first
  lookup on a live app still passes.
