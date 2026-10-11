# `grantiva_context` presents a config synthesized from `.maestro/` as if a grantiva.yml existed

Severity: ux (re-graded from wrong-result: the `.maestro/` fallback is documented behaviour; the defect is that the context does not say where the config came from)
Component: mcp
Platforms: ios (`grantiva mcp --platform ios`)
Rows: AND-OBS-10 (android slice)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9
Triage note: README:158 ("Place your flows in a `.maestro/` directory, or write `grantiva.yml` in Maestro format") makes `.maestro/` a valid iOS config source without grantiva.yml, and the "first booted simulator" in `[Simulator]` is labelled as such. The fix is presentation, plus not using another platform's project as an iOS config.

## Expected
`grantiva mcp --platform ios` in a directory with only `grantiva-android.yml` and a Gradle project reports that there is
no `grantiva.yml` (ContextTool's own text: `No grantiva.yml found in current directory.`), or, when it does derive a
config from `.maestro/`, says so (`source: .maestro/ (no grantiva.yml)`), so an agent does not believe a grantiva.yml
exists with an Android app ID as its iOS bundle ID.

## Actual
landmarks-demo/android with `--platform ios` (findings/evidence/cov-android/MCP-079/mcp-02/transcript.txt):
```
[Config]
  platform: ios
  bundle_id: com.kylebrowning.landmarks
  screens: 18

[Simulator]
  name: cov-ios-1
  ...
  source: first booted simulator (no runner session, no simulator in grantiva.yml)
```
`com.kylebrowning.landmarks` is the Android application ID (the iOS app is `com.kylebrowning.Landmarks`), read from
the Android `.maestro/` flows' `appId:` headers; `cov-ios-1` belonged to another process (the iOS slice).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=fix-k58
rm -rf /tmp/k58 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k58 && cd /tmp/k58/android
{ echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_context","arguments":{}}}'
  sleep 5; } | grantiva mcp --platform ios | grep '"id":1' | jq -r '.result.content[0].text'
```
Read-only; it lists simulators but changes none.

## Evidence
- findings/evidence/cov-android/AND-OBS-10/commands.txt (points at MCP-079/mcp-02)
- findings/evidence/cov-android/MCP-079/commands.txt, mcp-02/transcript.txt

## Suspected cause
- Sources/GrantivaCore/Config/GrantivaConfig.swift:281-287 (`loadIfPresent`): for iOS without grantiva.yml it loads
  `.maestro/` through `MaestroFlowParser.loadDirectory` regardless of what else is in the directory (here a Gradle
  project and `grantiva-android.yml`).
- Sources/GrantivaMCP/Tools/ContextTool.swift:35-56: prints `[Config]` identically for a file-backed and a
  `.maestro/`-derived config; `GrantivaConfig` carries no source.
- ContextTool.swift:126-128: the "first booted simulator" fallback is labelled; no change needed there beyond keeping
  the label.

## Acceptance criteria
- Re-running the repro: `[Config]` says `source: .maestro/ (no grantiva.yml)` (or reports no grantiva.yml), and the
  iOS `bundle_id` is not taken from flows of a directory whose only config is `grantiva-android.yml`; either skip the
  `.maestro/` fallback when the directory resolves to Android-only (PlatformResolver detects only Gradle), or label the
  value as read from the flows' `appId:`.
- An iOS project with only `.maestro/` keeps working (README:158) and its context names the source.
- GrantivaMCPTests/ContextToolTests: a `.maestro/`-derived config renders a source line; GrantivaCoreTests/
  GrantivaConfigPlatformTests: the chosen rule for an Android-only directory with `--platform ios`.
