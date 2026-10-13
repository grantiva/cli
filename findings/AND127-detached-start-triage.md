# AND-127 detached Android start triage

## Verdict

AND-127 is a reproducible product readiness/contract failure against the binding matrix example. `runner start --detach` records and reports a `ready` session as soon as the new UIAutomator2 session can be attached, before the generated `launchApp` flow has necessarily completed. An immediate documented `runner dump-hierarchy --format tree` can therefore return Android System UI rather than Landmarks. The isolated poll rerun closes the causal question: with no concurrent iOS/Android start, poll 0 returned only System UI and poll 1 returned three `Landmarks` matches while the same runner's daemon log subsequently recorded successful `launchApp` and `waitForAnimationToEnd` steps.

This is not supported as a stale-fixture or malformed-harness result. It is also not evidence that app launch permanently fails: the app becomes observable shortly afterward. Keep the AND-127 row failed until the detached-start readiness contract or the documented sequence is corrected through the campaign's normal triage process.

## Binding expectation and observed evidence

The matrix requires the `docs/android.md` session sequence “as written” and specifically requires the tree immediately following detached start to contain `Landmarks` ([matrix](../../regression/docs/superpowers/plans/2026-10-13-round3-coverage-matrix.md), AND-127). Candidate documentation describes `runner dump-hierarchy` as reading the runner-held UIAutomator2 tree ([docs/android.md](../../release-main/docs/android.md), lines 138–147). The command help says detached start returns “once the driver is up” ([DriverCommand.swift](../../release-main/Sources/GrantivaCLI/DriverCommand.swift), lines 100–119), which is weaker than “once the app is launched.”

Three valid observations show the gap:

- `AND-126-127-exact-rerun1` started Android application ID `com.kylebrowning.landmarks`, produced a ready session for `emulator-5554`, then immediately captured only `com.android.systemui` nodes. Its preserved daemon log `/var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-runner-1791868259.log` shows UIAutomator2/session creation, then `launchApp` taking 1.5 s; the harness stopped the session during the following animation wait. Evidence: [commands](../../cov3-android/findings/evidence/cov3-android/AND-126-127-exact-rerun1/commands.txt), [start JSON](../../cov3-android/findings/evidence/cov3-android/AND-126-127-exact-rerun1/start.json), [session](../../cov3-android/findings/evidence/cov3-android/AND-126-127-exact-rerun1/session-after-start.json), and [tree](../../cov3-android/findings/evidence/cov3-android/AND-126-127-exact-rerun1/tree.out).
- `AND-127-exact-rerun1` first ran `.maestro/01-browse.yaml` successfully, establishing that the installed app and fixture worked. Detached start then resolved the same Android app ID and device and returned a ready session, but the immediate tree again contained only System UI. Its daemon log `/var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-runner-1791868531.log` shows interruption before the 1.4 s `launchApp` completed. Evidence: [commands](../../cov3-android/findings/evidence/cov3-android/AND-127-exact-rerun1/commands.txt), [prelaunch report](../../cov3-android/findings/evidence/cov3-android/AND-127-exact-rerun1/prelaunch-report/report.json), [session](../../cov3-android/findings/evidence/cov3-android/AND-127-exact-rerun1/session.json), and [tree](../../cov3-android/findings/evidence/cov3-android/AND-127-exact-rerun1/tree.out).
- `AND-127-isolated-poll-rerun2` ran with no concurrent runner start. Start began at epoch `1791868736.585185`, returned at `1791868741.460259`, and wrote `state:"ready"`. Poll 0 began 37 ms later and had zero `Landmarks` matches; poll 1 began at `1791868742.643142` and had three. The preserved daemon log records the correct Android flow and successful `launchApp` (1.5 s) plus `waitForAnimationToEnd` (376 ms). Evidence: [commands](../../cov3-android/findings/evidence/cov3-android/AND-127-isolated-poll-rerun2/commands.txt), [session at return](../../cov3-android/findings/evidence/cov3-android/AND-127-isolated-poll-rerun2/session-at-return.json), [poll summary](../../cov3-android/findings/evidence/cov3-android/AND-127-isolated-poll-rerun2/polls/summary.txt), [poll 0](../../cov3-android/findings/evidence/cov3-android/AND-127-isolated-poll-rerun2/polls/0.out), [poll 1](../../cov3-android/findings/evidence/cov3-android/AND-127-isolated-poll-rerun2/polls/1.out), and [daemon log](../../cov3-android/findings/evidence/cov3-android/AND-127-isolated-poll-rerun2/daemon.log).

The first two runs also completed the unrelated AND-127 clauses: start metadata/session, 22-tool MCP listing, stop success, and forward cleanup. The hierarchy clause alone failed.

## Implementation correlation

At candidate `8f2cff676b3c12e951478920fa20e600cdca4e29`, `RunnerStartCommand` writes a generated flow containing the resolved app ID, `launchApp`, and `waitForAnimationToEnd` to the process-wide temporary path `grantiva-session/session-flow.yaml` and starts the runner with that path ([DriverCommand.swift](../../release-main/Sources/GrantivaCLI/DriverCommand.swift), lines 176–229). On Android, detached start waits only for `waitForUIAutomator2Port`, records the session as ready, and returns ([DriverCommand.swift](../../release-main/Sources/GrantivaCLI/DriverCommand.swift), lines 350–382 and 500–565). Nothing in that readiness path waits for the generated flow's launch step.

The shared flow path is a separate plausible concurrency hazard, but these captures do not establish an overwrite. The iOS attempt 20 ran from `05:15:04Z` through `05:15:11Z`; the second Android daemon filename/start was approximately `05:15:31Z`, after iOS attempt 20 finished. More decisively, the isolated rerun reproduced the initial System UI tree without another runner start and its daemon log executed the correct Android flow. Do not attribute AND-127 to cross-platform flow contamination on this evidence.

## Minimal discriminating owned-Android verification

The completed isolated poll rerun is the minimal discrimination that was needed: one owned emulator, no concurrent starts, exact detached-start command, session JSON captured at return, monotonic/epoch timestamps, immediate hierarchy followed by bounded polling, preserved generated-flow location and daemon log, then normal stop/forward cleanup. It distinguishes readiness from permanent launch failure without inventing a sleep threshold.

For a fix verification, retain that shape and require an observable condition rather than a fixed delay:

1. Start on the owned Android emulator with no concurrent runner starts; preserve the generated flow and daemon log.
2. Capture session state and an immediate hierarchy at command return.
3. Require either (a) detached start not to return until its generated `launchApp` and initial animation wait complete and the immediate tree contains Landmarks, or (b) revise the product/documented contract explicitly so callers must await an app-ready signal before hierarchy access.
4. Poll only to diagnose timing; do not treat an arbitrary sleep followed by success as satisfying the current “as written” matrix sequence.
5. Stop and verify session and adb-forward cleanup.

No further live observation is required to classify the present failure. A controlled concurrent-start repro would be appropriate only for separately triaging the global `session-flow.yaml` design risk.
