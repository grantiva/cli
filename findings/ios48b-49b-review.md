# iOS attempts 48b and 49b scoped review

Read-only review against the round-3 matrix; no live calls were made.

## Attempt 48b

The new grades for N-01, D2-14, B3-L36.2, and B3-L56.1 are supported. The retained `case-summary.json` records three active-flow stops at the runner's `[1/1] ... launchApp` output, each exit 130 with terminal `interrupted`; the three stop documents identify the live session and report `stopped`, and post-release session inventories are empty. Separate completed pass/fail cases released by both `runner stop` and SIGINT retain `passed`/`failed` and exit with earned 0/1. The stop JSON and before/final ready files support D2-14's write-once terminal-state claim.

B3-L55.1 is correctly retained as a matrix failure/expectation conflict: the three behavioral output legs pass, but the literal input that `r` show a running flow cannot occur in the exact candidate. `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/RunCommand.swift:279-280` prepares the path, and `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Runner/RunnerExecution.swift:196-227` first writes it only after the report becomes terminal. The launch-output observation is honest active-flow proof; it is not a claim that a running ready file existed.

## Attempt 49b and B3-L24

B3-L24 is supported by the joined evidence. Attempt 49 supplies three crash-on-launch wait cases, each classified `app_crash` in 459–476 ms with the later assert skipped. Attempt 49b's corrected screen config exits 1: the nested launch completes, generated `waitForAnimationToEnd` fails with `app crashed ... is not running` at 498 ms, `takeScreenshot` is explicitly skipped, and `captures.txt` contains no Home capture. Attempt 45 supplies the intentional-stop passing control, while the permitted current-round IOS-117/IOS-118 stock groups supply unchanged passing controls on both runtimes. The exact runner settle-crash test is an appropriate semantic source join.

No grading correction is required.
