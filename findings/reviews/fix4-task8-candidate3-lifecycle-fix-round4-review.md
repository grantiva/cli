# Task 8 candidate 3 lifecycle fix round 4 review

**Specification verdict: PASS for this scoped helper revision.** The remaining round-3 P1 is addressed. Required completed-report proof is now retained and validated before ready interruption or force teardown can remove its source. The L72 startup-interruption exception remains narrow and does not require a completed report.

**Quality verdict: PASS.** No new blocking defect was found in the round-4 delta. Worker joining, retained-report validation, repeated-stop behavior, and narrowed exception handling are consistent with the required lifecycle ordering. This approves the prepared helper for the root-owned fresh live rerun; it does not grade that rerun or authorize treating prior incomplete evidence as a pass.

## Addressed finding

The round-3 P1 combined a post-cleanup recopy dependency with missing complete/passed validation for ready interruption and force teardown. Both parts are addressed:

- In `lifecycle_smoke.py:602`, ready interruption calls `stop_report_snapshot` after readiness, exact expected-PID authentication, and the Landmarks hierarchy assertion, before SIGINT at line 603. The worker completes its terminal copy and joins before validation returns. The finally-block stop at line 616 does not restart the worker or copy from the removed source.
- In `lifecycle_smoke.py:472–493`, required mode reads the retained `report.json` only after joining and propagating worker errors. It requires a passed top-level result with an end time and a nonempty collection of passed flows with end times. Missing, malformed, incomplete, or failed reports fail instead of being counted as captured proof. Repeated calls revalidate retained bytes; live source existence is no longer a post-cleanup prerequisite on the successful ready-interrupt path.
- Force teardown reaches the same required validation at line 768 before the destructive command at line 775. The authenticated PID is compared with the returned start PID before teardown. Detached readiness also passes through this shared completion validation before its existing ready-state assertions and stop command.

No part of the remaining P1 is left unaddressed within the reviewed delta.

## Preserved contract and regression assessment

Startup interruption still explicitly selects `report_required=False`, observes `starting`, authenticates the expected runner PID/device binding, and sends SIGINT without waiting for `ready`. Exit 130, the exact platform notice, runner absence, and session cleanup remain required. Optional mode retains observed raw report bytes and truthful terminal absence metadata without imposing completion on an interrupted startup.

The original evidence under `findings/evidence/round4-smoke-candidate3/03-lifecycle` remains immutable and classified only as a harness failure after the iOS startup-interrupt assertions passed. It remains incomplete as a full lifecycle run. This review did not modify or reclassify those artifacts.

The narrowed session parse/process-disappearance catch no longer encloses report copying or ownership persistence. Ownership errors, including `KeyError`, therefore reach the worker error channel and caller. The existing non-daemon thread, bounded join, expected-PID handshake, exact device argument check, generated-flow retention, and readiness criteria are preserved. Stable-file copy errors still propagate; the change introduces no blanket missing-file suppression. Required source absence before its pre-cleanup terminal capture still fails, as intended.

## Verification scope

Reviewed the round-3 review, round-4 report, exact round-4 diff, fixture source, and actual helper call sites. The eight supplied fixtures were inspected, not rerun. Their cases cover retained-success/source-removal/repeated-stop behavior, missing and incomplete/failed required reports, optional startup bytes and terminal absence, ownership and copy errors, and cleanup ordering. The reported fixture result is author-provided evidence, not an independently executed result of this review.

Verified file hashes:

```text
38a48f3765fd4615f483f066ed6519da0f9fa31746f52aa3dd66dc37ed21e0d9  task8-candidate3-harness/lifecycle_smoke.py
b79c7ec546c5092c54c3e623bc7a57edce4bfaa29b382acd466b056e56bec347  task8-candidate3-lifecycle-fix-round4.diff
```

This was a static scoped re-review. No fixtures, product tests, builds, live helper, CLI, runner, simulator, emulator, or device commands were executed. No product or helper source was edited. Fresh lifecycle retry, force-teardown evidence, and final cleanup remain with root.
