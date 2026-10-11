# MCP build, simulator and emulator tools report failures as JSON-RPC internal errors instead of `isError` results

Severity: contract
Component: mcp
Platforms: both (iOS `grantiva_build`; Android `grantiva_emulator_boot` / `grantiva_emulator_delete`)
Rows: CLI-100 (cli), MCP-057, MCP-061, MCP-062, AND-100 (android), MCP-031 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
A tool that fails returns a `CallTool` result with `isError: true` and a readable message, never a JSON-RPC error.
- docs/mcp.md:21-22 states it for session tools ("Session tools report every failure as an `isError` result, never as a
  JSON-RPC error"); the MCP specification says the same for all tools (tool execution errors belong in the result;
  protocol errors are for unknown tools and malformed requests); and the server already follows it for argument
  errors (Sources/GrantivaMCP/Tools/SimTools.swift:121-123 comment; GrantivaMCPTests/ToolErrorContractTests).
- Messages name the tool's own arguments (`force`), not CLI flags (`--force`).

## Actual
- iOS, `grantiva_build {}` with the configured simulator missing (findings/evidence/cov-cli/CLI-100/ios.out) and
  `grantiva_build {scheme: "Landmarks (UI Testing)"}` in a directory without config, defaulting to `iPhone 16`
  (findings/evidence/cov-ios/MCP-031/empty-dir/transcript.txt):
```
"error":{"code":-32603,"data":{"detail":"Invalid argument: Simulator not found: \"qa-ios-1\""},"message":"Internal error: Invalid argument: Simulator not found: \"qa-ios-1\""}
{"code": -32603, "message": "Internal error: Invalid argument: Simulator not found: \"iPhone 16\""}
```
- Android (findings/evidence/cov-android/MCP-061/mcp-01/transcript.txt; MCP-062; AND-100 and MCP-057 cite these):
```
>> grantiva_emulator_delete {"name": "cov-android-2"}            (hand-made AVD)
<< {"error": {"code": -32603, ... "message": "Internal error: Invalid argument: AVD \"cov-android-2\" was not created by Grantiva (grantiva emulator ensure). Pass --force to delete it anyway."}}
>> grantiva_emulator_delete {"name": "cov-android", "force": true} (running)
<< {"error": {"code": -32603, ... "AVD \"cov-android\" is running as emulator-5554. Run `grantiva emulator teardown --serial emulator-5554` first."}}
>> grantiva_emulator_boot {"name": "no-such-avd"}
<< {"error": {"code": -32603, ... "No attached device has the serial \"no-such-avd\" ... AVDs: Pixel_8_API_35, cov-android."}}
```
  A second delete of a missing AVD is a JSON-RPC error too. Successful calls are fine.

## Repro
Shared helper (stdio JSON-RPC; one request per line after the handshake):
```
mcp() { dir=$1; plat=$2; shift 2
  { echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}'
    echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
    for r in "$@"; do echo "$r"; done; sleep 20; } | grantiva mcp --project-dir "$dir" --platform "$plat"; }
```
iOS:
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k53
rm -rf /tmp/k53 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k53 && mkdir /tmp/k53/empty
mcp /tmp/k53/empty ios '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_build","arguments":{"scheme":"Landmarks","simulator":"no-such-sim"}}}' \
                       '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"grantiva_sim_boot","arguments":{"name":"no-such-sim"}}}'
```
Android (JAVA_HOME/ANDROID_HOME/PATH as in docs/android-environment.md):
```
echo no | avdmanager create avd -n fix-k53-hand -k "system-images;android-35;google_apis;arm64-v8a" -d pixel_8
mcp /tmp/k53/android android \
  '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_emulator_delete","arguments":{"name":"fix-k53-hand"}}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"grantiva_emulator_boot","arguments":{"name":"no-such-avd"}}}' \
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"grantiva_emulator_delete","arguments":{"name":"no-such-avd"}}}' \
  '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"grantiva_emulator_delete","arguments":{"name":"fix-k53-hand","force":true}}}'
```
Today: ids 1-3 (and iOS ids 1-2) answer `{"error":{"code":-32603,...}}`; id 4 succeeds and cleans up.

## Evidence
- findings/evidence/cov-cli/CLI-100/commands.txt, ios.out, ios.requests.jsonl
- findings/evidence/cov-ios/MCP-031/commands.txt, empty-dir/transcript.txt
- findings/evidence/cov-android/MCP-061/commands.txt, mcp-01/transcript.txt; MCP-062/commands.txt and its mcp-01/;
  MCP-057/commands.txt and AND-100/commands.txt (point at MCP-059 and MCP-061)

## Suspected cause
- Sources/GrantivaMCP/ToolRegistry.swift:110-173: every non-session tool is `result = try await ...` with no `catch`;
  only session tools are wrapped (:70-90, `sessionToolError`). Sources/GrantivaMCP/MCPServer.swift:102-108 passes a
  thrown error to the SDK, which answers -32603.
- Throwing sites reached: BuildTools.swift:158 and :201 (`device.bootDevice`), SimTools.swift:75, :109, :130, :146,
  EmulatorTools.swift:89-91, :102, :109, :116.
- The refusal text comes from Sources/GrantivaCore/Android/EmulatorManager.swift:421-424 (CLI wording `--force`).

## Acceptance criteria
- Re-running the repro: every call answers `{"result":{"content":[{"type":"text","text":"Error: ..."}],"isError":true}}`;
  no response carries `"error"`. Cancellation still propagates as cancellation.
- The hand-made-AVD refusal says `Pass force: true to delete it anyway.` (or names the argument) in the MCP result;
  the CLI keeps `--force`.
- `ToolRegistry.call` converts any thrown non-cancellation error from any tool into an isError result in one place
  (the existing `errorResult`).
- GrantivaMCPTests/ToolErrorContractTests: with fakes that throw, `grantiva_build`, `grantiva_run`, `grantiva_sim_boot`,
  `grantiva_sim_delete`, `grantiva_emulator_boot`, `grantiva_emulator_delete`, `grantiva_emulator_ensure` and
  `grantiva_emulator_list` each return `isError == true` from `ToolRegistry.call` (none throws).
