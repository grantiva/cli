# iOS 47 and Android K17v3 scoped review

This follow-up began only after both batches completed. It reviews iOS attempt 47 N3-01/02/03 and Android `B2-K17-temp-provenance-rerun3`; no live command was run.

## Findings

1. **Minor — B2-K17 [android] should cite its exact source assertion.** The runtime proof is valid and complete, but the ledger cites only runtime directories. Add `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/RunnerReportContractTests.swift:44-93` at CLI `8f2cff67`: it explicitly checks real command durations/statuses, failure-path durations/status, and generated screen-step sums including launch-only. State that source was inspected, not newly executed.

## Approved conclusions

- **N3-01 [ios]: approved by an explicit current-round join.** Attempt 47 cleanly proves the three named session tools return normal JSON-RPC results with `isError:true` and exact retryable WDA-starting text during an observed `session.json` `starting` state. Attempt 16c transcript line 17 records an explicit `runner start ... --detach` returning exit 0 and `Runner started (detached)`; lines 61-62 and raw stdout line 19 then record `grantiva_screenshot` returning an `image/png` result. The app had subsequently been terminated, which strengthens the intended parenthetical: screenshot is device-level and succeeds after detach returned without requiring the app session. Together these satisfy the distinct starting and post-detach screenshot clauses.
- **N3-02 [ios]: approved.** Attempt 47 captures both hierarchy and screenshot resources returning JSON-RPC `-32002` with exact starting text, without an invalid-argument label, internal error, or no-session text. The current-candidate attempt-6 ready-resource captures validly supply the required successful transition.
- **N3-03 [ios]: fail is supported.** During a directly observed starting state, the second JSON and text starts identify the same first runner PID. Text has the required `starting` wording. JSON reports `already_running` but omits the required `port:null`, so the binding criterion fails. The evidence supports this exact contract defect; it does not need to prove a second product defect.
- **B2-K17 [android]: approved, subject only to citation finding 2.** The preserved verbose runner command names the exact temporary report copied by a terminal-state monitor. That report is passed with 22/22 terminal commands. Every emitted screen-step duration equals the corresponding generated command duration or exact command sum, including launch-only Home at 2278 ms → 2.278 s. The retained failing JSON control agrees exactly with its report at 1532/990/17148 ms and passed/passed/failed statuses. No fake zero appears.

The monitor's 349 copy iterations are provenance for the terminal report, not 349 independent executions.
