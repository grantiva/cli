# Honour grantiva.yml `simulator:` in `diff capture --no-build` and in MCP `grantiva_vrt_capture`, never falling back to the first booted device

Severity: wrong-result
Platforms: ios
Found by: IOS-F27 (matrix rows IOS-090, IOS-113)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7, Xcode 27.0, qa-ios-1 (iPhone 17, iOS 26.0)

## Expected
With grantiva.yml `simulator: qa-ios-1` and no `--simulator`, capture drives qa-ios-1. Source: README §Configuration
(`simulator:`); VRTTools.swift:15 ("Equivalent to 'grantiva diff capture --no-build --json'").

## Actual
`diff capture --no-build --json` in the app dir attached to the user's iPhone 17 Pro (B27D7D31), the first booted
simulator, which the campaign must not touch, and tried to launch an app that is not installed there:
```
  [1/1] flow (/var/folders/.../grantiva-flows-95902BFB-.../flow.yaml) - Device: iPhone 17 Pro (ios 26.0 Simulator)
      ╰─ Failed to create session for app: com.kylebrowning.Landmarks — ... returned nil for "com.kylebrowning.Landmarks" ...
Error: Runner failed (exit 1):
```
With `--simulator qa-ios-1` it works. MCP `grantiva_vrt_capture` shells out to exactly this command, so agents hit the
same wrong device.

## Repro
Needs a second simulator booted before qa-ios-1 (use a throwaway `QA iPhone 17 Pro`, not a personal device):
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
grantiva simulator ensure --name "QA iPhone 17 Pro" --runtime 26.0
grantiva simulator ensure --name qa-ios-1 --device-type "iPhone 17" --runtime 26.0
grantiva build install --simulator qa-ios-1
grantiva diff capture --no-build --json 2>&1 | grep -E "Device:|^Error"
```
`Device:` names the other simulator.

## Evidence
- findings/evidence/IOS-F-diffsim/{err.txt,NOTE.txt,out.json} (line 30 `Device: iPhone 17 Pro`)

## Suspected cause
Sources/GrantivaCLI/DiffCommand.swift:124-128: under `--no-build` it uses
`target.simulator ?? target.device ?? target.emulator`, else `device.defaultDevice()` (IOSPlatform.swift:91-94 →
`simulators.bootedDevice()`, the first booted device). It never reads `resolved.simulator`, which the build path uses at
:74. Sources/GrantivaMCP/Tools/VRTTools.swift:56 passes no `--simulator` either.

## Acceptance criteria
- Re-running the repro: `Device: qa-ios-1`, capture succeeds; the other simulator is untouched.
- `--no-build` resolves the device as flag > config `simulator:` > the runner session's UDID > (only if exactly one
  simulator is booted) that one; with several booted and nothing configured it fails naming them.
- MCP `grantiva_vrt_capture` targets the same device (config or session UDID).
- GrantivaCLITests/DiffCommandTests: with a fake platform reporting two booted devices and config `simulator: B`, the
  `--no-build` path boots/uses B, not the first.
