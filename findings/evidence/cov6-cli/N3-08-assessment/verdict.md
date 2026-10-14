# N3-08 candidate5 clause assessment

Verdict: **PASS**.

Expected: All exit 64 with the same shape: an `Error: <message>` line (no `Invalid argument:`), then `Usage: grantiva <command> …` and `See 'grantiva <command> --help' for more information.` (README Errors paragraph; briefs L26-a, L26-b, K42)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `N3-08-run-1/android-ext.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `android-ext.stdout`, `android-ext.stderr` retained.
- `N3-08-run-1/duration.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `duration.stdout`, `duration.stderr` retained.
- `N3-08-run-1/ios-ext.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `ios-ext.stdout`, `ios-ext.stderr` retained.
- `N3-08-run-1/mutual.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `mutual.stdout`, `mutual.stderr` retained.
- `N3-08-run-1/teardown.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `teardown.stdout`, `teardown.stderr` retained.
