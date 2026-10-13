# Task 3 iOS-handoff integration re-review

Compared the current `cov3-cli` `findings/cov3-cli-results.md` and `task-3-report.md` with checkpoint `5a7a1b43`, then checked every newly cited iOS capture against the raw evidence in this worktree.

Verdict: **ADDRESSED**. The seven latest-verdict transitions are evidence-backed and the revised counts reconcile: 368 pass, 7 fail, 5 blocked, 4 n/a across 384 unique CLI matrix IDs.

- CLI-048/049 cite the exact relative/missing run-flow and named cycle captures.
- CLI-061 claims byte-preserving parse/staging only and expressly excludes the deliberately missing runtime target.
- CLI-064 claims the executed flow's `id: heart` selector; it does not contradict the separate MCP label-fallback defect.
- CLI-066 accurately reports bare DOWN and explicit up conversion.
- B3-L14.1 joins prior CLI immediate/unknown-id/source evidence with attempt11's measured 212.6 ms delayed cancellation and following live `tools/list`; it does not use attempt11b's cleanup evidence.
- N3-11 joins the earlier install/version/hierarchy captures with attempt9b, the first capture that reaches real RunnerManager, warns exactly once, and stops from the same scratch runner home without another warning.

The report preserves earlier blocked/inconclusive observations rather than rewriting them and correctly says the CLI worker itself performed no device action. The absolute handoff paths in the CLI ledger resolve to the cited raw captures in the current campaign workspace; the report also gives repository-relative cross-worktree references. No overclaim found in the scoped changes.
