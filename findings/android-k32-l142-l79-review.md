# Android K32, recovered L14.2, and L79 review

Candidate CLI: `8f2cff67`; runner: `fd9d8e8`. This review used retained round-3 files only and performed no device operation.

## B2-K32: PASS

The valid evidence is `B2-K32-absent-app-rerun2` (rerun1 is superseded). It creates a unique fresh AVD, proves `pm path com.kylebrowning.landmarks` is empty, and runs the literal two-step repro.

- `build install --no-build` exits 1. Its only product error sentence names `com.kylebrowning.landmarks`, `cov3-android-k32-r4 (emulator-5556)`, says the app is not installed, and gives install/`--no-launch` remedies. Neither stream contains monkey `arg=` or `data=` output.
- `runner start --detach` exits 0. Stdout contains only the detached-runner result block (plus its tail/stop instructions); stderr contains the normal `Starting runner`, application ID, and device progress. Neither stream contains monkey output.
- Targeted stop succeeds, teardown kills the recorded row-owned AVD, delete removes it, and the unrelated primary remains.
- The exact-head `ADBTests.swift` excerpt contains the monkey argument-trace fixture and semantic assertions for a missing package: package/device wording, one-line message, and no `arg=`/`data=`. It also covers an exit-0 monkey abort and an unrelated launch failure retaining only the last meaningful line.

This covers every B2-K32 clause. The detached runner does not need the app installed because it starts the automation service without launching the application; its clean output is the required second control.

## B3-L14.2 recovered session: complete, not interrupted

The recovered evidence directory is `B3-L14.2-cancel-gradle-rerun1`. Its immutable outputs show the harness completed its assertions and cleanup:

- `client.exit` is 0; `runtime/decoded.json` has all four checks true.
- A real project-scoped Gradle process is present at cancellation.
- The cancelled request ID has no response; `runtime/responses.json` contains only `init` and `post-cancel-list`.
- `runtime/child-gone-within-5s.txt` is `true`, the descendant and project-build survivor files after five seconds are empty, and the next `tools/list` response is complete.
- The MCP server's `runtime/mcp.exit` is `-15`, which is the harness's terminal server shutdown after receiving the post-cancel response, not evidence that the test was interrupted.
- `processes-final.txt` and the scoped survivor captures contain no row-owned Gradle child. A full local evidence hash manifest exists, but it includes generated build/cache paths and should not be committed as a purported manifest of the narrower retained set.

Verdict: **B3-L14.2 [android] PASS**. Generated `project/.gradle/` and `project/**/build/` trees are execution byproducts and should not be committed; the runtime captures, frozen input/source excerpts, commands, and manifest-relevant non-cache artifacts are sufficient.

## L79 brief: supported after cause correction

The corrected controller brief `L79-optional-tap-failure-exits-nonzero.md` now matches the raw contradiction:

- Runner stderr says `PASS`, and each `report/report.json` has overall `status: passed`, summary one passed / zero failed.
- The optional command remains command-level `failed` with `element_not_found`.
- CLI stdout reconstructs that command as a failed step, reports zero passed / one failed, and exits 1.
- Exact CLI source explains the boundary: `RunnerReportSteps.swift` converts raw failed commands into failed `StepResult`s; `RunCommand+Result.swift` and `RunCommand.swift` require all reconstructed steps to pass for the summary and exit status.
- First lookup latency remains independently passing (99.737–150.490 ms exact-text responses); the approximately seven-second duration is the optional polling budget.

The brief no longer incorrectly attributes the overall failure to runner flow aggregation. Its expected behavior, source-supported cause, scope, and positive/negative acceptance controls are review-ready.

## Commit scope

CLI review files:

- `findings/android-b2l02-l05-l06-b3l05-l06-review.md`
- `findings/android-k32-l142-l79-review.md`
- Other already finished untracked reviews visible in this worktree: `findings/android-b3l142-cancel-parent-review.md`, `findings/android-k27-pty-parent-review.md`, and `findings/android-n02-k54-parent-review.md`.

Controller brief:

- `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L79-optional-tap-failure-exits-nonzero.md` in the regression worktree.

Android evidence/scripts that are complete for this review:

- `findings/evidence/cov3-android/B2-K32-absent-app-rerun2/`
- `findings/evidence/cov3-android/B3-L14.2-cancel-gradle-rerun1/input/`
- `findings/evidence/cov3-android/B3-L14.2-cancel-gradle-rerun1/runtime/`
- `findings/evidence/cov3-android/B3-L14.2-cancel-gradle-rerun1/{client.exit,commands.txt,load1-immediately-before.txt,processes-final.txt}`
- `findings/evidence/cov3-android/B2-B3-L02-L05-stock99-quiet-rerun2/`
- `findings/evidence/cov3-android/B2-L05-L06-exact-rerun3/` (L79 raw plus selector evidence).

Exclude `B3-L14.2-cancel-gradle-rerun1/project/.gradle/`, every `project/**/build/` tree, unrelated generated caches, and `B3-L14.2-cancel-gradle-rerun1/all-files.sha256` because that full-tree manifest names those excluded files. In this CLI worktree, also exclude `findings/mcp082-pipelined-harness/__pycache__/`. `findings/harnesses/run-android-d2-05-compound-maestro-v2.sh` is an obsolete unexecuted v2 harness and should remain excluded in favor of the completed v3 evidence owned by the Android slice.
