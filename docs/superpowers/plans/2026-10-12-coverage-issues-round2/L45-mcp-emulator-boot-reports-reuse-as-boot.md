# MCP `grantiva_emulator_boot` answers "Emulator booted: …" for an AVD that was already running

Severity: ux
Component: mcp
Platforms: android (2 of 2 calls, with and without `name`, load 4.3; logical).
Rows: AND2-OBS-05 [android] (evidence under MCP-059; also noted in MCP-057 [android], pass)
Regresses/extends: extends K12 (#193) and K29 (#189), which made the CLI say `Using`/`Reused` for a running device; this is the MCP twin.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
Like the CLI after K12/K29 (`Using emulator: <avd> (<serial>)` for a running AVD, `Booting AVD <avd> as <serial>` only
when it boots), the tool says whether it booted the AVD or reused a running one, e.g. `Emulator already running:
cov2-android (emulator-5554)` vs `Emulator booted: …`.

## Actual
findings/evidence/cov2-android/MCP-059/mcp-01/transcript.txt:12-15, with `cov2-android` running as emulator-5554
before the calls (answers in 0.1 s, so nothing booted):
```
>> {"method": "tools/call", "params": {"name": "grantiva_emulator_boot", "arguments": {}}, "id": 6, "jsonrpc": "2.0"}
<< [0.1s] {"id": 6, "jsonrpc": "2.0", "result": {"content": [{"text": "Emulator booted: cov2-android (emulator-5554)", "type": "text"}]}}
>> {"method": "tools/call", "params": {"name": "grantiva_emulator_boot", "arguments": {"name": "cov2-android"}}, "id": 7, "jsonrpc": "2.0"}
<< [0.1s] {"id": 7, "jsonrpc": "2.0", "result": {"content": [{"text": "Emulator booted: cov2-android (emulator-5554)", "type": "text"}]}}
```

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l45
unset GRANTIVA_API_KEY
rm -rf /tmp/l45 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l45 && cd /tmp/l45/android
sed -i '' 's/^emulator: .*/emulator: fix-l45/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-l45)        # running now
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"grantiva_emulator_boot","arguments":{"name":"fix-l45"}}}' \
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"grantiva_emulator_boot","arguments":{}}}' \
  | (cat; sleep 15) | grantiva mcp --project-dir /tmp/l45/android | grep -o '"text":"[^"]*"'
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l45
```
(The no-argument call uses the config's `emulator: fix-l45`, `EmulatorTools.swift:100`.)

## Evidence
- findings/evidence/cov2-android/MCP-059/mcp-01/transcript.txt, requests.json, stdout.raw; MCP-059/commands.txt
- findings/evidence/cov2-android/MCP-057/commands.txt (pointer)

## Suspected cause
- `Sources/GrantivaMCP/Tools/EmulatorTools.swift:98-103` (`boot`): calls `deps.boot(name)` and always returns
  `"Emulator booted: \(device.name) (\(device.udid))"` (`:102`).
- `deps.boot` is `platform.bootDevice(named:)` (`:22`), which returns a running match without booting
  (`AndroidPlatform.swift:73-82` for a serial; `EmulatorManager.selectDevice`, `:253-255`, for an AVD name) and boots
  otherwise (`EmulatorManager.boot(avd:)`, `:305-317`). `BootedDevice` (`DevicePlatform.swift:19-27`) does not say
  which happened.
- The CLI avoids this by narrating at the call sites (`RunCommand.swift:134-156`, `bootNarration`) and in
  `EmulatorManager.boot` itself (`Booting AVD … as …`, `:314`); the MCP tool has neither.

## Acceptance criteria
- For a running AVD (by name, by serial, or from the config) the tool text says it was already running (wording to
  match the CLI's `Using emulator: <avd> (<serial>)`), and for a shut-down AVD it says `Emulator booted: …`.
- No extra boot is attempted for the running case; latency stays ~0.1 s.
- docs/mcp.md's tool table/notes give both texts.
- Tests in GrantivaMCPTests/EmulatorToolsTests.swift (next to `testBootFallsBackToTheConfiguredEmulator`, `:35`): with
  fake deps reporting the AVD running, the text says "already running"/"Using"; with deps that boot, it says "booted".
  `EmulatorToolDependencies` gains whatever it needs to tell the two apart (a reuse flag from the platform, or
  `listDevices` + `avdName` as `list` uses at `:89-93`).
