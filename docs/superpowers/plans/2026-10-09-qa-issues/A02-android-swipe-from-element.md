# Start Android swipes on the `from:` element, and fail when it cannot be found

Severity: wrong-result
Platforms: android
Found by: AND-F02 (matrix rows AND-043, 02-favorite green for the wrong reason; gate Defect 2)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7+android-drivers-2, emulator-5554 (Pixel_8_API_35, API 35)

## Expected
`swipe: {direction: LEFT, from: "Lake Tahoe"}` swipes starting on the element matching `from`, and fails if no element
matches. Source: README §Maestro Compatibility (`swipe` listed as supported); Maestro `swipe.from` semantics.

## Actual
The runner swipes across the screen centre, does no lookup for "Lake Tahoe", and reports success:
```
    ✓ assertVisible: text="Lake Tahoe" (130ms)
[swipe] Using screen coords: (972,1200) → (108,1200)
    ✓ swipe: LEFT (456ms)
```
`captures/02-favorite-cmd-008-before.png` and `-after.png` are identical; the row (y≈400) shows no swipe action. The flow
passes only because each Favorites row also has a visible `Remove` button. A coordinate swipe on the same row
(`swipe: {start: 60%, 17%, end: 5%, 17%}`) does reveal the swipe action.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=qa-android
cd /Users/kyle/Developer/landmarks-demo/android
grantiva run --no-build --flow .maestro/02-favorite.yaml --device emulator-5554 --snapshot full --report-dir /tmp/a02 2>&1 | grep -A1 "\[swipe\]"
md5 /tmp/a02/captures/02-favorite-cmd-008-{before,after}.png        # identical
```
Variant: change `from:` to `"No Such Row"`; the step still passes.

## Evidence
- findings/evidence/AND-F-swipe/stderr.txt (lines 39-40), AND-F-swipe/report/client.log
- findings/evidence/AND-F-swipe/report/captures/02-favorite-cmd-008-after.png

## Suspected cause
Runner, not this repo (source checked at ~/Developer/maestro-runner, branch grantiva-patches d98d7dd):
pkg/flow/step.go:194-207 `SwipeStep` has no `from` field, only `selector`, so `from:` is dropped as an unknown key;
pkg/driver/uiautomator2/commands.go:604-629 then takes the no-selector path and calls `swipeWithMaestroCoordinates`
(:681-716, screen centre). Grantiva's own parser (Sources/GrantivaCore/Config/MaestroFlowParser.swift:291-308) only matters
for screens mode; the `--flow` path passes the YAML through unchanged (RunnerSession.swift:285-310).

## Acceptance criteria
- Re-running the repro: the runner log shows an element lookup for "Lake Tahoe" and a swipe starting inside its bounds;
  cmd-008-after.png shows the revealed swipe action. With `from: "No Such Row"` the step fails with "Element not found".
- The bundled runner maps `from:` to the swipe selector (Maestro semantics: start at the element centre); bump the
  bundled runner and CHANGELOG.
- Runner test: parsing `swipe: {direction: LEFT, from: X}` yields a non-empty selector; a driver test with a fake page
  source asserts the swipe start point is inside X's bounds. GrantivaCoreTests: if the CLI pre-validates flows, a
  MaestroFlowParser test that `from:` is kept, not discarded.
