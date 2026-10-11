# Round 1 runner follow-ups (PRs 6-12)

Source: pull requests #6 through #12 on grantiva/runner, read on 2026-10-10 with `gh pr view --json title,body,url`, `gh pr view --comments`, and the inline-comment and review APIs. Those PRs have no discussion comments, no inline review comments and no reviews, so every item below comes from the PR bodies (sections titled follow-ups, parked, out of scope, not done, not verified, or limits stated in the text). Items the threads or bodies did not defer are not listed. No item has an inline file:line, so that column is `-` throughout.

Task assignment: Task 1 = Android text input / tapOn; Task 2 = swipe geometry on any driver, coordinate parsing; Task 3 = selectors, element waits, isolation, alerts, everything else.

Notes: PR #12 later merged upstream work that changed some of these areas (F01 is still open for the drivers it names; F04 may already be covered by the merge). Check current code before implementing.

| ID | PR | file:line | Requirement | Task |
|---|---|---|---|---|
| F01 | #6 | - | Make the appium, devicelab and cdp drivers honour a swipe step's `from:` element | Task 2 |
| F02 | #6 | - | Add ExpandStep handling for swipe steps | Task 3 |
| F03 | #7 | - | Make the app-process check (pidof) work for apps using `android:process` | Task 3 |
| F04 | #7 | - | Retry or tolerate a single dropped adb read | Task 3 |
| F05 | #7 | - | Add a test covering logcat `-t` scoping | Task 3 |
| F06 | #7 | - | Stop tests depending on init()-set timing globals | Task 3 |
| F07 | #7 | - | End an element wait early when the app process is gone and a launch crash is in the log | Task 3 |
| F08 | #8 | - | M-2: make Stop wait for xcodebuild (or retry RemoveAll once) so Cleanup cannot race a dying process | Task 3 |
| F09 | #8 | - | M-4: replace the same-host PID liveness check with a host/boot token or flock so run-dir pruning is safe | Task 3 |
| F10 | #8 | - | M-5: verify launching from the cloned Products dir on a physical device | Task 3 |
| F11 | #8 | - | Stop devicelab_ios setup from editing its xctestrun port in place | Task 3 |
| F12 | #8 | - | Serialise concurrent cold-cache WDA Build calls (lockfile) so they stop sharing DerivedData | Task 3 |
| F13 | #8, #12 | - | Run the two-simulator concurrent-launch check for per-run isolation | Task 3 |
| F14 | #10 | - | Make WDA `id:` match a true identifier, not the label fallback (needs identifier attribute in the vendored WDA) | Task 3 |
| F15 | #10, #12 | - | Deliver flow-header `env:` to the app on iOS, not only launchApp environment | Task 3 |
| F16 | #12 | - | Make WDA `text:` match the whole value like the Android matchers | Task 3 |
| F17 | #12 | - | Make WDA `id:` matching case-insensitive | Task 3 |

Totals: 17 follow-ups. Task 1: 0. Task 2: 1. Task 3: 16.

## Context blocks

### F01
PR: https://github.com/grantiva/runner/pull/6
> Follow-ups (out of scope): appium/devicelab/cdp drivers do not honour `from`; ExpandStep for swipe.

### F02
PR: https://github.com/grantiva/runner/pull/6
> Follow-ups (out of scope): appium/devicelab/cdp drivers do not honour `from`; ExpandStep for swipe.

### F03
PR: https://github.com/grantiva/runner/pull/7
> Follow-ups not done: pidof with `android:process`, one dropped adb read, logcat `-t` scoping test, init() timing globals in tests.

### F04
PR: https://github.com/grantiva/runner/pull/7
> Follow-ups not done: pidof with `android:process`, one dropped adb read, logcat `-t` scoping test, init() timing globals in tests.

### F05
PR: https://github.com/grantiva/runner/pull/7
> Follow-ups not done: pidof with `android:process`, one dropped adb read, logcat `-t` scoping test, init() timing globals in tests.

### F06
PR: https://github.com/grantiva/runner/pull/7
> Follow-ups not done: pidof with `android:process`, one dropped adb read, logcat `-t` scoping test, init() timing globals in tests.

### F07
PR: https://github.com/grantiva/runner/pull/7
> - Follow-up: fail the element-wait early when the process is gone and a launch crash is logged (not done).

### F08
PR: https://github.com/grantiva/runner/pull/8
> - M-2: `Stop` kills xcodebuild without waiting, so the `RemoveAll` in `Cleanup` can race a dying process. Wait briefly, or retry `RemoveAll` once.

### F09
PR: https://github.com/grantiva/runner/pull/8
> - M-4: liveness is a same-host PID check. PID reuse can keep a dead run's dir around, and on a home shared across hosts a remote live run looks dead. A host or boot token, or a flock in the run dir, would make pruning provably safe.

### F10
PR: https://github.com/grantiva/runner/pull/8
> - M-5: launching from a cloned Products dir has not been verified on a physical device (only simulators so far).

### F11
PR: https://github.com/grantiva/runner/pull/8
> - Out of scope: `devicelab_ios/setup.go` still injects the port into its xctestrun in place.

(PR #12 renamed that driver to devicelab_ios_legacy and took the upstream setup; confirm whether the in-place edit remains.)

### F12
PR: https://github.com/grantiva/runner/pull/8
> Concurrent cold-cache `Build` calls share DerivedData (a lockfile around Build would fix it).

### F13
PRs: https://github.com/grantiva/runner/pull/8 and https://github.com/grantiva/runner/pull/12
> - On-device concurrency check (5 paired runs of flows 06/07 on two simulators with one `MAESTRO_RUNNER_HOME`). Pending the iOS slot.

PR #12:
> - The two-simulator concurrency check was skipped: the dispatch gave me one simulator.

### F14
PR: https://github.com/grantiva/runner/pull/10
> Limit: WDA `name` falls back to the label when an element has no identifier, so a strict fix needs an identifier attribute in the vendored WDA.

### F15
PRs: https://github.com/grantiva/runner/pull/10 and https://github.com/grantiva/runner/pull/12
> Note: flow-level env: does not reach the app on iOS, only launchApp environment does.

PR #12:
> That gap predates this merge (it is in the wda-selectors report) and is not caused by the merge.

### F16
PR: https://github.com/grantiva/runner/pull/12
> As a result Android whole-matches plain text but iOS/WDA still uses substring. This is a cross-platform difference to fix as a follow-up.

### F17
PR: https://github.com/grantiva/runner/pull/12
> Remaining gap: Maestro compiles ids with IGNORE_CASE, and ours is case-sensitive. That is unchanged and is a candidate follow-up.
