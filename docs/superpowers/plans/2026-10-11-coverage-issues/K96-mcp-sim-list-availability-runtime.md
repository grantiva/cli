# MCP `grantiva_sim_list` has no availability column and prints runtimes as identifier fragments (`iOS-26-0`)

Severity: contract
Component: mcp
Platforms: ios (iOS-only: simulator tools)
Rows: MCP-047 (ios); the same runtime spelling in `grantiva_context` is MCP-042, placed in C56
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
docs/mcp.md:70 and the tool description (`Sources/GrantivaMCP/Tools/SimTools.swift:14`): "List available iOS
simulators with name, UDID, state, runtime, and availability." Matrix MCP-047: `{filter: "booted"}` and
`{filter: "all"}` list name, UDID, state, runtime, availability. Runtimes read as the CLI prints them elsewhere
(`simulator ensure --json`: `"runtime" : "iOS 26.0"`, IOS-006).

## Actual
MCP-029/with-config/transcript.txt:
```
Name | UDID | State | Runtime
cov-ios-1 | A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF | Booted | iOS-26-0
cov-ios-2 | C2C8E2D3-F7E6-4FBF-A2FE-7A25B9363961 | Booted | iOS-27-0
iPhone 17 Pro | B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C | Booted | iOS-26-0
```
and for `{filter: "all"}`:
```
Name | UDID | State | Runtime
Apple Watch Series 12 (42mm) | 85FE83E3-D690-4DA8-BEEC-210AF5ECE8D5 | Shutdown | watchOS-27-0
…
```
No availability column; runtimes are `iOS-26-0`; and "all" also lists watchOS devices although the tool lists "iOS
simulators" (secondary; decide alongside the column).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"
unset GRANTIVA_API_KEY
rm -rf /tmp/k96 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k96 && cd /tmp/k96/ios   # 4e49dc4
{ printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"fix","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"grantiva_sim_list","arguments":{"filter":"booted"}}}' \
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"grantiva_sim_list","arguments":{"filter":"all"}}}'
  sleep 10; } | grantiva mcp --project-dir "$PWD" | grep -o '"text": "[^"]*' | cut -c1-300
```

## Evidence
- findings/evidence/cov-ios/MCP-029/commands.txt, with-config/transcript.txt, with-config/requests.json
- findings/evidence/cov-ios/IOS-006/ensure-json-new.out, ensure-json-reuse.out (`"runtime" : "iOS 27.0"` / `"iOS 26.0"`)
- findings/evidence/cov-ios/MCP-LIVE1/run/transcript.txt (`grantiva_context`: `runtime: iOS-26-0`, MCP-042)

## Suspected cause
- `Sources/GrantivaMCP/Tools/SimTools.swift:70-101` (`list`): filters to `isAvailable` devices (:77-78), so every row
  is available and the column was never added; prints `device.runtime` (:92), the identifier fragment
  (`SimulatorDevice.runtime`, e.g. `iOS-26-0`); also folds every non-Booted state into `Shutdown` (:91).
- The human runtime name is available through the simctl catalog, as `SimulatorManager.ensure` does
  (`Sources/GrantivaCore/Simulator/SimulatorManager.swift:230`, `catalog.runtimes.first { $0.shortName == … }?.name`).
- The tool lists every platform's devices; nothing filters to iOS runtimes.

## Acceptance criteria
- Re-running the repro: the header is `Name | UDID | State | Runtime | Available` (or docs/mcp.md:70 and the tool
  description drop "availability" and say only available simulators are listed; pick one and make both agree).
- Runtimes print as `iOS 26.0` / `iOS 27.0`; `grantiva_context` uses the same spelling (coordinate with C56).
- `State` shows simctl's state (`Booted`, `Shutdown`, `Booting`, …), not a two-way fold.
- Either only iOS simulators are listed, or the description says all platforms are.
- GrantivaMCPTests (new SimToolsTests or ArgumentValidationTests): with an injected device list including an iOS
  device with runtime `iOS-26-0` and a watchOS device, `list` renders `iOS 26.0` and follows the chosen platform and
  availability rules.
