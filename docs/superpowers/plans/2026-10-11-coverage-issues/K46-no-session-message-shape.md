# The "No active runner session" message mixes quote styles and is labelled "Invalid argument"

Severity: ux
Component: cli
Platforms: both (CLI dump-hierarchy and MCP session tools)
Rows: CLI-087 (cli), B-C11.2 (ios); original brief C11 (mcp-starts-without-session-or-config); IOS-OBS-03 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
One consistent message: both commands quoted the same way (the repo's prose uses backticks for commands), and not
labelled `Invalid argument:` when no argument was wrong. Brief C11 criterion 2 (B-C11.2) requires session tools to
return `isError` with the "No active runner session ... Start one with ..." text, which they do.

## Actual
CLI, `runner dump-hierarchy` with no session (findings/evidence/cov-cli/CLI-087/dump.err), exit 1:
```
Error: Invalid argument: No active runner session. Start one with 'grantiva runner start' or `grantiva run --keep-alive`, or pass --port.
```
MCP session tool with no session in this project (findings/evidence/cov-ios/MCP-079/other-dir/transcript.txt):
```
Error: Invalid argument: No active runner session at …/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive` in …. 1 keep-alive session(s) started from another project directory or for another platform were ignored.
```
Single quotes for one command, backticks for the other, and an "Invalid argument" label for a missing session.


**Absorbed from the iOS fix round.** Widened by IOS-OBS-03: MCP `isError` texts use three different prefixes across tools (evidence `findings/evidence/cov-ios/IOS-OBS-03/error-texts.txt`); the acceptance criterion is one prefix rule for every MCP error text, including the no-session text.

Result rows (`findings/cov-ios-results.md`):

> | IOS-OBS-03 | fail | IOS-OBS-03/error-texts.txt | MCP isError texts use three prefixes: `Error: 'name' is required.`, `Error: Invalid argument: Invalid swipe direction …` / `Error: Invalid argument: No active runner session …` ("Invalid argument" also for a missing session) and `Unknown tool: grantiva_nosuch_tool` (no prefix). Referenced by B-C11.2, IOS-115. |

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k46
rm -rf /tmp/k46 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k46 && cd /tmp/k46/ios
grantiva runner dump-hierarchy; echo "exit $?"
printf '%s\n' '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Home"}}}' \
  | (cat; sleep 3) | grantiva mcp --platform ios
```
Today: both texts above (the MCP one names this directory's `.grantiva/session.json`).

## Evidence
- findings/evidence/cov-cli/CLI-087/commands.txt, dump.err, dump.out (`rc=1`)
- findings/evidence/cov-ios/MCP-079/commands.txt, other-dir/transcript.txt, other-dir/requests.json

## Suspected cause
- Sources/GrantivaCLI/DriverCommand.swift:735-737 (`resolveTarget`) and Sources/GrantivaMCP/MCPServer.swift:187-189
  (`loadActiveSession`): both hand-write the sentence with mixed quotes and throw `GrantivaError.invalidArgument`,
  whose description adds `Invalid argument: ` (Sources/GrantivaCore/GrantivaError.swift:51-52).
- The MCP side prints it through Sources/GrantivaMCP/ToolRegistry.swift:74-81 (`"Error: \(error.localizedDescription)"`).
- Sources/GrantivaCLI/HierarchyCommand.swift (the `hierarchy` no-session path) may carry a third variant; check it.

## Acceptance criteria
- One shared message builder in GrantivaCore produces the no-session text for `runner dump-hierarchy`, `hierarchy` and
  the MCP session tools; both commands appear as `` `grantiva runner start` `` and `` `grantiva run --keep-alive` ``.
- The error is not `invalidArgument` (for example a `GrantivaError.notFound`/dedicated case), so the CLI prints
  `Error: No active runner session. ...` (exit 1) and the MCP isError text has no `Invalid argument:`.
- docs/dump-hierarchy.md:57 and docs/mcp.md quote the new text if they quote it.
- GrantivaCLITests/DumpHierarchyCommandTests and GrantivaMCPTests/SessionLifecycleTests assert the exact text (no single
  quotes, no "Invalid argument").
