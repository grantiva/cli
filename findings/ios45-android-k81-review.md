# iOS 45 and Android K81 scoped review

This review covers only iOS attempt 45's new N-14/N2-13 grades, Android `B2-K17-K81-completion-rerun1/K81`, and exact reusable source/runtime joins. The running iOS 46 batch is excluded. No live command was run.

## Verdict

- **N-14 [ios]: approved.** The retained stock edit report has a passing `inputText: " Renamed"` command with no `warning` field. The crash report fails the first post-launch assert with `error.type: "app_crash"`, names the stopped bundle, and retains failure artifacts.
- **N2-13 [ios]: approved.** Three stock crash runs fail their first assert in 143–179 ms. The four required scratch wait primitives—extended visible, not-visible, scroll-until-visible, and animation settle—each fail against the dead app with `app_crash` in 12–529 ms, well below their configured timeout, and none passes. The source semantics are exact at runner `fd9d8e8`: `pkg/driver/wda/wait_crash_test.go` covers visible/not-visible crash conversion, `scroll_find_test.go` covers scroll lookup behavior, and `settle_crash_test.go:56-123` distinguishes dead-app failure from intentional-stop success.
- **B2-K81 [android]: approved.** The no-report trailing run's expected command exit is 1 because the exact-negative flow fails. Comparing its preserved before/after inventories adds only the failure screenshot, last-good `cmd-001-after`, failing `cmd-002-before/after`, and failing hierarchy under `.grantiva/run-captures/android`; it creates no report directory. Joined to the earlier kept-report full/trailing/failure modes and exact trace-pruning source assertions, this completes the row. The wrapper's monitor count of zero is unrelated to the command's valid expected failure result.
- **B2-K17 remains ungraded.** Its wrapper leg returned 0 but retained zero snapshot files; no conclusion is drawn from it.

## Remaining lifecycle join: B3-L24

Attempt 45 closes two clauses but not the row:

- `wait-anim-report/flows/flow-000.json` proves one dead-app settle fails with `app_crash` in 529 ms.
- `intentional-stop-report/flows/flow-000.json` proves `launchApp`, `stopApp`, then `waitForAnimationToEnd` passes.
- Runner `pkg/driver/wda/settle_crash_test.go:56-123` is the exact semantic source match for dead-app classification, the transient-state control, intentional-stop success, and live-app success.

The matrix still requires **three** dead-app `waitForAnimationToEnd` runs, a crashing screens/diff-capture session that fails before saving Home, and unchanged stock-set controls on both iOS 26 and 27. Attempt 45 supplies one of the three runs and no screens-session or two-runtime stock control, so B3-L24 must remain ungraded. This mapping should allow the remaining runtime work to target only those missing observations.
