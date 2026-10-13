# Task 3 CLI counterpart review — L79 warned optional command

Reviewed `63c9b45190e43bfb8aa239d0f9fcc75ec455dd72..b26027c121c7c65358d1a4be7331fe6c3d24c1df` against `task-3-brief.md`, the implementation report and diff, and the retained evidence in `findings/evidence/fix4-3-cli/`.

## Verdicts

- **Spec compliance: changes requested.** The source change is narrowly aligned with L79: the real report decoder retains a `warned` command and its rewritten error message, run text uses a warning glyph, JSON preserves the existing keys and emits `"warned"`, warned steps count as passing, and failed steps retain their existing failing behavior. No public command, flag, MCP name, JSON key, or raw capture is changed. Approval remains conditional on resolving the two findings below and on the separately owned joint live acceptance proving three successful optional repetitions plus the required-command failure control on every required surface.
- **Code quality: changes requested.** The production implementation is small and coherent, and the focused tests pass, but the claimed TDD proof is compile-time rather than behavioral and the new CLI test bypasses the production `allPassed`/exit calculation it claims to cover.

## Findings

### 1. Blocking — retained RED is not a behavioral failure against production code

`findings/evidence/fix4-3-cli/red.txt:1-4` says the test failed to compile because `StepStatus.warned` and `isPassing` did not exist at the base revision. That establishes missing API surface, but it never runs `RunnerReportSteps.steps` and therefore does not demonstrate the actual production defect: the base decoder's default branch drops the warned command (`Sources/GrantivaCore/Runner/RunnerReportSteps.swift:69-89`). This does not satisfy the binding requirement that the behavior change begin with a failing semantic test against production code, and the report should describe it as compile RED rather than “the production-report test” proving runtime behavior.

Add and retain a base-compatible semantic RED that writes the real `passed / warned / passed` report, calls the production collector, and asserts that all three actions survive (including the warning action and message). At the base revision this must compile and fail because the middle command is omitted. Record its exact command, source revision, assertion failure, and nonzero exit. The existing post-fix status assertions can remain as GREEN coverage.

### 2. Blocking — CLI test supplies `allPassed: true` instead of exercising the changed run verdict and exit path

The production behavior change at `Sources/GrantivaCLI/RunCommand.swift:590-604` makes warned steps contribute to `allPassed` and determines whether `run` exits successfully. The new test at `Tests/GrantivaCLITests/RunCommandTests.swift:683-688` constructs `RunResult(..., allPassed: true)` directly, so its JSON assertion is tautological and would pass if the production calculation reverted to “only `.passed`”. The test also never reaches the exit decision at line 603. The decoder test at `Tests/GrantivaCoreTests/RunnerReportContractTests.swift:69-83` checks `isPassing`, but it likewise does not cover the run command's calculation or process semantics.

Drive the normal run result path with the decoded warned capture (using the existing run-command seam/helper), assert emitted JSON has `screen.passed == true` and `allPassed == true`, and assert no failure exit is thrown. In the same production path, change only the command to failed and assert `screen.passed == false`, `allPassed == false`, and failure exit. Avoid duplicating already passing generic required-failure tests; this control should specifically guard the new warned-versus-failed branch.

## Verification

- `git diff --check` passed and the task worktree was clean.
- Independent focused run with an unset API key and a fresh empty `GRANTIVA_RUNNER_HOME` passed: `RunnerReportContractTests.testWarnedOptionalCommandIsRetainedWithItsError` and `RunCommandTests.testWarnedFlowRendersWarningAndRemainsPassedInTextAndJSON`, 2 tests / 0 failures.
- Retained full-suite evidence reports exit 0 with Core 968 / API 101 and all CLI/MCP targets passing; the isolated runner home remained empty.
- No new JSON keys were introduced, so `JSONKeyCasingContractTests` requires no new key assertion for this patch.
- JUnit is runner-owned in this split task. Source approval remains conditional on the separate joint live acceptance confirming its zero-failure optional result and nonzero required control without CLI rewriting.
