# Round 1 demo flows: coverage flows and hooks for landmarks-demo

Input for Task 2 of `docs/superpowers/plans/2026-10-11-round1-coverage-pass.md`. Every `NEW:<name>` in
`2026-10-11-round1-coverage-matrix.md` is specified here; Task 2 adds them to landmarks-demo by PR and proves each runs
(or fails for the documented reason) once per platform with `$GRANTIVA run --flow <file>`.

## Conventions

- Flows live at `ios/.maestro/coverage/<name>.yaml` and `android/.maestro/coverage/<name>.yaml`. The two copies are
  identical except the `appId:` line: `com.kylebrowning.Landmarks` (iOS) and `com.kylebrowning.landmarks` (Android).
  The YAML below shows the iOS header. A flow marked "iOS only" or "Android only" exists only in that tree.
- Coverage configs (`NEW:cfg/<name>`) live at `ios/.maestro/coverage/cfg/<name>.grantiva.yml` and
  `android/.maestro/coverage/cfg/<name>.grantiva-android.yml`. A slice uses one by copying it over the scratch
  project's `grantiva.yml` / `grantiva-android.yml`; paths inside are relative to the project root, where the copy
  lands. The Android variant replaces the iOS header (`scheme`, `simulator`, `bundle_id`) with `platform: android`,
  `module: app`, `variant: freeDebug`, `application_id: com.kylebrowning.landmarks`, `emulator: cov-android`.
- `grantiva.yml` and `grantiva-android.yml` keep the stock 12 flows and five screens; no coverage flow is added to
  them.
- "Expected" is what the round-1 binary must do. A negative flow fails on purpose; its expected failure is the pass
  condition of the rows that use it.

## Hooks (app-side changes)

Two hooks. Everything else runs on the app as it is today.

### H1: Gesture Lab screen (SwiftUI and Compose)

Why: no element in the app reacts differently to a double tap, a long press, a tap location or a swipe direction, so
without a hook a flow cannot prove that `doubleTapOn`, `longPressOn`, `tapOn: {point: ...}`, `swipe` `start`/`end`,
`duration` or `from:` did what the README says; the flows would pass for a plain tap or a swipe that landed anywhere.
The Favorites row swipe (stock 02) covers `from:` on a list row only. Used by NEW:03, 04, 05, 06, 20 and the MCP tap,
swipe and script rows.

- **Entry:** a new first row in the Deep Links "Try It" section (iOS `DeepLinksView` Section "Try It", Android
  `DeepLinksScreen` above "Caching Demo"), label exactly `Gesture Lab`, navigating to the screen. No launch argument
  is needed (the Deep Links tab is reachable from launch, and "Try It" is kept at the top so it fits one screen).
- **Screen:** title `Gesture Lab`. The whole content area below the title bar is one pad with accessibility
  identifier `gesture-pad` (iOS `.accessibilityIdentifier("gesture-pad")`; Android `Modifier.testTag("gesture-pad")`,
  exposed as resource id by H2) and accessibility label `Gesture pad`. The pad does not scroll and is not inside a
  List/ScrollView/LazyColumn, so swipes are never consumed by scrolling. On iOS it extends to the bottom edge
  (`.ignoresSafeArea(edges: .bottom)`); on Android it fills to the bottom of the window.
