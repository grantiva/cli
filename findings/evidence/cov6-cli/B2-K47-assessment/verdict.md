# B2-K47 candidate5 clause assessment

Verdict: **PASS**.

Expected: `grantiva runner dump-hierarchy --format bogus`: exit 64, usage error naming `tree`, `json`, `xml`, with or without a session; no session lookup happens. • `--format XML`/`Tree` still work (case-insensitive), or the help says lowercase only. • Prefer a `CaseIterable` `ExpressibleByArgument` enum (see K40) so ArgumentParser lists the choices. • GrantivaCLITests/DumpHierarchyCommandTests: `DumpHierarchyCommand.parse(["--format", "bogus"])` throws a validation error naming the three values. (brief K47 Acceptance criteria; Platforms: both)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B2-K47-run-1/bogus.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `bogus.stdout`, `bogus.stderr` retained.
- `B2-K47-run-1/tree-json.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `tree-json.stdout`, `tree-json.stderr` retained.
- `B2-K47-run-1/xml-case.command.json`: exit 1, timedOut=false, cleanupFailed=false; raw `xml-case.stdout`, `xml-case.stderr` retained.
