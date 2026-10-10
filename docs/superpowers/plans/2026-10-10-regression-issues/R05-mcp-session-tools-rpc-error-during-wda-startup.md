# MCP session tools answer with a JSON-RPC error, not an isError result, while WDA starts after `runner start --detach`

Severity: contract
Blocking: no
Platforms: ios (observed); Android not exercised
Found by: CLI slice, Step 4 row `S4-startup-window` (findings/cli-results.md, Step 4). Original briefs: C21 (`plans/2026-10-09-qa-issues/C21-remediation-names-real-commands.md`, rpc-error versus isError shape) and C11 (`plans/2026-10-09-qa-issues/C11-mcp-starts-without-session-or-config.md`, lazy attach); last round's files are on branch `qa-campaign`, commit 8084069, with an exported copy at `~/.grantiva-qa/briefs/docs/superpowers/`.
Binary: grantiva 2.1.0 at a278b77, grantiva-runner 1.1.28-grantiva.8, qa-reg-ios-1 (iPhone 17, iOS 26.0, `4278E141-1297-46F9-989F-FB9995D123F9`)

## Expected
C21: "Note `grantiva_tap` returned this as a JSON-RPC internal error (rpc-error), not an `isError` result; return
`isError`." C11: session tools "return `isError` with the "No active runner session ... Start one with ..." text; the
driver attaches lazily on first use, and re-checks after a session starts." A session tool called while the runner
session exists but WDA is not ready yet should return an `isError` tool result that says so, and a later call on the
same server should attach.

## Actual
In the seconds after `grantiva runner start --simulator <udid> --detach` returns (exit 0, `.grantiva/session.json`
written with `wdaPort` 8581), session tools answer with a JSON-RPC error instead of a tool result:
```
<< {"error":{"code":-32603,"data":{"detail":"No active WDA session"},"message":"Internal error: No active WDA session"},"id":2,"jsonrpc":"2.0"}
```
- findings/evidence/cli/step4-session-regios.txt: one server spans the start; three calls made right after it fail this
  way: `grantiva_a11y_tree` (id 2), `grantiva_tap {"label":"No Such Label QA"}` (id 4) and
  `grantiva_script {"steps":[{"wait":0.1}]}` (id 6). `grantiva_context` (id 3) and the invalid-steps
  `grantiva_script` (id 5, rejected before any device call) answer normally in between.
- findings/evidence/cli/C11-lazy-attach.txt: the server starts with no session (id 1 is the correct isError "No active
  runner session ..."). After `runner start --detach`:
  ```
  id 2 (right after start):            {"error":{"code":-32603,"data":{"detail":"No active WDA session"},"message":"Internal error: No active WDA session"},"id":2,...}
  WDA /status answered on 8581 after 1s
  id 3 (after /status answered):       {"error":{"code":-32603,"data":{"detail":"No active WDA session"},"message":"Internal error: No active WDA session"},"id":3,...}
  $ sleep 10
  id 4 (about 10 s later):             {"id":4,"jsonrpc":"2.0","result":{"content":[{"text":"{\n  \"children\" : [ ...
  ```
  The same server then answers `grantiva_tap` on a missing label with the correct isError (id 5).

So lazy attach works once WDA has a session, but during the startup window the client gets a protocol-level error
(which many MCP clients surface as a server failure) with no hint that waiting and retrying will work.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-r05
unset GRANTIVA_API_KEY
rm -rf /tmp/r05 && mkdir -p /tmp/r05 && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/r05/ios && cd /tmp/r05/ios
UDID=$(grantiva simulator ensure --name qa-fix-r05 --device-type "iPhone 17" --runtime 26.0 | tail -1); echo "$UDID"
grantiva build install --simulator "$UDID"
CALL='{"jsonrpc":"2.0","method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}},"id":ID}'
{
  echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  sleep 2
  grantiva runner start --simulator "$UDID" --detach >&2      # server is already running, with no session
  echo "${CALL/ID/1}"                                           # immediately after start returns
  sleep 10
  echo "${CALL/ID/2}"                                           # same server, about 10 s later
  sleep 10
} | grantiva mcp --project-dir /tmp/r05/ios --platform ios | grep -E '"id":(1|2)' | cut -c1-200
# cleanup
grantiva runner stop
grantiva simulator teardown --udid "$UDID"
```
Today: id 1 is `{"error":{"code":-32603,"data":{"detail":"No active WDA session"},"message":"Internal error: No active
WDA session"},...}`; id 2 is a `result` holding the hierarchy JSON. The window is timing-dependent (it lasted past
the first `/status` answer in C11-lazy-attach.txt, id 3); if id 1 succeeds on a fast host, rerun with the `sleep 2`
removed. The CLI slice kept one `grantiva mcp` server open and wrote JSON-RPC lines to its stdin between shell steps
(C11-lazy-attach.txt), with the same `initialize` / `notifications/initialized` framing as its `send.sh` (D09.txt); the
brace group above does the same in one shell.

## Evidence
- findings/evidence/cli/step4-session-regios.txt (ids 2, 4, 6 fail; ids 3 and 5 answer)
- findings/evidence/cli/C11-lazy-attach.txt (id 2 right after start, id 3 after WDA `/status`, id 4 succeeds about 10 s
  later)
- findings/cli-results.md, Step 4 row `S4-startup-window`; C21 row (the isError shape holds once WDA is ready)

## Suspected cause
Hypothesis, from reading source; not confirmed by a run. `WDAClient.resolveSessionId`
(Sources/GrantivaCore/WDA/WDAClient.swift:254-264) throws `GrantivaError.commandFailed("No active WDA session", 1)`
when WDA's `/status` answers without a `sessionId`, which is the state while the runner is still creating the WDA
session. In `ToolRegistry.call` (Sources/GrantivaMCP/ToolRegistry.swift:62-81) only the `connection.current()` step is
wrapped in a do/catch that turns errors into an isError result; `callSessionTool` is called with `try`, and the UI tools
rethrow every `GrantivaError` except `.elementNotFound` (for example `UITools.tap`, Sources/GrantivaMCP/Tools/UITools.swift:141-150).
The thrown error reaches the MCP server library, which reports it as JSON-RPC `-32603` "Internal error".

## Acceptance criteria
- Re-running the repro: a session tool called in the window between `runner start --detach` returning and WDA having a
  session returns a `result` with `"isError": true`, never a JSON-RPC `error` object. Its text names the startup state
  and how to retry, for example `The runner session is starting (WDA on port 8581 has no session yet). Retry in a few
  seconds.`
- The same holds for every session tool (`grantiva_screenshot`, `grantiva_tap`, `grantiva_swipe`, `grantiva_type`,
  `grantiva_a11y_tree`, `grantiva_a11y_check`, `grantiva_script`), and for other driver errors those tools hit.
- Lazy attach still works: on the same server, the call made once WDA is ready (id 2 in the repro) returns the
  hierarchy without a restart, and a missing label still gives `Element not found: ...` as isError.
- GrantivaMCPTests: with a session file present and a WDA stub whose `/status` has no `sessionId`, a session tool
  returns isError whose text mentions the session starting; no error is thrown out of `ToolRegistry.call`.
