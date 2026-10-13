# Task 8 stock crash invocation correction

Status: harness-only correction complete, awaiting independent scoped review before controller rerun. No device commands or acceptance flows ran during this correction. Attempt4 is retained as a rejected crash harness invocation, not a product crash finding.

## Evidence and scope

The controller observed attempt4 healthy stock passing, followed by crash-1 failing an ordinary later assertion without a fatal event. Its retained command directly invoked the packaged runner. This matches the documented non-acceptance direct-runner attempt in `findings/reports/fix4-task1-implementation.md:53-58`: Android stock header environment is converted into intent extras by production CLI FlowEnvironment. Accepted Task 1 stock-4 through stock-8 therefore invoked the CLI. Read and used `findings/evidence/fix4-1/stock-4/command.json` as the exact argument reference.

Before editing, preserved the current durable and scratch helpers in `task8-crash-invocation-base/`. Changed only the crash-loop invocation in `findings/tools/round4-smoke/android_runner_smoke.py` and mirrored it to `task-8-harness/android_runner_smoke.py`. No product edits, fixture changes, or raw attempt edits.

The five crash repetitions now run the already frozen and validated CLI with `run --platform android --device <owned serial> --no-build --verbose --flow <unchanged stock flow> --report-dir <per-run report>`, then read the same copied raw report. Healthy, gesture, favorite, and stopApp direct-runner calls remain unchanged. Existing report status, fatal PID match, clock probes and conservative two-second interval, failed launchApp/app_crash, no successful launch, and raw artifact retention logic remain unchanged.

## No-device verification

- Python AST parsing, helper `--help`, byte-identical scratch mirror, and `git diff --check` passed.
- Evaluated only the crash loop's report/argv assignment AST nodes, without executing the loop or any device command. The resulting argv exactly matches accepted stock-4 after substituting the frozen candidate binary, current flow, and destination report path.
- Verified stock input SHA256 remains `2ca48944814d39effe21cbb65616461e3f517c0eddb00feedd80edd26e017b6f`, equal to the accepted Task 1 command's recorded hash.
- Compared source around the changed invocation: prefix before it and all remaining acceptance logic after it are byte-identical to the pre-edit snapshot.
- Retained exact validation output in `task8-crash-invocation-check.json`.

All attempt4 raw outputs remain preserved. No new smoke acceptance is claimed; independent scoped review precedes a new evidence-directory rerun by the controller.
