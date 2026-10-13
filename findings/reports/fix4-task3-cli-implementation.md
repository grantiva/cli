# Task 3 CLI counterpart report — L79 warned optional command

## Outcome

Implemented the narrow CLI compatibility change on `fix4/optional-status` from base `63c9b45190e43bfb8aa239d0f9fcc75ec455dd72`. Review-fix head `c1373f6c07bf97ec5cb7978d45c954902958c04a` is pushed and draft PR [grantiva/cli#211](https://github.com/grantiva/cli/pull/211) is open. No merge or release was performed.

The CLI now decodes the runner's `warned` command status, retains its action, measured duration, and error message, and renders it as `⚠` in run text output. JSON keeps the existing shape and reports the step status as `warned`. A warned step is non-failing, so its containing flow/screen remains `passed: true`, suite `allPassed` remains true, and the command exits successfully when the runner did. Existing passed, failed, and skipped behavior is unchanged. The CLI does not rewrite JUnit verdicts; the runner's zero-failure JUnit remains intact.

## Production evidence and TDD

The controller's retained live report at `findings/evidence/fix4-3/live/optional-text-1-final/report/flows/flow-000.json` has the production sequence `passed / warned / passed`; the warned tap includes `error.type=element_not_found` and its useful message. Before this change the retained CLI output omitted that command. The initial test was a compile RED and is labeled as such in the raw proof. The retained source-compatible behavioral RED ran at clean base `63c9b45190e43bfb8aa239d0f9fcc75ec455dd72` through the production report collector and failed with 2 steps instead of 3, the warned action absent, and its message nil.

After implementation, the focused report decode test proves all three commands survive as `passed / warned / passed` with the warning message. The CLI contract test drives the same `emitRunResult` helper used by the real run command. The warned case renders text, emits `screen.passed=true` and `allPassed=true`, and returns normally. Changing only that step to failed emits `screen.passed=false`, `allPassed=false`, and `status=failed`, then throws `ExitCode.failure`.

Raw command/exit proof is in `findings/evidence/fix4-3-cli/`.

## Verification and joint replay provenance

- Focused Core test: exit 0, 1 test / 0 failures.
- Focused CLI test: exit 0, 1 test / 0 failures.
- Post-review full `swift test` with `GRANTIVA_API_KEY` unset, `GRANTIVA_SESSION_ID=fix4-3-cli`, and fresh isolated `GRANTIVA_RUNNER_HOME`: exit 0. Core 968, CLI 662, MCP 281, API 101; all zero failures.
- Isolated home `/tmp/grantiva-fix4-3-cli-review-full.4BL0sX`: 0 entries before and 0 after.
- Joint-replay executable: `/Users/kyle/Developer/grantiva-cli/.worktrees/fix4-optional-status/.build/out/Products/Debug/grantiva`
- Executable SHA-256: `c87ae8a4c30d75daf6b7b724e1526b2d1a8f954da422fb18e5343e18358b9f73`
- Full source head: `c1373f6c07bf97ec5cb7978d45c954902958c04a`

The runner owner can use this exact binary and hash for the three text/JSON repetitions and required-step controls. No device operation was performed by this CLI task.

## Retained raw verification supplement

The initial authored summaries are not raw execution logs, and the overwritten initial RED summary was not recovered. Fresh actual reruns are retained under `findings/evidence/fix4-3-cli/raw-semantic-red/`, `raw-focused-green/`, and `raw-full-green/`, with exact command/source/time/home/exit metadata. Independent evidence review approves behavioral RED at base63c9, two focused GREEN tests and full2012-test GREEN at c1373; each isolated home remained empty. See `findings/reviews/fix4-task3-cli-evidence-review.md`. These are replacement execution proofs, not reconstructed initial output.
