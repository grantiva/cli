# N2-19 candidate5 clause assessment

Verdict: **PASS**.

Expected: Record the full text per tool. Argument failures read `Error: Invalid argument: <message>` (e.g. `Error: Invalid argument: Simulator not found: "no-such-sim"`); no-session texts carry no `Invalid argument:` label; no text has two `Error:` prefixes; every answer is an `isError` result (plan N2-19; docs/mcp.md error paragraph; brief K46 follow-up)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `N2-19-run-1/grantiva_emulator_boot.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_emulator_boot.stdout`, `grantiva_emulator_boot.stderr` retained.
- `N2-19-run-1/grantiva_emulator_delete.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_emulator_delete.stdout`, `grantiva_emulator_delete.stderr` retained.
- `N2-19-run-1/grantiva_emulator_ensure.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_emulator_ensure.stdout`, `grantiva_emulator_ensure.stderr` retained.
- `N2-19-run-1/grantiva_script.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_script.stdout`, `grantiva_script.stderr` retained.
- `N2-19-run-1/grantiva_sim_boot.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_sim_boot.stdout`, `grantiva_sim_boot.stderr` retained.
- `N2-19-run-1/grantiva_sim_delete.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_sim_delete.stdout`, `grantiva_sim_delete.stderr` retained.
- `N2-19-run-1/grantiva_sim_ensure.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_sim_ensure.stdout`, `grantiva_sim_ensure.stderr` retained.
- `N2-19-run-1/grantiva_swipe.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_swipe.stdout`, `grantiva_swipe.stderr` retained.
- `N2-19-run-1/grantiva_type.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_type.stdout`, `grantiva_type.stderr` retained.
