# iOS gate findings (seeded from Task 1's GATE-NOTES; verify and renumber as IOS-F entries)

(see GATE-NOTES gap 0).

| Flow | Result |
|---|---|
| 01-browse | PASS |
| 02-favorite | FAIL: CLI gap 3, `swipe from:` is ignored |
| 03-edit | PASS |
| 04-discard | PASS in the last 2 full gates; failed 2 of 3 early runs (alert flake, see notes) |
| 05-category | PASS |
| 06-visit | PASS |
| 07-deeplink | PASS |
| 08-caching | PASS |
| 09-seed-empty | FAIL: CLI gap 1, flow `env:` is not passed to the app; passes with `--env LANDMARKS_SEED=empty` |
| 10-seed-many | FAIL: CLI gap 2, bare `scroll` is unsupported (plus gap 1) |
| 11-slow | PASS |
| 12-quote-label | PASS |
| 99-crash | Fails as expected. Without env it fails on the last assert; with `--env LANDMARKS_CRASH_ON_LAUNCH=1` it fails because the app crashed. |

Summary: 9 of 12 green; the 3 failures are CLI or runner gaps, with app behaviour confirmed by the scratch and `--env` runs below.
Evidence the app is correct for the gap flows:
- 09 passes with `--env LANDMARKS_SEED=empty`.
- A scratch flow with 4 x swipe UP finds `Landmark 30` with `--env LANDMARKS_SEED=many`.
- A scratch flow with a coordinate swipe shows and taps `Remove`, and the empty state appears.

The simulator was torn down (`simulator teardown --session-id qa-build-ios` → deleted).
`iPhone 17 Pro` B27D7D31 was not touched.

## GATE-NOTES.md (full content)
# iOS gate notes (grantiva 2.0.1, iOS 26.0 simulator "qa-build-ios", iPhone 17)

Final gate: 9 of 12 flows pass (01, 03, 04, 05, 06, 07, 08, 11, 12 -- 04 is flaky, see below).
Fails: 02, 09, 10. Each comes from a CLI or runner defect, not the app. 99-crash fails as expected.
The flows were not edited.

Gate command (brief Step 11, with one change: `--device-type`, see gap 0):

    export GRANTIVA=~/.grantiva-qa/bin/grantiva GRANTIVA_SESSION_ID=qa-build-ios
    cd /Users/kyle/Developer/landmarks-demo/ios
    udid=$($GRANTIVA simulator ensure --name qa-build-ios --device-type "iPhone 17" --runtime 26.0)
    for f in .maestro/0*.yaml .maestro/1*.yaml; do $GRANTIVA run --flow "$f" --simulator "$udid" --report-dir "build/reports/$(basename $f .yaml)" || echo "GATE FAIL $f"; done

## Gap 0: `simulator ensure --name qa-build-ios` fails without a device model in the name

    $ $GRANTIVA simulator ensure --name qa-build-ios --runtime 26.0
    Error: Invalid argument: Could not infer a device type from the name "qa-build-ios". Include a device model in the name (for example "iPhone 17") or pass --device-type.

The command prints nothing on stdout, so `udid` is empty and every later `run` fails with
`Error: Invalid argument: Simulator not found: ""`. The brief's command does not work as written.
Workaround: add `--device-type "iPhone 17"`.

## Gap 1 (flows 09, 10, 99): flow-level `env:` is not passed to the app at launch

    $ $GRANTIVA run --flow .maestro/09-seed-empty.yaml --simulator "$udid" --report-dir build/reports/09-seed-empty
        ✓ launchApp (2.0s)
        ✗ assertVisible: text="No landmarks yet" (18.3s)
          ╰─ Element not visible: text='No landmarks yet' (cause: context deadline exceeded: no elements match selector; closest on-screen texts: "Landmarks", "All Landmarks", "road.lanes")

The app shows the default seed, so `LANDMARKS_SEED=empty` never reached it. The CLI only forwards
`--env KEY=VALUE` (into `launchApp.environment`). It ignores the flow header's `env:` block (in real
Maestro that block sets flow variables, not launch environment). The same command with
`--env LANDMARKS_SEED=empty` passes:

    $ $GRANTIVA run --flow .maestro/09-seed-empty.yaml --env LANDMARKS_SEED=empty --simulator "$udid" --no-build ...
        ✓ launchApp (2.1s)
        ✓ assertVisible: text="No landmarks yet" (1.1s)
        ✓ takeScreenshot (68ms)

99-crash also gets no env from the gate command, so the app does not crash. The flow still fails,
but on its last step (`'This never appears'`, closest texts "Sierra Nevada, CA", ...), not because
of a crash. With `--env LANDMARKS_CRASH_ON_LAUNCH=1` it fails the intended way:

    ✗ assertVisible: text="Landmarks" (17.6s)
      ╰─ ... WDA error: The application under test with bundle id 'com.kylebrowning.Landmarks' is not running, possibly crashed

## Gap 2 (flow 10): bare `scroll` is unsupported

    $ $GRANTIVA run --flow .maestro/10-seed-many.yaml --simulator "$udid" --report-dir build/reports/10-seed-many
        ✓ launchApp (2.1s)
        ✗ scroll (0ms)
          ╰─ Failed to get screen size (cause: screen dimensions not available)

