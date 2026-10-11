# Other-platform flag rejections are worded differently by `runner start` and `record`

Severity: ux
Component: cli
Platforms: both
Rows: CLI-134 (cli)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Every command rejects an other-platform flag by name before any build or boot (docs/android.md:55-56), with the same
sentence, including where the platform came from.

## Actual
All six cases are rejected correctly (exit 1), but build/ci/diff/install say (findings/evidence/cov-cli/CLI-134/*.err):
```
Error: Invalid argument: --variant is an Android option, but this is an iOS project (resolved from --platform, GRANTIVA_PLATFORM, the config file, or the directory).
```
while `runner start` says:
```
Error: Invalid argument: --application-id is an Android option, but this is an iOS project.
Error: Invalid argument: --simulator is an iOS option, but this is an Android project.
```
`record` uses the short form too (source; not in the row).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=fix-k43
rm -rf /tmp/k43 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k43
cd /tmp/k43/ios
grantiva build build --variant x; grantiva runner start --application-id a.b; grantiva record --duration 1 --emulator x
cd /tmp/k43/android
grantiva diff capture --scheme X; grantiva runner start --simulator X; grantiva record --duration 1 --simulator X
```
All fail before touching a device.

## Evidence
- findings/evidence/cov-cli/CLI-134/commands.txt, ios_build_variant.err, ios_ci_device.err, ios_runner_appid.err,
  and_install_bundle.err, and_capture_scheme.err, and_runner_sim.err

## Suspected cause
- Sources/GrantivaCLI/TargetOptions.swift:66-72 (`otherPlatformFlagError`) builds the long message.
- Hand-written short messages: Sources/GrantivaCLI/DriverCommand.swift:129-131, :134, :195, :201 (runner start /
  appID) and Sources/GrantivaCLI/RecordCommand.swift:85-86, :92.

## Acceptance criteria
- `grep -rn "option, but this is an" Sources/GrantivaCLI` finds only `otherPlatformFlagError`; DriverCommand and
  RecordCommand call it.
- The repro's six commands all print the long form, exit 1, before any boot.
- GrantivaCLITests/PlatformOptionTests (or RunnerLifecycleCommandTests / RecordCommandTests): `runner start
  --application-id` on iOS and `record --simulator` on Android throw the `otherPlatformFlagError` text.
