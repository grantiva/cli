# Round 4 fix-wave plan re-review

Reviewed:

- `docs/superpowers/plans/2026-10-13-round4-fix-wave.md`
- `findings/round4-plan-review-response.md`
- the new binding L81 brief
- the exact CLI `release-main` candidate paths cited by the response

This was a scoped static re-review of the previously reported seven issues, the three strengthenings, and L81. It did not reopen unrelated plan choices or run product/device work.

## Verdict

**READY.** All seven required corrections and all three recommended strengthenings are materially present in the plan. L81 is correctly added as the 22nd binding brief and is assigned a complete test-first implementation and acceptance path in Task 6. I found no new load-bearing omission in the changed scope.

## Resolution audit

1. **L61 cancellation — addressed.** Task 1 now uses package-private context-aware screenshot, hierarchy and log-tail methods, requires cancellation acknowledgement, forbids abandoned goroutines, and adds a 25-failure resource control. Drivers without the internal interface remain synchronous rather than being wrapped in an unkillable timeout goroutine.
2. **L80 ordering — addressed.** Review Focus and live acceptance now require whole valid records and exactly-once IDs while explicitly leaving completion order unconstrained. Small responses and notifications remain covered.
3. **L65/L66 live coverage — addressed.** Task 5 requires the exact L65 live-session error on iOS and Android plus precedence/type/empty controls, and the full IOS-102, B2-K78 and D2-36 selector criteria.
4. **Lifecycle controls — addressed.** Task 4 now spells out the complete AND-127 and N3-03 forms, all L72 output modes and causal controls, L73 live/free/non-force cases, and repeated immediate L78 inventories with the unaffected-run and terminal-output controls. L71's app-file leg is also explicit.
5. **L79 surfaces — addressed.** Task 3 requires three end-to-end repetitions across text, JSON, JUnit, report/detail and ready summary, preserves useful error detail and the following step, and includes the nonoptional failure control.
6. **L67 CLI-025 — addressed.** Task 6 names the exact text/JSON rerun, Advisory placement, exit 0, selection guidance and unchanged ambiguous-run rejection.
7. **Candidate paths — resolved.** The earlier review's nonexistence claim was incorrect because it inspected the regression worktree instead of the exact `release-main` candidate. The following files all exist at the candidate and are correctly marked `Modify`: `Sources/GrantivaCLI/RunnerLifecycleDocument.swift`, `Tests/GrantivaMCPTests/MCPTransportTests.swift`, and `Tests/GrantivaCLITests/DocsContractTests.swift`. The MCP test already sits above the real `Server`/`ValidatingTransport` integration seam described by the plan.

The strengthenings are present: L64 includes healthy and post-return controls, L71 includes the D2-08 app-file control, and packaging now stops rather than omitting or reusing a cache when any required WDA runtime is unavailable.

## L81 audit

L81 is mapped once in the 22-row coverage map and owned by Task 6. Its plan steps match the brief:

- tests call the full `DoctorRunner.checkBootedSimulator` entry point;
- both simulator-list orders are covered;
- the unowned-default note is required while the booted check stays `.ok` in Advisory and preserves exit behavior;
- absent-default and Grantiva-owned-default negative controls are included;
- existing no-booted and list-failure behavior is preserved;
- text and JSON exposure are included in acceptance.

The plan consistently says 22 findings/briefs in its goal, ledger, matrix, and self-review, and the coverage map contains exactly 22 distinct entries.

The corrected plan is execution-ready for Task 0.
