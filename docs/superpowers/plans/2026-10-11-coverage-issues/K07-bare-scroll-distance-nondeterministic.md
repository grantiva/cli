# Android bare `scroll` travels a different distance on every run, so `10-seed-many` passes or fails by chance

Severity: wrong-result
Component: runner
Platforms: android (Android-only: iOS twin IOS-223 passed, Landmark 30 visible after four `scroll`s)
Rows: N-03, AND-223 (android); original brief C10 (QA campaign, via AND-223)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix N-03 / AND-223 (plan N03; README:172 lists `scroll`; brief C10): four bare `scroll`s in
`.maestro/10-seed-many.yaml` (seed `many`) leave `Landmark 30` visible, on a fresh and on a warm AVD, with or without
`--snapshot full`. The underlying requirement is that one `scroll` moves the list by a repeatable amount: the same
flow on the same device must not land in a different place each run. (The "Landmark 30" target is calibrated to
the distance iOS scrolls; if Android's repeatable distance differs, the flow's assert may need its own Android value,
but the spread below is the defect.)

## Actual
Last landmark fully visible after the four scrolls (N-03/01.out, 02.out, commands.txt note):
| device / mode | runs | last landmark | result |
|---|---|---|---|
| cov-android (warm), default | a1, a2, a3 | 33, 32, 33 | pass |
| cov-android, `--snapshot full` | f1, f2 | 47, 48 | fail (Landmark 30 scrolled off) |
| cov-android-2 (fresh AVD), default | run 1, run 2 | 27, 33 | fail, pass |
| cov-android-2, `--snapshot full` | 1 | 49 | fail |

```
assert failed visible-after-fail (39, 47)
assert failed visible-after-fail (40, 48)
assert failed visible-after-fail (19, 27)
assert passed visible-after-fail -
assert failed visible-after-fail (41, 49)
```
(pairs are the first and last landmark numbers in the failure hierarchy). 7 runs: 3 fail with overshoot, 1 with
undershoot, 3 pass. AND-223 reports the same range (19-27 on a fresh AVD's first run, 39-49 with `--snapshot full`);
AND-120 also landed at 48.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k07
unset GRANTIVA_API_KEY
rm -rf /tmp/k07 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k07 && cd /tmp/k07/android
SERIAL=$(grantiva emulator ensure --name fix-k07)       # fresh AVD
grantiva build install --device "$SERIAL" --no-launch
for i in 1 2 3; do grantiva run --device "$SERIAL" --no-build --flow .maestro/10-seed-many.yaml --report-dir /tmp/k07/d$i >/dev/null 2>&1; echo "default $i exit $?"; done
for i in 1 2; do grantiva run --device "$SERIAL" --no-build --flow .maestro/10-seed-many.yaml --snapshot full --report-dir /tmp/k07/f$i >/dev/null 2>&1; echo "full $i exit $?"; done
ls /tmp/k07/*/assets/flow-000/*Scrolled*.png 2>/dev/null   # the Scrolled capture shows where each run stopped
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k07
```
Flow `.maestro/10-seed-many.yaml`:
```
appId: com.kylebrowning.landmarks
env:
  LANDMARKS_SEED: many
---
- launchApp
- scroll
- scroll
- scroll
- scroll
- assertVisible: "Landmark 30"
- takeScreenshot: "Scrolled"
```

## Evidence
- findings/evidence/cov-android/N-03/01.out, 02.out, commands.txt (including the note on the passing runs' Scrolled captures)
- findings/evidence/cov-android/N-03/passing-runs-scrolled-montage.png
- Helper used: findings/evidence/cov-android/inputs/seedmany.sh
- Row pointer: findings/evidence/cov-android/AND-223/commands.txt
- iOS twin: findings/evidence/cov-ios/IOS-030/10-seed-many.* (IOS-223 pass)

## Suspected cause
Runner (release-round1, ae48e34); mechanism hypothesised, not confirmed:
- A bare `scroll` is `adb shell input swipe` over 50% of the screen height in 300 ms
  (pkg/driver/uiautomator2/commands.go:819-833 `scroll` → `performScroll` :990-1000 → `scrollByAdbInRect` :1031-1036,
  `scrollDurationMs = 300` at :980). 1200 px in 300 ms is a fling: the list keeps moving after the finger lifts, and how
  far it coasts depends on what the next step does and when.
- Default mode: the next `scroll` starts while the previous fling is still coasting, and the new touch stops it, so the
  total depends on step timing (fresh AVDs are slower, giving more or less coast). `--snapshot full` adds a hierarchy dump
  after each step, letting every fling run to its end, which is why it consistently overshoots (47-49).
- The iOS driver passes because its scroll is not a fling of this kind (IOS-223).
- Possible fixes: a slower swipe that does not fling (Maestro-style scroll duration), a hold before lift, or waiting for
  the list to settle after each scroll so every scroll contributes the same distance.

## Acceptance criteria
- Across 5 default runs and 2 `--snapshot full` runs on a freshly created AVD, plus 3 runs on a warm AVD, the last
  landmark visible after the four scrolls differs by at most 2, and `10-seed-many` passes in all 10.
- A single bare `scroll` on the Landmarks list moves it by the same amount (±5%) whether or not another step follows
  immediately.
- `scroll: DOWN` with `speed:` still honours the speed mapping (core.ScrollDurationOrDefault).
- iOS unchanged: IOS-223 and the iOS stock set still pass.
- Runner test: the bare-scroll gesture the UIAutomator2 driver issues has a duration and distance below the fling
  threshold chosen (or is followed by a settle wait); a table test pins the endpoints for a 1080x2400 screen.
