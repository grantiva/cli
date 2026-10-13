# Task 8 candidate 3 lifecycle fix round 5 review

**Specification verdict: PASS for the scoped round-5 correction.** Mandatory capture now accepts an absent terminal source only while still requiring a retained complete, passed report. This addresses the first-join detached-return failure without relaxing startup timing or completed-report acceptance.

**Quality verdict: PASS.** No new blocking finding in the reviewed delta. Authentication, worker error propagation, bounded non-daemon thread joining, terminal metadata, and pre-SIGINT/pre-force validation remain intact. This is helper review approval, not a passing live lifecycle grade.

## Addressed finding and evidence

Attempt 2 is a harness false failure at the first detached iOS snapshot join. The preserved traceback names the explicit `required terminal runner report disappeared` assertion. The detached CLI exited 0 and emitted started PID 69412, port 8274, and owned device `33BCE8AB-B7F2-4D47-B0B8-2CB1D8A1971E`. Its retained report is top-level passed with an end time, with one passed flow and end time; summary and command counts show no failed/running/pending work. Report device and flow source match PID 69412's authenticated ownership arguments and report directory. The retained log records completed flow/report generation and keep-alive session 69412. Terminal metadata records a prior snapshot and absent terminal source. Failure cleanup subsequently stopped that exact PID/device successfully.

I checked the actual frozen checkout `/Users/kyle/Developer/grantiva-cli/.worktrees/release-round4-candidate3` at `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`, matching the attempt's verified identity. `DriverCommand.swift:219–224` defers removal of the temporary directory containing the report and generated flow. The detached branch hands off the lease after `startDetached` returns; completed launch-report readiness, session recording, started output, and PID return occur before that normal return cleanup. Continued report-source existence at the first helper join is therefore not a valid detached-readiness requirement.

The round-4 review incorrectly treated source absence before the first join as necessarily invalid. The attempt-2 evidence and frozen source correct that assessment. Attempt 2 remains immutable and incomplete as a full lifecycle run; it is not a product failure or a reusable passing lifecycle result. Its startup artifacts show genuine starting states, exit 130 on both platforms, and the exact corresponding SIGINT notices before detached capture failed.

Round 5 removes the worker's source-absence assertion and permits either recorded terminal source state at join. Required mode still reads the retained `report.json`, requires top-level passed/endTime and nonempty all-passed/endTime flows, and rejects missing, malformed, incomplete, or failed retained data. It does not infer completion from `snapshotCaptured` or terminal absence. This addresses the observed first-join defect.

## Scoped regression assessment

The actual before/after helper difference matches the supplied narrow delta. Present-source copying and its exceptions are unchanged; ownership errors and stable-file copy errors still reach the caller before report validation. No new missing-file catch was introduced. Repeated stops only revalidate retained bytes after the worker is joined.

Startup remains explicitly optional and still signals after genuine starting authentication without waiting for ready or report completion. Ready interruption still joins and validates before SIGINT; force teardown still joins and validates before its destructive command. Exact expected-PID/device binding, generated-flow retention, and readiness assertions are unchanged. No new blocking issue was identified within this correction.

Inspected the five new first-join source-removal fixtures and their eight inherited fixtures without executing them. The new cases coordinate source disappearance after authenticated capture while the mocked live runner/session remain, covering retained success, missing/incomplete/failed reports, and the real attempt-2 report with isolated identity paths. The reported 13 passing tests remain author-provided execution evidence.

Verified hashes:

```text
e5ece28eed78f72feb2e0ec7ef0e2da83bfc5b13dda56aeb788360ac907d13b8  task8-candidate3-harness/lifecycle_smoke.py
4c7c2f8e690c5630769d897d20f28569a480d08d73a336db5fb577be5114489c  task8-candidate3-lifecycle-fix-round5.diff
```

Static review only: no fixtures, product tests, builds, live helper, CLI, runner, simulator, emulator, or device commands ran. No source or evidence was edited. Root retains ownership of the fresh live lifecycle run and cleanup.
