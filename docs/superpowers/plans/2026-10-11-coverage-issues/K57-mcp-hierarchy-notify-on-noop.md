# The MCP server announces a hierarchy change after UI tool calls that failed and changed nothing

Severity: ux
Component: mcp
Platforms: both (platform-independent code; seen on Android; iOS twin IOS-108 passed without judging notifications)
Rows: AND-OBS-09 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
`notifications/resources/updated` for `grantiva://hierarchy` follows only calls that may have changed the UI: a tap,
swipe, type or script that ran at least one step. A rejected call (invalid arguments, element not found, no step run)
sends none. Notifications go to clients that subscribed (the server advertises `resources.subscribe: true`).

## Actual
Android keep-alive session, no `resources/subscribe` sent by the client
(findings/evidence/cov-android/MCP-026/mcp-01/transcript.txt:4-6):
```
>> {"method": "tools/call", "params": {"name": "grantiva_script", "arguments": {"steps": [{"bogus": 1}, 5]}}, "id": 2, "jsonrpc": "2.0"}
<< (other) {"jsonrpc": "2.0", "method": "notifications/resources/updated", "params": {"uri": "grantiva://hierarchy"}}
<< [0.1s] {"id": 2, ... "text": "Error: invalid script steps; no steps were run. ..."}], "isError": true}}
```
findings/evidence/cov-android/MCP-006/mcp-02/transcript.txt:12-14:
```
>> {"method": "tools/call", "params": {"name": "grantiva_tap", "arguments": {"label": "No Such Label"}}, "id": 5, "jsonrpc": "2.0"}
<< (other) {"jsonrpc": "2.0", "method": "notifications/resources/updated", "params": {"uri": "grantiva://hierarchy"}}
<< [0.0s] {"id": 5, ... "text": "Error: Element not found: \"No Such Label\". ..."}], "isError": true}}
```

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k57
rm -rf /tmp/k57 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k57 && cd /tmp/k57/android
SERIAL=$(grantiva emulator ensure --name qa-fix-k57 | tail -1)
grantiva build install --device "$SERIAL" && grantiva runner start --detach --device "$SERIAL"
{ echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"bogus":1}]}}}'
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"No Such Label"}}}'
  echo '{"jsonrpc":"2.0","id":3,"method":"resources/subscribe","params":{"uri":"grantiva://hierarchy"}}'
  echo '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Gesture Lab"}}}'
  sleep 10; } | grantiva mcp --platform android | grep -n 'resources/updated\|"id":[1-4]'
grantiva runner stop; grantiva emulator teardown --serial "$SERIAL"
```
Today: a notification precedes ids 1, 2 and 4. Expected: only before (or after) id 4.

## Evidence
- findings/evidence/cov-android/AND-OBS-09/commands.txt (points at MCP-026/mcp-01 and MCP-006/mcp-02)
- findings/evidence/cov-android/MCP-026/commands.txt, mcp-01/transcript.txt
- findings/evidence/cov-android/MCP-006/commands.txt, mcp-02/transcript.txt

## Suspected cause
- Sources/GrantivaMCP/ToolRegistry.swift:84-95: after `callSessionTool` returns, the registry notifies for every tool in
  `uiMutatingTools` (:63) without looking at `result.isError`; the tools return isError results (not throws) for invalid
  steps and missing elements, so those reach the notify.
- Sources/GrantivaMCP/ToolRegistry.swift:257-262 (`notifyHierarchyUpdate`) sends unconditionally; the subscribe and
  unsubscribe handlers (Sources/GrantivaMCP/MCPServer.swift:122-132) only acknowledge and record nothing, so
  notifications also go to clients that never subscribed.

## Acceptance criteria
- Re-running the repro: no `notifications/resources/updated` for ids 1 and 2; one for id 4 (after the subscribe).
- Without a `resources/subscribe`, no `resources/updated` notification is sent (or docs/mcp.md says notifications are
  sent to every client, if that is the intended contract).
- A script whose first steps ran and a later step failed still notifies (the UI changed).
- GrantivaMCPTests/SessionLifecycleTests (or UIToolsTests) with a fake server/notifier: an isError `grantiva_tap` and a
  rejected `grantiva_script` send no notification; a successful tap sends one.
