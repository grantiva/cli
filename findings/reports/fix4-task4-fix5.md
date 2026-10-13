# Task4 absolute path rewrite follow-up

Commit `e9ae823d0fcb1496b8ef9ccc8be8dd7c72814281`, parent combinedheadf6b4a1ad. Independent review and final suite/CI pending.

Live `cycle-controls-combined/absolute.err` reproduced `/private/private/tmp/.../a.yaml` from an explicitly supplied `/private/tmp/.../a.yaml`. OutputRewriter sequentially replaced inserted targets via another alias. Semantic RED in `unit-fix5-path` reproduces that exact absolute path and the separate streaming target-suffix problem. One-pass regex matching of original text now chooses longest sources and never reprocesses inserted targets. Streaming retains raw original fragments; an earlier complete match is not split by a later partial source, while a longer incomplete source at the same start remains buffered.

All49 focused OutputRewriter/RunnerSessionOutput/FlowReferenceResolver tests pass, fresh empty home remains empty, API key unset. Coverage includes every boundary of absolute and mixed-cycle diagnostics, Unicode source/target paths, overlapping sources, inserted-target suffixes, ordinary non-cycle text, and existing root/as-written controls. Existing warnings preserved; git diff --check passes.

Initial real screens and root controls passed exactly under5s at combinedhead; absolute control failed and was retained. Exact absolute operand applies to the supplied root; untouched nested written operands remain b.yaml/a.yaml/b.yaml. The corrected live replay asserts that existing contract, not an invented requirement to make all occurrences absolute.

Live replay and cleanup are now complete; exact criteria, all raw paths, failures and provenance are indexed in task-4-live-report.md. Final05d8cd39 pushed to PR208; independent review, full suite and CI pending.

Final update: final05d8cd39 full suite passed2006 tests, zero failures, fresh empty runner home/API key unset, evidence integration-fix6. All live criteria completed. The retained fix4-4 capacity reservation found during independent review was released through supported simulator teardown --session-id fix4-4; ios-capacity-cleanup-fix6 proves pre/post ledger active→[], no task devices/processes and unchanged owner states. No live acceptance or cleanup remains pending. Final-head CI and independent fix5–6/source/live acceptance review remain pending. No push beyond already-authorized05d8cd39 or merge was performed.
