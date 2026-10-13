# Task 8 L84 CLI-owned forward source review

Reviewed requirement `L84-cli-orphan-cleanup-removes-unrelated-device-forwards.md`, report `task8-cli-owned-forward-report.md`, scoped source diff `015521cb75ff46b19aa66790300d6c85d2bd6e3b..a587581723ec2599e0247c186d27667951959d9e`, the clean product worktree at `a587581723ec2599e0247c186d27667951959d9e`, and the captured semantic RED/focused/full evidence. No tests or device actions were rerun.

## Spec verdict: PASS

No blocking spec findings.

- Routine `AndroidPlatform.cleanupOrphans(deviceID:)` no longer lists or removes device forwards. It only force-stops the two UIAutomator2 packages, so an unknown same-device TCP forward is preserved and no arbitrary local port can be selected from `adb forward --list`.
- Exact removal is isolated in `removeOwnedForward(deviceID:localPort:)`, rejects non-positive ports, and invokes only `adb forward --remove tcp:<recorded-port>` for the named device.
- `RunnerStopCommand` supplies a port only from a ready `RunnerSessionInfo`; a starting session supplies none. The Android-only guard remains at the caller, so iOS stop behavior is unchanged.
- `RunnerSessionStopper` supplies a positive port from a published `KeepAliveSession`, or from a ready runner-start session during device teardown. Unknown/unpublished and zero-port sessions receive routine process cleanup without forward deletion.
- Normal and signal cleanup inside `RunnerSession` still calls routine orphan cleanup, which is now ownership-safe. Its attachment lifecycle remains responsible for its own exact forward detach. The scoped diff contains no L82 attachment discovery, selection, detach, ready-state publication, or handoff changes.
- Explicit emulator teardown still calls `ADB.removeForwards(serial:)` before killing the emulator, preserving the existing full-device teardown contract.
- The CLI flags, result documents, exit rendering, readiness behavior, and public protocol surface are unchanged by the scoped diff.

The live acceptance cases required by L84 remain controller gates. This source verdict does not claim the rebuilt-candidate ready/SIGINT/normal-stop/absent-app/healthy-stock matrix, CI, or merged-candidate smoke has passed.

## Quality verdict: PASS

No blocking quality findings.

The change makes ownership explicit at the call sites rather than inferring it from device membership. The narrow helper is small, idempotent at the ADB boundary, and retains the existing best-effort cleanup behavior. Tests cover preservation of an unrelated same-device forward, exact recorded-port removal, ready versus starting runner-stop semantics, Android versus iOS routing, and published detached keep-alive cleanup. Existing focused coverage also exercises the L82 lifecycle surface.

The semantic RED is production-valid: its source patch changes only the existing real `AndroidPlatform`/scripted-ADB test, and against base production behavior it fails because the command log contains `forward --list` followed by removal of the unrelated `tcp:61211`. The production change makes that same expectation green and adds caller-level ownership tests.

Captured evidence is internally consistent and checksum-valid:

- semantic RED: 1 selected production-seam test, 1 expected failure;
- focused fresh-home run: 128 tests, 0 failures (Core 54, CLI 74);
- full fresh-home run: 2,022 tests, 0 failures (MCP 281, Core 973, CLI 667, API 101);
- both governing commands record literal `GRANTIVA_SESSION_ID=fix4-84`, separate fresh runner homes with empty final inventories, and API environment unset;
- all listed SHA-256 values for RED, scoped/GREEN diff, focused transcript, full transcript, and full-source diff match the files; `git diff --check` is clean;
- the product worktree is clean at `a587581723ec2599e0247c186d27667951959d9e`.

## Non-blocking observation

The exact-port helper itself has no direct zero-port assertion, but both production callers exclude absent/non-positive ownership and the helper independently guards `localPort > 0`. This does not weaken the ownership boundary.

## Gate status

Source/spec review: PASS. Source/quality review: PASS. Live acceptance, CI, and merged/rebuilt-candidate validation remain controller-owned gates and are not converted into source passes by this review.
