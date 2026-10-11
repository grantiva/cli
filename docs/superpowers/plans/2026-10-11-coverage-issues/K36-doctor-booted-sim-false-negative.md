# `doctor` reports "No simulator booted" when it could not list simulators at all

Severity: wrong-result
Component: cli
Platforms: ios
Rows: CLI-081 (cli)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
When `simctl` cannot be queried (here `DEVELOPER_DIR` points nowhere), the Booted Simulator check says the simulator
list could not be read and why, rather than claiming none is booted. Matrix CLI-081 (README:330) covers the Xcode
half, which passes; this is the adjacent check's statement in the same run. The MCP context tool already makes the
distinction (Sources/GrantivaMCP/Tools/ContextTool.swift:109-113, "Could not list simulators: ...").

## Actual
`DEVELOPER_DIR=/nonexistent grantiva doctor` in an iOS project while simulator `cov-flows-ios` was booted
(findings/evidence/cov-cli/CLI-081/text.out), exit 1:
```
    ✗ Xcode             /nonexistent does not exist
    ✗ Xcode Version     Could not determine Xcode version
    ● Booted Simulator  No simulator booted
                          Run: grantiva simulator ensure --name "iPhone 17 Pro"
```
A false statement, and a fix line that cannot work with the same broken `DEVELOPER_DIR`. The suggested name is the
fallback because the newest-iPhone lookup failed for the same reason (see K37).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k36
rm -rf /tmp/k36 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k36 && cd /tmp/k36/ios
UDID=$(grantiva simulator ensure --name "fix-k36 iPhone 17"); echo "$UDID"     # booted
DEVELOPER_DIR=/nonexistent grantiva doctor; echo "exit $?"
DEVELOPER_DIR=/nonexistent grantiva doctor --json | jq '.[] | select(.name == "Booted Simulator")'
grantiva simulator teardown --session-id fix-k36     # deletes the Grantiva-created simulator
```
Today: `No simulator booted` with `Run: grantiva simulator ensure --name "iPhone 17 Pro"` while `$UDID` is booted.

## Evidence
- findings/evidence/cov-cli/CLI-081/commands.txt, text.out, json.out

## Suspected cause
- Sources/GrantivaCore/Doctor/DoctorRunner.swift:87-98 (`checkBootedSimulator`): `catch` turns every error from
  `SimulatorManager.live.bootedDevice()` into `noBootedSimulatorCheck`, but `bootedDevice()`
  (Sources/GrantivaCore/Simulator/SimulatorManager.swift:42-48) throws both when `listDevices()` fails and, as
  `GrantivaError.simulatorNotRunning`, when nothing is booted.
- DoctorRunner.swift:101-107: the fallback name `"iPhone 17 Pro"` is used when `newestIPhone()` also fails.

## Acceptance criteria
- Re-running the repro: the Booted Simulator check reads like `Could not list simulators: <reason>` (status warning or
  error, fix line pointing at the Xcode check / `DEVELOPER_DIR`), never `No simulator booted`.
- With a working toolchain and nothing booted, the check is unchanged (`No simulator booted` with the ensure fix line).
- GrantivaCoreTests/DoctorTests: `checkBootedSimulator` with an injected list that throws gives the "could not list"
  check; with an empty list gives "No simulator booted" (inject the simulator manager rather than `.live`).
