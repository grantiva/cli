# `grantiva_context` shows an empty app ID (and driver port 0 on Android) for a keep-alive runner session

Severity: wrong-result
Component: mcp
Platforms: both
Rows: X-020 (android), MCP-042 (ios; its `runtime: iOS-26-0` half belongs to cluster C96)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
`[Runner Session]` reports the session the UI tools use: its pid, the driver port in use, the app ID under test and the
device. For a `grantiva run --keep-alive` session these are known (the run resolved the app ID; the session file has
the port), as they are for a `runner start` session (matrix X-020; docs/mcp.md "Runner session").

## Actual
Android, keep-alive session from `run --keep-alive` (findings/evidence/cov-android/AND-094/mcp-01/transcript.txt, id 3):
```
[Runner Session]
  pid: 79748
  driver_port: 0
  application_id: 
  udid: emulator-5554
```
iOS 26.0, keep-alive session (findings/evidence/cov-ios/MCP-LIVE1/run/transcript.txt):
```
[Runner Session]
  pid: 4267
  wda_port: 8235
  bundle_id: 
  udid: A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF
```

## Repro
iOS (the Android repro is the same with `--device <serial>` in `landmarks-demo/android`, `--platform android`):
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k56
rm -rf /tmp/k56 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k56 && cd /tmp/k56/ios
UDID=$(grantiva simulator ensure --name "fix-k56 iPhone 17")
grantiva build install --simulator "$UDID"
grantiva run --simulator "$UDID" --no-build --flow .maestro/01-browse.yaml --keep-alive --ready-file /tmp/k56/ready &
while [ ! -f /tmp/k56/ready ]; do sleep 1; done
{ echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_context","arguments":{}}}'
  sleep 5; } | grantiva mcp --platform ios | grep '"id":1' | jq -r '.result.content[0].text' | sed -n '/Runner Session/,$p'
kill %1; grantiva simulator teardown --session-id fix-k56
```
Today: `bundle_id:` is empty (Android: `driver_port: 0`, `application_id:` empty).

## Evidence
- findings/evidence/cov-android/X-020/commands.txt (points at AND-094), AND-094/commands.txt, AND-094/mcp-01/transcript.txt
- findings/evidence/cov-ios/MCP-LIVE1/commands.txt, run/transcript.txt

## Suspected cause
- Sources/GrantivaMCP/MCPServer.swift:175-182 (`loadActiveSession`): for a keep-alive session it synthesizes
  `RunnerSessionInfo(pid:, wdaPort: port, bundleId: "", udid:, startedAt: Date())`; the app ID is hard-coded empty and,
  on Android, the keep-alive session file records port 0 (the platform forwards a port on attach; see
  Sources/GrantivaCLI/DriverCommand.swift:726-733 comment "A keep-alive port of 0 (Android) becomes nil").
- Sources/GrantivaCore/Runner/KeepAliveSessionStore.swift:12-37: `KeepAliveSession` has no app ID field, and the owner
  sidecar (`KeepAliveOwner`, :40-) records only udid, pid, project directory and platform.
- Sources/GrantivaMCP/Tools/ContextTool.swift:74-82 prints the fields as they are.

## Acceptance criteria
- `grantiva run --keep-alive` records the app ID it launched in the owner sidecar; `loadActiveSession` fills
  `bundleId` from it. Re-running the repro: `bundle_id: com.kylebrowning.Landmarks` (Android: `application_id:
  com.kylebrowning.landmarks`).
- Android: `driver_port` shows the port the attached driver uses, or the line reads `driver_port: (forwarded on
  attach)`; never a bare `0`.
- A sidecar written by an older Grantiva without the app ID prints `bundle_id: (unknown)`, not an empty value.
- GrantivaCoreTests/KeepAliveSessionStoreTests: owner sidecar round-trips the app ID; GrantivaMCPTests/ContextToolTests:
  a keep-alive-derived session renders the app ID and no empty value lines.