An earlier run of the same flow failed instead with
`✗ scroll (1ms) ╰─ Invalid scroll direction (cause: invalid direction: )`.
Flow 10 also depends on gap 1 (`LANDMARKS_SEED=many`).
Evidence that the app behaves correctly: a scratch flow (not committed) with 4 x `swipe: direction: UP`,
run with `--env LANDMARKS_SEED=many`, passes `assertVisible: "Landmark 30"`.

## Gap 3 (flow 02): `swipe` with `from:` ignores the `from` element

    ✓ swipe: LEFT (1.1s)
    ✗ tapOn: text="Remove" (12.0s)
      ╰─ Element not found: text='Remove' ... closest on-screen texts: "love", "water.waves", "Vertical scroll bar, 1 page"

The runner log shows the swipe ran across the screen's vertical centre, not over the "Lake Tahoe" row
(the row is at y≈210pt):

    WDA POST .../wda/dragfromtoforduration body={"duration":0.1,"fromX":361.8,"fromY":437,"toX":40.2,"toY":437}

Evidence that the app behaves correctly: a scratch flow using `swipe: start: "85%, 24%" end: "15%, 24%"`
shows and taps `Remove`, and the empty state appears.
That scratch run hit a second runner defect. `assertNotVisible: "Lake Tahoe"` failed because the runner
found the row while it was animating out, then got 404 on every attribute lookup ("element is visible").
It does not retry when the element goes stale. The hierarchy captured at that moment contained no "Lake Tahoe",
only "Landmarks you favorite will appear here.".

## Flake (flow 04): the SwiftUI alert sometimes disappears right after it appears

2 of the first 3 runs failed; the last 2 full-gate runs passed. When it fails:

    ✓ tapOn: text="Cancel"
    ⚠ assertVisible: text="You have unsaved changes that will be lost." (7.2s)
    ✗ tapOn: text="Keep Editing" ... closest on-screen texts: "Deep Links", "AdditionalDimmingOverlay", "link"

The runner log shows the alert text was found, then each attribute GET took about 2.2 s and returned 404.
After that the Edit screen was gone (the Landmarks list was showing) and only the dimming overlay
was left. That matches Discard being pressed. The app calls `dismiss()` only from Discard or from a
Cancel with no changes, and the Cancel had changes. My guess is XCTest's automatic alert handling
during those slow element lookups, but I have not confirmed it. Out-of-band scratch runs of the same
steps always kept the alert up.

## Environment breakage seen at the end of the session

After the last full gate run, every `grantiva run` began exiting with code 133:

    GrantivaCore/resource_bundle_accessor.swift:44: Fatal error: unable to find bundle named grantiva_GrantivaCore

`grantiva --version` still works. I did not change the binary or anything under grantiva-cli. The extra
04 repeat runs after the gate could not be done because of this.

## Files changed
All of `ios/` is new (58 files). The files modified from the source are listed above. New files:
- `Landmarks/TestEnvironment.swift`
- `Landmarks/Views/SlowScreenView.swift`
- `Landmarks-Info.plist`
- the 2 `.xcscheme` files
- `grantiva.yml`
- `.maestro/*.yaml`

`ios/.grantiva/captures/*.png` (created by the 99 `--no-build` run) were removed and not committed. The root
`.gitignore` pattern `.grantiva/captures/` is anchored to the repo root, so it does not match
`ios/.grantiva/captures/`. Suggest changing it to `**/.grantiva/captures/`. I did not edit the root
`.gitignore`, because I own only `ios/`.

## Self-review findings
- **Flaky flow 04.** The alert sometimes disappears and the Edit screen pops while the runner is still
  checking the alert text. My best guess is XCTest's automatic alert handling, but I have not confirmed it.
  A failed run can be rerun.
- **UI_TESTING startup reset.** `UI_TESTING` builds clear navigation state and the disk cache at launch.
  This only affects UI-testing builds and makes runs deterministic.
- **Flows tested on one screen size.** The Deep Links layout depends on the first screen fitting every flow
  target. I only checked iPhone 17 (874pt). Smaller devices (iPhone SE) could push `Mountains → Yosemite Valley`
  below the fold, since the runner does not auto-scroll.
- **Pre-existing warnings.** Swift 6 sendability warnings in the Caching and Network files predate my change;
  my changes add none I noticed.
- **Live service behaviour.** The live `toggleFavorite` still PUTs `isFeatured` (the original behaviour) and
  also toggles the local favorites. Favorites in live mode are in-memory only.

## Concerns
1. The push is blocked; the commit is local only.
2. Three CLI gaps (flow `env:`, bare `scroll`, `swipe from:`) and the brief's `simulator ensure` without
   `--device-type` mean the gate cannot be all green as written.
3. Near the end, `grantiva run` started crashing:
   `Fatal error: unable to find bundle named grantiva_GrantivaCore` (exit 133). It happened after the final
   gate completed. `--version` still works. I changed nothing in the binary or in grantiva-cli; possibly
   something else on the host rebuilt or moved files. The extra 04 repeat runs could not be done.
