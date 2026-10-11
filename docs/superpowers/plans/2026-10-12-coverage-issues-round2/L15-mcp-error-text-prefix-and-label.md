# MCP failure texts break the docs/mcp.md shape: an unknown tool has no `Error: ` prefix, and missing arguments have no `Invalid argument: ` label

Severity: contract
Component: mcp
Platforms: n/a (stdio transport; the same texts on both platforms)
Rows: N2-19 [cli], D2-34 [cli] (part 1; part 2 is L14). Also seen in MCP-077 [cli] (pass, note).
Regresses/extends: K53 (MCP tool errors become JSON-RPC), fixed by CLI #195; K46 (no-session message shape), fixed by CLI #194. The follow-up is incomplete.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
docs/mcp.md:23-34 at c65fc17: every tool failure is an `isError` result "whose text starts with `Error: `". "A failure
caused by an argument … carries the label `Invalid argument: ` after `Error: `", for example `Error: Invalid argument:
Simulator not found: "no-such-sim"`. A required argument that is missing is an argument failure. An unknown tool name
is the `name` argument of `tools/call` and gets the same `Error: Invalid argument: ` shape.

Triage note: docs/mcp.md's examples name only "does not exist / still running" failures. If the owner rules that a
missing required argument is not an "argument failure", the second half becomes a docs line that names the exception.
The missing `Error: ` prefix on the unknown tool contradicts the docs either way.

## Actual
Nine calls to one server (findings/evidence/cov2-cli/N2-19/summary.txt; requests in texts.requests.jsonl). Every
answer is `isError`, but three texts break the shape:
```
1 isError= True Error-count= 1 :: Error: Invalid argument: Simulator not found: "no-such-sim"
3 isError= True Error-count= 1 :: Error: 'name' is required.
5 isError= True Error-count= 1 :: Error: Invalid argument: No AVD named "no-such-avd". Existing AVDs: Pixel_8_API_35, cov2-android.
6 isError= True Error-count= 1 :: Error: 'name' is required.
7 isError= True Error-count= 0 :: Unknown tool: grantiva_bogus_tool
```
(3 = `grantiva_sim_ensure {}`, 6 = `grantiva_emulator_ensure {}`, 7 = an unknown tool.) D2-34 contract.out repeats the
unknown-tool text: `"id":1 … "text":"Unknown tool: grantiva_nope"`.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"; unset GRANTIVA_API_KEY
rm -rf /tmp/l15 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l15 && cd /tmp/l15/ios
{ cat <<'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"l15","version":"1"}}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"grantiva_sim_ensure","arguments":{}}}
{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"grantiva_emulator_ensure","arguments":{}}}
{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"grantiva_bogus_tool","arguments":{}}}
EOF
sleep 3; } | grantiva mcp --project-dir /tmp/l15/ios | jq -r 'select(.id>1) | "\(.id) \(.result.content[0].text)"'
# bug: "3 Error: 'name' is required."  "6 Error: 'name' is required."  "7 Unknown tool: grantiva_bogus_tool"
```

## Evidence
- findings/evidence/cov2-cli/N2-19/summary.txt, texts.out, texts.requests.jsonl, commands.txt
- findings/evidence/cov2-cli/D2-34/contract.out, contract.requests.txt
- findings/evidence/cov2-cli/MCP-077/ (same texts, graded pass with a note)

## Suspected cause
- Unknown tool: `Sources/GrantivaMCP/ToolRegistry.swift:190-194` builds `CallTool.Result(content: [.text("Unknown tool:
  \(name)")], isError: true)` by hand, bypassing `errorResult` (`ToolRegistry.swift:223-226`, which adds `Error: `).
- Missing required arguments are hand-built strings without the label: `Sources/GrantivaMCP/Tools/SimTools.swift:126,142`
  (`"Error: 'name' is required."`), `Sources/GrantivaMCP/Tools/EmulatorTools.swift:108,115` (`toolError("'name' is
  required.")`, `toolError` at `:83-85`), `Sources/GrantivaMCP/Tools/ScriptTools.swift:80` (`'steps' array is
  required.`), `Sources/GrantivaMCP/Tools/UITools.swift:185,202` (`'direction'`, `'text'`).
- The tests assert only `contains: "'name' is required"` (`Tests/GrantivaMCPTests/ToolErrorContractTests.swift:41-68`,
  `ArgumentValidationTests.swift:86,95`), so they do not pin the prefix or label.

Fix: route all of these through `errorResult(GrantivaError.invalidArgument(…))`. The unknown tool becomes `Error: Invalid
argument: Unknown tool: grantiva_bogus_tool`.

## Acceptance criteria
- Every `isError` text from every tool, the unknown-tool path included, starts with `Error: ` exactly once.
- Missing required arguments read `Error: Invalid argument: '<name>' is required.` for `grantiva_sim_ensure`,
  `grantiva_emulator_ensure`, `grantiva_script`, `grantiva_swipe`, `grantiva_type` (session tools still give the
  no-session text first when there is no session).
- An unknown tool reads `Error: Invalid argument: Unknown tool: <name>` (or the agreed form) and stays an `isError`
  result, not a JSON-RPC error.
- No-session texts keep no `Invalid argument:` label (K46).
- Tests: GrantivaMCPTests/ToolErrorContractTests, assert the exact full text (not `contains`) for each case above and for
  the unknown tool through `ToolRegistry.call`. A table-driven test asserts `hasPrefix("Error: ")` and a single
  occurrence of `Error: ` for every tool's empty-arguments call.
