# On Android `scrollUntilVisible` scrolls with a device-dependent `input swipe` fling, so on the default AVD 20 scrolls can fall short of a row that a faster device reaches

Severity: wrong-result
Component: runner
Platforms: android. **Confirmed on a quiet host, flaky** (fix round 1, load 8.1-11.3: 1 of 3 fail); original 2 of 2 fail (load 6.5-10.9). iOS passes its 08-scroll half.
Rows: AND-224 [android], AND-224 rerun [android] (08-scroll is also reached by AND-038 [android], which passed its own criterion)
Regresses/extends: extends L03 (docs/superpowers/plans/2026-10-12-coverage-issues-round2/L03-android-scroll-distance-device-dependent.md), fixed for bare `scroll` in runner #20 (bundled in #199). `scrollUntilVisible` was outside L03's scope.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
`scrollUntilVisible: {element: "Landmark 70", direction: DOWN, timeout: 60000}` after one bare scroll finds the row on
the default `emulator ensure` AVD, as it did in round 1 and as runs 2-3 of the fix round do (README:172). The number of
scrolls a step needs does not depend on how fast the device injects a gesture.

## Actual
5 runs, 3 fail with `Element not found after 20 scrolls` before the 60 s timeout:

| run | load (1-min) | bare `scroll` | `scrollUntilVisible "Landmark 70"` |
|---|---|---|---|
| CF-08-scroll | 10.9 | 13.5 s | ✗ 49.8 s, after 20 scrolls |
| CF-08-scroll-r2 | 6.5 | 14.0 s | ✗ 52.2 s, after 20 scrolls |
| CF-rr-scroll-1 | 8.1 | 16.5 s | ✗ 53.5 s, after 20 scrolls |
| CF-rr-scroll-2 | 10.4 | 14.8 s | ✓ 26.2 s |
| CF-rr-scroll-3 | 11.3 | 1.6 s | ✓ 17.5 s |

findings/evidence/cov2-android/CF-rr-scroll-1/report/maestro-runner.log:24-29:
```
14:12:23.508112 [INFO] scroll down: dragged 1200 px in {0 316 1080 1748}, content moved 1179 px (measured=true)
14:12:23.508209 [DEBUG] Step 1 completed successfully (16455ms): scroll: DOWN
14:12:23.509388 [DEBUG] Executing step 2: scrollUntilVisible: text="Landmark 70"
14:13:17.002118 [ERROR] Step 2 failed (53492ms): scrollUntilVisible: text="Landmark 70" - Error: Element not found after 20 scrolls (cause: element not found)
```
The bare scroll (L03 path) logs its measured travel; the `scrollUntilVisible` gestures log nothing. The slice noted that
the last hierarchy of the original failures reached only Landmark 55 of 70 (the hierarchy itself was not kept).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l34
unset GRANTIVA_API_KEY
rm -rf /tmp/l34 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l34 && cd /tmp/l34/android
sed -i '' 's/^emulator: .*/emulator: fix-l34/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-l34)
grantiva build install --device "$SERIAL" --no-launch
for i in 1 2 3 4 5; do
  grantiva run --device "$SERIAL" --no-build --flow .maestro/coverage/08-scroll.yaml --report-dir /tmp/l34/r$i > /tmp/l34/r$i.txt 2>&1
  grep -a -E 'scrollUntilVisible: text="Landmark 70"' /tmp/l34/r$i.txt | head -1
done
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l34
```
The flow (landmarks-demo b3f046f, `.maestro/coverage/08-scroll.yaml`, first steps):
```yaml
appId: com.kylebrowning.landmarks
env:
  LANDMARKS_SEED: many
---
- launchApp
- scroll
- scrollUntilVisible:
    element: "Landmark 70"
    direction: DOWN
    timeout: 60000
- assertVisible: "Landmark 70"
```

## Evidence
- findings/evidence/cov2-android/CF-08-scroll/, CF-08-scroll-r2/ (original), CF-rr-scroll-1/, CF-rr-scroll-2/, CF-rr-scroll-3/ (fix round): run.err, report/maestro-runner.log, report/client.log
- findings/evidence/cov2-android/AND-224/commands.txt, AND-224/rerun/commands.txt (pointers)

## Suspected cause
Runner (release-round2b, 1be68db), `pkg/driver/uiautomator2/commands.go`.
- `scrollUntilVisible` (`:972-1074`) caps the loop at `maxScrolls := 20` (`:978`) whatever the step's `timeout`, and
  each iteration scrolls with `performScroll(direction, width, height, step.Engine, 0.3, scrollMs)` (`:1062`) or
  `performScrollInRect` (`:1060`).
- With the default engine, `performScroll` (`:1089-1100`) goes to `scrollByAdbInRect` (`:1130-1135`):
  `input swipe x y x y 300`, a lift-while-moving fling. K07 (runner #19) and L03 (runner #20) replaced exactly this
  gesture for bare `scroll` because how far the content coasts depends on the device; the bare path now drags with a
  hold (`DragAndDrop`) and measures the move with `contentShift`/`scrollTopUp` (`bare_scroll.go:78`, `:145`, `:220`).
  None of that is used here.
- Nothing logs how far each `scrollUntilVisible` gesture moved the list, so a short run is invisible in the runner log.

## Acceptance criteria
- On the default `emulator ensure` AVD (software rendering) the repro passes 5 of 5: Landmark 70 found, then Golden
  Gate Bridge found scrolling UP, each within the flow's 60 s timeout.
- `scrollUntilVisible` moves the content by a device-independent distance per scroll: it uses the held drag of the bare
  scroll path (or measures each move from the page source and tops up a short one, as L03 does), and logs
  `dragged N px, content moved M px` per scroll like `scroll` does.
- An explicit `engine: adb` / `engine: agent` keeps its current gesture, as for bare `scroll`.
- Without an explicit `maxScrolls`, the loop ends on the step's timeout or on `ScrollProgress` reporting no movement,
  not after a fixed 20 scrolls; an explicit `maxScrolls` is still honoured.
- Runner tests in `pkg/driver/uiautomator2` (next to `bare_scroll_test.go` / `scroll_rect_test.go`): a fake device whose
  list moves half the dragged distance per gesture still reaches a row 60 rows down within the timeout; with
  `maxScrolls` unset and a list that keeps moving, the step does not stop at 20 scrolls.
