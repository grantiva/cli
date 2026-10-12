# Android failure capture takes 5–10 s after a crash, mostly `adb screencap`

Severity: ux
Component: runner
Platforms: android
Rows: none yet; found during the round-3 smoke addendum (runner PR #23 device runs, 99-crash)
Regresses/extends: L05 (failure capture queues behind the first lookup), L57 (crash timing)
Binary: grantiva-runner 1.1.28-grantiva.12 + PR #23 branch

## Expected
Once a step fails, the failure artefacts (screenshot, hierarchy, logcat tail) are captured within ~2 s on the default
software-rendered AVD at host load below 15, so a crash flow's wall time is the app's cold start plus a few seconds.

## Actual
The capture takes 5–10 s after the failure is decided. `adb screencap` on the software-rendered AVD accounts for most of
it; the hierarchy dump and the log tail follow serially.

## Reproduce
On the default AVD: `.maestro/99-crash.yaml` with the dev runner; compare the step failure timestamp with the time the
report directory's screenshot and hierarchy files appear.

## Fix direction
Capture screenshot, hierarchy and logcat concurrently; take the screenshot through the UIAutomator2 server
(`GET /screenshot`, PNG over the existing socket) instead of `adb screencap` + pull when the server is alive; bound each
capture by a short deadline and record a note instead of blocking the report. Schedule: round 4 unless a `B3`/`N3` row
fails on it.
