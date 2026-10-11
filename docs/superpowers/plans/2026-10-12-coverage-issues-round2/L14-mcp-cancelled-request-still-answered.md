# An MCP `tools/call` cancelled with `notifications/cancelled` still gets a late result

Severity: contract
Component: mcp
Platforms: n/a (stdio transport; the same server code serves both platforms)
Rows: D2-34 [cli] (part 2; the row is counted once, under L15)
Regresses/extends: K53 (MCP tool errors become JSON-RPC) and K101 (error response to a notification), both fixed by CLI #195. Neither covers cancellation.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
docs/mcp.md:22-26 at c65fc17: "Every tool … reports every failure as an `isError` result … Cancelling a call still
cancels it." MCP spec (cancellation): after `notifications/cancelled` for an in-flight request, the receiver should
stop the work and must not send a response for that request. A `tools/call` cancelled while in flight gets no response.
Later requests are answered as usual.

## Actual
Three lines written at once to one `grantiva mcp` server, in a directory whose grantiva.yml names `simulator:
cov-missing` (findings/evidence/cov2-cli/D2-34/cancel.requests.txt):
```
{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"grantiva_build","arguments":{}}}
{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":10,"reason":"test"}}
{"jsonrpc":"2.0","id":11,"method":"tools/list"}
```
`tools/list` (id 11) was answered first, so id 10 was still in flight when the cancel arrived. Id 10 still got its result
(findings/evidence/cov2-cli/D2-34/cancel.out):
```
{"id":11,"jsonrpc":"2.0","result":{"tools":[…]}}
{"id":10,"jsonrpc":"2.0","result":{"content":[{"text":"Error: Invalid argument: Simulator not found: \"cov-missing\"","type":"text"}],"isError":true}}
```
1 run. The call failed fast, so it never reached a long build. A cancelled long build (xcodebuild, Gradle) was not tried.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"; unset GRANTIVA_API_KEY
rm -rf /tmp/l14 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l14 && cd /tmp/l14/ios
sed -i '' 's/^simulator: .*/simulator: cov-missing/' grantiva.yml
{ cat <<'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"l14","version":"1"}}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"grantiva_build","arguments":{}}}
{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":10,"reason":"test"}}
{"jsonrpc":"2.0","id":11,"method":"tools/list"}
EOF
sleep 5; } | grantiva mcp --project-dir /tmp/l14/ios | jq -c '{id, isError: .result.isError}'
# bug: a line with "id":10. Expected: ids 1 and 11 only.
```
A stronger variant cancels a real build. Put back the stock `simulator:` and use a simulator that exists. Send the cancel
2 s after id 10, then check with `pgrep -f "xcodebuild.*Landmarks"` that the build was stopped and that no id-10 line
follows.

## Evidence
- findings/evidence/cov2-cli/D2-34/cancel.requests.txt, cancel.out, cancel.err, grantiva.yml, commands.txt
- docs/superpowers/plans/2026-10-11-coverage-issues/K53-mcp-tool-errors-become-jsonrpc.md, K101-mcp-error-response-to-notification.md

## Suspected cause
The cluster map said `notifications/cancelled` has no handler. That is not quite right. The MCP Swift SDK in use (0.12.1,
revision a0ae212, `Package.resolved`) registers one itself (`Server.registerCancellationHandler`,
swift-sdk `Sources/MCP/Server/Server.swift:977-1015`). It cancels the request's handler task when that
task is in `pendingRequestTasks`, and sends no response if the task throws `CancellationError` (`:798-805,830-835`).
Two gaps in grantiva let the result through anyway:
- grantiva turns a cancelled call into a normal result. `Sources/GrantivaMCP/MCPServer.swift:101-108` returns whatever
  `tools.call` returns. `ToolRegistry.call` (`Sources/GrantivaMCP/ToolRegistry.swift:94-112`) rethrows only a thrown
  `CancellationError`. Here the tool body (`BuildTools.build`, `Sources/GrantivaMCP/Tools/BuildTools.swift:142-160`, through
  `SimulatorManager` and `simctl` subprocesses) never checks `Task.isCancelled`. It throws `GrantivaError` "Simulator not
  found", which `errorResult` turns into an `isError` result. The handler then returns normally, and the SDK sends it.
- Race in the SDK: each request is handled in an unstructured `Task { handleRequest }` (`Server.swift:233-237`, the call at `:236`), and the
  task registers itself in `pendingRequestTasks` only when it starts running (`:816`). Notifications are handled
  inline in the receive loop. A cancel that arrives right behind its request can find no pending task and be ignored
  ("unknown or completed request", `:1007-1013`). Which of the two applied here was not traced. The fix must cover
  both.

Fix direction (grantiva side, independent of the race): register an extra `onNotification(CancelledNotification.self)`
handler (the SDK appends handlers, `Server.swift:354-360`) that records cancelled request ids. In the `CallTool` handler,
read `Server.currentHandlerContext?.id` and throw `CancellationError` when the id was cancelled or `Task.isCancelled`,
both before and after the tool runs. Long-running tools pass cancellation to their subprocess
(`withTaskCancellationHandler` → terminate xcodebuild/Gradle).

## Acceptance criteria
- The repro's three lines produce responses for ids 1 and 11 only. No line with `"id":10` is written, even when the
  cancel arrives before the request's task has started.
- A `grantiva_build` cancelled 2 s in stops its xcodebuild (iOS) or Gradle (Android) process within 5 s, and no
  response for its id follows.
- A cancel for an unknown or finished id changes nothing, and later requests are answered.
- Tests: GrantivaMCPTests/MCPTransportTests (in-memory transport), (1) a tool stub that sleeps 1 s and then returns an
  `isError` result: a request plus an immediate cancel yields no response for that id, and a following `tools/list` is
  answered. (2) The same with the cancel sent 200 ms later. (3) A cancel for an unknown id is ignored.
