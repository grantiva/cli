# Campaign completion plan

Status: executing. Requested by Kyle after the 17-hour status checkpoint.
Authority: full-coverage-campaign-design.md; existing campaign authorization for fixes, PRs, CI and merges remains active. No tags or releases.

## Outcome and constraints

Finish with one frozen binary completing the approved 1,489 effective coverage keys and 39 separate iOS runtime qualifications, with no product findings or unresolved acceptance gates. Preserve explicit environment-blocked rows; do not count them as passes or conceal their limitations. If those limitations prevent the exit criterion, report that precisely.

The approved feature matrix and protected-device constraints remain unchanged. No default-home writes, broad cleanup, owner-device changes, or credential-dependent operations. All raw first failures remain immutable. New candidate means fresh results, not transferred passes.

## Task 1: Close the failed diagnostic run and stabilize execution

Close candidate3 coverage as INCOMPLETE / FAILED: the source suite exposed L86, so completing the rest on this known failing binary would require substantial duplicate work. Preserve candidate identity, source tests, 40 CLI proposed passes, iOS evidence gaps, Android fixture failures, blocked rows, and all unexecuted keys. Publish exact counts with provisional versus accepted evidence distinguished. Keep the existing matrix intact.

Finish the already-open Android helper correction/review, limited to stable process identity, reserved port, bounded probes and immutable failure journals. Correct iOS capture omissions in one bounded preparation task: intermediate runtime/state snapshots, command metadata and group artifact identity. Reuse the approved CLI capture helper. No new general test framework, repeated broad harness audits, or implementation of hypothetical improvements. Validate only changed behavior; reviewers consume existing test evidence and review fixes within scope.

Before new live work, inventory and retire only authenticated campaign-owned devices/processes. Preserve original raw process captures locally; publish only reviewed safe derivatives where broad process captures may contain sensitive values. Do not stage worktree dirt indiscriminately.

## Task 2: Fix L86 simulator ownership race

Base: frozen CLI 6ba12ed37658228a3ce87cb64e1f5d88dda38e07 in a fresh isolated fix worktree. Read docs/superpowers/plans/2026-10-13-coverage-issues-round4/L86-twin-boot-loses-simulator-ownership.md and findings/reviews/fix4-task9-twin-boot-failure-diagnosis.md from the controller worktree as exact requirements.

Create deterministic red evidence for stale snapshot -> twin activation -> prune/claim. Fix the ownership invariant without inferring Grantiva ownership merely from Booted state. Audit every snapshot-fed prune entry point. Cover real stale pruning, pending twins, capacity, foreign sessions, manual devices and ownership-aware teardown. Replace sleep-dependent scheduling in the affected regression with deterministic coordination where appropriate. Preserve source and raw red/green logs.

Run relevant SimulatorCapacity/SimulatorManager tests, then the full suite once, each in fresh isolated homes with API key unset. No live device operations during source implementation. Obtain one independent spec/quality review, scoped fix reviews only as necessary. Controller allocates a separate owned live simulator for concurrent ensure and ownership-aware teardown acceptance after source review. Run required CI and squash merge after approval. No runner rebuild/version bump unless the actual source change requires one.

## Task 3: Prepare and freeze the replacement candidate

Build the merged CLI once in a clean release worktree, retaining existing candidate artifacts. Keep unchanged runner/demo artifacts and verify their recorded hashes. Reuse the reviewed smoke harness with fresh candidate/session/device bindings. Execute required smoke acceptance, cleanup, and provenance checks; freeze a new immutable manifest only after success. Do not rerun unchanged runner/WDA builds solely because the CLI changed.

## Task 4: Execute final full coverage

Create clean result destinations for the new candidate. Three slice actors own CLI, iOS and Android; root alone manages device allocation and scarce host windows. Device-free CLI work may overlap one live slice. Serialize compiler-heavy work and load-sensitive Android work against iOS boot/WDA work. Use standing row delegations instead of approval per command.

Execute approved keys in order within each slice, exact expectations, explicit clause-level verdicts, immutable raw capture. Batch review and controller reconciliation at natural feature-group boundaries; do not review every ordinary command as a separate task. Progress reports state verified counts, failed/blocked counts, active work and next dependency. Reuse shared fresh evidence only where the matrix permits; never infer success from command invocation alone.

On a new product failure, preserve it, perform the smallest independent confirmation needed to distinguish fixture from product, and triage immediately. Decide whether remaining independent coverage materially reduces future rework before continuing a known failing candidate. Do not spend a full matrix merely to rediscover a known gate failure.

## Task 5: Reconcile and close

Join every required key, shared platform half and runtime qualification. Review all B4 rows, non-passes, reruns, provenance and owned cleanup. Turn every product failure into an actionable brief and follow the approved fix/repack/coverage cycle until the exit criterion is met. Publish honest blocked limitations. Commit and push scoped evidence/docs; required PRs merge only after checks pass. Final report distinguishes passing, failing, blocked and unexecuted counts. No clean claim while any acceptance gate remains unsatisfied.

## Execution safeguards against repeated churn

- Existing completed Tasks1–8 are history, not redispatched work.
- One product implementer at a time; independent evidence consolidation can proceed concurrently.
- Existing helper repair resumes its author; no fresh redesign or duplicate reviewer.
- Minor review observations are ledgered, not grounds for expanding the current fix.
- Every test/build has a named acceptance purpose; passing checks repeat only after relevant changes or an unresolved concern.
- No time estimate until replacement freeze and measured feature-group throughput provide evidence.

## Task4 interruption: L87 runner fix

Candidate4 full coverage is FAILED / INCOMPLETE after the exact iOS26 stock run and diff capture both fail the Detail navigation sequence. Preserve the passed candidate4 smoke gate and completed coverage as historical evidence; do not spend the remaining matrix on the known failing runner.

1. Retain both public failures and minimal hierarchy/screenshot diagnosis. Return owned iOS resources safely; freeze remaining coverage as unexecuted.
2. One isolated runner implementer adds deterministic competing-button RED evidence, then the smallest tap-only BackButton preference. Preserve all selector semantics, ordinary fallback, frozen demo and configuration. Run focused tests only after iOS yields the compiler window.
3. One independent source/spec review; correct only substantiated defects, at most five review rounds. Then run required runner checks and bounded owned iOS26/iOS27 live acceptance.
4. Pass required CI, merge the reviewed fix and package/freeze a replacement using the established workflow. Do not rebuild unchanged demo or WDA. Reuse unchanged source-test evidence under existing provenance rules; do not transfer prior runtime verdicts to a different candidate.
5. Resume the full approved matrix on the replacement and complete final reconciliation/owned cleanup. No tags/releases; no further routine permission requests.
