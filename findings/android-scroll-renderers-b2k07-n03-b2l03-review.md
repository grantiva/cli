# Android scroll-renderer review: B2-K07, N-03, B2-L03

Reviewed 2026-10-13, read-only. Candidate runner is
`/Users/kyle/Developer/maestro-runner/.worktrees/release-round3b` at `fd9d8e8`.
Runtime evidence is
`/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-K07-N03-B2-L03-scroll-renderers-rerun1`.

## Eligible runtime

Only these six runs executed and are eligible:

- software renderer, full snapshots: `runs/fresh-full-1`, `runs/fresh-full-2`, and
  `runs/software-full-3`;
- GPU renderer, full snapshots: `runs/gpu-full-1` through `runs/gpu-full-3`.

All six commands exit 0, their reports are `passed`, and the final hierarchy in
each ends at Landmark 28. Thus software and GPU have identical final landings
(variation 0 rows) for the required three repeats per renderer.

The five `fresh-default-*` and three `warm-default-*` directories are not
failed product runs. Bash 3 aborted at an empty-array expansion under `set -u`
before those commands ran. Their synthetic exit-1/null rows in `decoded.json`
must be excluded. The pending default-only complement owns those eight inputs.

## B2-L03: partial

Supported:

- Three software-rendered and three GPU-rendered full-snapshot runs pass and
  land at the same Landmark 28, satisfying the repeated cross-renderer landing
  observation.
- Every run preserves four unredacted `POST /actions` request bodies in
  `report/client.log`. Each gesture begins at `(540,1848)`, advances in twenty
  60-pixel moves, ends at `(540,648)`, and holds there for 250 ms before
  `pointerUp`. This proves the expected list-contained endpoints and retained
  pointer actions.
- Exact-head semantic tests make the intended contract concrete:
  `pkg/driver/uiautomator2/bare_scroll_verify_test.go:76-114` pins
  `(540,1848)->(540,648)` in the `[0,432][1080,2064]` list and verifies that a
  half-delivery device is topped up until four-scroll travel is within one
  189-pixel row of full delivery. Lines 116-130 bound top-ups at list end, and
  lines 150-162 verify waiting for the list before dragging.

Not supported by this capture:

- The matrix explicitly asks for a hierarchy after each of the four scroll
  steps and a row-advance comparison in which no step differs by more than one
  row. Each eligible run retains only one post-flow `hierarchy.xml` (the other
  XML file is JUnit); full snapshots retain per-step PNGs, not per-step
  hierarchies. The source test establishes the algorithm but cannot replace
  this explicit runtime observation. Therefore B2-L03 remains **partial** until
  a complement captures four before/after hierarchy transitions for each
  renderer (or an equivalent exact per-step hierarchy series).

## B2-K07 and N-03 after the default complement

The additive evidence at
`/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-K07-N03-default-complement-rerun2`
contains the eight executions that v1 never ran. Five fresh-default and three
warm-default commands all exit 0, pass, and end at Landmark 28. Its decoded
checks also confirm the row-created software AVD was removed and the protected
primary remained. Joined to v1's two fresh full-snapshot executions, the exact
B2-K07 5 + 2 + 3 set is 10/10 passed with landing spread 0.

The six eligible full-snapshot runs are strong additive evidence: every run
passes, all land at Landmark 28, and their gesture bodies are identical.
Exact-head tests cover the source clauses:

- `bare_scroll_test.go:13-50` pins the held-drag endpoints and rejects an
  `input swipe` fling;
- `bare_scroll_test.go:52-63` maps `speed:` through
  `core.ScrollDurationOrDefault`;
- `bare_scroll_test.go:125-147` verifies four scrolls have the same landing
  with and without an immediate inter-step delay and that each contributes the
  same distance.

The semantic delayed-versus-immediate source test is exact evidence for the
single-scroll spacing clause; no extra device repetition is needed for that
algorithmic condition. N-03 is therefore fully supported. The explicit “iOS
unchanged” clause is supplied by current-round `cov3-ios` evidence:
`findings/evidence/cov3-ios/FLOWS-26/10-seed-many.out` and
`FLOWS-27/10-seed-many.out` (IOS-223 and IOS-223 @27.0), with the complete
iOS 26/27 stock sets at `IOS-117/stock-26.out` and `IOS-118/stock-27.out`.

## Verdicts

- **B2-L03: PARTIAL** — six cross-renderer repeats, final landing, pointer
  bodies/endpoints, and semantic tests pass; the literal per-step hierarchy
  advancement series is missing.
- **B2-K07: PASS** — the required Android 5 fresh default + 2 fresh full + 3
  warm default set is 10/10 with spread 0; exact source covers spacing, speed,
  and endpoints; current-round iOS 26/27 stock and IOS-223 both pass.
- **N-03: PASS** — fresh and warm executions all reach the same Landmark 28.
