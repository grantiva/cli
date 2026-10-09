# Report the session's device in grantiva_context

Severity: wrong-result
Platforms: cli, ios
Found by: CLI-F20 (matrix rows: none; MCP Step 5)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
The `[Simulator]` section of `grantiva_context` describes the device the other tools act on, i.e. the runner session's
device. Source: tool description "Get current project context: config, booted simulator or running emulator, ... and runner
session status" (Sources/GrantivaMCP/Tools/ContextTool.swift:14).

## Actual
With two booted simulators and the session on the second:
```
[Simulator]
  name: iPhone 17 Pro
  udid: B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C
  runtime: iOS-26-0
  state: Booted
...
[Runner Session]
  pid: 55313
  wda_port: 8400
  bundle_id: com.apple.Preferences
  udid: D3E7E498-2E80-469C-A465-4757C8995ACC
```
An agent reading context reasons about the wrong device.

## Repro
1. Boot two simulators: `a=$(grantiva simulator ensure --name "iPhone 17 Pro")`, `b=$(grantiva simulator ensure --name qa-c06)`.
   Make sure `a` was booted first.
2. In a project dir with a `grantiva.yml`, start a session on `b`:
   `grantiva runner start --simulator "$b" --bundle-id com.apple.Preferences`.
3. Call `grantiva_context` via `fixtures/mcp/client.py` (or `fixtures/mcp/send.sh <dir> ios req.jsonl`). `[Simulator]` shows `a`.

## Evidence
- findings/evidence/cli/mcp/calls-ios.jsonl (id 116)

## Suspected cause
Sources/GrantivaMCP/Tools/ContextTool.swift:60 uses `simManager.bootedDevice()` (the first booted simulator) instead of
looking up `session.udid`, which the same tool already loads at :81.

## Acceptance criteria
- Re-running the repro: `[Simulator] udid` equals `[Runner Session] udid`. With no session, it says so rather than
  picking an arbitrary booted simulator (or labels it "first booted simulator").
- Android: `[Emulator]` likewise names the session's serial.
- GrantivaMCPTests/ContextToolTests: with a fake sim manager returning two booted devices and a session on the second,
  assert the output's `[Simulator]` udid is the session's.
