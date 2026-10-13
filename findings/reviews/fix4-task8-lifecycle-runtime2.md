# Task 8 lifecycle runtime harness fix 2 follow-up review

**Spec-compliance verdict: APPROVED for the two reviewed findings.** Both Important findings from `task8-lifecycle-runtime2-review.md` are addressed. No new breakage was found in `task8-lifecycle-runtime2-fix-review.diff`. This was a static, device-free review; live lifecycle acceptance remains unassessed.

## Finding verdicts

1. **ADDRESSED — the interrupted gate is bound to the helper-spawned CLI and current case.** `bind_log_runner` requires the runner to be a direct child of the current `proc.pid`, with a PGID equal to either that CLI PID or the child PID. It also requires the exact owned iOS UDID in `--device`, the resolved executable path from the validated frozen candidate manifest, the current executable SHA-256 from that manifest, an existing runner report directory, and an existing staged flow whose SHA-256 equals this case's source flow and whose content contains `extendedWaitUntil`. The retained `activeRunner` evidence records PID, PPID, PGID, CLI PID, executable path/hash, report path, and flow path/hash before SIGINT. An unrelated same-device runner or same-basename executable can no longer satisfy the gate.

2. **ADDRESSED — the vanish-between-probes race is handled without accepting a live mismatch.** `bound_argv_if_running` catches both the ownership assertion and `ps_argv`'s `CalledProcessError`, then performs a second liveness probe. It returns only when that probe shows the PID absent or zombie; if the PID is still live, it re-raises the original argv-read failure or ownership mismatch. `preserve_runner_report` no longer catches `CalledProcessError` in its outer ignore list and does not catch `AssertionError`, so a live ownership mismatch is not converted into an ended capture.

## Preserved requirements

- Log-control exits remain success 0, failure 1, and interruption 130.
- Success and failure still require reports with their expected status. The interrupted report remains optional, and when present must truthfully contain `interrupted` at the top level or in a flow.
- Every case still requires three immediate marked-log-child absence inventories, exactly one terminal log-subprocess diagnostic, and no cleanup-uncertain diagnostic.
- Android cleanup still passes the exact discovered local-forward value as the final `adb forward --remove` argument; only its evidence filename uses the sanitized identity token.
- The durable helper and SDD mirror are byte-identical in the reviewed worktree.

## New-breakage review

No new defect was identified in the scoped fix diff. No source was edited, no device command was run, and no tests were rerun for this review.
