# Return isError from grantiva_script when steps are invalid

Severity: contract
Platforms: cli, ios, android
Found by: CLI-F22 (matrix rows: none; MCP Step 5)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
A script whose steps cannot run returns `isError: true` naming the bad steps, like the other tools' argument errors
(e.g. `grantiva_swipe` → `"Error: 'direction' is required."`, isError). Source: MCP tool-result contract; ToolErrorContractTests.

## Actual
`tools/call grantiva_script {"steps":[{"bogus":1},5]}` returns a normal result (no `isError`):
```
Step 1: unknown action, skipped
Step 2: skipped (not an object)

Final hierarchy:
{
  "children" : [
```
An agent checking `isError` thinks the script ran.

## Repro
1. Start a runner session in a project dir (`grantiva runner start --simulator <udid> --bundle-id com.apple.Preferences`).
2. Write `calls.jsonl` with one line:
   `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"bogus":1},5]}}}`
3. `python3 -I fixtures/mcp/client.py "$(which grantiva)" <dir> ios calls.jsonl 30 out.jsonl` and inspect `isError`.

## Evidence
- findings/evidence/cli/mcp/calls-ios.jsonl (id 137); findings/evidence/cli/mcp/calls-ios-summary.tsv (id 137)

## Suspected cause
Sources/GrantivaMCP/Tools/ScriptTools.swift:76 and :105 log skipped steps and continue; :114-116 always return a
`CallTool.Result` without `isError`.

## Acceptance criteria
- Re-running the repro returns `isError: true` with text naming steps 1 and 2 and why. Decide whether invalid steps are
  rejected before any step runs (preferred) or reported after; document it in the tool description.
- GrantivaMCPTests/ScriptToolsTests: `steps: [{"bogus":1}, 5]` yields `isError == true`; a valid script still yields no `isError`.
