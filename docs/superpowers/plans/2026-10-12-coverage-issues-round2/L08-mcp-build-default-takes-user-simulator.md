# MCP `grantiva_build {scheme}` with no simulator and no config boots a simulator the user created and records it as a Grantiva slot

Severity: wrong-result
Component: mcp
Platforms: ios (iOS-only: the default simulator name; Android `grantiva_build` boots nothing since K54)
Rows: B2-K37.2 [ios] (seen through MCP-031 [ios], graded pass there with a slip note)
Regresses/extends: K37 (default simulator name), fixed by CLI #190. The fix gave `init` a provenance warning; MCP has none.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
K37 criteria 2 and 3: the shared default (`DefaultSimulator.name`, the newest installed iPhone type) must not silently
take over a simulator the user created for something else. MCP `grantiva_build {scheme}` in a directory with no
`grantiva.yml` uses that default. If no Grantiva-created simulator of that name exists, the tool creates one, or returns
an `isError` result that names the default and how to override it (`simulator` argument, `simulator:` in grantiva.yml).
It never boots a user's simulator and never records one as a Grantiva-booted slot of the caller's session.

## Actual
One `grantiva mcp --project-dir <empty dir>` server on a host whose newest iPhone type is iPhone 18 Pro, and where the
user owns a Shutdown simulator called `iPhone 18 Pro` (FE441EE5…) that Grantiva did not create. The call took 15.0 s,
booted the user's simulator, and reported success without naming the destination
(findings/evidence/cov2-ios/MCP-031/empty-dir/transcript.txt):
```
>> {"method": "tools/call", "params": {"name": "grantiva_build", "arguments": {"scheme": "Landmarks (UI Testing)"}}, "id": 4, "jsonrpc": "2.0"}
<< [15.0s @11:34:05] {"id": 4, "jsonrpc": "2.0", "result": {"content": [{"text": "Build succeeded\nScheme: Landmarks (UI Testing)\nDuration: 7.9s\nWarnings: 117\nErrors: 0\nProduct: /Users/kyle/Library/Developer/Xcode/DerivedData/...
```
`simulator sessions --json` afterwards (findings/evidence/cov2-ios/B2-K37.2/sessions-record.out) lists the user's device
as an ephemeral, Grantiva-booted slot of session cov2-ios. A later `simulator teardown --session-id cov2-ios` would shut it
down:
```
    "acquiredAt" : "2026-10-11T18:33:50Z",
    "bootedByGrantiva" : true,
    "ephemeral" : true,
    "name" : "iPhone 18 Pro",
    "sessionId" : "cov2-ios",
    "udid" : "FE441EE5-BBFC-4981-B68A-59C0DBCE26D6"
```
In the same server, `grantiva_context` (id 2) reported `[Simulator] cov2-ios-1 … source: first booted simulator`. Context
and build therefore disagree on which simulator a sessionless call targets (see L17 aside). Seen once. The device has not
been touched since. CLI `init` warns about this same device (B2-K37.1 [cli] pass, CLI-153 blocked on it).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l08
unset GRANTIVA_API_KEY
rm -rf /tmp/l08 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l08
mkdir -p /tmp/l08/empty && cp -c -R /tmp/l08/ios/Landmarks /tmp/l08/ios/Landmarks.xcodeproj /tmp/l08/empty/
# A simulator the user owns, named like the default (newest installed iPhone type), created outside Grantiva:
DEFAULT=$(xcrun simctl list devicetypes | grep -E '^iPhone' | tail -1 | sed 's/ (.*//')
USER_UDID=$(xcrun simctl create "$DEFAULT" "$DEFAULT")
cd /tmp/l08/empty && grantiva mcp --project-dir /tmp/l08/empty <<'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"l08","version":"1"}}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"grantiva_build","arguments":{"scheme":"Landmarks (UI Testing)"}}}
EOF
xcrun simctl list devices | grep "$USER_UDID"     # bug: Booted
grantiva simulator sessions --json                 # bug: lists $USER_UDID, bootedByGrantiva true, sessionId fix-l08
xcrun simctl shutdown "$USER_UDID"; xcrun simctl delete "$USER_UDID"
```
Keep stdin open until id 2 is answered (the build takes about 15 s), for example with a client like
`findings/evidence/cov2-ios/inputs/mcp/client.py`. Do not run this on a host where a simulator of the default name holds
data you need.

## Evidence
- findings/evidence/cov2-ios/MCP-031/empty-dir/transcript.txt (ids 2 and 4), requests.json, server.stderr
- findings/evidence/cov2-ios/B2-K37.2/sessions-record.out, commands.txt, schema_defaults.txt
- findings/evidence/cov2-ios/MCP-031/commands.txt (load 27.18)
- docs/superpowers/plans/2026-10-11-coverage-issues/K37-default-simulator-name.md

## Suspected cause
- `Sources/GrantivaMCP/Tools/BuildTools.swift:105-107` (`resolvedProject`): `simulator: arguments["simulator"] ??
  config?.simulator ?? DefaultSimulator.name`. `build` (`:142`, boot at `:160`) and `run` (`:183`, boot at `:201`) call
  `device.bootDevice(named:)` with that name. `test` repeats the fallback at `:279` and boots at `:280`.
- `Sources/GrantivaCore/Platform/IOSPlatform.swift:27` boots with `simulators.boot(nameOrUDID:, ephemeral: true)`.
  `SimulatorManager.boot` (`Sources/GrantivaCore/Simulator/SimulatorManager.swift:111-133`) reserves a capacity slot,
  runs `simctl boot`, and calls `capacity.activate(udid:, bootedByGrantiva: !current.isBooted)`. Nothing checks
  provenance. Provenance is only read in `ensure`/`delete`/`cleanup` (`SimulatorManager.swift:195-383`).
- The only "not created by Grantiva" check is `InitCommand.existingSimulatorWarning`
  (`Sources/GrantivaCLI/InitCommand.swift:169-177`, called at `:63-65` with `SimulatorProvenance.live.all()`).
- `DefaultSimulator.name` (`Sources/GrantivaCore/Simulator/DefaultSimulator.swift:20`) is the newest stock iPhone type
  name, the name a developer most likely already uses.
- The CLI has the same fallback without a check: `Sources/GrantivaCore/Config/ProjectResolver.swift:133` (`run`,
  `diff capture`, `build`) and `Sources/GrantivaCLI/DriverCommand.swift:254` (`runner start`). Those paths were not
  exercised in round 2 (the slices always named a device). Fix them in the same change.

## Acceptance criteria
- When the default name is used (no `simulator` argument, flag or config), a simulator of that name that is not in the
  provenance ledger is never booted or slotted. The MCP build/run/test tools return `isError` naming it, for example
  `Error: Invalid argument: "iPhone 18 Pro" (FE441EE5-…) was not created by Grantiva. Pass 'simulator' or set
  simulator: in grantiva.yml (create one with grantiva simulator ensure --name "Grantiva iPhone 18 Pro").` An
  alternative is to create and use a Grantiva-owned simulator instead.
- A simulator the user names explicitly (argument, flag or config) is still used as today.
- `simulator sessions --json` never lists a device with `bootedByGrantiva: true` that was Booted or user-created before
  the call.
- The CLI `run`/`diff capture`/`runner start` default path follows the same rule, or gives the same warning.
- `grantiva_build` names its destination simulator in its result text (`Simulator: <name> (<udid>)`), as
  `grantiva_run` does.
- Tests: GrantivaMCPTests/BuildToolsTests, a scripted simctl that lists a user-created `<default>` simulator and an empty
  provenance ledger: `grantiva_build {scheme}` returns `isError` and runs no `simctl boot`. Also a ledger-registered
  simulator of the default name is booted. GrantivaCoreTests (ProjectResolutionTests or SimulatorManagerTests): the
  default-name path refuses an unregistered device.
