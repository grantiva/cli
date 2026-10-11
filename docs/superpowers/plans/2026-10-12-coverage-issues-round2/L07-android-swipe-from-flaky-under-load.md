# On Android `swipe: {direction: LEFT, from: "Lake Tahoe"}` opened the row's swipe action in only 2 of 3 runs under host load, and the flow passes either way

Severity: wrong-result
Component: runner (follow-up in demo: landmarks-demo android/.maestro/02-favorite.yaml must be able to detect a missed swipe)
Platforms: android (the element swipe goes through `adb shell input swipe`; not checked on iOS)
Rows: round3-A2-K09 (smoke, runner .11); B2-K09 (matrix)
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
`swipe: {direction: LEFT, from: "Lake Tahoe"}` on a Favorites row opens the row's swipe action every time, whatever the
host load, because the gesture the device receives has the same distance, duration and velocity each time. A flow that
swipes a row open and then taps the revealed action fails if the swipe did not open the row.

## Actual
On a fresh software-rendered API 35 AVD (smoke3-android) with host load 7-16, the swipe opened the row in 2 of 3 runs.
In run 1 the before and after captures of the swipe step are identical, and so is the capture before the next step
(`dab5f51f` for cmd-008 before, cmd-008 after and cmd-009 before): the row did not move. Runs 2 and 3 differ after the
swipe (`a1884783`/`9794d551`, `dab5f51f`/`d39c4c26`) and show the red swipe "Remove" background. summary.txt:
```
run 1 load averages: 8.95 | ✓ swipe: LEFT from text="Lake Tahoe" (1.4s) | ✓ tapOn: text="Remove" (1.6s) | exit=0 | dab5f51f dab5f51f
run 2 load averages: 7.26 | ✓ swipe: LEFT from text="Lake Tahoe" (1.4s) | ✓ tapOn: text="Remove" (1.7s) | exit=0 | a1884783 9794d551
run 3 load averages: 7.02 | ✓ swipe: LEFT from text="Lake Tahoe" (1.4s) | ✓ tapOn: text="Remove" (1.7s) | exit=0 | dab5f51f d39c4c26
```
The failing run had the highest load of the three (one sample each, so this is a correlation, not a measurement).
All three runs exit 0: `tapOn: "Remove"` also matches the row's always-visible inline "Remove" text button, so a
missed swipe still ends with the favorite removed. The flow cannot tell the two cases apart.

For comparison: runner .10 (round 2 smoke, round2-A2-K09) opened the row 3 of 3, and the fix-wave device check
(K09) opened it 10 of 10, at lower host load (loads were not recorded for those runs).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l07
unset GRANTIVA_API_KEY
rm -rf /tmp/l07 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l07 && cd /tmp/l07/android
SER=$(grantiva emulator ensure --name fix-l07)          # default: software rendering
grantiva build install --device "$SER"
# generate host load >= 8 (for example one busy loop per core, plus a second emulator booting), then:
uptime
for i in $(seq 1 10); do
  grantiva run --device "$SER" --no-build --flow .maestro/02-favorite.yaml --snapshot full --report-dir /tmp/l07/r$i > /tmp/l07/r$i.txt 2>&1
  # compare the captures around the swipe step (cmd-008 before vs after): identical = the swipe did not open the row
  md5 -q /tmp/l07/r$i/assets/flow-000/cmd-008-before.png /tmp/l07/r$i/assets/flow-000/cmd-008-after.png | tr '\n' ' '; echo
