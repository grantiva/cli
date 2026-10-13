# Round 4 plan review response

Review input: `findings/round4-plan-review.md`.

All seven load-bearing issues were checked against CLI candidate `8f2cff67`, runner candidate `fd9d8e8`, the binding briefs, and newly accepted L81.

1. **L61 cancellation: addressed.** Task 1 now requires package-private context-aware screenshot, hierarchy and log-tail collection. Timeout cancellation must abort the HTTP request or kill the exact owned shell child, wait for collector termination, and pass a 25-failure goroutine/resource control. The prior permanently blocked `select {}` fake and abandoned-goroutine design are removed.
2. **L80 ordering: addressed.** Review Focus and Task 5 now say completion order is unconstrained. Only whole-record serialization, exactly-once IDs, valid newline JSON, notifications and small-response delivery are required.
3. **L65/L66 live criteria: addressed.** Task 5 names live-session missing-steps runs on both platforms, no-session/wrong-type/empty-array controls, and full IOS-102/B2-K78/D2-36 selector, annotation, exclusion, escaping and retry criteria.
4. **Lifecycle literal controls: addressed.** Task 4 Step 9 now enumerates AND-127/L68, both-platform N3-03/L69, all L72 signal modes and controls, L73 live/free/non-force/helper cases, and repeated immediate L78 inventories plus unaffected-run and terminal-output controls. L71 also retains D2-08 `--app-file`.
5. **L79 surfaces/repetitions: addressed.** Task 3 has a dedicated three-repetition end-to-end gate covering text, JSON, JUnit, index/detail reports, ready summary, error detail, following-step behavior, exit status and the required-step control.
6. **CLI-025: addressed.** Task 6 requires the named full text/JSON ambiguity rerun, Advisory placement, exit 0, selection guidance and `run` rejection.
7. **Paths: resolved against the exact candidate.** The plan now writes every Task 4 CLI source path in full. Contrary to the review's filesystem claim, all three questioned files already exist at candidate HEAD and are therefore correctly marked Modify:
   - `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/RunnerLifecycleDocument.swift`
   - `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaMCPTests/MCPTransportTests.swift`
   - `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCLITests/DocsContractTests.swift`
   `MCPTransportTests` already exercises the real `Server` + `ValidatingTransport` in-memory client/server seam, which Task 5 extends above the actual MCP integration boundary.

Recommended strengthenings were also applied: L64 healthy/post-return controls, L71 D2-08, and a hard packaging stop if any of the four required WDA runtimes is unavailable.

L81 is now the 22nd binding brief. Task 6 owns its `DoctorRunner.checkBootedSimulator` production-entry tests in both device orders, negative ownership/default controls, text/JSON output and unchanged status/exit behavior.

