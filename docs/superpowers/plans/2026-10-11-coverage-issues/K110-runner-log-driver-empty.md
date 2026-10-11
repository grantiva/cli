# The runner log's `Driver:` line is empty when the driver is left to its platform default

Severity: ux
Component: runner
Platforms: both (the same line is empty in an Android runner log, `findings/evidence/cov-android/X-003/maestro-runner.log`, whose report.json says `"driver": "uiautomator2"`)
Rows: N-10 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
The runner log written to the report dir names the driver the run actually uses: `Driver: wda` on iOS,
`Driver: uiautomator2` on Android. grantiva never passes `--driver`, so this is the default path for every grantiva
run. report.json already records the resolved name, and the log line exists to show that choice when a run is
debugged (N-10 checks that iOS runs on WDA, not the legacy driver).

## Actual
`findings/evidence/cov-ios/N-10/runner-log-driver.txt` (from the run's runner log):
```
01:39:57.958078 [INFO] Driver: 
01:39:58.060727 [INFO] Creating driver for single device execution
```
while `findings/evidence/cov-ios/N-10/report.json:20-23` says:
```
  "maestroRunner": {
    "version": "1.1.28-grantiva.9",
    "driver": "wda"
  },
```
Android, same build (`findings/evidence/cov-android/X-003/maestro-runner.log`):
```
00:11:18.470005 [INFO] Platform: android
00:11:18.470009 [INFO] Driver: 
```
The rest of N-10 passed (WDA started, no legacy-driver lines).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k110
unset GRANTIVA_API_KEY
rm -rf /tmp/k110 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k110 && cd /tmp/k110/ios   # main 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k110 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
grantiva run --simulator "$UDID" --no-build --flow .maestro/02-favorite.yaml --report-dir /tmp/k110/rep; echo "exit $?"
grep -h 'Platform:\|Driver:' /tmp/k110/rep/*.log
grep -A2 '"version"' /tmp/k110/rep/report.json | grep driver
grantiva simulator teardown --session-id fix-k110; grantiva simulator delete --name "fix-k110 iPhone 17"
```
Today: `Platform: ios`, an empty `Driver: `, and `"driver": "wda"` in report.json.

## Evidence
- findings/evidence/cov-ios/N-10/runner-log-driver.txt, report.json (lines 20-23), verbose02.err, commands.txt
- findings/evidence/cov-android/X-003/maestro-runner.log, report.json (Android: same empty line, `"driver": "uiautomator2"`)
- findings/cov-ios-results.md row N-10

## Suspected cause
In the runner (ae48e34):
- pkg/cli/test.go:809: `RunConfig.Driver` is `getString("driver")`. The `--driver` flag deliberately has no default
  (pkg/cli/cli.go:33-39: "Empty means 'not chosen' — each platform then picks its default"), so it is `""` under
  grantiva.
- pkg/cli/test.go:910-911 logs `Platform: %s` and then `Driver: %s` with `cfg.Driver`, the raw flag value.
- The name used for reports is resolved later by `resolveDriverName(cfg, cfg.Platform)` (pkg/cli/test.go:295-317,
  called at :1568 and :1623), which maps `""` to `wda` on iOS and `uiautomator2` on Android. The log line never
  goes through it.

Fix direction: log `resolveDriverName(cfg, cfg.Platform)` when the platform is known at that point (grantiva always
passes `--platform`). Otherwise log `Driver: <platform default>` once the platform is detected, e.g. next to
`Driver created:` (test.go:1566).

## Acceptance criteria
- With no `--driver`, the runner log reads `Driver: wda` on iOS and `Driver: uiautomator2` on Android, matching
  report.json's `driver`.
- An explicit `--driver` value is still logged as given (lower-cased as `resolveDriverName` does).
- Runner unit test in `pkg/cli` (next to the existing `resolveDriverName` tests in cli_test.go):
  `TestRunLogsResolvedDriverName`, which captures the logger output for a config with `Platform: "ios"` and an
  empty `Driver` and asserts `Driver: wda`; same for android → `uiautomator2`.
- The bundled runner version is bumped in this repo and the release notes mention the log fix.
