# Android `swipe: {direction: LEFT, from: <element>}` is too short to open the row

Severity: wrong-result
Blocking: yes
Platforms: android
Found by: Android slice, brief row `A02` (findings/android-results.md), re-checked in the fix-round device session with touch traces on (findings/evidence/android/A02/probes/). Original brief: A02 (`plans/2026-10-09-qa-issues/A02-android-swipe-from-element.md` (last round's files are on branch `qa-campaign`, commit 8084069; exported copy at `~/.grantiva-qa/briefs/docs/superpowers/`)), partially fixed.
Binary: grantiva 2.1.0 at a278b77, grantiva-runner 1.1.28-grantiva.8, emulator-5554 (AVD `qa-reg-android`, API 35 google_apis arm64, 1080x2400)

## Expected
From A02's acceptance criteria: "the runner log shows an element lookup for "Lake Tahoe" and a swipe starting inside
its bounds; cmd-008-after.png shows the revealed swipe action. With `from: "No Such Row"` the step fails with
"Element not found"." README:173 lists `swipe` with `direction:`, "optionally with `from:`". A left swipe from a
Favorites row should open that row's swipe-to-delete action, as a full-length swipe across the row does.

## Actual
Partially fixed since 2.0.1:
- Met: the runner looks the element up before swiping (A02/02-favorite-client.log:36-38, `POST /element`
  `text("Lake Tahoe")`, then `/text` and `/rect`).
- Met: `from: "No Such Row"` fails at the swipe after the lookup timeout, exit 1 (A02/02-nosuch.txt:40-41):
  ```
      ✗ swipe: LEFT (17.0s)
        ╰─ Element not found for swipe: context deadline exceeded: no such element: ...
  ```
- Not met: the swipe does not open the row. With the pointer-location overlay on, the `direction: LEFT, from:
  "Lake Tahoe"` swipe draws only a short trace inside the 227 px wide "Lake Tahoe" text element, and the row stays
  closed, in flow 02 (probe a) and in a one-step probe (probe c). The step still reports `✓ swipe: LEFT`. Probe c then
  fails its `assertNotVisible "Lake Tahoe"` check (A02/probes/c-direction-left-from.txt:40-45). Flow 02 passes only
  because each Favorites row also has a visible `Remove` button, so the release flow set does not catch this.

Controls from the same device session (A02/probes/summary.txt):

| probe | swipe | result |
|---|---|---|
| (a) flow 02 as-is | `direction: LEFT, from: "Lake Tahoe"` | short trace on the text only; row not opened (flow passes via `Remove`) |
| (c) one-step probe | `direction: LEFT, from: "Lake Tahoe"` | short trace on the text only; row not opened; FAIL |
| (b2) coordinate swipe | `start: 60%, 22%` → `end: 5%, 22%` (y=528) | full-length trace across the row; row opened; PASS |
| (d) manual control | `adb shell input swipe 648 528 54 528 300` | row opened; "Lake Tahoe" nodes 1 → 0 |

Runner swipes therefore reach the screen and can open the row; the element swipe is too short. Row geometry
(A02/probes/d-hierarchy-before.xml): row `[0,432][1080,621]`, "Lake Tahoe" text `[42,469][269,532]`. The
first-session probe at `60%,17%` (y=408) missed because it lies above this row, not because coordinate swipes fail.

Hypothesis, from reading the grantiva-runner source and not shown on device: the element swipe runs from the element
centre to 10% of the screen width, (155,500) → (108,500), a 47 px drag, which is below the row's dismiss threshold.
Supporting hand control (A02/probes/e-manual-short-swipes.txt): `adb shell input swipe 155 500 108 500 300` leaves the
row closed ("Lake Tahoe" nodes 1 → 1), while `input swipe 155 500 0 500 300` opens it (1 → 0).

Separate hypothesis, same fixer: absolute-pixel swipe coordinates appear to be scaled as percentages. Probe c2
(`start: 900, 520` / `end: 100, 520`, no `%`) reports `✓ swipe` but leaves no trace on the screen and the row stays
closed; the overlay header reads `dX -8640.0 dY 0.0`, which is what (900-100)% of 1080 px gives
(A02/probes/c2-abs-px-row.txt, png/c2-abs-px-row-failure-after-swipe.png).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-r02
unset GRANTIVA_API_KEY
EV=/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/android/A02/probes
rm -rf /tmp/r02 && mkdir -p /tmp/r02 && cp -R /Users/kyle/Developer/landmarks-demo/android /tmp/r02/android && cd /tmp/r02/android
SERIAL=$(grantiva emulator ensure --name qa-fix-r02 | grep -o 'emulator-[0-9]*' | tail -1); echo "$SERIAL"
grantiva build install --device "$SERIAL"
adb -s "$SERIAL" shell settings put system pointer_location 1        # draws touch traces into screenshots
# element swipe: fails today (row stays closed, assertNotVisible "Lake Tahoe" times out)
grantiva run --device "$SERIAL" --no-build --flow $EV/c-direction-left-from.yaml --report-dir /tmp/r02/c; echo "exit $?"
# control: full-length coordinate swipe on the same row passes
grantiva run --device "$SERIAL" --no-build --flow $EV/b2-coord-22pct-row.yaml --report-dir /tmp/r02/b2; echo "exit $?"
# absolute pixels: fails today, overlay reads dX -8640
grantiva run --device "$SERIAL" --no-build --flow $EV/c2-abs-px-row.yaml --report-dir /tmp/r02/c2; echo "exit $?"
open /tmp/r02/c/captures/*.png /tmp/r02/b2/captures/*.png /tmp/r02/c2/captures/*.png
# lookup and not-found (already fixed; must stay fixed)
sed 's/from: "Lake Tahoe"/from: "No Such Row"/' .maestro/02-favorite.yaml > /tmp/r02/02-nosuch.yaml
grantiva run --device "$SERIAL" --no-build --flow /tmp/r02/02-nosuch.yaml; echo "exit $?"   # Element not found for swipe, exit 1
# cleanup
adb -s "$SERIAL" shell settings put system pointer_location 0
grantiva emulator teardown --serial "$SERIAL" && avdmanager delete avd -n qa-fix-r02
```
The row's y position depends on the device; the probes assume a 1080x2400 screen with the Lake Tahoe row at
`[0,432][1080,621]`. Check `adb shell uiautomator dump` if `b2` does not open the row.

## Evidence
- findings/evidence/android/A02/probes/summary.txt (probe table and findings), probes/commands.txt
- findings/evidence/android/A02/probes/png/: `02-favorite-cmd-008-after.png` (short trace, row closed),
  `c-direction-left-from-failure-after-swipe.png`, `b2-coord-22pct-row-cmd-010-After.png` (row opened),
  `c2-abs-px-row-failure-after-swipe.png` (no trace, dX -8640), `d-manual-after.png`, `e-manual-155-108.png`,
  `e-manual-155-0.png`; probes/hashes.txt
- findings/evidence/android/A02/probes/e-manual-short-swipes.txt (47 px hand swipe leaves the row closed)
- findings/evidence/android/A02/probes/d-hierarchy-before.xml, d-hierarchy-after.xml (row and text bounds)
- findings/evidence/android/A02/02-favorite.txt, 02-favorite-client.log:36-38 (lookup), 02-nosuch.txt (not-found, exit 1)
- iOS half of A02 passes: findings/ios-results.md Step 3, A02 row

## Suspected cause
Bundled grantiva-runner, not this repo. Both points are hypotheses from the grantiva-runner source
(grantiva/runner main 2f2ee31), not confirmed on device.
- `pkg/core/gesture.go:149-166` `SwipeCoordsToScreenEdge`: for `left` it returns `(cx, cy) → (screenW/10, cy)`. For
  an element whose centre is near the left edge (here x=155 on a 1080 px screen) that is a 47 px drag, too short for a
  swipe-to-dismiss row. The travel depends on where the element sits, not on the swipe asked for.
- Absolute coordinates: `pkg/core/point.go:89-110` `ParsePercentageCoords` strips an optional `%` and divides by 100 in
  every case, so `900, 520` is read as 900% / 520% of the screen.

## Acceptance criteria
- Re-running the repro: `c-direction-left-from.yaml` passes, and its After capture shows the row opened (red
  background with the swipe Remove action); the overlay trace runs most of the row's width.
- Flow 02's `cmd-008-after.png` (with `--snapshot full`) shows the revealed swipe action, as A02 required.
- `from: "No Such Row"` still fails at the swipe with `Element not found for swipe`, exit 1, and the lookup
  (`/element` + `/rect` for "Lake Tahoe") still appears in client.log.
- `c2-abs-px-row.yaml` either swipes from (900,520) to (100,520) in pixels and opens the row, or fails before the swipe
  with an error saying coordinates must be percentages. It must not report `✓ swipe` for a gesture that lands off screen.
  If pixels stay unsupported, README:173 says so.
- Runner tests: an element swipe LEFT from an element centred at x=155 on a 1080 px screen travels at least the
  distance a coordinate swipe of `60%`→`5%` covers (or another documented minimum); parsing `900, 520` does not yield 9.0 / 5.2.
- The Android flow set still passes 12/12, and the iOS flow set (02-favorite in particular) still passes on iOS 26.0
  and 27.0 if the runner changes. Bundled runner version bumped and noted in the release notes.
