# iOS `launchApp: {clearState: true}` clears the app's data but nothing in the run output or the runner log says so

Severity: ux
Component: runner
Platforms: ios (Android twin AND-231 passed; its runner log also shows only the step `launchApp (clearState)` and no clear call, so the same gap may exist there)
Rows: IOS-231, IOS-231@27.0 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix IOS-231 (README:172): after favoriting Lake Tahoe, `launchApp: {clearState: true}` leaves Favorites empty
**and the runner log shows the app data being cleared**. The behaviour is right; the clearing should be observable,
since an in-memory app (like this one) would pass the Favorites check without any clearing.

## Actual
The marker probe shows the data container is replaced (marker-probe.out: a `launchApp: {clearState: true}` flow
moves the app to a new data container, B09EE4B6-… before, D0DE1AB8-… after, and the `cov-marker` file is gone), and the flow passes on 26.0 and 27.0. The runner log around the step (10-lifecycle on 26.0, findings/evidence/cov-ios/IOS-077/report-dir/maestro-runner.log)
has only:
```
00:16:08.648664 [DEBUG] Executing step 6: launchApp (clearState)
00:16:08.649787 [DEBUG] WDA POST /session/6A8A3957-…/wda/apps/terminate body={"bundleId":"com.kylebrowning.Landmarks"}
00:16:09.728760 [DEBUG] WDA POST /session/6A8A3957-…/wda/apps/terminate completed (1078ms, status: 200)
00:16:10.534035 [DEBUG] [wda] launchApp com.kylebrowning.Landmarks: argv=[] env=map[]
00:16:10.538690 [DEBUG] WDA POST /session/6A8A3957-…/wda/apps/launch body={"bundleId":"com.kylebrowning.Landmarks"}
```
The 0.8 s between the terminate completing and the launch is the uninstall and reinstall, and nothing is logged for
it. The run output prints `✓ launchApp` and nothing else, with or without `--verbose`.

## Repro
Flow (written to `/tmp/k77/clearstate.yaml` below; the same steps are in `ios/.maestro/coverage/10-lifecycle.yaml`):
```
appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "Lake Tahoe"
- tapOn: "Favorite"
- assertVisible: "Unfavorite"
- launchApp:
    clearState: true
- tapOn: "Favorites"
- assertVisible: "Landmarks you favorite will appear here."
```
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k77
unset GRANTIVA_API_KEY
rm -rf /tmp/k77 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k77 && cd /tmp/k77/ios   # 4e49dc4
cat > /tmp/k77/clearstate.yaml <<'YAML'
appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "Lake Tahoe"
- tapOn: "Favorite"
- assertVisible: "Unfavorite"
- launchApp:
    clearState: true
- tapOn: "Favorites"
- assertVisible: "Landmarks you favorite will appear here."
YAML
UDID=$(grantiva simulator ensure --name "fix-k77 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
DATA=$(xcrun simctl get_app_container "$UDID" com.kylebrowning.Landmarks data); mkdir -p "$DATA/Documents"; touch "$DATA/Documents/k77-marker"
grantiva run --no-build --simulator "$UDID" --flow /tmp/k77/clearstate.yaml --report-dir /tmp/k77/out --verbose
ls "$(xcrun simctl get_app_container "$UDID" com.kylebrowning.Landmarks data)/Documents/"   # marker gone
grep -niE 'clear|uninstall|install' /tmp/k77/out/maestro-runner.log                         # today: nothing for the step
grantiva simulator teardown --session-id fix-k77
```

## Evidence
- findings/evidence/cov-ios/IOS-231/clearstate.yaml, commands.txt, marker-probe.out
- findings/evidence/cov-ios/FLOWS-26/10-lifecycle.out/.err, FLOWS-27/10-lifecycle.out/.err
- findings/evidence/cov-ios/IOS-077/report-dir/maestro-runner.log (step 6, around 00:16:08-00:16:10) and runner-log-launch-lines.txt

## Suspected cause
grantiva-runner:
- `pkg/driver/wda/commands.go:1027-1047` (`launchApp`, `step.ClearState` branch): the result of `clearAppState` is
  checked for failure only; on success its message is dropped and nothing is logged.
- `pkg/driver/wda/commands.go:1335-1357` (`clearAppStateSimulator`): runs `simctl uninstall` then `simctl install`
  of a staged copy via `exec.Command` (not through the logged WDA client), and returns
  `Cleared state for %s (uninstall+reinstall)` that no caller prints. Hence the silent 0.8 s.

## Acceptance criteria
- Re-running the repro: the runner log has an Info line for the step such as
  `[wda] clearState com.kylebrowning.Landmarks: uninstalled and reinstalled from <staged path> (0.8s)`; a failure
  logs which half failed.
- With `--verbose` the run output shows that line (or the step line reads `launchApp (clearState)` and the
  launch result message mentions the clearing).
- Behaviour unchanged: the marker file is gone, the flow passes on 26.0 and 27.0, and 10-lifecycle still passes.
- Runner test (pkg/driver/wda): `launchApp` with `ClearState: true` on a simulator driver records a log entry (or
  result message) for the clear.
- Android: check the UIAutomator2 `clearState` path and add the equivalent line if it is silent too.
- Bundled runner version bumped in this repo.
