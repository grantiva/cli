# B2-K40 candidate5 clause assessment

Verdict: **PASS**.

Expected: `grantiva run --snapshot bogus`: exit 64 and the error line names `failure`, `trailing`, `full` (ArgumentParser's `Please provide one of 'failure', 'trailing' or 'full'.` or equivalent). • Every `ExpressibleByArgument` enum in Sources/GrantivaCLI is `CaseIterable` (grep check), so `hierarchy --format bogus` also lists `xml`, `json`. • GrantivaCLITests/RunCommandTests: parsing `--snapshot bogus` throws an error whose message contains all three values; GrantivaCLITests/HierarchyCommandTests the same for `--format`. (brief K40 Acceptance criteria; Platforms: n/a)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B2-K40-run-1/hierarchy.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `hierarchy.stdout`, `hierarchy.stderr` retained.
- `B2-K40-run-1/platform.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `platform.stdout`, `platform.stderr` retained.
- `B2-K40-run-1/snapshot.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `snapshot.stdout`, `snapshot.stderr` retained.
