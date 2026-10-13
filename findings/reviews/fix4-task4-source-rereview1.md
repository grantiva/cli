# Finding Verdicts

- **Important 1 — reused PID before initial signal: ADDRESSED.** `Sources/GrantivaCore/Runner/LogStreamer.swift:98–118` captures kernel start seconds and microseconds. `:151–162` brackets command discovery with identity reads, rejecting a replacement during the inventory. `:166–184` retains the discovered identity, obtains a fresh marker/identity confirmation, and checks the retained identity immediately before initial and escalation signals. Exact marker-token matching at `:131–140` excludes prefix/suffix lookalikes. `Tests/GrantivaCoreTests/LogStreamerTests.swift:6–67` verifies replacement during inventory, replacement between discovery and signaling, and changed-marker rejection; the replacement identities differ within the same second.
- **Important 2 — inventory subprocess and final confirmation escape the deadline: ADDRESSED.** `Sources/GrantivaCore/Runner/LogStreamer.swift:151–155,166–192` passes the outer deadline to each inventory and removes the unbudgeted final snapshot. The new `processSnapshot` implementation (`:354–406`) uses nonblocking reads, limits execution to the remaining budget, reserves time to kill its exact inventory child, and observes Foundation's child completion within that budget; it no longer blocks in EOF reading or `waitUntilExit()`. `Tests/GrantivaCoreTests/LogStreamerTests.swift:69–120` exercises a stalled inventory, a stalled final confirmation with no extra inventory, ESRCH/ECHILD after cleanup, and output larger than the pipe capacity.
- **Minor — introduced diagnostic warning leaks into passing tests: ADDRESSED.** `Tests/GrantivaCoreTests/LogStreamerTests.swift:135–145` captures stderr and asserts the exact warning once while verifying repeated `stop()` preserves incomplete-cleanup status. Neither final focused log contains the previously leaked warning.
- **File-inventory reconciliation: ADDRESSED as documentation.** `task-4-fix1-report.md`, “Minor warning and file-list reconciliation,” explains all four unchanged named files: production RunCommand routing already reaches LogStreamer, the resolver already provides the canonical map, and affected regressions are covered in the lifecycle and LogStreamer classes. No behaviorless file changes were added.

# New Breakage in the Fix Diff

- None identified.

# Out-of-Scope Observations

- The existing `Sources/GrantivaCore/Output/CLILogHandler.swift:34` protocol deprecation still appears in `unit-fix1/green.log:4`; it is unchanged by this fix and remains non-blocking for this scoped review.
- Scheduled live acceptance remains pending, including real simulator marker validity, immediate owned-child absence after success/failure/interruption, and concurrent-stream survival. Final-head CI is newly pushed but has no result verified by this review. Task 7's nested notes/logTail compatibility gate remains separately assigned. These are acceptance/integration gates, not new fix defects.

# Checks

- Read the brief, original review, appended report, separate fix report, and complete 442-line fix package once: `78e9b7526c80bb5f9c2892c19c1d3b31841cce3f` → `9c7748523e703338887124a52a0a3af6d40a884b`. Scope stayed within the findings and fix diff; no git commands, device operations, source mutations, subagents, or test reruns.
- Verified retained semantic RED evidence in `findings/evidence/fix4-4/unit-fix1/red.log:77,82,85–86`: incorrect initial signal to PID 500 in the marker/reuse cases, and the 100 ms inventory budget returning normally after approximately 578 ms.
- Verified final focused output: `unit-fix1/final-LogStreamerTests.log:57` records **19 tests, zero failures**; `unit-fix1/final-RunnerLifecycleCommandTests.log:147` records **63 tests, zero failures**. `red-status.json`, `green-status.json`, and `final-status.json` record the expected exits and empty scoped runner homes.
- The prior 1,976-test full-suite pass predates the final argument-order correction and this fix. It is not evidence of a full-suite pass at this head.

# Verdict

**Fix round: All findings addressed, no new Critical/Important breakage.** Source review approved for the scoped Task 4 fix round. Complete task acceptance remains gated on the recorded live checks, final-head CI, and assigned integration work.
