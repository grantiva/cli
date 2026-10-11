# On Android four bare scrolls land on a different landmark per AVD: the held-drag distance depends on device speed

Severity: wrong-result
Component: runner
Platforms: android (Android-only: UIAutomator2 held-drag bare scroll from #19; iOS 10-seed-many passes)
Rows: round2-A-K07, round2b-A-K07; also round2-A1 (10-seed-many fails in the stock set without 03-edit)
Binary: grantiva 2.1.0 (main 5eab55d), grantiva-runner 1.1.28-grantiva.10

## Expected
After K07, a bare `scroll` moves the list by a fixed, device-independent amount (one drag across the middle half of
the screen), so `launchApp` + four `scroll`s in 10-seed-many (`LANDMARKS_SEED: many`) lands on the same rows on every
API 35 AVD, and the demo flow's `assertVisible: "Landmark 28"` (landmarks-demo b3f046f, set from the fix wave's device
check) passes wherever that check passed.

## Actual
Deterministic per AVD, different between AVDs. On the smoke AVDs (software rendering: `hw.gpu.enabled=no`, resolved
to lavapipe/SwiftShader) the list shows Landmark 14-22 after four scrolls in 3 of 3 runs (round2b) and 2 of 2 (round2);
the fix wave's device check (fresh AVD fix2-2-android, API 35, headless, GPU setting not recorded) showed first visible
20, last 28-29 in 6 of 6. Row pitch is 189 px on the 1080x2400 screen, so the 6-row gap is ~1134 px, about one whole
1200 px drag. round2b-A-K07/run-1.txt:33-38 and run-1-client.log (drag requests):
```
    ✓ scroll: DOWN (2.8s)
    ✓ scroll: DOWN (8.2s, slow)
    ✓ scroll: DOWN (5.8s, slow)
    ✓ scroll: DOWN (8.9s, slow)
    ✗ assertVisible: text="Landmark 28" (19.0s)
      ╰─ Element not visible: text='Landmark 28' (cause: ... closest on-screen texts: "Landmark 20", "Landmark 21", "Landmark 22")
POST .../actions [836.991959ms] OK body={"text":"<redacted>"}
POST .../actions [4.723564958s] OK ...   POST .../actions [4.00545825s] OK ...   POST .../actions [7.250209209s] OK ...
```
The nominal gesture is 300 ms of movement plus a 250 ms hold, yet the server took 0.8-7.3 s to perform it: on this AVD
the drag is injected far slower than requested, and the content moved less. In the stock set (round2-A1/run-without-03.txt:215-216)
the closest texts were "Landmarks", "Mono Lake", "Lake Tahoe" (unseeded list; screenshot failure-10-seed-many.png).
Side note: the client log redacts every `/actions` body as `{"text":"<redacted>"}`, pointer drags included, which hides
the drag coordinates needed to debug this.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l03
unset GRANTIVA_API_KEY
rm -rf /tmp/l03 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l03 && cd /tmp/l03/android
measure() {  # $1 = serial, $2 = label
  grantiva build install --device "$1"
  for i in 1 2 3; do
    grantiva run --device "$1" --no-build --flow .maestro/10-seed-many.yaml --snapshot full --report-dir /tmp/l03/$2-$i > /tmp/l03/$2-$i.txt 2>&1
    grep -o 'text="Landmark [0-9]*"' /tmp/l03/$2-$i/assets/flow-000/cmd-005-hierarchy.xml | sort -t' ' -k2 -n | sed -n '1p;$p'
  done
}
SW=$(grantiva emulator ensure --name fix-l03-sw); measure "$SW" sw          # default: hw.gpu.enabled=no -> lavapipe
grantiva emulator teardown --serial "$SW"
G0=$(grantiva emulator ensure --name fix-l03-gpu); grantiva emulator teardown --serial "$G0"   # create the AVD, then stop it
sed -i '' -e 's/^hw.gpu.enabled=.*/hw.gpu.enabled=yes/' -e 's/^hw.gpu.mode=.*/hw.gpu.mode=host/' ~/.android/avd/fix-l03-gpu.avd/config.ini
GPU=$(grantiva emulator ensure --name fix-l03-gpu); measure "$GPU" gpu     # reuses the AVD; hw.gpu.mode=host
grantiva emulator teardown --serial "$GPU"; avdmanager delete avd -n fix-l03-sw; avdmanager delete avd -n fix-l03-gpu
```
Today: sw lands on 14..22 every run; compare gpu. (`emulator ensure` passes no GPU option, Sources/GrantivaCore/Android/EmulatorManager.swift:228-232 at 5eab55d,
so the GPU AVD needs the config.ini edit; confirm with `adb shell dumpsys SurfaceFlinger | grep GLES`.)

## Evidence
- findings/evidence/round2-smoke/round2b-A-K07/run-1..3.txt, run-<i>-client.log (lines 9, 14, 20, 25), run-<i>-cmd-005-hierarchy.xml
- findings/evidence/round2-smoke/round2-A-K07/run-1.txt, run-2.txt, run-1-maestro-runner.log, run-1-report.json
- findings/evidence/round2-smoke/round2-A1/run-without-03.txt:215, failure-10-seed-many.png
- findings/evidence/round2-smoke/round2b-A0/ensure.txt (GPU facts)
- .superpowers/sdd/2026-10-11-round2-fix-wave/task-2-report.md:39, :66 (fix-wave device check: 20..28-29)
- Related: docs/superpowers/plans/2026-10-11-coverage-issues/K07-bare-scroll-distance-nondeterministic.md

## Suspected cause
Runner (release-round2, 56224e1). Not confirmed on device.
- `pkg/driver/uiautomator2/commands.go:818-830` (`scroll`, no engine): drag from `scrollPointsInRect(..., 0.5)`
  (commands.go:1067, ±600 px around the screen centre) with `DragAndDrop(fromX, fromY, toX, toY, 0, 300)`
  (`scrollDurationMs`, commands.go:1003), with `waitForScrollSettle` (2 s cap, commands.go:833-858) before and after.
- `pkg/uiautomator2/gestures.go:126-162` (`DragAndDrop`): pointerDown with a 0 ms hold, 20 `pointerMove`s of 15 ms each,
  250 ms pause, pointerUp, all in one `POST /actions`. The distance the list moves is whatever the app's gesture
  handling makes of those events as delivered. When injection runs 10-20x slower than requested (4-7 s for a 550 ms
  gesture), hypotheses: moves arrive coalesced or late and part of the travel is spent inside touch slop or lost to the
  list's own gesture detection; on a fast device the release after the 250 ms hold may still carry residual velocity
  and add distance. Either way the outcome depends on frame pacing, not only on the coordinates.
- The 6-row (~one drag) gap could also be one of the four drags being mostly lost (e.g. the first, 837 ms, issued while
  the seeded list was still laying out after launch). Capturing the hierarchy after each scroll on both AVDs separates the
  two (per-drag loss vs one lost drag).

## Acceptance criteria
- A bare `scroll` moves the scrollable content by a fixed, device-independent fraction of the scrollable area (for
  example its height minus a fixed overlap), independent of how long the device takes to perform the drag; the runner
  verifies the move (content offset or first-visible row changed by the expected amount, within one row) and corrects
  or reports a short scroll rather than silently under-scrolling.
- 10-seed-many lands on the same last-visible landmark (±1) on a software-rendered AVD (`emulator ensure` defaults,
  lavapipe) and on a GPU AVD (`hw.gpu.mode=host`), 3 of 3 runs each; the landmarks-demo Android flow target is then set
  once from that landing and passes on both.
- Each scroll's per-step hierarchy shows a constant row advance across the four scrolls (no scroll moves less than the
  others by more than one row).
- The client log keeps pointer-action coordinates (redact only key-action text).
- Runner tests in pkg/driver/uiautomator2 (next to bare_scroll_test.go / scroll_rect_test.go): a fake whose page
  source advances by half the requested travel makes the scroll top up (or fail with a message naming the short
  scroll), and the drag geometry for a 1080x2400 screen with a [0,432][1080,2064] list is asserted; pkg/uiautomator2
  (gestures_test.go): the logged body of a pointer `/actions` request is not redacted.
