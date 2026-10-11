# MCP `grantiva_run {scheme}` in a directory without grantiva.yml fails with `no bundle_id in grantiva.yml` instead of using the built app's bundle ID

Severity: wrong-result
Component: mcp
Platforms: ios (iOS-only: the Android path reads the application ID from the build)
Rows: MCP-036 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
docs/mcp.md:26-27: "A `scheme` (iOS) or `module` (Android) argument stands in for the file for `grantiva_build` and
`grantiva_run`." Matrix MCP-036: in a directory without config, `grantiva_run {scheme: "Landmarks (UI Testing)"}`
builds, installs and launches the app. The bundle ID can come from the built product (the CLI's `run` already reads
it from a binary's Info.plist, README:174).

## Actual
MCP-031/empty-dir/transcript.txt, `grantiva_run {scheme: "Landmarks (UI Testing)"}` (and with
`simulator: cov-ios-1`):
```
{"content": [{"text": "Error: no bundle_id in grantiva.yml. Cannot launch app.", "type": "text"}], "isError": true}
```
It fails before building, and names a grantiva.yml that does not exist in that directory. In the same directory
`grantiva_build {scheme: "Landmarks (UI Testing)"}` succeeds (`Build succeeded … Product: …/Landmarks.app`), so the
scheme argument does stand in for the file for building, just not for `grantiva_run`.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k95
unset GRANTIVA_API_KEY
rm -rf /tmp/k95 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k95 && cd /tmp/k95/ios   # 4e49dc4
rm grantiva.yml
UDID=$(grantiva simulator ensure --name "fix-k95 iPhone 17" --runtime 26.0)
{ printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"fix","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"grantiva_run\",\"arguments\":{\"scheme\":\"Landmarks (UI Testing)\",\"simulator\":\"$UDID\"}}}"
  sleep 300; } | grantiva mcp --project-dir "$PWD" | grep -o '"text": "[^"]*'
grantiva simulator teardown --session-id fix-k95
```
Today: `Error: no bundle_id in grantiva.yml. Cannot launch app.` within a second.

## Evidence
- findings/evidence/cov-ios/MCP-031/commands.txt, empty-dir/transcript.txt, empty-dir/requests.json

## Suspected cause
`Sources/GrantivaMCP/Tools/BuildTools.swift:197-199` (`run`): on iOS, `resolved.bundleId == nil` (no config) returns
the error before building. The later choice at :215-217 (`resolved.bundleId ?? buildResult.applicationId`) would fall
back to the build, but on iOS `XcodeBuildRunner` does not fill `applicationId`, so moving the check alone is not
enough: the product's `Info.plist` (`CFBundleIdentifier`) must be read (AppBinaryResolver already does this for
`--app-file`).

## Acceptance criteria
- Re-running the repro: the app is built, installed and launched; the result is
  `App built and launched. Scheme: Landmarks (UI Testing) Bundle ID: com.kylebrowning.Landmarks Simulator: …`.
- If no bundle ID can be found anywhere (no config, no argument, unreadable product), the error names where it looked
  and does not mention a grantiva.yml that is absent, for example
  `No bundle ID: no grantiva.yml in <dir> and the built app has no CFBundleIdentifier.`
- With grantiva.yml present, `bundle_id` from it still wins.
- GrantivaMCPTests/BuildToolsTests: `run` with no config, a `scheme` argument and a stub build whose product
  Info.plist says `com.example.App` launches `com.example.App`.
