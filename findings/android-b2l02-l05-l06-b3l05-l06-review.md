# Android crash and first-lookup review

Reviewed against candidate `8f2cff67`, runner `fd9d8e8`, and the literal matrix clauses for B2-L02, B2-L05, B2-L06, B3-L05, and B3-L06. This is a read-only review of retained round-3 evidence.

## Verdicts

| Row | Verdict | Reason |
|---|---|---|
| B2-L02 | **FAIL on retained evidence; controlled rerun required before defect attribution** | The exact current-round `99-crash.yaml` repetitions correctly report `app_crash` and capture artifacts promptly after `am_crash`, but flow durations are 17.528 s, 13.206 s, and 10.420 s (all over the required 6 s), and wall times are 27.01 s, 23.70 s, and 26.92 s (all over 12 s). Those older captures have no retained host-load samples; the newer selector batch finishes in 4.31–5.25 s. A quiet exact-stock rerun is needed before attributing the old timing miss to the product. |
| B2-L05 | **PARTIAL / observed timing fail pending controlled rerun** | Present and absent first element requests satisfy the lookup bounds. The retained exact `99-crash` repetitions exceed the flow/wall bounds, but lack contemporaneous host-load evidence and should be repeated under controlled load before final defect attribution. The optional-step exit-1 behavior is a separate product contract defect. |
| B2-L06 | **PASS** | Index-0, relative-below, and width variants each fail 3/3 with `app_crash`; launch-to-FATAL is about 0.52 s and launch failure is 1.17–1.28 s. No selector step passes. Exact runner semantic tests cover the selector path skipped when cold launch detects the crash first. |
| B3-L05 | **PARTIAL / observed timing fail pending controlled rerun** | Present and absent first element requests satisfy their bounds. The retained exact stock crash runs violate the 6 s flow and 12 s wall bounds but lack host-load samples, and the retained evidence has not yet established the maximum first lookup across all stock flows. The optional-step exit-1 behavior is a separate product contract defect. |
| B3-L06 | **PASS** | Index-1-regex and tap-fallback variants add 3/3 failures each to the B2 selector variants. Every runtime failure is `app_crash` at cold `launchApp`, about 0.52 s after launch; the matrix expressly permits the selector half to be graded from the exact runner tests in this case. The retained stock control passes. |

## Timing evidence

The present-element evidence is `S2-01-inputtext-three-runs-rerun1`. Its first `POST .../elements` for `Deep Links` takes 715.422 ms, 733.324 ms, and 762.021 ms. The corresponding first `tapOn` report durations are 867 ms, 893 ms, and 948 ms. This satisfies the under-2-second find and under-3-second tap bounds.

The absent evidence is `B2-L05-L06-exact-rerun3/runs/l05-absent-{1,2,3}`. The frozen input is exactly `launchApp` followed by `tapOn: {text: "No Such", optional: true}`. The first exact-text `POST .../elements` answers with no match in 99.737 ms, 129.910 ms, and 150.490 ms. The subsequent content-description attempts take 606.890 ms, 603.117 ms, and 607.959 ms; regex attempts take 24.782–26.882 ms. These requests satisfy the under-2-second first-lookup criterion. The 7086–7106 ms command duration is the designed optional-find polling budget and must not be substituted for an individual 404 response time.

There is nevertheless a distinct product-contract failure: every optional command is serialized as `failed` with `error.type=element_not_found`, and every CLI invocation exits 1 even though its human summary says the optional step passed. Runner source at exact head says optional failure must be converted to warned/passing flow status: `pkg/executor/runner_test.go` (`TestRunner_Run_OptionalStepFailure`) expects `StatusPassed`, while `pkg/core/result.go` treats warned optional results as non-failing. This is not a matrix L05 lookup-latency failure, but it is supported new-defect evidence suitable for L79.

The exact stock crash evidence is `CF-crash1`, `CF-crash2`, and `CF-crash3`:

| Run | Flow | Wall | `am_crash` to failed-command end | Result/artifacts |
|---|---:|---:|---:|---|
| 1 | 17.528 s | 27.01 s | 1.863 s | `app_crash`; screenshot and hierarchy on failed assert |
| 2 | 13.206 s | 23.70 s | 1.229 s | `app_crash`; screenshot and hierarchy on failed assert |
| 3 | 10.420 s | 26.92 s | 0.695 s | `app_crash`; screenshot and hierarchy on failed launch |

Thus crash recognition and artifact completion are within about two seconds of `am_crash`, but the independent flow and wall limits fail in all three repetitions. These captures contain no host-load snapshot. Because the newer crash-selector runs complete in 4.31–5.25 seconds, the old 23.70–27.01-second wall results cannot by themselves distinguish product latency from transient host contention. They remain literal failure evidence, while a quiet exact-stock three-run complement is the minimum evidence needed for final causal classification.

The fresh selector batch `B2-L05-L06-exact-rerun3` records these ranges:

- B2 variants: index 0, below, and width each fail 3/3; wall 4.31–5.25 s; failed launch duration 1.168–1.279 s.
- B3 additions: index 1 regex and tap fallback each fail 3/3; wall 4.65–5.23 s; failed launch duration 1.159–1.203 s.
- Every one records `LANDMARKS_CRASH_ON_LAUNCH`, `FATAL EXCEPTION`, and `error.type=app_crash`; the FATAL line follows the launch log by 0.521–0.527 s. All later selector/tap commands are skipped, never passed.

## Evidence paths

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-L05-L06-exact-rerun3/summary.json`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-L05-L06-exact-rerun3/input/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/S2-01-inputtext-three-runs-rerun1/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/CF-crash1/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/CF-crash2/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/CF-crash3/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/D2-02-stock-ready-pass-rerun1/`

The exact runner selector/crash semantic tests previously retained with the campaign supply the source half for selector paths skipped after launch-time crash. The runtime verdicts above do not rely on test names alone.
