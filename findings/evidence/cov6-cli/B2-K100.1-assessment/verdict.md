# B2-K100.1 candidate5 clause assessment

Verdict: **PASS**.

Expected: With no session, `resources/read` for `grantiva://hierarchy` and `grantiva://screenshot` never answers `-32603`. It answers either a documented error code (not `-32603`, not `-32602`) whose message starts with the no-session text without `Internal error:`/`Invalid argument:` prefixes, or a `result` whose contents state that no session is active. • An unknown URI keeps its current typed error. • docs/mcp.md lists both resources and states what a read returns when there is no session. • Unit test in `GrantivaMCPTests` (MCPServerTests.swift or ToolErrorContractTests.swift): `testResourceReadWithoutASessionIsNotAnInternalError`: build the registry with a connection whose resolver throws the no-session error, call the resource path the server handler uses, and assert the chosen code/contents. If the fix lives in the handler closure, factor the closure into a testable static function first. (criteria 1, 3, 4, 5 of 5; brief K100 Acceptance criteria; Platforms: both)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B2-K100.1-run-1/resources.command.json`: exit 2, timedOut=false, cleanupFailed=false; raw `resources.stdout`, `resources.stderr` retained.
