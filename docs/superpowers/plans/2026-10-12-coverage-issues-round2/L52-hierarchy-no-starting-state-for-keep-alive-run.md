# `grantiva hierarchy` and `runner dump-hierarchy` report "no session" for a `run --keep-alive` runner that has not published its session yet; only MCP reports `starting`

Severity: minor
Component: cli
Platforms: ios, android
Rows: none yet; found during the round-3 Task 7 docs consistency pass
Regresses/extends: L38-a (session file written at runner launch with a `starting` state)
Binary: grantiva main ffc661ae (round 3, after CLI PR #201)

## Expected
Every session consumer gives the same answer during start-up. While a `run --keep-alive` runner is executing its flow
and has not yet published a session, `grantiva hierarchy` and `runner dump-hierarchy` say the session is starting (or
that a run is in progress) and suggest retrying, exactly as MCP session tools and `resources/read` do after L38-a.

## Actual
MCP reports `starting`; the two CLI commands print the pre-L38-a "No active runner session" text. docs/mcp.md (round 3)
describes the behaviour as it is.

## Reproduce
`grantiva run --keep-alive --flow <slow flow> --simulator <udid>` in one shell; in another, `grantiva hierarchy --simulator <udid>`
during the first seconds of the run.

## Fix direction
Route `hierarchy` and `dump-hierarchy` through the same session loader MCP uses (`loadActiveSession` with the `starting`
branch) and print one shared "starting, retry" message; one test per command. Schedule: round 4 unless a `B3-L` row fails on it.
