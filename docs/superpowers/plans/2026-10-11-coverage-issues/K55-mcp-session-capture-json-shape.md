# Live-session `grantiva_vrt_capture` on Android omits the `emulator` object that `diff capture --json` has

Severity: contract
Component: mcp
Platforms: android (Android-only (iOS twins X-022 (ios) and IOS-113 passed; `simulator` is the right key there))
Rows: MCP-064, X-022 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
docs/mcp.md (the `grantiva_vrt_capture` row): with a live runner session the tool "returns the same JSON as `diff
capture --json`". On Android that JSON has `directory, duration, emulator, screens, simulator`.

## Actual
`diff capture --device emulator-5554 --no-build --json` (findings/evidence/cov-android/AND-108/02.out) keys:
`['directory', 'duration', 'emulator', 'screens', 'simulator']`. Live-session `grantiva_vrt_capture {}` after `runner
start --detach --device emulator-5554` (findings/evidence/cov-android/MCP-064/mcp-01/capture.json, result text parsed):
```
['directory', 'duration', 'screens', 'simulator']
{'display_scale': 2.625, 'name': 'cov-android', 'pixel_dimensions': {'height': 2400, 'width': 1080}, 'point_dimensions': {'height': 914, 'width': 411}, 'udid': 'emulator-5554'}
```
Without a session the tool shells out to `diff capture` and does include `emulator` (X-022, MCP-066). Separately, the
live-session step `duration`s are real while the CLI's are all 0; that is the CLI's defect (cluster C17).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k55
rm -rf /tmp/k55 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k55 && cd /tmp/k55/android
SERIAL=$(grantiva emulator ensure --name qa-fix-k55 | tail -1)
grantiva build install --device "$SERIAL"
grantiva diff capture --device "$SERIAL" --no-build --json | jq -c 'keys'
grantiva runner start --detach --device "$SERIAL"
{ echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}}}'
  sleep 300; } | grantiva mcp --platform android | grep '"id":1' | jq -r '.result.content[0].text' | jq -c 'keys'
grantiva runner stop; grantiva emulator teardown --serial "$SERIAL"
```

## Evidence
- findings/evidence/cov-android/MCP-064/commands.txt, mcp-01/requests.json, mcp-01/capture.json
- findings/evidence/cov-android/AND-108/commands.txt, 02.out (CLI JSON)
- findings/evidence/cov-android/X-022/commands.txt (points at MCP-064 and MCP-066)

## Suspected cause
- Sources/GrantivaMCP/Tools/SessionCapture.swift:120-122: `CaptureResult(screens:directory:duration:simulator: target)`
  never passes `emulator:`.
- Sources/GrantivaCLI/DiffCommand.swift:194: the CLI passes `emulator: platform == .android ? target : nil`.

## Acceptance criteria
- Re-running the repro: both `keys` lines print `["directory","duration","emulator","screens","simulator"]`, and the
  `emulator` object equals `simulator` as in the CLI output.
- iOS live-session capture JSON is unchanged (no `emulator` key).
- One shared constructor builds `CaptureResult` for the CLI and the session path so the shapes cannot drift.
- GrantivaMCPTests/VRTToolsTests (session capture with a fake driver, Android): the decoded result has `emulator`;
  iOS: it has none.
