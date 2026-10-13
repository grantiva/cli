# Task 3 CLI fix1 re-review — L79 warned optional command

Reviewed only `b26027c121c7c65358d1a4be7331fe6c3d24c1df..c1373f6c07bf97ec5cb7978d45c954902958c04a`, the updated report, and `findings/evidence/fix4-3-cli/`. Tests were not rerun because this review was scoped to the fix diff and supplied evidence.

## Verdicts

- **Spec compliance: source approved; evidence gate remains open.** The fix resolves both original code/test findings, introduces no new product regression visible in the scoped diff, and preserves the public JSON shape and required-failure behavior. Final task approval remains conditional on genuine retained RED/GREEN command streams and on the separately owned joint device replay.
- **Code quality: approved.** Extracting `emitRunResult` gives the production run command and its tests one verdict/emit/exit path. The warned and failed cases now exercise that path rather than constructing a pre-decided result.

## Original findings

1. **Production-path verdict coverage — resolved.** `Sources/GrantivaCLI/RunCommand+Result.swift:9-27` now computes `allPassed`, emits the real result, and throws `ExitCode.failure` for a failed step. `Sources/GrantivaCLI/RunCommand.swift:589-592` delegates to that helper. `Tests/GrantivaCLITests/RunCommandTests.swift:683-718` proves warned emits `screen.passed=true` / `allPassed=true` without throwing, then changes only the warned step to failed and proves the false verdict plus `ExitCode.failure`.
2. **Base-compatible behavioral RED formulation — resolved in test design, not yet proven by raw evidence.** `Tests/GrantivaCoreTests/RunnerReportContractTests.swift:77-83` now expresses the expectations using raw status strings and `!= .failed`, so it compiles at the base revision and reaches the production collector. This is the correct test shape for demonstrating that the base decoder drops the warned command.

## Remaining evidence finding

### Blocking evidence issue — supplied “raw” files are authored summaries and the RED file was rewritten

`findings/evidence/fix4-3-cli/red.txt` contains labeled assertions such as `behavioral_red_exit` and `behavioral_red_assertions`, but it does not contain the invoked test process's stdout/stderr or shell-captured exit. The GREEN files use the same summary format. These are useful indexes, but they are not raw execution proof. In addition, `red.txt` observed during the first review contained only the initial compile RED; the same path now has rewritten content combining that with a later behavioral-RED summary. That conflicts with the binding rule that raw captures remain byte-for-byte unchanged.

Retain the original compile-RED capture unchanged, and add new append-only artifacts containing the exact behavioral RED command, source revision, unedited stdout/stderr, explicit exit code, and before/after isolated-home counts. Do the same for the fix1 focused and full GREEN commands, or point this review to existing immutable stream captures that contain those fields. Keep authored summaries separate and label them as summaries. Until that evidence is available, the reported base failure and 2,012-test GREEN are claims rather than independently inspectable raw proof.

## Scoped regression review

- `git diff --check b26027c1..c1373f6c` passed; the product worktree was clean.
- The helper preserves the prior ordering: emit text or JSON first, then throw on a failing verdict.
- The real command passes the same existing report-directory value into the helper.
- The warned branch remains passing; the failed control preserves required failure semantics.
- No command, flag, MCP tool, JSON key, raw-capture behavior, or runner-owned JUnit behavior changes in fix1.
- Joint device replay remains a separate acceptance gate; source approval here is conditional on that replay succeeding.
