# On the default Android AVD a launch-only screen (`path: launch`) is captured blank, because the generated flow's only wait before the shot is a static-screen check that a not-yet-drawn app passes at once

Severity: wrong-result
Component: cli
Platforms: android. **Confirmed on a quiet host** (fix round 1, load 7.2-7.8: 3 of 3 blank, 19.3 KB); original run blank in every CLI capture while the AVD was slow (load 14-41). iOS not affected in this pass.
Rows: N-12 [android], N-12 rerun [android], AND2-OBS-02 [android], AND2-OBS-02 rerun [android] (also seen in AND-108 and AND-142, which passed their own criteria)
Regresses/extends: new. Related to M17 (WDA `waitForAnimationToEnd` passes on a dead app): the settle wait is fooled by a static screen.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
README screens section: `launch` — "screenshot immediately after app launch", and "before every screenshot, it waits
(up to 5 s) for the screen to stop changing, so a capture never shows the screen it is leaving". The first screen is
captured after the app has drawn it. N-12: a session capture (MCP `grantiva_vrt_capture`) and a CLI `diff capture` of the
same screens pass `diff compare` against each other.

## Actual
- Fix round 1 (findings/evidence/cov2-android/FIX1-home/, app force-stopped first, three `diff capture --no-build` runs):
  Home is 19.3 KB each time and shows only the status bar and an empty window (home1-3-small.png); the other screens
  are 52.8-123.9 KB. cap1.out:
```
    ✓ launchApp (4.0s)
    ✓ waitForAnimationToEnd (2.0s)
    ✓ takeScreenshot (512ms)
  • Home (19.3 KB)
  • Favorites (52.8 KB)
  • Deep Links (123.9 KB)
```
- N-12 (session captures as baseline, CLI capture as current; findings/evidence/cov2-android/N-12/01.out):
```
✗ Home  pixel=99.90%  perceptual=6.2
```
  Deep Links, Detail, Favorites and Lakes pass at 0.00%; session-Home.png shows the list, cli-Home.png (20.3 KB) is blank.
- Same blank Home in AND-108, the stock `run` screens (Home.png 20850 B) and the flow-format `Home Swiped`. Later,
  once the AVD ran faster, Home was 122 KB (B-A04.1).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l44
unset GRANTIVA_API_KEY
rm -rf /tmp/l44 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l44 && cd /tmp/l44/android
sed -i '' 's/^emulator: .*/emulator: fix-l44/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-l44)
grantiva build install --device "$SERIAL" --no-launch
for i in 1 2 3; do
  adb -s "$SERIAL" shell am force-stop com.kylebrowning.landmarks
  grantiva diff capture --device "$SERIAL" --no-build 2>&1 | grep -a -E '• (Home|Favorites)'
  cp .grantiva/captures/android/Home.png /tmp/l44/home$i.png
done
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l44
```
The repo's `grantiva-android.yml` has `- name: Home` / `path: launch` as its first screen. Open `/tmp/l44/home*.png`:
blank today; the Landmarks list after the fix.

## Evidence
- findings/evidence/cov2-android/FIX1-home/cap1-3.out, home1-3.png, home1-3-small.png, 01-03.cmd, commands.txt
- findings/evidence/cov2-android/N-12/01.out, cli-Home.png, cli-home-small.png, session-Home.png, commands.txt
- findings/evidence/cov2-android/N-12/rerun/commands.txt; findings/evidence/cov2-android/AND-108/, AND-142/

## Suspected cause
- `Sources/GrantivaCore/Runner/FlowGenerator.swift:51-60` emits `launchApp`; for a `launch` screen (no steps) the only
  thing between it and `takeScreenshot` is `appendSettle` (`:133-134`, defined at `:211-218`):
  `waitForAnimationToEnd` with `timeout: 5000`.
- The runner's `waitForAnimationToEnd` on UIAutomator2 (`pkg/driver/uiautomator2/commands.go:2457-2490`,
  `waitForScreenStatic`) returns as soon as two consecutive screenshots differ by ≤ 0.5%. An app window that has not
  drawn yet is static, so the wait ends after one pair (2.0 s here, ~1 s per software-rendered screenshot).
- The runner's `launchApp` confirms the launch once the process has been alive about 1 s (`confirmLaunch`,
  `pkg/driver/uiautomator2/commands.go:1609-1675`); it does not wait for the first frame.
- Why the session path draws in time was not established: `SessionCapture.captureScreens` uses the same kind of
  static-screen settle (`Sources/GrantivaMCP/Tools/SessionCapture.swift:138-141`, `:361-370`) but also reads selector
  rules before the shot (`:141`), which adds time.

## Acceptance criteria
- On the default `emulator ensure` AVD, the repro's Home capture shows the app's first screen 3 of 3 (size within 10% of a
  session capture of Home), and N-12 passes Home under the configured thresholds.
- The launch-only wait is an app-drawn condition, not only a static-screen check: e.g. after `launchApp`, wait (bounded,
  documented) until the hierarchy contains an element of the app's package, or until a static screen whose hierarchy
  includes the app; the same applies to the first screen after `launchApp` in a flow-format screens config.
- iOS output for launch-only screens is unchanged (same image), and the added wait costs < 1 s when the app is already
  drawn.
- README's `launch` bullet says what the capture waits for.
- Tests: GrantivaCoreTests/FlowGeneratorTests.swift (next to `testTapIsFollowedBySettleBeforeScreenshot`, `:135`): a
  `path: launch` screen generates the app-drawn wait between `launchApp` and `takeScreenshot` on Android (and whatever
  the fix chooses for iOS).
