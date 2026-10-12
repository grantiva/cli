# On Android `doubleTapOn` still registers as two single taps in 4 of 5 runs: the one 200 ms pointer sequence takes 0.7-1.3 s on the software-rendered AVD

Severity: wrong-result
Component: runner
Platforms: android (4 of 5 fail, default `emulator ensure` AVD, software rendering, load 7.0-9.8). iOS passes 5 of 5 (I-doubletap: `✓ doubleTapOn` 545-667 ms, `✓ "Double taps: 1"`).
Rows: round3-smoke A-doubletap (findings/evidence/round3-smoke/A-doubletap/)
Regresses/extends: L32 (fixed in runner #21 by replacing the server's `double_click` gesture with one W3C `/actions` sequence; the implementer's device check passed 6 of 6) and L33 (point-only double tap, same code path). The smoke shows the fix did not make the gap device-independent.
Binary: grantiva 2.1.0 (main dc965716), grantiva-runner 1.1.28-grantiva.12

## Expected
L32: `doubleTapOn: {id: "gesture-pad"}` on Gesture Lab gives `Double taps: 1` and leaves `Taps` at its prior value,
10 of 10 on the default AVD; the inter-tap gap does not depend on device speed. A step that reports success has
performed the gesture it names.

## Actual
Flow `.maestro/coverage/03-gesture-lab-taps.yaml`, 5 runs. Runs 1-4: `✓ doubleTapOn: id="gesture-pad"` then
`✗ assertVisible: text="Double taps: 1" (17.3-17.6s)`, closest texts `"Double taps: 0", "Taps: 3"` (the app saw two
more single taps). Run 5 passed. The runner sends one sequence (dt-1-maestro-runner.log):
```
18:31:59.536731 [INFO] doubleTap: (540, 1295), presses 40 ms, gap 80 ms
```
and the request that carries it (pointerMove, down, pause 40, up, pause 80, down, pause 40, up: 160 ms of pauses)
takes far longer on the device (dt-<i>-client.log, `POST /session/…/actions`):

| run | `/actions` | step | result |
|---|---|---|---|
| 1 | 972 ms | 1.2 s | two single taps |
| 2 | 892 ms | 1.1 s | two single taps |
| 3 | 964 ms | 1.2 s | two single taps |
| 4 | 1297 ms | 1.5 s | two single taps |
| 5 | 692 ms | 1.2 s | `Double taps: 1` |

The only passing run is the fastest one; the app's double-tap window (Compose `detectTapGestures`, the platform's
~300 ms timeout) is consistent with a stretched gap.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l59
unset GRANTIVA_API_KEY
rm -rf /tmp/l59 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l59 && cd /tmp/l59/android
SERIAL=$(grantiva emulator ensure --name fix-l59)          # default config: software rendering
grantiva build install --device "$SERIAL" --no-launch
for i in 1 2 3 4 5 6 7 8 9 10; do
  adb -s "$SERIAL" shell getevent -lt > /tmp/l59/getevent-$i.txt 2>&1 &
  GE=$!
  grantiva run --device "$SERIAL" --no-build --flow .maestro/coverage/03-gesture-lab-taps.yaml --report-dir /tmp/l59/r$i > /tmp/l59/r$i.txt 2>&1
  kill $GE
  grep -a -E 'doubleTapOn|Double taps' /tmp/l59/r$i.txt | head -2; grep -a '/actions' /tmp/l59/r$i/client.log | cut -c1-120
done
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l59
```
`getevent -lt` shows whether the injected events reach the input device with the planned 40 / 80 / 40 ms spacing or
stretched; injected events from UiAutomation may not appear there, in which case
`adb shell dumpsys input` (recent events) or a temporary `onTouchEvent` log in the demo's Gesture Lab gives the
`MotionEvent.getEventTime()` values the app compares.

## Evidence
- findings/evidence/round3-smoke/A-doubletap/commands.txt, dt-1..5.txt, dt-1..5-client.log,
  dt-1..5-maestro-runner.log, dt-1..5-flow-000.json
- findings/evidence/round3-smoke/I-doubletap/ (iOS comparison)

## Suspected cause
Runner, grantiva/main 2d1b625. The runner side is confirmed; the device side is an inference to verify.
- `doubleTapOn` resolves the element (or the point) and calls `doubleTap` (`pkg/driver/uiautomator2/commands.go:
  171-213`), which sends one W3C sequence through `DoubleClick` (`pkg/uiautomator2/gestures.go:41-67`): one round trip,
  so the gap is not stretched by two requests. The comment at gestures.go:41-46 says the fixed pauses hold "however
  slow the device is"; the smoke shows they do not.
- The UIAutomator2 server replays the sequence by injecting each MotionEvent in turn and sleeping for the pauses
  between them. If each injection is synchronous (waits until the event is dispatched) and stamped with the current
  clock, a busy UI thread on a software-rendered AVD (the app redraws `Taps: N` after the first up) delays the second
  down; the app's detector compares event times, so it sees a gap above its double-tap timeout. 0.7-1.3 s for 160 ms
  of pauses fits that. Not traced on the device.
- Nothing checks the outcome: the step passes on the server's 200.

## Acceptance criteria
- On the default `emulator ensure` AVD at load 7-15, the repro passes 10 of 10 (`Double taps: 1`, `Taps` unchanged by
  the double tap); iOS unchanged; `doubleTapOn` with `point:` (L33) the same.
- The gap the app sees is fixed on the device, not by the speed of injection. Candidates, in order of preference
  (say which in the PR, with the event times from the repro as proof):
  (a) the two taps' MotionEvents carry planned event times (down at t, up at t+40, down at t+120, up at t+160, sharing
  the same base) so the detector sees an 80 ms gap however late each is delivered, e.g. a server-side double tap that
  builds the events up front and injects them asynchronously;
  (b) the server's own double-click on the element if, measured, it lands the second down inside the window on this
  AVD (L32 measured 1.05-1.22 s for it in round 2, so this needs new evidence);
  (c) a shell-side injection that runs entirely on the device in one command (for example
  `input motionevent DOWN/UP` pairs in one `adb shell`, or `sendevent` on the emulator's touch device), only if (a)
  is not possible and the measured gap stays under 150 ms.
- The runner log records the gap actually achieved when it can be measured (or the method used), and the
  gestures.go comment states what is and is not guaranteed.
- Runner tests in `pkg/uiautomator2` (next to `TestDoubleClickSendsOnePointerSequence`, double_tap_test.go:91): the
  request body for the chosen mechanism carries the planned timing; and a driver test where the fake server takes
  1 s to answer still produces one double-tap request (no per-tap round trips).
