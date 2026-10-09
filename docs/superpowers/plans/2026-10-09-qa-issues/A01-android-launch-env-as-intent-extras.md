# Deliver `--env`, flow `env:` and `launchApp.environment` to Android apps as intent extras

Severity: wrong-result
Platforms: android
Found by: AND-F01 (matrix rows AND-035, AND-037, AND-038, AND-039, AND-040, AND-043; gate Defect 1)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7+android-drivers-2, emulator-5554 (Pixel_8_API_35, API 35)

## Expected
Each `--env KEY=VALUE` reaches the app under test. Source: help: run (`--env`: "Environment variable for the app under
test, as KEY=VALUE. Repeatable. Forwarded through the flow's launchApp environment."); README §Agent-Native Features
(`--env`). On Android the only launch-time channel is intent extras, which the landmarks label contract relies on.

## Actual
`run --flow qa-note.yaml --env 'LANDMARKS_NOTE=a=b c'` fails at `assertVisible "a=b c"` (exit 1). The runner launches with no
environment and the app sees no extras:
```
POST /session/50ef7a04-.../appium/device/launch_app [9.7075ms] OK body={"appId":"com.kylebrowning.landmarks"}
I Landmarks: launch action=android.intent.action.MAIN data=null extras=[none] env=[LANDMARKS_SEED=null, LANDMARKS_CRASH_ON_LAUNCH=null, LANDMARKS_NOTE=null]
```
Same for `--env LANDMARKS_SEED=empty|many`, `LANDMARKS_CRASH_ON_LAUNCH=1` (99-crash fails only at its last assert, green up
to there for the wrong reason) and flow-header `env:` (09-seed-empty, 10-seed-many). `launchApp: arguments:` does arrive:
`launch_app body={"appId":"...","arguments":{"LANDMARKS_SEED":"empty"}}` -> `extras=[LANDMARKS_SEED=empty]`.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=qa-android QA=/Users/kyle/Developer/grantiva-cli/.worktrees/qa-android
cd /Users/kyle/Developer/landmarks-demo/android
adb -s emulator-5554 logcat -c
grantiva run --no-build --flow $QA/findings/evidence/flows/qa-note.yaml --device emulator-5554 --env 'LANDMARKS_NOTE=a=b c'
adb -s emulator-5554 logcat -d | grep "Landmarks: launch"     # extras=[none]
grantiva run --no-build --flow .maestro/09-seed-empty.yaml --device emulator-5554   # fails: flow env: dropped
```

## Evidence
- findings/evidence/AND-035/{stderr.txt,logcat.txt,report/client.log}
- findings/evidence/AND-037/log.txt, AND-038/log.txt, AND-039/log.txt, AND-040/log.txt, AND-043/summary.txt
- findings/android-gate.md (Defect 1: the `arguments:` probe and `am start --es` hand checks)

## Suspected cause
CLI: Sources/GrantivaCore/Runner/FlowEnvironment.swift:132-134 (`environmentLines`) and
Sources/GrantivaCore/Runner/FlowGenerator.swift:20-28 always write `launchApp: environment:`, whatever the platform;
the injection call is Sources/GrantivaCore/Runner/RunnerSession.swift:292-300. Runner (not in this repo; source checked at
~/Developer/maestro-runner, branch grantiva-patches d98d7dd, which may lag the bundled build):
pkg/driver/uiautomator2/commands.go:849-852 forwards only `step.Arguments` to `LaunchApp`; `Environment`
(pkg/flow/step.go:401) is parsed and dropped. Flow-header `env:` is never turned into launch data on either side.

## Acceptance criteria
- Re-running the repro: logcat shows `extras=[LANDMARKS_NOTE=a=b c]` and qa-note passes; 09-seed-empty and 10-seed-many
  pass; 99-crash fails at `launchApp` with the app's `RuntimeException`.
- On Android, `--env` is delivered as string intent extras: either FlowEnvironment writes `arguments:` (merging with any
  existing `arguments:` map) when the platform is Android, or the bundled runner maps `environment` to extras. Pick one
  and say which in CHANGELOG and docs/android.md.
- Decide flow-header `env:`: deliver it the same way or document that it is only for `${VAR}` substitution on Android.
- GrantivaCoreTests/FlowEnvironmentTests: an Android-platform injection into bare, scalar and mapping `launchApp` forms
  yields `arguments:` entries (values with `=` and spaces quoted); FlowGeneratorTests: same for the screens flow.
