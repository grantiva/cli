# An auto-accepted iOS system alert is not mentioned in the run output, even with `--verbose`

Severity: ux
Component: runner
Platforms: ios (iOS-only: WDA system-alert handling; no Android twin expected)
Rows: IOS-151 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

Triage note: the matrix row asks for `accepted system alert …` "in the runner log". The runner does log that at Info
(pkg/driver/wda/alerts.go:115), but the slice kept only a 3-line extract of the log, which shows the WDA requests and
not that line. First check the full maestro-runner.log of the repro: if the Info line is there, the matrix
expectation is met and what remains is the request to surface it in the run output (this brief); if it is absent,
the accept took another path and that is the defect.

## Expected
Matrix IOS-151 (README:156): the system location prompt is auto-accepted (`accepted system alert …` in the runner
log) and the flow passes. A user reading the run output, or the runner log after a run without `--report-dir`, can
tell that a system dialog was answered on their behalf.

## Actual
From a directory without grantiva.yml, Maps' location prompt is accepted and the flow passes (maps-noconf.out/.err,
exit 0). The report dir's runner log extract (runner-log-alert-lines.txt) has only:
```
01:28:07.588294 [DEBUG] WDA GET /session/DCF52E81-…/alert/text completed (96ms, status: 200)
01:28:07.680180 [DEBUG] WDA POST /session/DCF52E81-…/alert/accept body={"name":"Allow Once"}
01:28:08.100766 [DEBUG] WDA POST /session/DCF52E81-…/alert/accept completed (420ms, status: 200)
```
Nothing about the alert appears in the run's stdout/stderr, with or without `--verbose`. Without `--report-dir` the
runner log is in a temporary report directory that is deleted at the end of the run, so there is no trace at all.

Secondary observation: run from the project directory, the same flow launched Landmarks, not Maps, and passed
(maps.out), because grantiva.yml's `bundle_id` outranks the flow's `appId:` (README:174). That is the documented
order, but a flow that names another app passing against the configured one is easy to misread; it belongs with
C23 (app-id-resolution-order) if anywhere.

## Repro
Flow (`ios/.maestro/coverage/21-system-alert-maps.yaml`):
```
appId: com.apple.Maps
---
- launchApp
- waitForAnimationToEnd
- tapOn:
    id: "MapsTrayHeaderSearchField"
    optional: true
- takeScreenshot: "maps"
- assertNotVisible: "Allow Once"
```
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k91
unset GRANTIVA_API_KEY
rm -rf /tmp/k91 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k91 && mkdir -p /tmp/k91/noconf
cp /tmp/k91/ios/.maestro/coverage/21-system-alert-maps.yaml /tmp/k91/noconf/ && cd /tmp/k91/noconf   # no grantiva.yml here
UDID=$(grantiva simulator ensure --name "fix-k91 iPhone 17" --runtime 26.0)
xcrun simctl privacy "$UDID" reset location com.apple.Maps
grantiva run --no-build --simulator "$UDID" --flow 21-system-alert-maps.yaml --report-dir /tmp/k91/out --verbose 2>&1 | grep -i alert
grep -n 'system alert\|alert/accept' /tmp/k91/out/maestro-runner.log
grantiva simulator teardown --session-id fix-k91
```
Today: the first grep prints nothing; check whether the second shows `[wda] accepted system alert …`.

## Evidence
- findings/evidence/cov-ios/IOS-151/commands.txt, maps-noconf.out/.err, maps.out/.err (project-dir run, launched
  Landmarks), runner-log-alert-lines.txt

## Suspected cause
grantiva-runner `pkg/driver/wda/alerts.go:62-117` (`handleSystemAlert`): after pressing the button it logs
`[wda] accepted system alert %q (button %q)` with `logger.Info` (:115), and a default-button accept with
`logger.Warn` (:113). These go to the runner's log file only; the step narration (live lines and summary) has no hook
for "the driver answered a system alert during this step", so nothing reaches the console.

## Acceptance criteria
- Re-running the repro: the run output shows one line for the alert, attached to the step during which it happened,
  for example `    ↳ accepted system alert "Allow “Maps” to use your location?" (Allow Once)`, without needing
  `--verbose`.
- The runner log contains the Info line (verify it is written today; if not, fix the path that accepted the alert).
- report.json records the alert on that step (a `warning` or a dedicated field), so a `--report-dir` report shows it
  without reading the runner log.
- Runner test (pkg/driver/wda, fake client with an open SpringBoard alert): `handleSystemAlert` produces an event
  the step reporter prints; bundled runner version bumped.
