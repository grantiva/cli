# Task4 absolute path rewrite follow-up

Commit `e9ae823d0fcb1496b8ef9ccc8be8dd7c72814281`, parent combinedheadf6b4a1ad. Independent review and final suite/CI pending.

Live `cycle-controls-combined/absolute.err` reproduced `/private/private/tmp/.../a.yaml` from an explicitly supplied `/private/tmp/.../a.yaml`. OutputRewriter sequentially replaced inserted targets via another alias. Semantic RED in `unit-fix5-path` reproduces that exact absolute path and the separate streaming target-suffix problem. One-pass regex matching of original text now chooses longest sources and never reprocesses inserted targets. Streaming retains raw original fragments; an earlier complete match is not split by a later partial source, while a longer incomplete source at the same start remains buffered.

All49 focused OutputRewriter/RunnerSessionOutput/FlowReferenceResolver tests pass, fresh empty home remains empty, API key unset. Coverage includes every boundary of absolute and mixed-cycle diagnostics, Unicode source/target paths, overlapping sources, inserted-target suffixes, ordinary non-cycle text, and existing root/as-written controls. Existing warnings preserved; git diff --check passes.

Initial real screens and root controls passed exactly under5s at combinedhead; absolute control failed and was retained. Exact absolute operand applies to the supplied root; untouched nested written operands remain b.yaml/a.yaml/b.yaml. The corrected live replay asserts that existing contract, not an invented requirement to make all occurrences absolute.
