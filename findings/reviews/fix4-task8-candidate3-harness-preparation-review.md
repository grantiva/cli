# Task 8 candidate 3 full-smoke harness preparation review

**Specification verdict: CHANGES REQUIRED.** The prepared tree correctly separates candidate 3 from candidate 2, uses a fresh evidence root and session/device names, rebuilds the CLI from the supplied clean merged HEAD, rebuilds both demo artifacts, and schedules the complete Task 8 smoke rather than importing candidate-2 phase grades. The cleanup helper preserves protected-device boundaries, targeted process handling, the immediate emulator PID/argv reuse check, simulator-managed process non-signaling, exact simulator deletion, and both reviewed AVD identity formats. Three blockers below must be corrected before root executes candidate 3.

**Quality verdict: CHANGES REQUIRED.** This was a static preparation-gate review only. I did not build, test, invoke a helper main, access a device, alter product code, or require live evidence. Candidate 2 and its evidence remain immutable.

## Findings

### P1 — release preparation rejects the actual current QA candidate and backs up the wrong manifest

File: `task8-candidate3-harness/candidate3_release.py:30-33`

The controller loads `findings/evidence/round4-smoke/candidate.json`, which is candidate 1 (`fb7af9d…`, binary `9519a249…`), and requires the current QA binary/bundle to match it. The current QA binary is candidate 2 (`33c62e…`, merge `22055ff…`), as recorded by the binding candidate-2 report and its frozen manifest. Consequently line 30 fails before backup or promotion, so the prepared candidate-3 release cannot run in the required current state. If that assertion were bypassed, the backup's `candidate.json` would still describe candidate 1 rather than the artifact actually being replaced.

Action: resolve and hash the actual current QA binary and bundle, require them to match the frozen candidate-2 manifest (or a separately captured exact current-QA inventory), and copy that same governing manifest into the backup. Keep candidate-2 evidence read-only.

### P1 — unchanged runner source is not bound to `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`

Files: `task8-candidate3-harness/candidate3_release.py:8,73-85`; `task8-candidate3-harness/candidate_identity.py:17-44,56`

The preparation report says the unchanged runner source is independently bound to `ba9008…`, but no executable helper contains or compares that required SHA. `candidate3_release.py` accepts `state['runnerSHA']`, writes it into the new manifest, and selects the fixed proof directory without asserting the value. `candidate_identity.py` then verifies the runner checkout and proof are self-consistent with whatever SHA the new manifest contains. A modified or mistaken runner SHA can therefore become the candidate-3 identity while still passing all of these checks; the fixed `.15` version string does not prove source identity.

Action: define the literal expected runner SHA and require `state['runnerSHA']`, the runner repository HEAD, every frozen uncached-test proof field, and the candidate manifest's `runner.sourceSHA` to equal it. Also require the runner checkout status used for source identity to be clean. Preserve the existing packaged/installed hash, version, stamp, and driver-directory checks.

### P1 — lifecycle snapshot thread errors are still detached from phase success, and the claimed terminal capture can miss the final report

File: `task8-candidate3-harness/lifecycle_smoke.py:380-434` (callers at `452-553` and `695-704`)

The new non-daemon threads are stopped and joined, but exceptions raised by `copy_report_snapshot`, flow copying, or ownership recording terminate only the worker thread. `stop_report_snapshot` checks only `is_alive()` and has no result/error channel, so the exact stable-file copy failure that the helper says must fail can still print a background traceback and let the phase continue. This repeats the acceptance-risk shape identified in candidate 2.

The terminal pass also rereads the session and requires `bound_argv_if_running(pid, device)` before it discovers the report path. Startup interruption can remove the session or exit the runner before the stop request, making lines 411-420 silently skip the terminal copy. Thus it does not reliably close the final atomic-write race described in the preparation report. Detach readiness happens to assert a retained passed report later, but startup/ready interruption and force paths do not establish equivalent complete pre-cleanup evidence.

Action: have each snapshot worker return its exception to `stop_report_snapshot` and re-raise it after the join. Retain the last authenticated report path (and generated-flow path) while the runner is live, then perform the terminal copy from that retained path after the stop request even if the session or process has disappeared. Require the applicable terminal evidence before cleanup/acceptance; continue tolerating only disappearing `.tmp` files.

## Confirmed boundaries

- Candidate-3 phase helpers and controllers point to `round4-smoke-candidate3`, `fix4-8-c3`, and newly owned `smoke4-c3-*` targets. No candidate-2 acceptance file is used to populate a candidate-3 phase result.
- `candidate3_cleanup.py:82-104` inventories the exact owned simulator UUID/name/runtime, classifies only UUID-bearing `launchd_sim`/`Landmarks` processes as simulator-managed, and never signals those processes directly.
- `candidate3_cleanup.py:134-169` re-reads the emulator PID row immediately before fallback signaling, requires the exact emulator/qemu executable plus `-avd smoke4-c3-android -port 5580`, requires live serial-to-AVD identity, exact recorded creation argv, exact registration path/path.rel, and either the legacy owned-name keys or the observed generated `<build>` keys.
- `candidate3_cleanup.py:171-188` proves owned-target absence and preserves the two protected simulator records and the `Pixel_8_API_35` config hash. No global teardown, pattern kill, or default runner-home operation is present in the prepared cleanup path.