done
uptime
grantiva emulator teardown --serial "$SER"; avdmanager delete avd -n fix-l07
```
Today: expect some runs with identical before/after hashes while every run exits 0. (The capture file names are those of
the smoke run; adjust to the report layout if they differ.)

## Evidence
- findings/round2-smoke.md, section "## Round 3 (runner .11)", row round3-A2-K09
- findings/evidence/round2-smoke/round3-A2-K09/summary.txt (loads, hashes), run1-cmd-008-before.png, run1-cmd-008-after.png,
  run1-cmd-009-before.png (identical), run<i>-cmd-008-{before,after}.png, run<i>-client.log, run<i>-maestro-runner.log
  (run1-maestro-runner.log: step 8 swipe started 09:37:46.97, completed 09:37:48.39, 1416 ms)
- findings/evidence/round2-smoke/round2-A2-K09/ (runner .10, 3 of 3)
- Note: the client log has no entry for the swipe (it is not a UIAutomator2 request, see below), so the log cannot show
  the gesture that was injected.

## Suspected cause
Runner (release-round2b, 1be68db). Not confirmed on device.
- The element swipe never uses the UIAutomator2 server. `swipe` (pkg/driver/uiautomator2/commands.go:1182) finds the
  element, calls `core.SwipeCoordsForElement` and then `swipeWithAbsoluteCoords` (commands.go:1356-1373), which runs
  `adb shell input swipe x1 y1 x2 y2 300` (300 ms when the step gives no duration). So the time the gesture takes and
  how its move events are paced depend on the `input` process (a JVM started per call) and on the device's CPU, which on a
  software-rendered AVD shares the loaded host. No hold before lift, no explicit pointer-event schedule.
- PR #20 (1be68db) did not change this path. Its commands.go diff only touches the bare `scroll` path (held drag via
  `d.client.DragAndDrop`, commands.go:863-890, from K07/L03); `scroll` with an explicit `engine` and the element swipe still
  use `input swipe`. The held-drag fix therefore does not cover `swipe: from:`.
- Geometry (pkg/core/gesture.go, `SwipeCoordsToScreenEdge`, ~line 167): for a left swipe whose centre is within a quarter of
  the screen of the left edge, the swipe starts at 90% across the element and runs to x=0. For "Lake Tahoe" that is
  246 -> 0, about 246 px in 300 ms. The comment records 10 of 10 on device, but also that 155 px opened it only 7 of 9, so
  the row's open threshold is close to this travel once touch slop is taken off. If the events are delivered late or
  coalesced under load, or the finger lifts while still moving, the travel the row sees can fall under the threshold.
  That the identical before/after captures show no movement at all (not a partial reveal) is consistent with either a
  lost gesture or a gesture treated as a tap/cancelled; which of the two is not established.
- Ruled out nothing by measurement; the load correlation rests on three runs.

## Acceptance criteria
- On the default software-rendered AVD at host load >= 8 (record `uptime` before and after the batch), `swipe: {direction:
  LEFT, from: "Lake Tahoe"}` opens the row in 10 of 10 runs of 02-favorite.yaml, judged by the swipe action being visible
  (or the before/after captures differing), not by the flow exiting 0.
- The element swipe is delivered through the UIAutomator2 server as one pointer-action sequence with an explicit duration
  and an explicit stationary hold before lift (like the bare `scroll` drag from #20), not through `input swipe`. Its
  duration and velocity do not depend on how long the host or device takes to start a process.
- The runner verifies or at least logs the gesture: the client log keeps pointer-action coordinates for the swipe
  (see L03 on `/actions` redaction), so a missed swipe can be debugged from the log.
- A fake-server test in pkg/driver/uiautomator2 (next to bare_scroll_test.go) asserts the parameters of the `/actions`
  request for `swipe: {direction: LEFT, from: <element>}` on a 1080x2400 screen with the element centred at x=155: start
  (246, y), end (0, y), duration, and the hold before pointerUp; and that no `input swipe` shell command is issued.
  pkg/core gesture tests keep the 246 -> 0 geometry.
- Demo follow-up (landmarks-demo, not runner): `android/.maestro/02-favorite.yaml` detects a missed swipe, either by
  giving the swipe action a label distinct from the inline "Remove" button (for example a content description or text
  such as "Swipe Remove") and tapping that, or by asserting the swipe action is visible before the tap. With the swipe
  deliberately disabled the flow fails.
