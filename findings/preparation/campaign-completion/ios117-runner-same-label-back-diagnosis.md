# IOS-117 candidate4 runner same-label back diagnosis

Status: **confirmed candidate4 public failure with a source-inferred click target.** Preserve the original candidate4 failures. The iOS actor owns only the minimal hierarchy/selected-element confirmation.

## Failure shape

Fresh candidate4 `IOS-117/stock26` exits 1. Screens Home, Favorites, Deep Links and Lakes succeed. While still on the Lakes list, Detail runs:

1. `tapOn: text="Landmarks"` — reported success;
2. `tapOn: text="Golden Gate Bridge"` — fails after 12.5 seconds;
3. page-source hints still name `Crater Lake, Oregon`, `Favorites`, and `water.waves`.

The second failure proves the first tap did not return from Lakes to the landmarks list. Raw evidence:

- `.worktrees/cov5-ios/findings/evidence/cov5-ios/IOS-117/stock26.command.json`, SHA-256 `b4e0a0a810542e29fe64d8ae4d14830ed5e0462efec6a876ed5b898efe23cef4`
- `stock26.stdout`, SHA-256 `06ba8f5205da3ac63530a9a83d671d5aaa831add237a7b477cd0df224cdd12de`
- `stock26.stderr`, SHA-256 `7272eceda4756cd42c9be2779d1c30206e19945db0fe925a61643b93dfc7f758`

Independent `IOS-120` `diff capture` on the same candidate repeats the Detail/Golden Gate failure after Lakes, exits 1, and takes 30.924 seconds (`.worktrees/cov5-ios/findings/evidence/cov5-ios/IOS-120/screens26.stderr`). Two different public entry points now confirm the observable defect. Neither capture directly records which same-labelled element ID the successful `Landmarks` tap selected.

The frozen config is not self-contradictory. `ios/grantiva.yml` (SHA-256 `351be314da3706b3b76d3284808d7562a107bb0299bf314f9db41bed3251af31`) intentionally uses `tap: "Landmarks"` as the navigation-back step between the Lakes and Detail screen paths. The app's public tab container also exposes a selected `Landmarks` tab with the same visible label.

Existing retained iOS26/27 hierarchy evidence under `findings/evidence/fix4-5-tab/public-container-regression*/navigation-before-switch.json` shows the actual navigation button has `label: Landmarks` and `identifier: BackButton`. Thus the screen contains two relevant same-label controls: the navigation back button and the selected tab.

## Source comparison

The frozen CLI MCP WDA path already handles this collision. `Sources/GrantivaCore/WDA/WDAClient.swift` (SHA-256 `1fb27109163a9934d1f824d76f5b285acd28a8a9ead3c00b33c604d8b6abecb6`) prepends this query before the broad label stage:

`label == <Landmarks> AND identifier == "BackButton" AND type == "XCUIElementTypeButton"`

Its product tests explicitly cover both sides:

- `testTapByLabelPrefersANavigationBackButtonOverACompetingLabelMatch`
- `testTapByLabelKeepsTheFirstBroadLabelMatchWhenThereIsNoBackButton`

The unchanged bundled runner at source `ba9008f4b2cd2c7320a9c46e04faed612b0958a2` does not contain equivalent preference logic. In `pkg/driver/wda/driver.go` (SHA-256 `2d8f8084754a54b3b78890d33279364565ff3c1b00c5bf0dc310bb1675ecd0af`):

- `findElementForTapWithContext` first calls `findInteractiveElementByWDA`;
- its button query is only `XCUIElementTypeButton[label == Landmarks]`;
- the fallback text predicates also match label/value without an `identifier == BackButton` preference;
- `FindElement` returns one match, so a same-labelled tab can win and be tapped successfully while leaving the Lakes stack unchanged.

The subsequent `Golden Gate Bridge` failure and Lakes page-source hints are the expected observable consequence of that wrong successful tap.

## Existing test coverage

Runner tests cover generic text taps, retries, relative selectors, IDs, false-green predicates and keyboard-button collisions. A targeted search of `pkg/driver/wda` finds no `BackButton`, competing-label, navigation-back, or same-label preference test. `pkg/driver/wda/driver_test.go` (SHA-256 `248498b8c20241320711483f8c9c2e4492d8a8ba8144e19d36d0c4ddf4c83645`) even retains unrelated comments that iOS has no hardware back action; those do not cover label-based navigation buttons.

The CLI's passing WDAClient test cannot cover runner-driven `grantiva run` screens. The failure uses the installed runner, not the MCP WDAClient path.

## Concrete repair brief

Likely repair location: `maestro-runner/pkg/driver/wda/driver.go`, in the tap-only text-selector path before the broad interactive button lookup.

Required behavior:

1. For a text tap, first query an exact same-label `XCUIElementTypeButton` whose accessibility identifier is `BackButton`.
2. If present, select it before any other same-label button.
3. If absent, retain the current broad-label result and all regex/exact/id/relative behavior.
4. Keep assertions unchanged; this preference is for tap selection.

Required deterministic runner tests:

- competing `Landmarks` buttons: selected tab first in ordinary query order, navigation button identified as `BackButton`; tap must choose the navigation button;
- no navigation button: current first broad label match remains selected;
- differing label: no `BackButton` special case;
- existing exact, regex, id and application-node behavior remains unchanged.

The actor's minimal confirmation should capture the hierarchy immediately before `tapOn: Landmarks` and, if available without another full reproduction, the selected element identity. The eventual fixed acceptance must prove the tap selects the `BackButton` and the following `Golden Gate Bridge` tap reaches `Plan Visit`. The public defect is already confirmed; the specific tab-click mechanism remains explicitly source-inferred until element identity is retained.
