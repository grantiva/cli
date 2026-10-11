# The three MCP VRT tools wrap failures in three different shapes

Severity: ux
Component: mcp
Platforms: both
Rows: MCP-075 (cli)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
`grantiva_vrt_capture`, `grantiva_vrt_compare` and `grantiva_vrt_approve` report failures with one shape (one prefix
convention, `Error:` once), like the other tools' `Error: <message>` results.

## Actual
Empty project (findings/evidence/cov-cli/MCP-033/empty_ios.out), all isError:
```
capture  "Capture failed:\ngrantiva.yml not found at …/grantiva.yml. Create one with grantiva init."
compare  "Error: No captures found in .grantiva/captures. Run: grantiva diff capture"
approve  "Approve failed:\nError: No captures found in .grantiva/captures. Run: grantiva diff capture"
```
With a config, a capture failure from the CLI reads `Capture failed:\nError: Invalid argument: ...`; build and run
tools use `Error: ...`.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"
mkdir -p /tmp/k59/empty && cd /tmp/k59/empty
{ echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  echo '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}}}'
  echo '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"grantiva_vrt_compare","arguments":{}}}'
  echo '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"grantiva_vrt_approve","arguments":{}}}'
  sleep 5; } | grantiva mcp --platform ios | grep '"id":[567]' | jq -c '.result.content[0].text'
rm -rf /tmp/k59
```
(This also creates `.grantiva/captures/diffs`, see K51.)

## Evidence
- findings/evidence/cov-cli/MCP-033/commands.txt, empty_ios.requests.jsonl, empty_ios.out, empty_android.out

## Suspected cause
- Sources/GrantivaMCP/Tools/VRTTools.swift:93-97 (`capture`: `"Capture failed:\n\(msg)"`), :120-130
  (`compareFailureResult`: the message as is), :144-148 (`approve`: `"Approve failed:\n\(msg)"`). `msg` is the CLI's
  stderr, which already begins with `Error: ` when the CLI produced it.
- Sources/GrantivaMCP/ToolRegistry.swift:157-161 (capture without config: `"Capture failed:\n\(missingConfig)"`, no
  `Error:`) and Sources/GrantivaMCP/Tools/SessionCapture.swift:375-377 (`captureFailure`).

## Acceptance criteria
- Re-running the repro: the three texts share one form, for example `Error: <message>` with no second prefix, or
  `<Tool> failed: <message>` on one line with the CLI's leading `Error: ` stripped; `Error:` appears at most once.
- Compare's diff-verdict JSON result (not an error) is unchanged.
- One helper builds the VRT failure result; capture-through-session, capture-without-config and the CLI-backed paths
  use it.
- GrantivaMCPTests/VRTToolsTests: a failing capture, compare and approve (fake `shell` failure with `Error: x`) produce
  texts with the same prefix and exactly one `Error:`.
