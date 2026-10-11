# `run --device <serial>` announces "Booting emulator" for a device that is already running, and tries an unknown serial as an AVD name

Severity: ux
Component: cli
Platforms: android (Android-only)
Rows: AND-OBS-05 (android); EXTRA-05 (cli)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
docs/android.md:36-37: "`--device <serial>` targets any attached device, including a physical one", while
`emulator:`/`--emulator` names an AVD that is "used if running, booted otherwise". So:
- `--device emulator-5554` with that emulator up says it is using it, with no "Booting" line.
- `--device emulator-9999` (nothing attached with that serial) fails as an unknown attached device, without
  announcing a boot or offering AVD names as if the serial were one.

## Actual
Running emulator (AND-106/02.err:4-5; also AND-027/02):
```
Booting emulator: emulator-5554
Emulator booted: cov-android (emulator-5554)
```
Unknown serial (cov-cli CLI-031/run_flag_android.err):
```
Resolved: module=app variant=freeDebug device=emulator-9999 screens=5 flows=12
Preparing runner...
Runner ready
Booting emulator: emulator-9999
Error: Invalid argument: No attached device has the serial "emulator-9999" (see `adb devices`) and no AVD has that name (see `emulator -list-avds`). AVDs: Pixel_8_API_35, cov-flows-android.
```

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k12
unset GRANTIVA_API_KEY
rm -rf /tmp/k12 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k12 && cd /tmp/k12/android
# unknown serial: no device needed
grantiva run --platform android --no-build --device emulator-9999 2>&1 | grep -E 'Booting|Error'
# running emulator
SERIAL=$(grantiva emulator ensure --name fix-k12)
grantiva build install --device "$SERIAL" --no-launch
grantiva run --device "$SERIAL" --no-build --flow .maestro/01-browse.yaml 2>&1 | grep -E 'Booting|booted'
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k12
```

## Evidence
- findings/evidence/cov-android/AND-106/02.err lines 4-5; findings/evidence/cov-android/AND-027/02.err
- findings/evidence/cov-cli/CLI-031/run_flag_android.err, CLI-031/commands.txt
- Row pointer: findings/evidence/cov-android/AND-OBS-05/commands.txt

## Suspected cause
- `Sources/GrantivaCLI/TargetOptions.swift:114` folds `--device` into the same field as the AVD name
  (`simulator: deviceFlag ?? android.emulator ?? ""`), so later code cannot tell a serial from an AVD.
- `Sources/GrantivaCLI/RunCommand.swift:116-124` (`bootNarration`) always returns `"Booting <noun>: <target>"` for a
  non-empty target and is logged at :290 before `bootDevice` runs (also `CICommand.swift:282`).
- `Sources/GrantivaCore/Android/AndroidPlatform.swift:73-95` (`bootDevice(named:)`) uses an attached serial as is,
  otherwise treats the value as an AVD name and boots it; the error at :89-91 names both lists. A strict
  `attachedDevice(serial:)` already exists (:99-108) and is what `build build` uses for `--device`.

## Acceptance criteria
- `--device emulator-5554` with that emulator attached prints `Using emulator: cov-android (emulator-5554)` (or similar)
  and no `Booting` line; `--emulator <avd>` keeps `Booting emulator: <avd>` only when it actually boots, and says
  `Using` when the AVD is already running.
- `--device emulator-9999` with nothing attached fails before any boot narration with an error naming the attached
  devices, e.g. `No usable attached device has the serial "emulator-9999". Attached: emulator-5554 (device).` and
  suggesting `--emulator <avd>` to boot an AVD; exit 1.
- iOS `--simulator` narration unchanged.
- GrantivaCLITests (RunCommandTests): `bootNarration` for an already-running target says "Using"; a TargetOptions test
  shows `--device` resolves through the attached-device path and never through AVD lookup.
