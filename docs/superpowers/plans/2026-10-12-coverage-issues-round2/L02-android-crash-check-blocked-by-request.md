# On Android a find request blocked against a crashing app stalls the crash check for 10 s, and assertVisible then passes on the dead app

Severity: wrong-result
Component: runner
Platforms: android (Android-only: UIAutomator2 element wait; iOS 99-crash fails in 128-158 ms with app_crash, K97)
Rows: round2-A3, round2b-A3
Binary: grantiva 2.1.0 (main 5eab55d), grantiva-runner 1.1.28-grantiva.10

## Expected
99-crash (`LANDMARKS_CRASH_ON_LAUNCH: "1"`, then `assertVisible: "Landmarks"`) fails on the first assert, within about
2 s of the crash, with `error.type` `app_crash` and the `java.lang.RuntimeException: LANDMARKS_CRASH_ON_LAUNCH` cause,
as the iOS path does since K97. No step after a crashed launch passes. Round 1 (.9): the assert failed in 318 ms, flow
2.4-2.6 s, wall 5.0-5.4 s.

## Actual
3 of 3 quiet-host runs and 3 of 3 round2 runs fail late: flow 20.7 / 16.8 / 18.0 s, wall 35.6 / 27.4 / 31.7 s. In 2 of 3
runs each time (round2b runs 1 and 3, round2 runs 1 and 3) `assertVisible "Landmarks"` **passes** against the dead app
and the crash surfaces on the next step. round2b-A3/crash-1.txt:32-35 and crash-1-client.log:
```
    ✓ assertVisible: text="Landmarks" (10.2s, slow)
    ✗ assertVisible: text="Featured" (654ms)
      ╰─ app crashed after launch: java.lang.RuntimeException: LANDMARKS_CRASH_ON_LAUNCH (step failed: Element not visible: text='Featured': com.kylebrowning.landmarks crashed (APP CRASH(EXCEPTION))) (cause: app crashed after launch)
06:54:47.619 POST .../appium/device/launch_app [235ms] OK body={"appId":"com.kylebrowning.landmarks","arguments":{"LANDMARKS_CRASH_ON_LAUNCH":"1"}}
06:54:59.697 POST .../element [10.001201875s] ERROR: ... context deadline exceeded (Client.Timeout exceeded while awaiting headers)
06:54:59.818 POST .../element [121ms] ERR:404 body={"strategy":"-android uiautomator","selector":"new UiSelector().description(\"Landmarks\")"}
06:54:59.852 POST .../element [33ms] OK body={"strategy":"-android uiautomator","selector":"new UiSelector().textMatches(\"(?ims)(?:Landmarks)\")...
```
Runs 2 and 3 show the same 10.00 s blocked first `POST /element` (crash-2/3-client.log:7). In run 2 every later strategy
404s and the step fails at 11.3 s; the post-step crash watch then relabels it `app_crash`. What matched "Landmarks" in
runs 1 and 3 was not captured (likely the launcher's app label once the app's window was gone).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l02
unset GRANTIVA_API_KEY
rm -rf /tmp/l02 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l02 && cd /tmp/l02/android
SERIAL=$(grantiva emulator ensure --name fix-l02)
grantiva build install --device "$SERIAL"
for i in 1 2 3; do
  /usr/bin/time -p grantiva run --device "$SERIAL" --no-build --flow .maestro/99-crash.yaml --report-dir /tmp/l02/r$i > /tmp/l02/r$i.txt 2>&1
  grep -E 'assertVisible|real' /tmp/l02/r$i.txt | head -4; grep -E 'POST .*/element ' /tmp/l02/r$i/client.log | head -3
done
grantiva emulator teardown --serial "$SERIAL"; avdmanager delete avd -n fix-l02
```
Drive it through `grantiva run`: run with the runner binary directly the app did not crash (round2b-AB, crash env did
not reach the app on that path), so that A/B is not a valid repro.

## Evidence
- findings/evidence/round2-smoke/round2b-A3/crash-1..3.txt, crash-<i>-client.log, crash-<i>-maestro-runner.log, crash-<i>-flow-000.json (`"type": "app_crash"` at :70)
- findings/evidence/round2-smoke/round2-A3/crash-1..3.txt, crash-3-flow-000.json, crash-3-report.json, crash-3-maestro-runner.log
- findings/evidence/round2-smoke/round2b-AB-runner/99-crash-runner-9.txt, 99-crash-runner-10.txt (invalid A/B, app did not crash)
- Related: docs/superpowers/plans/2026-10-11-coverage-issues/K97-crash-wait-error-type.md

## Suspected cause
Runner (release-round2, 56224e1).
- The crash check runs only between attempts, never during one: `pkg/driver/uiautomator2/driver.go:603` creates it and
  `:619` calls it before each attempt of the `findElementWithContext` loop (`assertVisible` reaches it via
  `findElementFast`, commands.go:272, driver.go:430). One attempt is `tryFindElementFast` (driver.go:708-731), which walks
  every strategy in turn; its first `FindElement` blocked for the full client timeout (`pkg/uiautomator2/client.go:50`,
  10 s, see L01), and no crash poll could run meanwhile.
- The first attempt is never checked: `pkg/driver/uiautomator2/wait_crash.go:22-26` returns nil on the first call ("an
  element found on the first attempt costs nothing"), and the 1 s `crashPoll` (commands.go:1477-1486) only gates later
  calls. So the blocked first attempt plus its looser strategies (`textMatches`) can return a match with no check at all.
- A passing step is never re-checked: `updateCrashWatch` (commands.go:1438) returns at `:1446` when `r.Success`, so a
  match against a dead app stands and the crash is pinned on the next step.

## Acceptance criteria
- 99-crash on the default `emulator ensure` AVD fails 3 of 3 at `assertVisible "Landmarks"` (never passes), with
  `error.type` `app_crash` and the `LANDMARKS_CRASH_ON_LAUNCH` cause, within ~2 s of the process dying (assert step under
  ~3 s; flow and wall time back near round 1: flow < 6 s, wall < 12 s on that AVD).
- The crash check runs concurrently with an in-flight find request (or the request is bounded by the next crash-poll
  tick through a context), so a request blocked by a dying app cannot delay crash detection beyond one `crashPoll`.
- The first attempt of an element wait is covered when the watch is armed and the find did not return promptly.
- No element-wait step reports success while the launched process is gone with a FATAL EXCEPTION logged since launch:
  a match found after the process died is re-checked before the step passes.
- Runner tests in pkg/driver/uiautomator2 (next to wait_crash_test.go / crash_test.go): a fake client whose first
  `FindElement` blocks 10 s while the fake device reports the process gone plus a FATAL EXCEPTION makes `assertVisible`
  fail with `ErrAppCrashed` within 2 s; a fake whose looser strategy then matches still fails with `app_crash`, not success.
