# Task 8 candidate 2 joint-forward helper review

Scope: `task8-candidate2-forward-report.md`, `task8-candidate2-forward.diff`, the new `task-8-candidate2-harness/forward_joint_live.py`, and the previously reviewed `forward_joint_live.py`. This was a bounded read-only review apart from this review artifact. No live command, device operation, build, product edit, or broad test was run.

## Verdicts

- **Specification compliance: APPROVED.** Candidate/ownership provenance, all four forward-cleanup cases, both unrelated controls, and exact session/process/PID/forward absence at both timed checkpoints satisfy the requested preparation contract.
- **Code quality: APPROVED.** The focused PID-set propagation closes the sole identified gap through the existing common absence routine without duplicating checks or weakening nearby cleanup behavior.

## Focused re-review

**Prior P1 — ADDRESSED.** `run_owned_case()` now forms `known_pids = set(seen) | {p.pid}` and passes the complete set to `absence()`. Inside both the `immediate` and `after1s` iterations, `absence()` checks every known PID for an empty prefixed global-session glob and an absent-or-zombie exact process state, alongside the existing project session, device-bound global session, exact installed-runner/device process, and exact control-forward checks. Foreground cases pass their ready runner PID as a one-element set through the same path. The reported AST contract directly covers the required data flow. No new scoped breakage was found.

## Accepted portions

- The helper imports and invokes the approved sibling `candidate_identity.validate` before live work, passing the candidate and ownership manifests, CLI source root, binary, bundle, packaged runner, runner home, Android device ID, and AVD. This preserves CLI/demo/runner source bindings, hashes, versions, install stamp, proof qualification, and controller ownership.
- Runtime uses the candidate manifest's installed runner, its native version is checked against the manifest, CLI source HEAD/status and binary version are rechecked, and the environment uses literal session `fix4-8` with the API key removed. No stale `a587…`, `6b3…`, `.14`, `fix4-84`, source override, repair manifest, or test-only runner binding remains.
- Foreground interrupt and normal stop retain ready identity, exact runner executable/device argv, owned forward presence, hierarchy exercise, exits 130/0, exact interrupt notice, and PID/session/process/forward absence immediately and after one second.
- Absent-app and healthy-stock retain their expected exits, before/after device-scoped global-session and exact-runner process inventories, observed runner PIDs, and immediate plus delayed exact control-only forward inventories. Their spawned and observed exact runner PIDs now also receive PID-specific session and process checks at both timed checkpoints.
- The fixed `tcp:6790 -> tcp:16790` and dynamically allocated `-> tcp:16791` controls must be the entire owned-device forward inventory before cases and after each case. Final cleanup asserts those exact controls when both were created, removes only recorded controls and owned ports, and requires the owned-device inventory to return to its empty baseline.

The report's compilation, help, argument-rejection, and static checks are credible and were not repeated. This review covers helper preparation only and does not authorize or assess candidate execution.
