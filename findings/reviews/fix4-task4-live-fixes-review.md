# Source / Spec Verdict

**Approved for the scoped fixes 2–4.** The three live-discovered defects are addressed in the reviewed source. This does not mark Task 4 complete: remaining live acceptance and final-head CI are controller-owned gates still pending.

- **Fix 2 — Android startup report location: ADDRESSED.** `Sources/GrantivaCLI/DriverCommand.swift:285–287` adds `--flatten` beside the explicit output directory, before the positional flow. The option is conditional on a report directory, preserving the iOS argument path. `Tests/GrantivaCLITests/RunnerLifecycleCommandTests.swift:9–15` exercises production argv construction. Retained Android replay evidence records the expected `report/report.json` location, immediate app hierarchy, matching runner PID/device, and successful stop/forward cleanup (`live/android-lifecycle-attempt2/report-path.txt`, `checks.json`).
- **Fix 3 — real mixed cycle path shape: ADDRESSED.** `Sources/GrantivaCore/Runner/OutputRewriter.swift:29–65` canonicalizes relative hops only in the circular-dependency diagnostic, only after a known preceding display path, and only to another known display target; relative escapes above the project remain unchanged. `:73–90,102` buffers the incomplete diagnostic and marker prefix across streaming chunks. `Tests/GrantivaCoreTests/RunnerSessionOutputTests.swift:533–540` now models the observed staged/absolute/relative shape, while `OutputRewriterTests.swift:61–85` covers every two-chunk boundary plus unknown, escape, absolute and ordinary-operand controls. The controller explicitly authorized this narrow extension beyond the original merge-only instruction. Both retained real cycle runs emit the exact four-hop chain (`live/android-cycle-attempt2/alias.err`, `private.err`); their result files report 1.75 s and 3.04 s respectively, within the five-second criterion.
- **Fix 4 — concurrent cleanup returns before session removal: ADDRESSED.** `Sources/GrantivaCLI/RunnerOutputForwarder.swift:3–21` holds the Once lock through body completion, so a concurrent caller cannot return while that cleanup remains active. The no-reentry contract is documented. `Tests/GrantivaCLITests/RunnerLifecycleCommandTests.swift:53–79` exercises the production Once with a blocked cleanup and a concurrent caller; the retained RED observed premature return and GREEN waits through the blocked interval.

# Quality Verdict

**Approved. No new Critical or Important defects identified.** The report option is narrowly scoped, diagnostic normalization preserves unrelated operands, and the cleanup synchronization matches the current production call graph.

## Named Integration Check: Once Reentrancy and Lock Ordering

- Checked every production Once construction and invocation using a focused search of `Sources/GrantivaCLI`. The startup cleanup at `DriverCommand.swift:644–649` only removes owned session/marker files and releases its lease. The hold wrapper at `:801–812` owns a separate Once whose body calls the startup Once via `:786`. The acquisition order is therefore hold Once → startup Once; no startup-cleanup path calls the hold Once or re-enters itself.
- Checked the cleanup implementations at `DriverCommand.swift:430–432`, `KeepAliveSessionStore.swift:246–258`, and `SimulatorLease.swift:391–411`. They do not invoke lifecycle callbacks. Lease release takes its own state lock, releases it before filesystem cleanup, and does not acquire either Once lock.
- Checked `SignalRelay.swift:251–275`: it snapshots pending callbacks and releases its own lock before terminating groups or calling cleanup. Consequently a concurrent relay caller waiting on a Once does not retain the relay lock, and the changed Once introduces no relay/Once lock inversion in these call sites.

# New Breakage in the Fix Diff

- None identified.

# Evidence and Limits

- Read the three reports and complete fix package once: approved base `9c7748523e703338887124a52a0a3af6d40a884b` → `60ccdf13a74e4ab6bb7966cc2af067ec13ddfb10` (three commits, six changed files). No git commands, source changes, device operations, subagents or test reruns.
- Verified semantic RED captures: `live/unit-fix2/red.out:17` shows missing `--flatten`; `live/unit-fix3/red.out:412–415` shows the two uncanonicalized relative hops for both spellings; `live/unit-fix4/red.out:17` shows the concurrent caller returning while cleanup remained blocked.
- Verified focused GREEN evidence: `live/unit-fix2/green.out:143` reports **63 lifecycle tests**, `live/unit-fix3/final.out:111` reports **46 focused path/rewriter/resolver tests**, and `live/unit-fix4/green.out:145` reports **64 lifecycle tests**, all with zero failures. Their status JSON files record exit 0 and empty scoped runner homes.
- The existing `CLILogHandler.swift:34` deprecation and `OutputRewriterTests.swift:23` never-mutated-variable warning appear in `live/unit-fix3/final.err:5,42`. Neither originates in these fix hunks; this review does not call that test output pristine.
- No final-tree full-suite/CI result was verified here. The continuing plain/quiet/JSON interruption repetitions, timeout/death controls, teardown/log-child acceptance and other recorded live gates remain open until the controller records their results. Task 7 artifact compatibility remains a separate integration dependency.
