# iOS attempts123b, 124, and 126 review

## B3-L22 [ios] — attempt123b

**Approve pass.** Two fresh, row-created iOS 26 devices run the real app first, producing their exact versioned runner homes. On the first device, an immutable `locked` child makes both text and JSON teardown exit 1. The text error names the exact home and OS reason, has exactly one period before `Delete it by hand.`, and has no doubled period. JSON preserves a nonempty `deviceHomeFailures` entry with the same home/reason. Removing the flag allows the clean teardown to exit 0. The recreated second device exercises `simulator delete`: deletion exits 0, emits the warning with the same punctuation shape, and the final device inventory contains neither fresh UUID. The retained SimulatorCommand/WDADeviceHome test excerpts pin the same formatting paths. Cleanup is complete and no campaign-owned simulator is involved.

## B3-L54.1 [ios] — attempt124

**Approve pass.** Each of three independent foreground starts publishes an owner record before teardown. From the separate `/private/tmp/cov3-ios-attempt124/other-cwd`, targeted `simulator teardown --udid ... --force --json` exits 0. Each foreground parent exits 0 and ends with `Runner stopped by teardown (pid N); the session has ended.` The saved owner record ties the message to the exact runner PID. Each `N-clean` is `1`, meaning the bounded post-exit polling found neither global session files for that runner PID nor a matching grantiva-runner/xcodebuild/simctl-diagnose process for the owned UDID. This satisfies the three-run, early teardown, other-cwd, exact-message, and cleanup clauses. The protected U1 device remains; only the foreground sessions are reclaimed.

## B2-K107-a [ios] — attempts126 + 103b + 106c

**Approve pass.** Attempt126 supplies the previously missing read-only runner-home inventory: five version-scoped `install-*.lock` files remain, including `install-1.1.28-grantiva.13+android-drivers-2.lock`, with paths, metadata, and hashes retained. Attempt103b records device-lock state around normal runner stops. Attempt106c proves the manual device lock is absent after normal run, session teardown, and guarded delete. Exact-head `SimulatorLeaseTests` cover release unlink and the concurrent acquire/release/unlink race, while the WDA device-home test covers deletion pruning. The matrix permits the listed lifecycle alternatives to be joined; it does not require repeating every path in one run. The current runtime plus exact semantic assertions cover device-lock release/pruning, concurrency, and install-lock preservation.

The three ledger grades and their cited evidence are accurate. No further runtime complement is needed for these rows.
