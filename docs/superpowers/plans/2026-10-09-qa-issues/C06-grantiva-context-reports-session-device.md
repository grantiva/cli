# Report the session's device in grantiva_context

Severity: wrong-result
Platforms: cli, ios, android
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

## Android detail (AND-F17)
With emulator-5554 and emulator-5556 running and a live `runner start` session on emulator-5554, `grantiva_context`
says no emulator is running while its own session block names one:
```
[Config]
  platform: android
  ...
  emulator: Pixel_8_API_35
[Emulator]
  No emulator running.
...
[Runner Session]
  pid: 55825
  application_id: com.kylebrowning.landmarks
  udid: emulator-5554
```
Repro (needs a second emulator; with one emulator the section is right):
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=qa-android
cd /Users/kyle/Developer/landmarks-demo/android
grantiva emulator ensure --name qa-android-1            # second emulator, emulator-5556
grantiva runner start --device emulator-5554 --detach
grantiva mcp                                            # tools/call grantiva_context {}
```
Evidence (qa-android worktree): findings/evidence/AND-093/session1.log, AND-105/with-platform.log.
Cause: Sources/GrantivaMCP/Tools/ContextTool.swift:69 calls `device.defaultDevice()` =
`selectDevice(configured: nil)` (Sources/GrantivaCore/Android/AndroidPlatform.swift:87-88), which throws "Several
emulators are running" for more than one; `try?` turns that into "No emulator running". It ignores both the config's
`emulator:` and the session's serial.
Extra acceptance criterion: on Android, `[Emulator]` shows the session's serial when a session exists, else the
configured AVD's serial if running, else lists the running serials; an error from device selection is never reported as
"No emulator running". ContextToolTests: a fake Android platform with two devices and a session on the first.

## iOS detail (IOS-F32)
With config `simulator: qa-ios-1` and a runner session on qa-ios-2, `[Simulator]` names the user's iPhone 17 Pro, the
first booted device, which is neither:
```
[Config]
  platform: ios
  simulator: qa-ios-1
[Simulator]
  name: iPhone 17 Pro
  udid: B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C
...
[Runner Session]
  pid: 84412
  wda_port: 8607
  udid: 4DAB1D26-5107-4B17-9093-AC2E19DE0403
```
In the triage re-run `[Runner Session]` said "No active session." although `grantiva_tap` acted on the live qa-ios-2
keep-alive session (C03's machine-wide fallback).
Repro (needs another simulator booted first):
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios QA=/Users/kyle/Developer/grantiva-cli/.worktrees/qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
grantiva simulator ensure --name "QA iPhone 17 Pro" --runtime 26.0
grantiva simulator ensure --name qa-ios-2 --device-type "iPhone 17" --runtime 26.0 && grantiva build install --simulator qa-ios-2
grantiva run --no-build --flow .maestro/01-browse.yaml --simulator qa-ios-2 --keep-alive --ready-file /tmp/c06.ready &
while [ ! -f /tmp/c06.ready ]; do sleep 0.2; done
python3 $QA/findings/evidence/IOS-mcp/client.py $QA/findings/evidence/IOS-mcp/phase1.json /tmp/c06 /tmp/qa-ios-app -- grantiva mcp
grep -o '\[Simulator\][^\[]*' /tmp/c06/transcript.txt | head -1; kill -INT %1
```
Evidence (qa-ios worktree): findings/evidence/IOS-mcp/phase1/transcript.txt (id 3).
Extra acceptance criterion: on iOS, with no session, `[Simulator]` shows the configured `simulator:` device (or says it
is not booted) rather than the first booted one; with a session, `[Runner Session]` is reported whenever the UI tools
would use it, so the two sections never disagree.
