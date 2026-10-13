# iOS attempts 28–29 and Android output rerun 2 review

Scope: the three iOS attempt-28 grades, the completed hierarchy/keep-alive results from attempt 29, and only the completed Android B2-K13/B2-K20 modes in `output-contracts-exact-rerun2`. The Android modes after the macOS Bash 3 empty-array abort are excluded. Rows marked `both` are assessed as independent platform halves except where a criterion itself requires a comparison.

Candidate provenance: Grantiva CLI `8f2cff67`; runner `fd9d8e8`; QA binary provenance remains the campaign-recorded `3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8`.

## Findings

No material unsupported grades remain in this scope.

## Accepted iOS evidence

- **B-A04.1 [ios]: pass supported.** All ten command records exit zero. Each `capture-01.sha256` … `capture-10.sha256` contains two distinct hashes, so Deep Links never equals Home in any iteration.
- **B-I04.1 [ios]: pass supported.** Ten distinct retained outputs each complete the exact discard flow, including the visible unsaved-changes text, explicit Keep Editing, then explicit Discard.
- **B-I04.2 [ios]: pass supported.** The same runtime captures prove app-owned alerts remain explicit while the Maps permission flow proves system-alert handling. Candidate CLI `README.md:166` documents the distinction. The required change note is in the exact runner candidate at `/Users/kyle/Developer/maestro-runner/.worktrees/release-round3b/CHANGELOG.md:701` (HEAD `fd9d8e8d1cb109eda6116f4221da10257b9838e3`): alert handling defaults to empty rather than implicit acceptance, leaving app alerts interactable while explicit permission configuration still auto-accepts. The CLI tree has no CHANGELOG, but the behavior and its change history belong to the runner and are present at the campaign's exact runner head.
- **IOS-047: pass supported.** `ready-observation.json` records the ready file while the process is alive; `keepalive.err` shows completed flow followed by the advertised keep-alive session, and the command exits only after the harness sends SIGINT.
- **IOS-048, IOS-049, IOS-050, IOS-051, IOS-055, IOS-056: passes supported.** The first post-ready XML is a live Landmarks detail hierarchy; both JSON forms parse successfully; every hierarchy command names exact U1 through `--udid`; the 0.01-second case exits 1 with exactly the prescribed actionable sentence; and `ready-observation.json` proves the immediate request was made while keep-alive remained alive. The detail hierarchy left by `01-browse` also supports the no-relaunch observation.
- **IOS-058: fail supported.** `keepalive.ready-before-signal` and `keepalive.ready-after-signal` are byte-equivalent completed/passed states. SIGINT releases the hold but does not produce the required group/flow `interrupted` state. This is a criterion failure, not missing evidence.
- **IOS-057 remains ungraded.** Attempt 29 retained broad process snapshots, but it does not provide a focused before/after proof for runner, WDA, `simctl diagnose`, session/owner-file removal, and lease release. The worker correctly did not add a row.

## Accepted Android evidence

- **B2-K13 [android]: pass supported.** `AND-106` covers the combined five-screen/twelve-flow narration; rerun 1 covers explicit `--flow`; rerun 2 covers flows-only and screens-only. The completed outputs contain the required counts once and never synthesize thirteen. Exact-head `Tests/GrantivaCLITests/RunSessionContractTests.swift:81-87`, `testSuiteNarrationCountsScreensAndFlowsSeparately`, asserts the combined, screens-only, and flows-only helper semantics.
- **B2-K20 [android]: pass supported.** `B2-K20-ready` exits 1, names Home and Broken plus the failed step, continues into `01-browse`, separates screen and flow totals, calls the runner session `screens`, and publishes failed `screens` beside passed `01-browse` in `ready.json`. No anonymous `flow` or staged `grantiva-flows` path appears in relayed runner output. `AND-119-exact-rerun1` supplies the exact 30-second Slow timeout without “interrupt.” Exact-head semantic assertions are `RunSessionContractTests.testTheSummaryCountsScreensAndFlowsSeparately`, `RunCommandTests.testContinueOnFailureStillRunsFlowsAfterAThrowingScreensSession`, the named/per-screen-label expectation in `FlowGeneratorTests`, and `RunnerSessionReportTests.testScreensRunIsKilledAtTheSuppliedTimeout`.

The interrupted Android rerun contributes no verdict beyond these two completed rows.
