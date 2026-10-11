# On Android `doubleTapOn: {point: …}` (and by the same code `longPressOn: {point: …}`) fails at once with "no selector specified" instead of acting on the screen point

Severity: wrong-result
Component: runner
Platforms: android (1 of 1 run, load 9.6; logical, not load-related). iOS passes the same steps (FLOWS-26/27 in the iOS slice: `✓ doubleTapOn: point="50%,50%" (1.4s)`, `✓ longPressOn: point="50%,50%" (1.5s)`).
Rows: AND2-OBS-01 [android] (found while running B2-K01 [android], which passed on narration)
Regresses/extends: new.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
README:172 lists `point:` for taps. `tapOn: {point: "50%,50%"}` taps the screen point on Android (IOS-208/AND-208);
`doubleTapOn: {point: "50%,50%"}` double-taps it and `longPressOn: {point: "50%,50%"}` long-presses it, as on iOS.

## Actual
findings/evidence/cov2-android/CF-k01-point-gestures/run.err:29-33:
```
    ✓ launchApp (7.3s, slow)
    ✓ tapOn: text="Deep Links" (9.1s, slow)
    ✓ tapOn: text="Gesture Lab" (2.3s)
    ✗ doubleTapOn: point="50%,50%" (476ms)
      ╰─ Element not found: selector (cause: no selector specified)
```
The following `longPressOn: {point}` step was skipped, so it was not observed; the source takes the same path (below).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l33
unset GRANTIVA_API_KEY
rm -rf /tmp/l33 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l33 && cd /tmp/l33/android
sed -i '' 's/^emulator: .*/emulator: fix-l33/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-l33)
grantiva build install --device "$SERIAL" --no-launch
cat > /tmp/l33/point-gestures.yaml <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Gesture Lab"
- doubleTapOn:
    point: "50%,50%"
- assertVisible: "Double taps: 1"
- longPressOn:
    point: "50%,50%"
- assertVisible: "Long presses: 1"
YAML
grantiva run --device "$SERIAL" --no-build --flow /tmp/l33/point-gestures.yaml --report-dir /tmp/l33/r1 2>&1 | grep -a -E '✓|✗|╰'
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l33
```
(`50%,50%` lands on the Gesture Lab pad on the default Pixel 8 AVD; if the layout moves, use the pad's centre.)

## Evidence
- findings/evidence/cov2-android/CF-k01-point-gestures/run.err, commands.txt, report/
- findings/evidence/cov2-android/inputs/flows/k01-point-gestures.yaml (the flow as run)
- findings/cov2-android-results.md rows AND2-OBS-01 (fail) and B2-K01 (pass)

## Suspected cause
Runner (release-round2b, 1be68db), `pkg/driver/uiautomator2/commands.go`.
- `tapOn` handles a point-only step first: `:26-28` (`step.Point != "" && step.Selector.IsEmpty()` →
  `tapOnPointWithCoords`).
- `doubleTapOn` (`:148-178`) calls `findElementForTap` at `:155` before its point branch at `:163`. `longPressOn`
  (`:180`) does the same at `:187`.
- `Selector.IsEmpty()` (`pkg/flow/selector.go:222-245`) ignores `Point`, so a point-only selector is empty.
  `findElementForTap` (`driver.go:508-538`) falls through to strategy building, which returns
  `fmt.Errorf("no selector specified")` (`driver.go:1493`), and `elementFailure` reports it as "Element not found:
  selector".
- `resolveGesturePoint` (`commands.go:121-146`, used by `dragAndDrop`) already handles the empty-selector case with
  `screenSize` + `core.ParsePointCoords`; the same three lines are missing from `doubleTapOn` and `longPressOn`.

## Acceptance criteria
- The repro flow passes on Android: `Double taps: 1` after the point double tap, `Long presses: 1` after the point long
  press, with no element lookup in client.log for either step.
- A point with a selector (`doubleTapOn: {id: gesture-pad, point: "10%,10%"}`) still resolves relative to the element.
- An empty step (no selector, no point) still fails with a clear "no selector or point" message.
- Runner tests in `pkg/driver/uiautomator2` (e.g. `commands_test.go`): with a fake client whose `FindElement` fails the
  test if called, `doubleTapOn` with `Selector{Point: "50%,50%"}` on a 1080x2400 screen calls `DoubleClick(540, 1200)`
  once; `longPressOn` likewise calls `LongClick(540, 1200, 1000)`.
