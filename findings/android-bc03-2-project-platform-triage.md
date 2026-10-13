# B-C03.2 Android project/platform triage

## Verdict

The new runtime supports **B-C03.2 for the MCP surface**. The successful
cross-directory `runner dump-hierarchy` probe is expected CLI behavior and is
not a B-C03.2 product failure. Do not file L79 from this observation.

The matrix wording is broad in isolation, but its binding provenance is brief
C03 and every adjacent acceptance clause scopes the rule to the MCP server:

- `MCP-079` says session tools must not use a keep-alive session from another
  directory or platform.
- `B-C03.1` speaks of “the server for B.”
- `B-C03.3` names `GrantivaMCPTests/MCPServerTests.loadActiveSession`.
- `B-C03.4` requires documentation of which sessions “the server” attaches to.

The candidate documentation makes the split explicit. At exact CLI head
`8f2cff676b3c12e951478920fa20e600cdca4e29`,
`docs/android.md:206-211` says the MCP server uses only sessions whose project
directory and platform match. In contrast, `README.md:97` documents the CLI
`hierarchy` command as finding the newest live keep-alive session in the global
`/tmp/grantiva-sessions/` store, and `docs/dump-hierarchy.md:36,57` documents
the same newest-session fallback for `runner dump-hierarchy` (with `--udid` to
select among global sessions).

## Runtime evidence

Evidence root:
`/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B-C03.2-project-platform-exclusivity-rerun1`

- `run/ready-before-probes.json` proves the Android owner reached its passed
  keep-alive hold.
- From the other Android project, `run/other-android/context.json` and
  `run/other-android/transcript.txt` report `No active session`; they do not
  expose or attach the owner's runner.
- From the owner directory but the wrong platform, `run/owner-ios/context.json`
  and `run/owner-ios/transcript.txt` likewise report `No active session`.
- `run/wrong-project.exit.txt` is `0` and `run/wrong-project.out` is the owner's
  Android hierarchy. That probe exercised the separately documented global
  CLI fallback. It does not contradict the MCP-scoped C03 contract.

The wrapper's later failure is a harness error: `input/controller.py` tries to
read `owner/.grantiva/session.json`, although this run is represented by the
global keep-alive store. Consequently its unproduced `decoded.json`, stop, and
session-file assertions must be excluded. The failure happened after both MCP
probes and does not invalidate their preserved responses.

## Source semantics

- `Sources/GrantivaMCP/MCPServer.swift:153-192` resolves a project-local
  runner-start session first, then filters the global keep-alive list by both
  canonical `projectDirectory` and `platform`; unmatched live sessions only
  contribute to the ignored-session error count.
- `Tests/GrantivaMCPTests/MCPServerTests.swift:99-143` separately asserts that
  another project, another platform, and legacy sidecars without a recorded
  project directory are never returned.
- `Sources/GrantivaCore/Runner/KeepAliveSessionStore.swift:187-206,316-340`
  records and reloads `projectDirectory` and `platform` in owner sidecars.
- `Sources/GrantivaCLI/DriverCommand.swift:1242-1267` deliberately asks
  `KeepAliveSessionStore.locateIncludingStarting(udid:)` without a project
  filter for `runner dump-hierarchy`; the store's documented locate behavior
  returns the newest global live session when no UDID is supplied.

The runtime proves both negative MCP branches. The store-field clause is a
source-semantic join here because this harness failed before archiving its
live owner sidecar. Existing current-round owner-sidecar evidence may be cited
for the serialized-field observation; the implementation and exact semantic
tests above establish the required behavior without reclassifying the CLI
probe as a failure.
