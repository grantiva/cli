# B2-K65 candidate5 clause assessment

Verdict: **PASS**.

Expected: docs/dump-hierarchy.md:55 lists 26.0, 26.2, 26.4 and 27.0 (iPhone), or points at a single source of truth (for example `ls <runner home>/cache/wda-builds`) instead of a list that drifts. • Any other doc or help text listing prebuilt runtimes (grep `26.2`) matches. (brief K65 Acceptance criteria; Platforms: ios)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B2-K65-run-2/wda-cache.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `wda-cache.stdout`, `wda-cache.stderr` retained.
