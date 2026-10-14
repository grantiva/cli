# B2-K46 candidate5 clause assessment

Verdict: **PASS**.

Expected: One shared message builder in GrantivaCore produces the no-session text for `runner dump-hierarchy`, `hierarchy` and the MCP session tools; both commands appear as `` `grantiva runner start` `` and `` `grantiva run --keep-alive` ``. • The error is not `invalidArgument` (for example a `GrantivaError.notFound`/dedicated case), so the CLI prints `Error: No active runner session. ...` (exit 1) and the MCP isError text has no `Invalid argument:`. • docs/dump-hierarchy.md:57 and docs/mcp.md quote the new text if they quote it. • GrantivaCLITests/DumpHierarchyCommandTests and GrantivaMCPTests/SessionLifecycleTests assert the exact text (no single quotes, no "Invalid argument"). (brief K46 Acceptance criteria; Platforms: both)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B2-K46-run-1/dump.command.json`: exit 1, timedOut=false, cleanupFailed=false; raw `dump.stdout`, `dump.stderr` retained.
- `B2-K46-run-1/hierarchy.command.json`: exit 1, timedOut=false, cleanupFailed=false; raw `hierarchy.stdout`, `hierarchy.stderr` retained.
- `B2-K46-run-1/mcp.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `mcp.stdout`, `mcp.stderr` retained.
