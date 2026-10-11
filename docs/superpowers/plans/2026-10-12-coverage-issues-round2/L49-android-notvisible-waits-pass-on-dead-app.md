# On Android, assertNotVisible and extendedWaitUntil notVisible have no crash check, so they pass against a crashed app, where iOS fails them with app_crash

Severity: wrong-result
Component: runner
Platforms: android (Android-only: UIAutomator2 driver's notVisible waits)
Rows: none yet; found in review of runner PR #22 (not run on a device)
Regresses/extends: L24, L06, K97 (L24 and K97 settle/visibility crash rule, applied to notVisible)
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11 + PR #22 branch 44ac084

## Expected
A notVisible wait on an app that crashed after launch fails like every other wait after L02/L24: `error.type`
`app_crash` with the FATAL EXCEPTION cause within ~2 s of the process dying. The element being absent because the app
is gone is not a pass. After an intentional stopApp/killApp/clearState the crash watch is off (as in L24), so a
notVisible wait there passes as before.

## Actual
`assertNotVisible` (`commands.go:~358`) and `extendedWaitUntil: {notVisible: ...}` (`commands.go:~2552`) both return
`waitNotVisible` (`visibility_wait.go:~96`). That loop has no crash check at all (no `newCrashCheck`, no
`watchedAttempt`, no `confirmMatch`). On a dead launched app nothing of the app is displayed, so the first probe finds
no match and the step passes ("Element is not visible"). The crash is pinned on the next step or never. iOS fails the
same flow with `app_crash` (round-2 evidence N2-13 `not-visible` on iOS; L24 covers the iOS and settle side). Found
by reading the PR #22 branch; not reproduced on a device.

## Repro
Not run (no device in this pass). Variant of 99-crash:
```
appId: com.kylebrowning.landmarks
env:
  LANDMARKS_CRASH_ON_LAUNCH: "1"
---
- launchApp
- assertNotVisible: {text: "Landmarks Home"}
- extendedWaitUntil:
    notVisible: {text: "Landmarks Home"}
    timeout: 5000
```
Run on an Android emulator as in L06's recipe (`grantiva run --device "$SERIAL" --no-build --flow ...`, 3 runs).
Defect: either step passes, or the flow fails with an error other than `app_crash`, or later than ~2 s after
`am_crash` (`adb logcat -b events -d -s am_crash`).

## Evidence
- Source read at fix3/crash-detection (44ac084), /Users/kyle/Developer/maestro-runner/.worktrees/fix3-crash:
  pkg/driver/uiautomator2/visibility_wait.go:~96 `waitNotVisible` (no crash check anywhere in the loop);
  commands.go:~358 (`assertNotVisible`) and :~2552 (`waitUntil`, notVisible branch) both call it before the
  `newCrashCheck`/`confirmMatch` code the visible branch of `waitUntil` has (:~2565-2580).
- Round-2 evidence N2-13 `not-visible` (iOS fails with `app_crash`), L24.
- Related: L02 (docs/superpowers/plans/2026-10-12-coverage-issues-round2/L02-android-crash-check-blocked-by-request.md),
  L06, L24.

## Suspected cause
`waitNotVisible` was written for K08 (visibility rule) and L02/L24 added the crash check to the visible waits and the
settle only. The loop's probe (`visibleMatch`, visibility_wait.go:~162) returns nil for "nothing displayed", which is
exactly what a dead app produces. Not confirmed: whether `visibleMatch` could surface a crash through its own error
path; reading it, its lookups only fail with the lookup error or `ServerUnavailableError`, neither is a crash.

## Acceptance criteria
- On Android, `assertNotVisible` and `extendedWaitUntil: notVisible` on a launched app that has crashed (process gone,
  FATAL EXCEPTION logged since the launch) fail with `app_crash` and the FATAL EXCEPTION cause within ~2 s of the
  crash, for both UiSelector and page-source selector kinds.
- The success path re-checks: a "nothing visible" result is confirmed (`confirmMatch`: one `pidof` on a live app)
  before the wait passes, so a crash during the final probe is not missed.
- Exempt after an intentional stopApp/killApp/clearState (watch off), same as L24: the wait passes there.
- Live app unchanged: a notVisible wait on a live app that is genuinely gone passes with no extra device calls beyond
  the single `pidof`; an element that stays visible still times out with the still-visible message.
- Runner tests in pkg/driver/uiautomator2 (next to wait_crash_test.go), using a fake client and the `lockedDevice`
  crash signal: (a) app killed after launch, element lookups return not-found -> `assertNotVisible` and
  `waitUntil{NotVisible}` fail with `ErrAppCrashed` within 2 s; (b) same after an intentional stopApp -> pass;
  (c) live app, element disappears after a few polls -> pass.
