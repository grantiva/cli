# iOS `launchApp: {arguments: …}` also sends every argument as a launch environment variable named after the flag

Severity: wrong-result
Component: runner
Platforms: ios (iOS-only: WDA launchApp; no Android twin expected)
Rows: IOS-077 (ios); IOS-238 passed on the same evidence
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

Triage note: the matrix row (IOS-077, README:172) only asks that the app receives `--flag`, which it does; the
slice failed the row for the extra environment entry. The runner mirrors arguments into the environment on purpose
(comment at pkg/driver/wda/commands.go:1172), so this needs a product decision before a fix.

## Expected
`launchApp: {arguments: {"--flag": true}}` passes `--flag true` as launch arguments (README:172 lists `launchApp`
arguments among supported commands; README:90 and :176 say the environment comes from `environment:`, flow `env:`
and `--env`, not from `arguments:`). The app's environment gains no variable named `--flag`.

## Actual
runner-log-launch-lines.txt (from the FLOWS-26 10-lifecycle run's maestro-runner.log, iOS 26.0):
```
34:00:16:03.056139 [DEBUG] [wda] launchApp com.kylebrowning.Landmarks: argv=["--flag" "true"] env=map[--flag:true]
39:00:16:03.057669 [DEBUG] WDA POST /session/6A8A3957-…/wda/apps/launch body={"arguments":["--flag","true"],"bundleId":"com.kylebrowning.Landmarks","environment":{"--flag":"true...
```
The app gets `--flag true` in argv (IOS-238 passed) and also an environment variable literally named `--flag`.

## Repro
Flow (`ios/.maestro/coverage/10-lifecycle.yaml`, first steps):
```
appId: com.kylebrowning.Landmarks
---
- stopApp
- launchApp:
    arguments:
      "--flag": true
- assertVisible: "Featured"
```
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k74
unset GRANTIVA_API_KEY
rm -rf /tmp/k74 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k74 && cd /tmp/k74/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k74 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva run --no-build --simulator "$UDID" --flow .maestro/coverage/10-lifecycle.yaml --report-dir /tmp/k74/out
grep -n 'launchApp com.kylebrowning.Landmarks: argv\|wda/apps/launch body' /tmp/k74/out/maestro-runner.log | head -2
grantiva simulator teardown --session-id fix-k74
```
Today: `env=map[--flag:true]` and `"environment":{"--flag":"true"}` in the launch body.

## Evidence
- findings/evidence/cov-ios/IOS-077/commands.txt, runner-log-launch-lines.txt (lines 34, 39), report-dir/maestro-runner.log (full log)
- findings/evidence/cov-ios/FLOWS-26/10-lifecycle.out, 10-lifecycle.err (flow passes)

## Suspected cause
grantiva-runner, `pkg/driver/wda/commands.go:1158-1175` (`launchApp`): for each `arguments` key the loop appends to
`launchArgs` and also sets `launchEnv[key]` (`launchEnv[key] = "true"` for a bare flag at :1167, and
`launchEnv[key] = strVal` at :1173 with the comment "Also set as environment variable so the app can read via
ProcessInfo.environment"). The merged map is sent as `environment` by `LaunchAppWithArgs` (:1244).

## Acceptance criteria
- Decision recorded: either arguments are argv only, or the mirroring is kept and documented (README:172/176).
- If argv only: re-running the repro shows `env=map[]` for that launch and a launch body without `environment`
  (or without the `--flag` key); `argv=["--flag" "true"]` is unchanged and flow 10-lifecycle still passes on 26.0
  and 27.0. An app that relied on `ProcessInfo.environment["--flag"]` needs `environment:` instead: say so in the
  release notes.
- If kept: README says `arguments:` keys are also set as environment variables on iOS, and the matrix row is
  corrected.
- Runner test (pkg/driver/wda): `launchApp` with `Arguments{"--flag": true}` and no `Environment` sends a launch
  request whose environment lacks `--flag` (or, if kept, asserts the documented behaviour).
- Bundled runner version bumped in this repo if the runner changes.
