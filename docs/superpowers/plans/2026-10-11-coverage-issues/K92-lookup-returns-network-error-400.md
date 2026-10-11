# MCP label lookups report `Network error (400): Failed to look up "…"` right after startup and when the app is not running

Severity: wrong-result
Component: mcp
Platforms: ios (iOS-only: WDA element lookup; the Android twin of MCP-078 passed with `Element not found: …` isError results)
Rows: MCP-078, N-05 (ios); related original brief R05 criterion 3 (docs/superpowers/plans/2026-10-10-regression-issues/R05-mcp-session-tools-rpc-error-during-wda-startup.md) and brief C21
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix MCP-078 (docs/mcp.md:21-22; brief R05 criteria 2-3): every session tool returns an `isError` result, never a
JSON-RPC error, and a missing label gives `Element not found: …`. Matrix N-05: a tap on a missing label as the first
call after WDA reports ready is always `Element not found: "No Such" …`, never `Network error (400)`. When the app has
been terminated, the texts should say the app is not running rather than blaming the network.

## Actual
The JSON-RPC shape is right (always `isError`), but the text is not.
N-05 (mcp-5x-b, 5 `runner start --detach` cycles, `grantiva_tap {label: "No Such"}` once a second): after the 3
`session is starting` results, the first post-startup call returned the network error in 3 of 5 cycles (transcript
lines 20, 160, 206), then `Element not found` for the rest:
```
<< [0.0s @01:34:16] {"id": 5, "jsonrpc": "2.0", "result": {"content": [{"text": "Error: Network error (400): Failed to look up \"No Such\"", "type": "text"}], "isError": true}}
```
MCP-078 (killed-app, after `xcrun simctl terminate <udid> com.kylebrowning.Landmarks`; lines 11-23):
```
grantiva_tap {label: "Landmarks"}  -> "Error: Network error (400): Failed to look up \"Landmarks\""
grantiva_swipe {direction: up}     -> "Error: Failed to swipe up"
grantiva_a11y_tree {}              -> "Error: Failed to get hierarchy from WDA"
grantiva_script [{tap: Landmarks}] -> "Error: Network error (400): Failed to look up \"Landmarks\""
grantiva_tap {label: "No Such"}    -> "Error: Network error (400): Failed to look up \"No Such\""
```
None says the app is not running. The flow path is fine: 5 of 5 `run --flow nosuch.yaml` give
`Element not found: text='No Such' …` (N-05/flow1-5.err).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k92
unset GRANTIVA_API_KEY
rm -rf /tmp/k92 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k92 && cd /tmp/k92/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k92 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"fix","version":"1"}}}'
NOTE='{"jsonrpc":"2.0","method":"notifications/initialized"}'
TAP='{"jsonrpc":"2.0","id":ID,"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"No Such"}}}'
# (a) right after startup, 5 cycles
for c in 1 2 3 4 5; do
  { printf '%s\n' "$INIT" "$NOTE"; grantiva runner start --bundle-id com.kylebrowning.Landmarks --simulator "$UDID" --detach >/dev/null
    for i in 2 3 4 5 6 7 8 9; do echo "${TAP/ID/$i}"; sleep 1; done; sleep 5; } \
    | grantiva mcp --project-dir "$PWD" | grep -o 'Network error[^"]*\|Element not found[^"]*\|session is starting' | head -5
  grantiva runner stop >/dev/null
done
# (b) app terminated under a live session
grantiva runner start --bundle-id com.kylebrowning.Landmarks --simulator "$UDID" --detach >/dev/null; sleep 8
xcrun simctl terminate "$UDID" com.kylebrowning.Landmarks
{ printf '%s\n' "$INIT" "$NOTE" "${TAP/ID/2}" \
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"grantiva_swipe","arguments":{"direction":"up"}}}' \
  '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}}}'; sleep 10; } \
  | grantiva mcp --project-dir "$PWD" | grep -o '"text": "Error[^"]*'
grantiva runner stop; grantiva simulator teardown --session-id fix-k92
```

## Evidence
- findings/evidence/cov-ios/N-05/commands.txt, mcp-5x-b/transcript.txt (lines 20, 160, 206), mcp-5x-b/requests.json,
  mcp-5x/transcript.txt, flow1-5.out/.err, nosuch.yaml
- findings/evidence/cov-ios/MCP-078/commands.txt, killed-app/transcript.txt (lines 4-23), killed-app/requests.json
- Android twin: findings/evidence/cov-android/MCP-078/ (after merge)

## Suspected cause
- `Sources/GrantivaCore/WDA/WDAClient.swift:88-101` (`tapByLabel`): any find status other than 200 or 404 throws
  `GrantivaError.networkError("Failed to look up …", status)`, rendered as `Network error (<status>): …`
  (`Sources/GrantivaCore/GrantivaError.swift:58-59`). WDA answers 400 when its session has no running application
  (just after startup, while the app is still launching, or after it was terminated). The WDA error body, which
  carries the reason, is discarded.
- The swipe and hierarchy paths have the same pattern with even less detail (WDAClient.swift:205 `Failed to swipe …`,
  :280 `Failed to get hierarchy from WDA`).

## Acceptance criteria
- Repro (a): 5 of 5 cycles give only `session is starting …` results followed by
  `Element not found: "No Such". Run grantiva hierarchy (or the grantiva_a11y_tree MCP tool) to inspect the tree.`;
  never `Network error`. (Waiting until the app is running before reporting ready is one way; mapping the 400 is
  another.)
- Repro (b): each session tool returns `isError` with a text that says the app under test is not running and how to
  recover (for example `com.kylebrowning.Landmarks is not running on <simulator>. Relaunch it (grantiva_run, or
  restart the session).`); `grantiva_screenshot` may still succeed.
- A genuine transport failure (WDA down) still reads as a connection problem naming the port.
- GrantivaCoreTests/WDAClientTests: a stub returning 400 with WDA's "application is not running" error body for
  `POST /elements` makes `tapByLabel` throw an app-not-running error; 404 still gives `elementNotFound`; the 400
  body text is included when it is not recognised.
- GrantivaMCPTests: the tool results for those errors are `isError` with the texts above.
