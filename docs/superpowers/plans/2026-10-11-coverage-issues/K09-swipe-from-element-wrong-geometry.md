# Android `swipe {direction: LEFT, from: <element>}` starts at the element's far side and covers only a quarter of the row

Severity: wrong-result
Component: runner
Platforms: android (Android-only: iOS twin IOS-217 passed)
Rows: B-R02.1, B-A02.2 (android); original briefs R02 (2026-10-10 regression, criterion 1) and A02 (QA campaign, criterion 2)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9
Triage note: the observed geometry is the runner's deliberate R02 rule, not an accident. `SwipeCoordsToScreenEdge`
(pkg/core/gesture.go:149-196) documents that when the element's centre is within a quarter screen of the target edge
the swipe starts at 90% across the element "deliberately unlike a pure centre-start rule", measured as opening the row
10 of 10 times. The row does open in both rows' runs. The briefs' criteria (A02: start at the element centre; R02:
trace runs most of the row's width and, in R02's runner-test criterion, travels at least a `60%`→`5%` swipe) contradict
that rule. The orchestrator should either correct the two brief criteria to the shipped rule or keep this as a runner
defect; the brief below is written as the defect.

## Expected
- Brief A02 criterion 2 (matrix B-A02.2): `from:` maps to the swipe selector with Maestro semantics: the swipe starts at
  the element centre.
- Brief R02 criterion 1 (matrix B-R02.1): `c-direction-left-from.yaml` passes, the After capture shows the row opened,
  and the pointer trace runs most of the row's width. R02's runner-test criterion: an element swipe LEFT from an element
  centred at x=155 on a 1080 px screen travels at least the distance of a `60%`→`5%` coordinate swipe (594 px).

## Actual
The flow passes and the row opens (B-R02.1/01.out: `✓ swipe: LEFT (396ms)`, `✓ assertNotVisible: text="Lake Tahoe"`),
but with pointer location on, the trace in the After capture runs from x≈241 px to the screen edge at y=500, about
241 px of a 1080 px row (B-R02.1/after-full.png; crop after-small.png). The Lake Tahoe text node is `[42,469][269,532]`,
centre (155,500), so the start is not the centre; it is 90% across the element (42 + 0.9×227 ≈ 246). Same in flow 02
(B-R02.2/cmd-008-after-full.png). No client.log request carries the gesture: it is an `adb shell input swipe`
(B-R02.2/client.log shows only the element lookups and taps). 1 of 1 runs each.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k09
unset GRANTIVA_API_KEY
rm -rf /tmp/k09 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k09 && cd /tmp/k09/android
SERIAL=$(grantiva emulator ensure --name fix-k09)
grantiva build install --device "$SERIAL" --no-launch
cat > /tmp/k09/c-direction-left-from.yaml <<'YAML'
appId: com.kylebrowning.landmarks
---
- launchApp
- tapOn: "Lake Tahoe"
- tapOn: "Favorite"
- assertVisible: "Unfavorite"
- tapOn: "Landmarks"
- tapOn: "Favorites"
- assertVisible: "Lake Tahoe"
- takeScreenshot: "Before"
- swipe:
    direction: LEFT
    from: "Lake Tahoe"
- waitForAnimationToEnd
- takeScreenshot: "After"
- assertNotVisible: "Lake Tahoe"
YAML
adb -s "$SERIAL" shell settings put system pointer_location 1
grantiva run --device "$SERIAL" --no-build --flow /tmp/k09/c-direction-left-from.yaml --report-dir /tmp/k09/out; echo "exit $?"
open /tmp/k09/out/assets/flow-000/*After*.png      # trace at y≈500 starts near x=241, ends at x=0
adb -s "$SERIAL" shell settings put system pointer_location 0
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k09
```

## Evidence
- findings/evidence/cov-android/B-R02.1/01.out, 01.err, commands.txt, c-direction-left-from.yaml
- findings/evidence/cov-android/B-R02.1/after-full.png (unmodified capture), after-small.png (crop, rows 300-900)
- findings/evidence/cov-android/B-R02.2/cmd-008-after-full.png, client.log, 01.out (flow 02 with `--snapshot full`)
- Bounds source: findings/evidence/android/A02/probes/d-hierarchy-before.xml (regression worktree; Lake Tahoe `[42,469][269,532]`)
- Row pointer: findings/evidence/cov-android/B-A02.2/commands.txt

## Suspected cause
Runner (release-round1, ae48e34):
- `pkg/driver/uiautomator2/commands.go:1106-1124` resolves the element and calls `core.SwipeCoordsForElement` with no
  `point` and no `distance`, which goes to `SwipeCoordsToScreenEdge` (pkg/core/gesture.go:215-219).
- `pkg/core/gesture.go:183-187`: for `left`, when the centre is within `screenW/4` of the left edge (155 < 270), the
  start moves to `b.X + b.Width*9/10` (≈246) and the end is x=0. The travel is therefore the element's 90% width
  (≈246 px), far below R02's 594 px floor and not a centre start.
- The direction-only path (`swipeWithMaestroCoordinates`, commands.go:1195-1227) runs 90%→10% of the screen, which is
  what "most of the row's width" refers to.

## Acceptance criteria
Pick one, record it in the runner's gesture.go comment and in the brief corrections:
- (Runner change) The repro's trace starts inside the Lake Tahoe text bounds (A02) and travels at least 594 px
  (R02), e.g. start at the element centre and end at 5% of the screen, still clamped on-screen; the row opens 10 of 10
  runs; flow 02 still passes 12/12 in the stock set; iOS 02-favorite still passes.
- (Brief correction) The A02.2 and R02.1 criteria are rewritten to "starts inside the element, ends at the screen edge,
  row opens", and this brief is closed as a matrix correction.
- Either way: runner test in pkg/core (`SwipeCoordsToScreenEdge` / `SwipeCoordsForElement`) pins the start point and the
  travel for an element at `[42,469][269,532]` on a 1080x2400 screen.