- **Read-outs:** five `Text`s stacked at the top of the pad, not hit-testable (iOS `.allowsHitTesting(false)`; on
  Android they sit inside the pad's `Box`, which owns the pointer input), each its own accessibility element with
  exactly this text:
  - `Taps: <n>`, `Double taps: <n>`, `Long presses: <n>` (start at 0)
  - `Last swipe: <none|left|right|up|down>` (starts `none`)
  - `Last tap: <none|center|edge>` (starts `none`)
- **Recognition:**
  - A double tap increments only `Double taps` (it is not also counted as taps). iOS: `.onTapGesture(count: 2)`
    declared before `.onTapGesture(count: 1)`; Android: `detectTapGestures(onDoubleTap = ..., onTap = ...)`.
  - A press held 500 ms or longer increments `Long presses` only (iOS `.onLongPressGesture(minimumDuration: 0.5)`;
    Android `onLongPress`).
  - A single tap increments `Taps` and sets `Last tap` to `center` when the tap is inside the middle third of the pad
    on both axes, else `edge`. iOS: `SpatialTapGesture` (location in the pad's coordinate space); Android: the
    `onTap` offset against the pad size.
  - A drag of at least 50 pt/dp sets `Last swipe` to the dominant axis direction of finger travel (end minus start:
    negative x = `left`, positive y = `down`). Speed does not matter, so a 1500 ms swipe counts. iOS:
    `DragGesture(minimumDistance: 50)` `.onEnded`; Android: `detectDragGestures` accumulating the drag, decided on end.
- **Tests:** if the demo has a unit/UI test target, add a test that the counters start at 0 and the direction
  helper maps (-100, 0) to `left` and (0, 100) to `down`.

### H2: Expose Compose test tags as resource ids (Android only)

Why: `tapOn: {id: ...}` on Android matches the resource id (docs/mcp.md:88, "`id:` reads the resource id, whole or
after its last `/`"). Compose `testTag("clock")` on the Caching Demo is not a resource id unless the tree opts in,
so today no Android element can be selected by id and the `id:` rows (IOS/AND-203, NEW:01, NEW:05, cfg/maestro-format,
B-C08) would fail for an app reason. iOS already has `accessibilityIdentifier("clock")`.

- In `MainActivity.setContent`, wrap `AppNavHost` in a root modifier `Modifier.semantics { testTagsAsResourceId =
  true }` (from `androidx.compose.ui.semantics`, `ExperimentalComposeUiApi`).
- Keep `testTag("clock")` on the Caching Demo clock; add `testTag("gesture-pad")` on the H1 pad.
- Check with `grantiva hierarchy` under `--keep-alive`: the clock node has `resource-id="clock"`.

## Flows

### 01-selectors (both)

Rows: IOS/AND-201..205, 207, 214, IOS-045, AND-044, IOS-078. Needs H2 on Android (the `id:` steps).

```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
# regex over the whole text
- tapOn: "Golden Gate.*"
- assertVisible: "San Francisco, CA"
- launchApp
# {text:} and exact
- tapOn:
    text: "Lakes"
    exact: true
- assertVisible: ".*Lake.*"
- assertNotVisible: "Lake"
- tapOn:
    text: "Lake Tahoe"
    exact: true
- assertVisible: "Sierra Nevada, CA"
- launchApp
# index: Lakes lists Lake Tahoe, Mono Lake, Crater Lake in that order
- tapOn: "Lakes"
- tapOn:
    text: "(Lake .*|.* Lake)"
    index: 1
- assertVisible: "Lee Vining, CA"
- launchApp
# non-ASCII label
- tapOn: "Deep Links"
- tapOn: "Mountains → Yosemite Valley"
- assertVisible: "Yosemite Valley"
- launchApp
# id selector
- tapOn: "Deep Links"
- tapOn: "Caching Demo"
- assertVisible:
    id: "clock"
- tapOn:
    id: "clock"
- takeScreenshot: "Selectors"
```

Expected: pass on both platforms. `assertNotVisible: "Lake"` passes because a label is matched against an element's
whole text (README:143-145).

### 02-exact-negative (both, negative)

Rows: IOS/AND-206, IOS-065, 066, 071, 074, 078, AND-047, 050, X-002, X-004, X-019, B-I12.1.

```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "Lakes"
- assertVisible: "Mono Lake"
- assertVisible:
    text: "Lake"
    exact: true
```

Expected: fails at the last step with the runner's element-not-visible failure naming `Lake` (for example
`✗ assertVisible: text="Lake" ... Element not visible`), followed by the remediation `Run grantiva hierarchy (or the
grantiva_a11y_tree MCP tool) to inspect the tree.` when Grantiva prints one; exit 1. Steps 1-3 pass.

### 03-gesture-lab-taps (both; H1, H2 on Android)

Rows: IOS/AND-210, 211.

```yaml
appId: com.kylebrowning.Landmarks
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
- assertVisible: "Taps: 1"
- longPressOn:
    id: "gesture-pad"
- assertVisible: "Long presses: 1"
- takeScreenshot: "Gesture Taps"
```

Expected: pass.

### 04-point-taps (both; H1)

Rows: IOS/AND-208, 209, N-11.

```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Gesture Lab"
- tapOn:
    point: "50%,50%"
- assertVisible: "Last tap: center"
- assertVisible: "Taps: 1"
- tapOn:
    point: "100%,100%"
- tapOn:
    point: "0%,0%"
- takeScreenshot: "Point Taps"
```

Expected: pass; the two corner taps report `✓` (they land on screen; whether the pad or the system bar receives them
is not asserted).

### 05-swipe-forms (both; H1, H2 on Android)

Rows: IOS/AND-216, 218, 220, 222.

```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Gesture Lab"
- swipe:
    direction: LEFT
- assertVisible: "Last swipe: left"
- swipe:
    direction: RIGHT
- assertVisible: "Last swipe: right"
- swipe:
    direction: UP
- assertVisible: "Last swipe: up"
- swipe:
    direction: DOWN
- assertVisible: "Last swipe: down"
- swipe:
    start: "80%, 50%"
    end: "20%, 50%"
- assertVisible: "Last swipe: left"
- swipe:
    direction: RIGHT
    duration: 1500
- assertVisible: "Last swipe: right"
- swipe:
    direction: UP
    from:
      id: "gesture-pad"
- assertVisible: "Last swipe: up"
- takeScreenshot: "Swipes"
```

Expected: pass; the `duration: 1500` step takes about 1.5 s (step time in the runner output).

### 06-swipe-absolute (both; H1)

Rows: IOS/AND-221, B-R02.4.

```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Gesture Lab"
- swipe:
    start: "300, 600"
    end: "60, 600"
- assertVisible: "Last swipe: left"
```

Expected: pass. The coordinates are on screen on both test devices (iPhone 17: 402x874 pt; API 35 Pixel: 1080x2400
px). A run that reports `✓ swipe` but leaves `Last swipe: none` is the R02 failure mode.

### 07-swipe-from-missing (both, negative)

Rows: IOS/AND-219, B-A02.1, B-R02.3.

```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
- swipe:
    direction: LEFT
    from: "No Such Row"
```

Expected: fails at the swipe with `Element not found for swipe` (naming `No Such Row`), exit 1; the runner log shows the
element lookup.

### 08-scroll (both)

Rows: IOS/AND-224, IOS-037, AND-038.

```yaml
appId: com.kylebrowning.Landmarks
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
- scrollUntilVisible:
    element: "Golden Gate Bridge"
    direction: UP
    timeout: 60000
- assertVisible: "Golden Gate Bridge"
- tapOn: "Deep Links"
```

Expected: pass. Ends on Deep Links so a `--keep-alive` run can show an `--env LANDMARKS_NOTE` value in `hierarchy`.

### 09-waits (both)

Rows: IOS/AND-228, 229.

```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Slow Screen"
- assertVisible: "Loading…"
- extendedWaitUntil:
    notVisible: "Loading…"
    timeout: 10000
- assertVisible: "Loaded after delay"
- waitForAnimationToEnd
- waitForAnimationToEnd:
    timeout: 2000
```

Expected: pass (the screen loads after 3 s).

### 10-lifecycle (both)

Rows: IOS/AND-231, 233, 234, IOS-075, 076, 077, IOS-237.

```yaml
appId: com.kylebrowning.Landmarks
---
- stopApp
- launchApp:
    clearState: true
    arguments:
      "--flag": true
- assertVisible: "Featured"
- tapOn: "Lake Tahoe"
- stopApp
- stopApp
- launchApp
- assertVisible: "Featured"
- killApp
- launchApp
- assertVisible: "Featured"
```

Expected: pass; the first `stopApp` (app not running) passes; the runner log shows the launch argument `--flag` (not
`---flag`) on iOS and an intent extra `--flag` on Android.

### 11-launch-environment (both)

Rows: IOS/AND-232, IOS-127, AND-117.

```yaml
appId: com.kylebrowning.Landmarks
env:
  LANDMARKS_NOTE: from header
---
- launchApp:
    environment:
      LANDMARKS_NOTE: from step
- tapOn: "Deep Links"
- assertVisible: "from step"
- assertNotVisible: "from header"
```

Expected: pass when run without `--env` (the step's value wins over the header's, README:176; docs/android.md:65-66).

### 12-env-precedence-cli (both)

Rows: IOS-127, AND-117. Run with `--env LANDMARKS_NOTE=from-cli`.

```yaml
appId: com.kylebrowning.Landmarks
env:
  LANDMARKS_NOTE: from header
---
- launchApp:
    environment:
      LANDMARKS_NOTE: from step
- tapOn: "Deep Links"
- assertVisible: "from-cli"
```

Expected: pass with `--env LANDMARKS_NOTE=from-cli`; without it, fails at the assert (`from step` shown), which is the
expected negative.

### 13-android-arguments-merge (Android only)

Rows: AND-116, AND-237.

```yaml
appId: com.kylebrowning.landmarks
---
- launchApp:
    arguments:
      LANDMARKS_SEED: empty
    environment:
      LANDMARKS_NOTE: merged
- assertVisible: "No landmarks yet"
- tapOn: "Deep Links"
- assertVisible: "merged"
```

Expected: pass; logcat `extras=[LANDMARKS_SEED=empty, LANDMARKS_NOTE=merged]` (order free).

### 14-runflow and 14-runflow-sub (both)

Rows: IOS/AND-225, 226, IOS-072, B-I18. The sub-flow is a separate file next to it; copies used for the same-basename
rows (`a/same.yaml`, `b/same.yaml`) take the sub-flow along.

`14-runflow-sub.yaml`:

```yaml
appId: com.kylebrowning.Landmarks
---
- tapOn: "Deep Links"
- assertVisible: "Caching Demo"
```

`14-runflow.yaml`:

```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
- runFlow: 14-runflow-sub.yaml
- launchApp
- runFlow:
    file: 14-runflow-sub.yaml
- launchApp
- runFlow:
    commands:
      - tapOn: "Favorites"
      - assertVisible: "Landmarks you favorite will appear here."
```

Expected: pass; the sub-flow's two steps appear twice in the output.

### 15-input-unicode (both)

Rows: IOS/AND-213.

```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Edit Landmark"
- tapOn: "Location"
- inputText: " · Ünïcødé ✓"
- assertVisible: "San Francisco, CA · Ünïcødé ✓"
- tapOn: "Cancel"
- tapOn: "Discard"
- assertVisible: "Caching Demo"
```

Expected: pass (text appended unmangled; the discard alert answered by the flow).

### 16-setpermissions (both)

Rows: IOS/AND-236, B-C10. Also run from a scratch directory with no config and no `--bundle-id` (B-C10.2).

```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
- setPermissions:
    permissions:
      all: allow
- scroll
- takeScreenshot: "Permissions Set"
```

Expected: pass (`setPermissions` gets the header appId; bare `scroll` scrolls down).

### 17-back (Android only)

Rows: AND-121, AND-238.

```yaml
appId: com.kylebrowning.landmarks
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Caching Demo"
- assertVisible: "Cache Policy"
- back
- assertVisible: "Slow Screen"
```

Expected: pass (a runner-only command passes through `run --flow`, README:172).

### 18-long-wait (both)

Rows: IOS-073, AND-049, B-A06, B-I11.2, X-023.

```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
- extendedWaitUntil:
    visible: "This never appears"
    timeout: 45000
```

Expected: with `--timeout 30` the runner is killed at about 30 s (ready file `failed`, no flow `running`); without
`--timeout` it fails at about 45 s at the wait (exit 1).

### 19-park-edit (both)

Rows: MCP type rows, IOS-104, AND-096, B-I06. Run with `--keep-alive`.

```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Edit Landmark"
- assertVisible: "Edit Landmark"
- tapOn: "Name"
```

Expected: pass; the session is held with the Name field focused.

### 20-park-deeplinks (both; H1 for the rows that open Gesture Lab)

Rows: MCP tap/swipe/script/error-shape rows, IOS-105, 107, 115, AND-095, 098, B-C17, B-C21, N-05, X-021. Run with
`--keep-alive`. Rows open the Gesture Lab themselves (`grantiva_tap {label: "Gesture Lab"}`), so the label tap is part
of what they test.

```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "Deep Links"
- assertVisible: "Gesture Lab"
```

Expected: pass.

### 21-system-alert-maps (iOS only)

Rows: IOS-151, IOS-238, B-I04.2. Same steps as the regression's `findings/evidence/ios/inputs/flows/maps.yaml`; no app
change (it drives Apple Maps, whose location prompt is a system alert).

```yaml
appId: com.apple.Maps
---
- launchApp
- waitForAnimationToEnd
- tapOn:
    id: "MapsTrayHeaderSearchField"
    optional: true
- takeScreenshot: "maps"
- assertNotVisible: "Allow Once"
```

Expected: pass; the runner log shows `accepted system alert "Allow “Maps” to use your location?..."`. If Maps shows
no prompt (permission already decided on that simulator), reset with `xcrun simctl privacy <udid> reset location
com.apple.Maps` first.

### 22-show-note (both)

Rows: IOS-035, 036, AND-035, 037. Run with `--env LANDMARKS_NOTE=<value> --keep-alive` (or `--snapshot full`); the row
checks the value in `hierarchy`, since the value varies per row.

```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "Deep Links"
- assertVisible: "Caching Demo"
```

Expected: pass; the note is the first row of the Deep Links list.

## Coverage configs

### cfg/screens-steps (both; H1)

Rows: IOS-094, 095, 141, AND-128, MCP vrt refusal rows, B-A13.1, B-C09, B-C15.2. Every `screens:` path step
(README:132-146), including the `{text, exact}` form and `run_flow`.

Screens run in order in one app session, each path starting where the previous one ended, so every screen after
`Home` first runs the helper `cfg/relaunch.yaml` (one step, `- launchApp`) to start from the launch screen. That also
exercises `run_flow` on every screen.

`cfg/relaunch.yaml`:

```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
```

`cfg/screens-steps.grantiva.yml`:

```yaml
scheme: "Landmarks (UI Testing)"
simulator: cov-ios-1
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
  - name: Lakes Exact
    path:
      - run_flow: ".maestro/coverage/cfg/relaunch.yaml"
      - tap: {text: "Lakes", exact: true}
      - assert_visible: {text: "Mono Lake", exact: true}
      - assert_not_visible: {text: "Lake", exact: true}
  - name: Caching
    path:
      - run_flow: ".maestro/coverage/cfg/relaunch.yaml"
      - tap: "Deep Links"
      - tap: "Caching Demo"
      - wait: 3
      - assert_visible: "Cache Policy"
  - name: Edit Typed
    path:
      - run_flow: ".maestro/coverage/cfg/relaunch.yaml"
      - tap: "Deep Links"
      - tap: "Edit Landmark"
      - tap: "Name"
      - type: " typed"
      - tap: "Done"
      - assert_visible: "Golden Gate Bridge typed"
  - name: Gestures Swiped
    path:
      - run_flow: ".maestro/coverage/cfg/relaunch.yaml"
      - tap: "Deep Links"
      - tap: "Gesture Lab"
      - swipe: up
      - swipe: DOWN
      - swipe: Left
      - swipe: right
      - assert_visible: "Last swipe: right"
  - name: Sub Flow
    path:
      - run_flow: ".maestro/coverage/cfg/relaunch.yaml"
      - run_flow: ".maestro/coverage/14-runflow-sub.yaml"
diff:
  threshold: 0.02
  perceptual_threshold: 5.0
```

Expected: `diff capture` captures six screens (the `Edit Typed` rename does not persist across the relaunches); the `wait: 3` step takes at least 3 s; `Caching` shows the live clock,
so it is the screen the threshold rows change between capture and compare. With a live runner session, MCP
`grantiva_vrt_capture` refuses this config before running (it has `run_flow`).

### cfg/screens-fail (both)

Rows: IOS-134, 146, AND-119, B-C04.2, B-I03, B-R03.2.

```yaml
scheme: "Landmarks (UI Testing)"
simulator: cov-ios-1
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Home
    path: launch
  - name: Broken
    path:
      - tap: "No Such Element"
flows:
  - .maestro/01-browse.yaml
```

Expected: the screens session fails at `Broken`; with `--continue-on-failure` it is reported and flow 01 still runs
(exit non-zero); `diff capture` exits non-zero and a following `diff compare` does not pass on stale captures.

### cfg/screens-slow (both)

Rows: IOS-135, AND-119, B-C04.2, B-R03.2.

```yaml
scheme: "Landmarks (UI Testing)"
simulator: cov-ios-1
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: Slow
    path:
      - tap: "Deep Links"
      - wait: 45
```

Expected: `run --timeout 30` kills the screens run at about 30 s; without `--timeout` it passes after about 45 s.

### cfg/maestro-format (both; H2 on Android)

Rows: IOS-142, AND-128, B-C07.1, B-C08. A `grantiva.yml` in Maestro format (README:158-172) using the three standard
forms of C07 and an `id:` selector (C08).

```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
- swipe:
    direction: UP
- waitForAnimationToEnd
- takeScreenshot: "Home Swiped"
- tapOn: "Deep Links"
- tapOn: "Caching Demo"
- extendedWaitUntil:
    visible: "Cache Policy"
    timeout: 5000
- tapOn:
    id: "clock"
- assertVisible:
    id: "clock"
- takeScreenshot: "Caching Maestro"
```

On Android the file is named `cfg/maestro-format.grantiva-android.yml` with the Android `appId`. Expected: `diff
capture` produces two screens, `Home Swiped` and `Caching Maestro`; the staged flow carries `id: "clock"`.

## Summary

| name | platforms | hook | negative |
|---|---|---|---|
| 01-selectors | both | H2 (Android) | no |
| 02-exact-negative | both | none | yes |
| 03-gesture-lab-taps | both | H1, H2 (Android) | no |
| 04-point-taps | both | H1 | no |
| 05-swipe-forms | both | H1, H2 (Android) | no |
| 06-swipe-absolute | both | H1 | no |
| 07-swipe-from-missing | both | none | yes |
| 08-scroll | both | none | no |
| 09-waits | both | none | no |
| 10-lifecycle | both | none | no |
| 11-launch-environment | both | none | no |
| 12-env-precedence-cli | both | none | without `--env` |
| 13-android-arguments-merge | Android | none | no |
| 14-runflow (+ 14-runflow-sub) | both | none | no |
| 15-input-unicode | both | none | no |
| 16-setpermissions | both | none | no |
| 17-back | Android | none | no |
| 18-long-wait | both | none | yes (timeout) |
| 19-park-edit | both | none | no |
| 20-park-deeplinks | both | H1 (rows) | no |
| 21-system-alert-maps | iOS | none | no |
| 22-show-note | both | none | no |
| cfg/screens-steps (+ cfg/relaunch helper) | both | H1 | no |
| cfg/screens-fail | both | none | yes |
| cfg/screens-slow | both | none | with `--timeout 30` |
| cfg/maestro-format | both | H2 (Android) | no |

22 flows (plus the helpers 14-runflow-sub and cfg/relaunch) and 4 configs; 2 hooks (H1 Gesture Lab on both apps, H2 Compose test tags as
resource ids).
