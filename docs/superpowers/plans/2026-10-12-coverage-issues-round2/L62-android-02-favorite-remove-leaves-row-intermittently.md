# Android `02-favorite`: after the swipe and the tap on "Remove from favorites" the row intermittently stays listed on its red background

Severity: wrong-result (flow passes or fails depending on the run; the removal does not happen)
Component: runner or demo (android) — cause not yet isolated
Platforms: android
Rows: none yet; found during the round-3 smoke addendum on a fresh software-rendered AVD that ran 3–10× faster than the earlier ones (runner PR #23 device runs: 1/5 on b4dc6f1, 2/5 on later builds, then a passing pass)
Regresses/extends: L07 (held-drag element swipes), landmarks-demo PR #3 (swipe action label)
Binary: grantiva-runner 1.1.28-grantiva.12 + PR #23 branch; landmarks-demo main 75acc87

## Expected
`swipe: {direction: LEFT, from: "Lake Tahoe"}` reveals the row's swipe action; `tapOn: "Remove from favorites"` removes
the favourite; `assertNotVisible: "Lake Tahoe"` passes, 5 of 5, on slow and fast AVDs alike.

## Actual
In 3 of 5 runs on the fast AVD the tap on "Remove from favorites" is accepted (the step passes) but the row stays listed on
its red (revealed) background and the item is not removed, so the assert fails. Timing-dependent: slower AVDs pass more
often.

## Reproduce
Fresh `emulator ensure --name <n>` AVD; `.maestro/02-favorite.yaml` ×5 with the dev runner; capture a screenshot right
after the tap step and the Compose semantics tree (`dump-hierarchy`) before and after.

## Fix direction
Isolate first: (a) does the tap land on the label while the row is still animating open (Compose `SwipeToDismissBox`
anchors not settled → the click is consumed by the drag), in which case the runner should wait for the revealed action to
be stable (two identical bounds reads) before tapping, as the K97 settle rule does for screenshots; (b) or does the demo's
`onRemove` fire and the list not recompose (demo bug) — then a landmarks-demo PR. Schedule: round 4 unless a `B3`/`N3` row
fails on it.
