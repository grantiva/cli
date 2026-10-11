# On Android `inputText` without a selector can spend almost its whole step budget on the focused-element lookup, so the typing request is then cut at the 10 s floor and the step fails

Severity: wrong-result
Component: runner
Platforms: android. **Load-only**: 1 of 3 original runs failed at load 68 (1-min, at the start of the run); runs 2-3 and the fix-round re-run (3 of 3, load 7.1-9.6, lookup 170-192 ms) pass. Same pattern once more in AND-120/01 (25.7 s lookup, load up to 81).
Rows: AND-213 [android] (AND-213 rerun [android] passes)
Regresses/extends: new. Not L01 (docs/superpowers/plans/2026-10-12-coverage-issues-round2/L01-android-inputtext-actions-timeout.md, runner #20): the fix round re-graded B2-L01 to pass because no call was cut at 10 s while its step still had time. Sits next to L05 (slow first lookup on the software AVD).
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
`inputText: " · Ünïcødé ✓"` (no selector, after `tapOn: "Location"`) types the text within its step timeout, as runs 2-3
and the re-run do (1.5-7.5 s). A slow auxiliary lookup never leaves the request that does the step's work less time
than it needs; at worst the step degrades (types without the before-text) rather than failing.

## Actual
findings/evidence/cov2-android/CF-15-input-unicode/ (load 68.4 at start). run.err:
```
    ✗ inputText: " · Ünïcødé ✓" (48.0s)
      ╰─ Failed to input text: UIAutomator2 server on emulator-5554 did not answer POST /actions within 10s
```
report/client.log:27-29 (the step started at 10:31:02.82, maestro-runner.log:55):
```
10:31:02.819625 POST /session/3a68c64f-fbfd-4365-bf6c-ae17553d39f0/appium/gestures/click [375.923084ms] OK body={"offset":{"x":540,"y":758}}
10:31:38.356262 GET /session/3a68c64f-fbfd-4365-bf6c-ae17553d39f0/element/active [35.53111525s] ERR:404 body=
10:31:48.358810 POST /session/3a68c64f-fbfd-4365-bf6c-ae17553d39f0/actions [10.0024585s] ERROR: UIAutomator2 server on emulator-5554 did not answer POST /actions within 10s
```
The lookup used 35.5 s and returned 404 (no focused field), so `/actions` got only the 10 s floor and, with no field to
read, the L01 late-answer recovery (`typedDespiteTimeout`) could not run. Runs r2/r3 (load 8.6/9.7): `element/active`
1.48 s / 3.60 s, pass. Re-run CF-rr-uni-1..3: 180 / 192 / 170 ms, pass.

## Repro
Load-dependent; the unit test in the criteria is the reliable repro. On a device, saturate the host first:
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l47
unset GRANTIVA_API_KEY
rm -rf /tmp/l47 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l47 && cd /tmp/l47/android
sed -i '' 's/^emulator: .*/emulator: fix-l47/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-l47)
grantiva build install --device "$SERIAL" --no-launch
N=$(( $(sysctl -n hw.ncpu) * 4 )); for i in $(seq 1 $N); do yes > /dev/null & done   # aim for 1-min load > 60
sleep 60; uptime
for i in 1 2 3 4 5; do
  grantiva run --device "$SERIAL" --no-build --flow .maestro/coverage/15-input-unicode.yaml --report-dir /tmp/l47/r$i > /tmp/l47/r$i.txt 2>&1
  grep -a -E 'inputText' /tmp/l47/r$i.txt | head -2; grep -a -E 'element/active|/actions' /tmp/l47/r$i/client.log
done
pkill -x yes
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l47
```
Flow (landmarks-demo b3f046f, `.maestro/coverage/15-input-unicode.yaml`, first steps):
```yaml
appId: com.kylebrowning.landmarks
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Edit Landmark"
- tapOn: "Location"
- inputText: " · Ünïcødé ✓"
- assertVisible: "San Francisco, CA · Ünïcødé ✓"
```

## Evidence
- findings/evidence/cov2-android/CF-15-input-unicode/run.err, report/client.log, report/maestro-runner.log, commands.txt (load 68.43)
- findings/evidence/cov2-android/CF-15-input-unicode-r2/, CF-15-input-unicode-r3/ (passes, lookup 1.48/3.60 s)
- findings/evidence/cov2-android/CF-rr-uni-1..3/report/client.log:28 (re-run, use `grep -a`)
- findings/evidence/cov2-android/AND-120/01.err (`✗ inputText: " Renamed" (51.6s)` in 03-edit; the 25.7 s lookup is from the slice's note, that run's client.log was not kept)
- findings/evidence/cov2-android/AND-213/commands.txt, AND-213/rerun/commands.txt (pointers)

## Suspected cause
Runner (release-round2b, 1be68db).
- `pkg/driver/uiautomator2/commands.go:421`: `active, err := d.client.ActiveElement()` with no bound of its own. Every
  request runs under `requestDeadline` (`pkg/uiautomator2/transport.go:82-99`): the later of the client's 10 s default
  and the step's remaining deadline. So under load the lookup may consume the whole step budget.
- The typing request that follows (`SendKeyActions`, `:448`, or `typeWhole` on the set-value path) then gets
  `max(10 s, time left)` = 10 s, and is cut.
- With `active == nil` (404), the timeout recovery `typedDespiteTimeout(active, …)` (`:451`) has no field to check, so
  the step fails even if the keys landed.

## Acceptance criteria
- The focused-element lookup has its own bound (a few seconds, e.g. 3 s, documented next to the constant); on timeout or
  404 the step proceeds with key events and no before-text, logging that it did.
- The request that types always gets at least its normal budget: either the lookup's time is not taken from it, or the
  step reserves a share of its deadline for `/actions` / set-value.
- Under the repro's load, 5 of 5 runs type the text (or, if the device itself is too slow to type, fail with a message
  that names the slow lookup rather than `/actions`).
- Runner test in `pkg/driver/uiautomator2` (next to `input_timeout_test.go`): a fake client whose `ActiveElement` blocks
  for 40 s inside a 45 s step makes `inputText` return within the step timeout having called `SendKeyActions` once with
  at least 10 s of budget; a fake whose `ActiveElement` returns 404 at once still types via key events.
