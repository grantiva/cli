# Android `init` writes `emulator: Pixel_8_API_35` without a warning when that AVD exists and Grantiva did not create it

Severity: wrong-result
Component: cli
Platforms: android (the iOS twin warns, CLI-069/CLI-072; a source and output check, no device needed)
Rows: EXTRA-01 [cli] (side finding of CLI-070 [cli], which passes)
Regresses/extends: K37 (default simulator name), fixed by CLI #190 on iOS only; K28 (created-AVDs record), fixed by CLI #189, whose ledger `init` does not read.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
K37 criterion 2 applied to Android: `init` either writes a Grantiva-specific AVD name that `emulator ensure`/`run`
creates on first use, or, if it writes a stock name, warns when an AVD of that name already exists and is not in
Grantiva's created-AVDs ledger (`~/.grantiva/android/created-avds.json`), naming it. That is the warning iOS `init`
prints for its default simulator. README Quick Start runs `init` then `run`, so whatever `init` writes is what the first
run boots and drives.

## Actual
In a Gradle-only copy of landmarks-demo/android on a host that has the owner's own `Pixel_8_API_35` AVD
(findings/evidence/cov2-cli/CLI-070/init.err and grantiva-android.yml), exit 0 in 0.048 s:
```
Created grantiva-android.yml
...
emulator: Pixel_8_API_35
system_image: "system-images;android-35;google_apis;arm64-v8a"
```
No warning. The same host's iOS `init` warns about its default (findings/evidence/cov2-cli/CLI-072, init stderr):
```
Warning: A simulator named "iPhone 18 Pro" (FE441EE5-BBFC-4981-B68A-59C0DBCE26D6) already exists and was not created by Grantiva; runs from this directory will boot and drive it. To keep them off it, set simulator: in grantiva.yml to a name of your own, for example "Grantiva iPhone 18 Pro" (created on first use with `grantiva simulator ensure --name "Grantiva iPhone 18 Pro"`).
```
A following `grantiva run` in that directory would boot and drive the user's AVD. That was not run, because Global
Constraints protect the owner's AVD.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$HOME/Library/Android/sdk/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"; unset GRANTIVA_API_KEY
rm -rf /tmp/l09 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l09
avdmanager list avd -c | grep -x Pixel_8_API_35                              # an AVD of the default name exists
grep -c Pixel_8_API_35 ~/.grantiva/android/created-avds.json 2>/dev/null   # 0: Grantiva did not create it
cd /tmp/l09/android && rm grantiva-android.yml && grantiva init; echo "exit=$?"                    # bug: no warning
grep '^emulator:' grantiva-android.yml                                       # emulator: Pixel_8_API_35
```
If the host has no `Pixel_8_API_35`, create one outside Grantiva first
(`avdmanager create avd -n Pixel_8_API_35 -k "system-images;android-35;google_apis;arm64-v8a" -d pixel_8`) and delete it
afterwards.

## Evidence
- findings/evidence/cov2-cli/CLI-070/commands.txt, init.out, init.err, grantiva-android.yml
- findings/evidence/cov2-cli/CLI-072/ (the iOS warning for comparison)
- docs/superpowers/plans/2026-10-11-coverage-issues/K37-default-simulator-name.md, K28-created-avds-record-bookkeeping.md

## Suspected cause
- `Sources/GrantivaCLI/InitCommand.swift:37-50`: the Android branch writes `androidTemplate(…, emulator:
  "Pixel_8_API_35")` (`:46`) and returns without any device check.
- The provenance warning (`existingSimulatorWarning`, `InitCommand.swift:169-177`, called at `:61-67`) runs only on the
  iOS branch.
- The data needed exists: `AndroidProvenance.createdAVDs()` (`Sources/GrantivaCore/Android/AndroidProvenance.swift:71`)
  and `EmulatorManager.listAVDs()` (`Sources/GrantivaCore/Android/EmulatorManager.swift:217`). `emulator delete` already
  uses the ledger to refuse a user AVD (`EmulatorManager.swift:555`).
- `Pixel_8_API_35` is also the name `scripts/android-env.sh` and doctor's fix lines suggest
  (`Sources/GrantivaCore/Doctor/DoctorRunner.swift:203,211`). That makes a user-owned AVD of that name likely on a
  developer host.

## Acceptance criteria
- Android `init` on a host where `Pixel_8_API_35` (or whatever default it writes) exists and is not in
  `created-avds.json` prints one `Warning:` line naming the AVD. The line says runs from this directory will boot and
  drive it, and suggests a Grantiva-specific name created on first use (`grantiva emulator ensure --name "Grantiva
  Pixel 8 API 35"` or similar). The exit code stays 0. Alternatively `init` writes a Grantiva-specific name and the
  warning is unnecessary.
- No warning when the AVD is absent or is in the created-AVDs ledger.
- The iOS and Android warnings share one sentence shape (one helper taking the device kind).
- Tests: GrantivaCLITests/InitAndroidTests: a pure helper (an Android counterpart of `existingSimulatorWarning`, taking
  the AVD list and the ledger) returns the warning for a listed, unregistered default and nil for an absent or
  registered one. The existing `testAndroidTemplate…` assertion on `emulator: Pixel_8_API_35` is updated if the default
  name changes.
