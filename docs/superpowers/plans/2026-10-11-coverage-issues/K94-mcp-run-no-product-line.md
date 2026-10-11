# MCP `grantiva_run` result has no `Product:` line with the app path, unlike `grantiva_build`

Severity: contract
Component: mcp
Platforms: ios (seen on iOS; the Android `grantiva_run` text has no product path either)
Rows: MCP-034, IOS-111 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

Triage note: likely a matrix error. docs/mcp.md:62 describes `grantiva_run` only as "Build, install, and launch the
app on the simulator or emulator" and promises no `Product:` line (docs/mcp.md:61 does not promise one for
`grantiva_build` either, though it prints one). If the orchestrator agrees, correct MCP-034/IOS-111 to expect the
build/install/launch summary and close this brief; otherwise implement the criteria below.

## Expected
Matrix MCP-034 and IOS-111 (citing docs/mcp.md:61-62): `grantiva_run` builds, installs and launches, and its result
carries a `Product:` line with the app path, as `grantiva_build` does.

## Actual
MCP-029/with-config/transcript.txt: `grantiva_build {scheme: "Landmarks (UI Testing)"}` returns
`Build succeeded … Product: …/Landmarks.app`, but `grantiva_run {}` and `grantiva_run {scheme: …}` return:
```
App built and launched.
Scheme: Landmarks (UI Testing)
Bundle ID: com.kylebrowning.Landmarks
Simulator: cov-ios-1
```
The app is built, installed and launched (the behaviour the docs promise is there).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k94
unset GRANTIVA_API_KEY
rm -rf /tmp/k94 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k94 && cd /tmp/k94/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k94 iPhone 17" --runtime 26.0)
sed -i '' "s/^simulator:.*/simulator: $UDID/" grantiva.yml
{ printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"fix","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"grantiva_build","arguments":{}}}' \
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"grantiva_run","arguments":{}}}'
  sleep 300; } | grantiva mcp --project-dir "$PWD" | grep -o '"text": "[^"]*' | cut -c1-300
grantiva simulator teardown --session-id fix-k94
```
(Interrupt the pipeline once id 3 has answered.)

## Evidence
- findings/evidence/cov-ios/MCP-029/commands.txt, with-config/transcript.txt, with-config/requests.json

## Suspected cause
Not a code defect if the docs are the contract. `Sources/GrantivaMCP/Tools/BuildTools.swift:172-174` appends
`Product:` only in `build`; `run` (:181-233) builds through the same `device.build` (:202-204), has
`buildResult.productPath`, and writes a fixed summary (:225-231) without it.

## Acceptance criteria
- Either: matrix rows MCP-034 and IOS-111 are corrected to expect the summary without `Product:` (no code change).
- Or: `grantiva_run` (iOS and Android) appends `Product: <path>` when the build produced one; docs/mcp.md:62 says the
  result includes the product path; GrantivaMCPTests/BuildToolsTests asserts the line for a stub build result with
  `productPath`.
