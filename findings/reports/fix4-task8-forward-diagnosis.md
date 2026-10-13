# Task 8: Android forward diagnosis

## Status

Read-only diagnosis against CLI candidate `fb7af9d1` and runner candidate `ff68658f`. No product files were changed.

The isolated missing-app reproduction in `findings/evidence/round4-smoke/03-lifecycle/absent-forward-repro` started with no forwards and had no forwards both immediately and one second after the command exited 1. Therefore the missing-app detached rollback is **not reproduced as leaking a forward**. The original `tcp:55149 -> tcp:6790` was almost certainly inherited from the immediately preceding successful foreground `runner start`, PID 36623, which was interrupted with Ctrl-C.

## Forward ownership

The runner logs show UIAutomator2 using `/tmp/uia2-emulator-5580.sock`. On macOS the runner owns a `localfilesystem:<socket> -> tcp:6790` ADB forward. It does not know dynamically allocated TCP port 55149.

The CLI creates `tcp:55149 -> tcp:6790` during readiness discovery:

1. `RunnerStartCommand.waitForUIAutomator2Port` calls `AndroidPlatform.attachDriver(deviceID:port:nil)`.
2. `UIAutomator2.attach` calls `ADB.forward`.
3. That executes `adb -s emulator-5580 forward tcp:0 tcp:6790`; ADB selects the local port.

The ready-interrupt evidence confirms the allocation directly: `android-ready-interrupt.stdout` reports `UIAutomator2 port: 55149` for runner PID 36623. The absent-app command starts only after that foreground command exits 130, and the subsequent forward listing reports the same port 55149. By contrast, the earlier detached session used port 54944 and was stopped normally.

## Root cause in the foreground lifecycle

`waitForUIAutomator2` deliberately returns a successful `DriverAttachment` without detaching it because the live session needs that forward. `waitForUIAutomator2Port`, however, immediately maps the attachment to only its numeric port:

```swift
return (wait.attachment.map { UInt16(clamping: $0.port) }, wait.exitStatus, wait.launchFailed)
```

That discards the attachment's cleanup closure. `startForeground` records the port and holds the runner, but its `cleanup` only removes session/owner/stop-marker files and releases the simulator lease. It never calls `attachment.detach()` and never removes the exact Android forward. On Ctrl-C, `holdForeground` runs precisely that metadata cleanup while `SignalRelay` stops the runner group.

The runner cannot compensate: its `StopUIAutomator2` knows its Unix-socket forward, not the CLI's allocated TCP port. Its unconditional `adb forward --remove tcp:6790` warning targets local port 6790 even though 6790 is the remote/device port. It cannot remove port 55149 and is a separate misleading cleanup defect.

This explains the complete sequence:

- foreground start publishes port 55149;
- hierarchy can use the recorded port while the session lives;
- Ctrl-C stops the runner and removes session metadata;
- the CLI-owned TCP forward remains because its attachment was discarded;
- the following missing-app run cleans up its own probe, but the inherited 55149 remains visible;
- manual helper cleanup removes 55149.

The controller's requested clean before/after reproduction of ready-interrupt is the final device-level confirmation. Static ownership and the recorded port already point to this path with high confidence.

## Missing-app rollback

For a failed launch report, `waitForUIAutomator2` calls `await attachment.detach()` before returning `launchFailed = true`, then detached `abandon()` interrupts and waits for the runner and removes metadata. The clean-baseline reproduction validates this path: forward lists were blank before, immediately after, and one second after. No missing-app fix is justified from the original contaminated sequence.

The detach implementation still suppresses ADB removal errors, but that is a resilience concern rather than the reproduced owner of port 55149.

## Smallest production fix and test seam

Preserve the successful `DriverAttachment` through foreground lifetime and detach it in the existing once-only foreground cleanup. The smallest shape is for `waitForUIAutomator2Port` to return the attachment (or a small result containing both `port` and `detach`) instead of reducing it to a port. `startForeground` can capture it in its `Once` cleanup; detached success intentionally keeps its attachment/forward until `runner stop`, whose teardown path owns broader cleanup.

The narrow regression test should not require a device or real child process:

1. Have the readiness seam return a `DriverAttachment` whose detach closure records the exact owned port.
2. Drive the successful foreground hold through its interrupt cleanup.
3. Assert detach runs exactly once and only after the session was published/held.
4. Also drive ordinary runner exit and assert the same exactly-once cleanup.

An Android-specific integration-level unit can use `AndroidPlatform` with its injected `ADB.execute` closure and assert that cleanup emits:

```text
'/sdk/platform-tools/adb' -s 'emulator-5554' forward --remove tcp:61211
```

The existing failed-launch unit only proves rejected attachments detach. The missing coverage is a **successful attachment released when foreground ownership ends**.

## Runner follow-up

Separately remove or correct `StopUIAutomator2`'s unconditional `forward --remove tcp:6790`. With socket forwarding it should remove the recorded socket; with TCP forwarding it should remove `d.localPort`. Treating the remote port as a local port creates noisy warnings and gives a false impression that arbitrary CLI probe forwards are being cleaned.
