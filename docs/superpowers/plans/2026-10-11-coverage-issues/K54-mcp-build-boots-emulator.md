# MCP `grantiva_build` on Android boots the configured emulator; `grantiva build build` does not

Severity: wrong-result
Component: mcp
Platforms: android (Android-only: on iOS both the CLI and the tool build for a booted simulator destination by design)
Rows: N-02 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
`grantiva_build {}` on Android compiles only, like `grantiva build build`, which "only compiles: the config's
`emulator:` is irrelevant and nothing is booted" (Sources/GrantivaCLI/BuildCommand.swift:46-48; AND-111 passed:
`adb devices` empty before and after). docs/mcp.md describes `grantiva_build` as the build step; booting is
`grantiva_emulator_boot`'s job.

## Actual
With `cov-android` shut down, `grantiva_build {}` took 24.4 s and booted it (findings/evidence/cov-android/N-02/mcp-01/server.stderr):
```
Booting AVD cov-android as emulator-5554
```
`adb devices` then lists `emulator-5554` (N-02/01.out).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k54
rm -rf /tmp/k54 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k54 && cd /tmp/k54/android
grantiva emulator ensure --name qa-fix-k54 --no-boot
sed -i '' 's/^emulator: .*/emulator: qa-fix-k54/' grantiva-android.yml
adb devices
{ echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_build","arguments":{}}}'
  sleep 240; } | grantiva mcp --platform android
adb devices                       # today: the qa-fix-k54 emulator is running
grantiva build build; adb devices # control: CLI boots nothing (stop the emulator first)
```
Cleanup: `grantiva emulator teardown --serial <serial>` and `grantiva emulator delete --name qa-fix-k54`.

## Evidence
- findings/evidence/cov-android/N-02/commands.txt, 01.out, mcp-01/ (server.stderr has the boot line)
- findings/evidence/cov-android/AND-111/commands.txt (CLI control: nothing booted)

## Suspected cause
- Sources/GrantivaMCP/Tools/BuildTools.swift:158: `let booted = try await device.bootDevice(named: resolved.simulator)`
  runs for both platforms; on Android `resolved.simulator` is the config's emulator (BuildTools.swift:118-121).
- Sources/GrantivaCLI/BuildCommand.swift:46-60: the CLI switches on platform and, on Android, only attaches to an
  explicit `--device` for its ABI.

## Acceptance criteria
- Re-running the repro: `grantiva_build {}` builds without booting; `adb devices` is unchanged; the result names module
  and variant as today.
- `grantiva_build {device: <running serial>}` (if the tool gains or has such an argument) uses that device's ABI like
  the CLI's `--device`; otherwise only compiles.
- `grantiva_run` still boots (it installs and launches).
- GrantivaMCPTests/BuildToolsTests: Android `build` with a fake device platform records no `bootDevice` call; iOS
  `build` still boots its simulator.
