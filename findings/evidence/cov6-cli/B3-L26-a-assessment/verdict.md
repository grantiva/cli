# B3-L26-a candidate5 clause assessment

Verdict: **PASS**.

Expected: Exit 64; the first line is the `Error: <message>` line with no `Invalid argument:`; then the same `Usage: grantiva record …` and `See 'grantiva record --help'` lines as `--duration 0` (round 3 ruling L26-a: platform resolved first, then validated) (brief L26-a)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B3-L26-a-run-1/android-ext.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `android-ext.stdout`, `android-ext.stderr` retained.
- `B3-L26-a-run-1/duration.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `duration.stdout`, `duration.stderr` retained.
- `B3-L26-a-run-1/ios-ext.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `ios-ext.stdout`, `ios-ext.stderr` retained.
