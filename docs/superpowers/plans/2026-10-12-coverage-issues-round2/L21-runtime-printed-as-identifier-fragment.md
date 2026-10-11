# doctor and the `simulator ensure` reuse refusal print runtimes and device types as raw simctl identifiers (`iOS-26-0`, `com.apple.CoreSimulator.SimDeviceType.iPhone-17`)

Severity: ux
Component: cli
Platforms: ios (iOS-only: simulator runtimes)
Rows: EXTRA-05 [cli], N2-03 [ios]
Regresses/extends: K96 (MCP sim list availability and runtime), fixed by CLI #195 for `grantiva_sim_list` and `grantiva_context`. Incomplete: doctor and the ensure refusal were not converted.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
One runtime spelling wherever Grantiva shows a runtime: `iOS 26.0`, as `grantiva_sim_list`, `grantiva_context`,
`grantiva_sim_boot` and `simulator ensure --json` (`"runtime" : "iOS 27.0"`) print it after K96. Device types are shown
by name (`iPhone 17`), as `ensure --json`'s `deviceType` does.

## Actual
doctor's Booted Simulator check (findings/evidence/cov2-cli/CLI-011/doctor_json.out; text form in
findings/evidence/cov2-ios/B-C21.1/doctor.out:9):
```
    "message" : "cov2-ios-1 — iOS-26-0",
    "name" : "Booted Simulator",
    ✓ Booted Simulator  cov2-ios-1 — iOS-26-0
```
`simulator ensure --name cov2-ios-3 --runtime 27.0` on an existing 26.0 device (findings/evidence/cov2-ios/N2-03/reuse-27.err).
The behaviour is right (refused). The text mixes raw identifiers with the user's form:
```
Error: Invalid argument: Simulator "cov2-ios-3" exists with incompatible configuration (device type: com.apple.CoreSimulator.SimDeviceType.iPhone-17, runtime: iOS-26-0); requested iOS 27.0
```
Deterministic. Seen in every doctor run with a booted simulator, and in the 1 refusal run.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l21
unset GRANTIVA_API_KEY
rm -rf /tmp/l21 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l21 && cd /tmp/l21/ios
grantiva simulator ensure --name fix-l21 --device-type "iPhone 17" --runtime 26.0
grantiva doctor | grep 'Booted Simulator'                       # bug: "… — iOS-26-0"
grantiva simulator ensure --name fix-l21 --runtime 27.0         # bug: "device type: com.apple.CoreSimulator.SimDeviceType.iPhone-17, runtime: iOS-26-0"
grantiva simulator teardown --session-id fix-l21; grantiva simulator delete --name fix-l21
```
(The 27.0 refusal needs an installed iOS 27.0 runtime. Any runtime other than the device's shows the same text.)

## Evidence
- findings/evidence/cov2-cli/CLI-011/doctor_json.out; findings/evidence/cov2-ios/B-C21.1/doctor.out
- findings/evidence/cov2-ios/N2-03/reuse-27.err, commands.txt; create-26.out and reuse-ios26.out (the passing halves)
- findings/evidence/cov2-cli/B2-K96/ (the MCP spelling for comparison)
- docs/superpowers/plans/2026-10-11-coverage-issues/K96-mcp-sim-list-availability-runtime.md

## Suspected cause
- `Sources/GrantivaCore/Doctor/DoctorRunner.swift:111`: `message: "\(device.name) — \(device.runtime)"`.
  `SimulatorDevice.runtime` is simctl's identifier tail (`iOS-26-0`).
- `Sources/GrantivaCore/Simulator/SimulatorManager.swift:204`: the refusal interpolates `existing.deviceTypeIdentifier`
  and `existing.runtime`. The same function already maps both to names for its result at `:245-247`
  (`catalog.deviceTypes.first { $0.identifier == … }?.name`, `catalog.runtimes.first { $0.shortName == … }?.name`).
- The K96 formatter lives in the MCP module (`SimTools.runtimeName`, `Sources/GrantivaMCP/Tools/SimTools.swift:98-102`),
  so GrantivaCore cannot reach it. Move one formatter into GrantivaCore (on `SimulatorDevice` or next to `SimctlCatalog`)
  and use it in all five places (`DoctorRunner.swift:111`, `SimulatorManager.swift:204`, `ContextTool.swift:105`,
  `SimTools.swift:91,114`).

## Acceptance criteria
- doctor prints `cov2-ios-1 — iOS 26.0` (text and `--json` `message`).
- The ensure refusal reads `Simulator "<name>" exists with incompatible configuration (device type: iPhone 17, runtime:
  iOS 26.0); requested iOS 27.0`. It falls back to the identifier only when the catalog has no name for it.
- `grep -rn '\.runtime)' Sources/` finds no user-facing interpolation of the raw identifier.
- Tests: GrantivaCoreTests/DoctorTests, a booted device with runtime `iOS-26-0` yields message `<name> — iOS 26.0`.
  GrantivaCoreTests/SimulatorManagerTests (next to the existing incompatible-configuration test at :353), the error text
  equals the expected sentence with names, not identifiers.
