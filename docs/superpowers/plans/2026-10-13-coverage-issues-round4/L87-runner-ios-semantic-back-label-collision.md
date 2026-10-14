# L87: Runner iOS semantic-back label collision

Status: **confirmed candidate4 public behavior; selected-element identity remains a source inference pending the actor's minimal hierarchy capture**

## Trigger

Candidate4 IOS-117 runs the frozen screen sequence on owned iOS26:

1. open `Landmarks`, then `Lakes`;
2. for the next Detail screen, tap `Landmarks` to navigate back;
3. tap `Golden Gate Bridge` and assert `Plan Visit`.

The runner reports the Detail screen's `tapOn: text="Landmarks"` as successful, but the following `Golden Gate Bridge` lookup fails after 12.5 seconds. Its fresh page-source diagnosis still lists Lakes content such as `Crater Lake, Oregon` and `water.waves`. Original evidence is immutable at `.worktrees/cov5-ios/findings/evidence/cov5-ios/IOS-117/stock26.*`.

An independent candidate4 `diff capture` public command reproduces the same Detail failure after Lakes and exits 1 after 30.924 seconds; retained raw is `.worktrees/cov5-ios/findings/evidence/cov5-ios/IOS-120/screens26.stderr`. The two distinct public paths (`run` and `diff capture`) are sufficient to confirm the product behavior; no third full reproduction is required.

## What is directly observed

- The `Landmarks` tap returns success.
- The UI remains on the Lakes list afterward, because `Golden Gate Bridge` is absent and the retained closest texts are from Lakes.
- Existing accepted hierarchy captures for this same public-tab demo show a navigation control with `label: Landmarks`, `identifier: BackButton`, while the public selected tab is also labelled `Landmarks`.
- Runner source `pkg/driver/wda/driver.go:788-855` queries generic same-label buttons in `findInteractiveElementByWDA`; it has no `BackButton` preference.
- CLI MCP source `Sources/GrantivaCore/WDA/WDAClient.swift` explicitly queries the matching `BackButton` before broad label matches, and has deterministic competing-label tests.

## Source inference pending live confirmation

The strongest explanation is that the runner's generic button query selected and tapped the already-selected `Landmarks` tab instead of the same-labelled navigation back button. A successful tap on that tab is a no-op, matching the observed Lakes state.

Neither public failure retained the selected element ID for the successful `Landmarks` tap. Therefore “the tab was clicked” remains an inference from source ordering and post-tap state, not a direct ID observation. The issue's observable behavior is confirmed independently of that internal-target inference. The iOS actor's minimal hierarchy capture may strengthen the mechanism diagnosis without requiring another full run.

## Bounded fix requirements

1. In runner WDA tap selection, prefer an exact same-label `XCUIElementTypeButton` with accessibility identifier `BackButton` before the generic same-label button query.
2. Apply the preference only to tap selection. Do not change assertion matching.
3. When no matching navigation back button exists, retain the current first broad same-label match.
4. Preserve exact, regex, ID, relative, state-filter, application-exclusion, retry, timeout and coordinate behavior.
5. Do not add selector aliases or change the frozen demo/config to avoid the collision.

## Required tests

- Competing buttons: a selected tab and navigation button both labelled `Landmarks`, with the navigation button identified as `BackButton`; the navigation button must be selected even when the broad query would return the tab first.
- No `BackButton`: the first broad same-label match remains selected.
- A `BackButton` carrying a different label does not win.
- Existing exact, regex, ID, relative and ordinary button tap tests remain green.

## Narrow live acceptance

On the owned iOS26 candidate fixture, retain the hierarchy immediately before the Detail screen's `Landmarks` tap and the exact selected element identity. The tap must select the `BackButton`, return to the landmarks list, then `Golden Gate Bridge` must open the detail and `Plan Visit` must be visible. Repeat on owned iOS27 if the actor's active reservation permits, without replacing the original IOS-117 failure.

Supporting diagnosis: `findings/preparation/campaign-completion/ios117-runner-same-label-back-diagnosis.md`.
