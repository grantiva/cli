# N2-02 candidate5 clause assessment

Verdict: **PASS**.

Expected: `runner --json` is a usage error (`Error: Unknown option '--json'`, exit 64) and `runner status` is not a subcommand: help: runner.txt lists only install, version, start, stop, dump-hierarchy and no `--json` on the group. `runner version` prints `grantiva-runner 1.1.28-grantiva.11` and `runner version --json` prints `{"version": "1.1.28-grantiva.11"}` (help: runner_version.txt; README:356). Record whether any documented command prints the installed stamp (`1.1.28-grantiva.11+android-drivers-2`, README "Concurrent runs" `<stamp>`); doctor's Runner check and `runner install` print the installed stamp today, so this is recorded, not a fail (plan N2-02) (corrected round 3)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `N2-02-run-1/group-json.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `group-json.stdout`, `group-json.stderr` retained.
- `N2-02-run-1/help.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `help.stdout`, `help.stderr` retained.
- `N2-02-run-1/status.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `status.stdout`, `status.stderr` retained.
- `N2-02-run-1/version-json.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `version-json.stdout`, `version-json.stderr` retained.
- `N2-02-run-1/version.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `version.stdout`, `version.stderr` retained.
