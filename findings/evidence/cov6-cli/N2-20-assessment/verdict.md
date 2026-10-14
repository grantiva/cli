# N2-20 candidate5 clause assessment

Verdict: **PASS**.

Expected: Either a test pins that a malformed non-video track is skipped (the hold still applies to the video track), or the current behaviour (the whole hold fails) is recorded and filed as a round-3 brief; grade `fail` when the latter (plan N2-20; fix-wave ledger Task 8 minor)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `N2-20-run-1/source.command.json`: exit 2, timedOut=false, cleanupFailed=false; raw `source.stdout`, `source.stderr` retained.