After the three P1 findings are fixed, this preparation should receive another static review before candidate-3 execution. Live proof remains root-owned after the L85 merge.

## Scoped re-review — fix diff `cab6f1272913b4e7445388197b3d133f9d43537815a057a4def7d66e40897245`

**Specification verdict: CHANGES REQUIRED.** Two prior P1 findings are resolved. The lifecycle finding is improved but remains open because terminal capture still depends on the snapshot worker winning a scheduling race before startup interruption removes the session.

**Quality verdict: CHANGES REQUIRED.** I reviewed only the supplied fix diff and updated helper interfaces for the three prior findings and new breakage. I did not build, test, execute a helper, or access a device. The reported syntax/JSON checks are preparation evidence only.

### Prior P1: current QA identity and backup — RESOLVED

`candidate3_release.py:32-35` now reads the immutable candidate-2 manifest, requires the current QA binary and bundle to match its exact recorded identities, and backs up those artifacts together with that same manifest under `previous-qa-candidate2`. The previous candidate-1 mismatch and incorrect backup provenance are removed.

### Prior P1: literal unchanged runner identity — RESOLVED

`candidate3_release.py:9-10,77-81,92` binds controller state, the clean runner checkout, uncached-proof source fields, and the frozen candidate record to literal `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`. `candidate_identity.py:5,19-32` independently rechecks the same literal SHA, clean checkout, hashed proof set, proof metadata, command/result, and empty status/home records for every phase. The packaged/installed `.15` version, stamp, and hash checks remain in place.

### Prior P1: lifecycle report capture — PARTIALLY RESOLVED; P1 remains

File: `task8-candidate3-harness/lifecycle_smoke.py:378-447`, especially `383-416`

Worker exceptions now travel through shared state and are re-raised after the bounded join, and a previously authenticated report/flow path is used after session/process disappearance. Those changes resolve the detached-exception and post-authentication terminal-copy defects.

However, starting the thread does not establish that authentication occurred. In `startup_interrupt`, the main thread can read the `starting` session, send SIGINT, wait for exit/session cleanup, and call `stop_report_snapshot` before the new worker is scheduled or before it reaches lines 390-401. Once the stop event is set, the worker skips the loop; if the session has already disappeared it has no fallback path. Lines 414-416 then raise `snapshot worker never authenticated a runner report path`. This makes a valid startup-interruption acceptance nondeterministically fail and still does not guarantee the requested pre-cleanup terminal evidence. The main thread's successful `wait_state` observation does not synchronize with the snapshot worker.

Action: add an explicit authentication handshake before any caller may interrupt or finish the observed runner. For example, have the worker signal a ready/error event only after it has bound the exact PID/device argv and retained report/flow paths, and make each caller wait boundedly for that event; alternatively authenticate and retain those paths synchronously from the already observed starting document. The stop/join path must still propagate worker errors and perform the terminal copy from the retained path.

No other new breakage was found in the scoped diff. Candidate-3 execution remains blocked on this lifecycle race; live proof remains root-owned.

## Scoped re-review round 2 — handshake diff `d7015fae241db2a8fd927038a1c67475c6ea6a694eb268eec6344a3b7518203c`

**Remaining-P1 verdict: RESOLVED.** `lifecycle_smoke.py:378-472` now exposes an explicit authentication/error event. The worker signals it only after the session PID is bound to the exact live device argv, both report and generated-flow paths are retained, and ownership is recorded. An exception before that point signals the same event and is synchronously re-raised by the waiter.

All four call sites wait for authentication before the action that previously created the race:

- `startup_interrupt` first records the genuine `starting` document, then verifies the worker's authenticated PID and only then sends SIGINT. The handshake does not wait for ready state, preserving the startup-interruption criterion.
- detached readiness verifies the starting PID before its secondary probes and before waiting for the foreground command to finish.
- ready interruption verifies the ready PID before hierarchy capture and SIGINT.
- force teardown authenticates before waiting for detached start completion, then cross-checks the authenticated PID against the CLI's completed start JSON before exercising teardown.

Each path retains the bounded stop/join, worker-error propagation, terminal copy from the retained path after session/process disappearance, and mandatory terminal-copy result. The caller/worker scheduling gap identified in the first re-review is closed.

**New-breakage verdict: NONE FOUND in the scoped round-2 diff.** The diff hash matches the supplied `d7015fae…` identity. No execution, build, test, or device claim was reviewed or made.

**Final static preparation verdict: APPROVED.** All three original P1 findings are resolved. This approval covers preparation and helper interfaces only; root still owns post-L85 candidate-3 build, live execution, evidence adjudication, cleanup, and the Task 8 gate.
