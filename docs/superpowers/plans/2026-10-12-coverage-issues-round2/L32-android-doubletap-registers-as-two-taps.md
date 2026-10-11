# On Android `doubleTapOn` passes but the app sees two single taps, because the server's double-click gesture lands its taps more than the double-tap timeout apart on the default AVD

Severity: wrong-result
Component: runner
Platforms: android. **Confirmed on a quiet host** (fix round 1, load 7.5-10.8: 3 of 3); original run 3 of 3 at load 9-19. iOS passes (IOS-210 [ios]: `Double taps: 1`, Taps unchanged).
Rows: AND-210 [android], AND-210 rerun [android]
Regresses/extends: new. Same UIAutomator2 gesture-robustness family as K06-K09 (runner #19); round 1 passed this row.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
`doubleTapOn: {id: "gesture-pad"}` on Gesture Lab gives `Double taps: 1` and leaves `Taps` at its prior value (README:172
lists `doubleTapOn`; the coverage flow `.maestro/coverage/03-gesture-lab-taps.yaml` asserts `Double taps: 1`, then
`Taps: 1`). A step that reports success has performed the gesture it names.

## Actual
6 of 6 runs (3 original, 3 fix-round): the step passes in 1.3-1.6 s, then `assertVisible "Double taps: 1"` fails with
`"Double taps: 0", "Taps: 3"` on screen, i.e. the double tap counted as two single taps. The server's
`/appium/gestures/double_click` took 1.05-1.22 s in every run (client.log). findings/evidence/cov2-android/CF-rr-gest-1/run.err:33-37
and report/client.log:32:
```
    ✓ tapOn: id="gesture-pad" (605ms)
    ✓ assertVisible: text="Taps: 1" (622ms)
    ✓ doubleTapOn: id="gesture-pad" (1.3s)
    ✗ assertVisible: text="Double taps: 1" (17.6s)
      ╰─ Element not visible: text='Double taps: 1' (cause: context deadline exceeded: no such element: An element could not be located on the page using the given search parameters; closest on-screen texts: "Double taps: 0", "Taps: 3", "Last tap: center")
14:09:42.725942 POST /session/983577e2-5794-4cf4-9154-bf228b30a1b2/appium/gestures/double_click [1.046056875s] OK body={"origin":{"ELEMENT":"00000000-0000-007c-0000-00d200000004"}}
```
| run | load (1-min) | step | double_click |
|---|---|---|---|
| CF-03-gesture-lab-taps | 9.1 | 1.4 s | 1.11 s |
| CF-03-gesture-lab-taps-r2 | 19.3 | 1.4 s | 1.16 s |
| CF-03-gesture-lab-taps-r3 | 12.7 | 1.4 s | 1.17 s |
| CF-rr-gest-1 | 10.8 | 1.3 s | 1.05 s |
| CF-rr-gest-2 | 7.5 | 1.3 s | 1.12 s |
| CF-rr-gest-3 | 9.6 | 1.6 s | 1.22 s |

The default `emulator ensure` AVD renders in software (`hw.gpu.enabled=no`, AND-001/02.out).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l32
unset GRANTIVA_API_KEY
rm -rf /tmp/l32 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l32 && cd /tmp/l32/android
sed -i '' 's/^emulator: .*/emulator: fix-l32/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-l32)
grantiva build install --device "$SERIAL" --no-launch
for i in 1 2 3; do
  grantiva run --device "$SERIAL" --no-build --flow .maestro/coverage/03-gesture-lab-taps.yaml --report-dir /tmp/l32/r$i > /tmp/l32/r$i.txt 2>&1
  grep -a -E 'doubleTapOn|Double taps' /tmp/l32/r$i.txt | head -3; grep -a double_click /tmp/l32/r$i/client.log
done
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l32
```
The flow (landmarks-demo b3f046f, `.maestro/coverage/03-gesture-lab-taps.yaml`):
```yaml
appId: com.kylebrowning.landmarks
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Gesture Lab"
- assertVisible: "Taps: 0"
- tapOn:
    id: "gesture-pad"
- assertVisible: "Taps: 1"
- doubleTapOn:
    id: "gesture-pad"
- assertVisible: "Double taps: 1"
```

## Evidence
- findings/evidence/cov2-android/CF-03-gesture-lab-taps/, CF-03-gesture-lab-taps-r2/, CF-03-gesture-lab-taps-r3/ (run.err, report/client.log)
- findings/evidence/cov2-android/CF-rr-gest-1/, CF-rr-gest-2/, CF-rr-gest-3/ (fix round 1)
- findings/evidence/cov2-android/AND-210/commands.txt, AND-210/rerun/commands.txt (pointers)
- findings/evidence/cov2-android/AND-001/02.out (AVD GPU config)

## Suspected cause
Runner (release-round2b, 1be68db).
- `pkg/driver/uiautomator2/commands.go:148-178` (`doubleTapOn`): an element match goes to `DoubleClickElement`
  (`:172`), a coordinate match to `DoubleClick` (`:168`).
- `pkg/uiautomator2/gestures.go:42-58`: both send the server's `/appium/gestures/double_click`, leaving the timing of
  the two taps to the server. The app detects the gesture with Compose `detectTapGestures(onDoubleTap = …)`
  (landmarks-demo `ui/GestureLabScreen.kt:56-57`), whose double-tap timeout is the platform's ~300 ms. A 1.05-1.22 s
  server-side gesture on the software-rendered AVD is consistent with the second down arriving after that window, so
  the app sees two taps. Not confirmed with a pointer trace (`adb shell getevent -lt` during the step would settle it).
- The runner already sends explicit W3C pointer sequences for drags (`DragAndDrop`, `gestures.go:126-165`, POST
  `/actions`), so a double tap with a fixed, short inter-tap gap is available without the server's gesture.
- Nothing checks the outcome: the step passes on the server's 200.

## Acceptance criteria
- On the default `emulator ensure` AVD (software rendering), the flow above passes 10 of 10: `Double taps: 1` and
  `Taps: 1` after the step.
- `doubleTapOn` with `point:` and with a relative selector gets the same timing (both go through coordinates).
- The two taps are sent as one W3C `/actions` pointer sequence (down/up, pause ≤ 100 ms, down/up, each press ≤ 50 ms)
  or an equivalent whose inter-tap gap does not depend on device speed; the runner log records the gap used.
- Runner test in `pkg/uiautomator2` (next to `gestures_test.go:371`, which already decodes `/actions` bodies):
  `DoubleClick(x, y)` posts one `/actions` body with two pointerDown/pointerUp pairs at (x, y) and a pause under the
  double-tap timeout between them, and no request to `/appium/gestures/double_click`; same for `DoubleClickElement`
  after resolving the element's centre.
