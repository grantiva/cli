# N3-11 candidate5 clause assessment

Verdict: **PASS**.

Expected: Every command that uses the runner prints the missing-bundle warning once (never twice in one process); `runner install` always does; record which of the others do; no command fails because of it while the current install exists (README GRANTIVA_RUNNER_HOME row; ruling L28)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `N3-11-run-1/hierarchy.command.json`: exit 1, timedOut=false, cleanupFailed=false; raw `hierarchy.stdout`, `hierarchy.stderr` retained.
- `N3-11-run-1/install.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `install.stdout`, `install.stderr` retained.
- `N3-11-run-1/start.command.json`: exit 1, timedOut=false, cleanupFailed=false; raw `start.stdout`, `start.stderr` retained.
- `N3-11-run-1/version.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `version.stdout`, `version.stderr` retained.
