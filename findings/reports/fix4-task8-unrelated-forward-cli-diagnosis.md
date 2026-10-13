# Task 8 unrelated Android forward diagnosis (L84)

## Finding

This is a separate ownership defect from L82. L82 was the foreground CLI attachment leaking its own allocated forward on exit. L84 is the CLI's generic Android orphan cleanup deleting TCP forwards that may belong to another process.

The live control created `emulator-5582 tcp:59633 tcp:16791` before `runner start`. At the ready inventory only the runner socket and the CLI readiness attachment remained:

```
emulator-5582 localfilesystem:/tmp/uia2-emulator-5582.sock tcp:6790
emulator-5582 tcp:59849 tcp:6790
```

The unrelated `tcp:59633` forward was gone even though it used neither UIAutomator2's remote port nor the CLI's allocated local port. This proves that serial membership alone is not an ownership boundary.

`AndroidPlatform.cleanupOrphans(deviceID:)` force-stops both UIAutomator2 packages and then calls `ADB.removeForwards(serial:)`. That helper lists every TCP local for the serial and removes each one. Its name and the existing test phrase “only this serial's forwards” encode device scope, but a device can have forwards owned by several tools and processes.

## Caller lifecycle

The broad operation is reachable through all of these CLI lifecycle paths:

1. `RunnerSession` normal completion calls `cleanupOrphans` after `RunnerExecution.run` returns. This covers ordinary `run` and keep-alive runner completion.
2. `RunnerSession.terminationCleanup` calls it from the synchronous signal callback after restoring capture state.
3. `RunnerSessionStopper.terminate` calls it after terminating or sweeping a detached/orphaned runner.
4. `RunnerStopCommand.stop` calls it after foreground, detached, or already-exited session handling.

The start command itself has no direct `cleanupOrphans` call. Its pre-start stale-session probe uses `attachDriver(port: nil)` and detaches the exact temporary attachment. Therefore the current source establishes the broad deletion on completion, signal, and stop paths, but does not by itself identify a startup call before the ready inventory. The ready-time observation should remain attributed to the product sequence, with exact call timing unresolved unless an ADB command trace shows which process issued the removal. It is still sufficient to reject the broad cleanup API because the listed lifecycle paths deterministically violate the same ownership rule.

The runner's separate removal of local `tcp:6790` is L83 and does not explain removal of allocated local `tcp:59633`; it remains outside this repair.

## Smallest ownership-preserving repair

Change generic Android orphan cleanup so it never enumerates and deletes every TCP forward for a serial. It may continue to force-stop the two UIAutomator2 packages. Forward deletion must receive an exact locally owned port and call `ADB.removeForward(serial:localPort:)` for that port only.

A bounded implementation shape is:

- extend the cleanup dependency/API with `ownedForwardPort: Int?` (or split exact forward release into a separate injected closure);
- normal and signal `RunnerSession` cleanup pass no TCP port because the runner owns its own socket/transport cleanup;
- `runner stop` passes `RunnerSessionInfo.wdaPort` when it is nonzero;
- `RunnerSessionStopper` passes the stopped `KeepAliveSession.port` when it is nonzero and recorded as a TCP port;
- unknown legacy/orphan forwards remain untouched because ownership cannot be inferred safely;
- keep `DriverAttachment.detach` as the preferred exact cleanup for live foreground ownership.

Simply filtering all serial forwards by remote `6790` is still unsafe: another tool may legitimately own a UIAutomator2 forward. Filtering by local `6790` repeats L83. An exact recorded local port is the minimum safe identity.

`EmulatorManager.stop` is intentionally different. A confirmed Grantiva-owned emulator teardown, or explicit `--force`, destroys the whole emulator and may retain its current force-stop plus `removeForwards(serial:)` behavior. That is full-device teardown semantics, not routine driver/session cleanup.

## Required tests

1. Replace `AndroidPlatformTests.testCleanupOrphansForceStopsUIA2AndRemovesOnlyThisSerialsForwards`. Its listing should contain an unrelated TCP forward, and routine orphan cleanup must issue no list/remove command while still force-stopping both UIAutomator2 packages.
2. Add an exact-owned-forward test with two forwards on the same serial. Cleanup receives one recorded local port and emits exactly one `forward --remove tcp:<owned>` command; it must not remove the unrelated port and must not use `--remove-all`.
3. Add `RunnerStopCommand` coverage showing the ready Android session's recorded `wdaPort` is handed to exact cleanup. Cover port `0`/starting state and iOS as no-forward cases.
4. Add `RunnerSessionStopper` coverage for detached/orphan sessions: a recorded nonzero TCP port is removed exactly; unknown/zero ports do not trigger broad cleanup.
5. Update `RunnerSessionCleanupTests` so normal and signal cleanup still restore capture state and stop UIAutomator2, while proving they provide no unowned TCP port.
6. Preserve or add `EmulatorManager` teardown coverage showing full teardown still removes all forwards for that emulator.

The production semantic RED should use the real `AndroidPlatform`/`ADB` scripted-shell seam: one owned and one unrelated forward on the same serial, then assert only the owned local port is removed. A fake event-only `cleanupOrphans` test is insufficient because it cannot detect the current enumeration behavior.

## Acceptance boundary

Live acceptance should create an unrelated allocated forward before start, capture it alongside the ready session forward, then exercise normal stop and SIGINT separately. The CLI-owned session port must disappear after each stop and the unrelated allocated port must remain until the controller removes it explicitly. Run the same control through detached `runner stop`. Full emulator teardown may remove both. No test should treat every forward on an Android serial as Grantiva-owned.

## Evidence and scope

Primary raw evidence:

- `findings/evidence/fix4-4-forward/live-acceptance/create-unrelated.stdout` (`59633`)
- `findings/evidence/fix4-4-forward/live-acceptance/interrupt-ready-forwards.stdout` (runner socket and `59849`, unrelated `59633` absent)

This diagnosis made no product-source changes and ran no device commands.
