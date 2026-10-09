# Make `simulator ensure --name` reuse an existing device before inferring a type, report that device's own type and runtime, and say in help and README that a new device needs a model in its name

Severity: contract
Platforms: ios
Found by: IOS-F08, IOS-F04, IOS-F07 (matrix rows IOS-002, IOS-007, IOS-001, IOS-006)
Binary: grantiva 2.0.1 (commit c8dc86d), Xcode 27.0 (iOS 26.0 and 27.0 runtimes installed)

## Expected
"`ensure` needs only `--name`: it ... reuses an existing simulator with that name" (README.md:360-363); help: simulator
ensure "`--name` alone is enough" (Sources/GrantivaCLI/SimulatorCommand.swift:14); SimulatorManager.swift:80-82 calls a
bare-name reuse "purely idempotent". `--json` "emits the full record" of that device (README §stdout is the result).

## Actual
- F08: with qa-ios-1 (created with `--device-type "iPhone 17"`) existing, `ensure --name qa-ios-1` exits 1, stdout empty:
  `Error: Invalid argument: Could not infer a device type from the name "qa-ios-1". Include a device model in the name
  (for example "iPhone 17") or pass --device-type.` So `udid=$(...)` is empty and the next command fails with
  `Simulator not found: ""`.
- F04: help and README promise `--name` alone works; it only works when the name contains a model.
- F07: reusing "QA iPhone 17 Pro" (created on iOS 26.0) with a bare `--json` reports `"runtime" : "iOS 27.0"` (newest
  installed). A strict reuse without `--runtime` is rejected: `exists with incompatible configuration (...
  runtime: iOS-26-0); requested iPhone 17, iOS 27.0`.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
grantiva simulator ensure --name qa-ios-1 --device-type "iPhone 17" --runtime 26.0 --no-boot
grantiva simulator ensure --name qa-ios-1 --no-boot; echo "exit $?"                      # F08: exit 1
grantiva simulator ensure --name "QA iPhone 17 Pro" --runtime 26.0 --no-boot
grantiva simulator ensure --name "QA iPhone 17 Pro" --no-boot --json | grep runtime     # F07: iOS 27.0
grantiva simulator delete --name "QA iPhone 17 Pro"
```

## Evidence
- findings/evidence/triage/F08.err, F08.out (empty), F07.err, F07.json
- findings/evidence/IOS-002/reuse-qapin.err, IOS-007/err.txt, IOS-007/err2.txt, IOS-006/{out.json,out-rt26.json,simctl-runtime.txt}

## Suspected cause
Sources/GrantivaCore/Simulator/SimulatorManager.swift:83-153. Type inference throws at :99-105 before the existing-device
lookup at :129-141; the non-strict reuse returns `existing.udid` at :136, but the result at :152 is built from the
requested/newest `runtime.name` and inferred `type.name`, not `existing.runtime` / `existing.deviceTypeIdentifier`.

## Acceptance criteria
- Re-running the repro: the bare `ensure --name qa-ios-1` reuses the device (exit 0, UDID on stdout); the `--json` reuse
  reports `runtime: iOS 26.0` and the device's real type.
- Look up by name first; infer type/runtime only when creating. A new name without a model still fails with today's
  message. Help (SimulatorCommand.swift:14, regenerate help/simulator_ensure.txt) and README.md:360 say a model in the
  name, or `--device-type`, is required to create, and `--name` alone suffices to reuse.
- GrantivaCoreTests/SimulatorManagerTests: with a fake catalog and an existing "qa-x" device, bare ensure returns its UDID
  and its own runtime/type; a bare ensure of an unknown model-less name throws the inference error.
