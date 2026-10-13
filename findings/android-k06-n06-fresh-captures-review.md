# Android B2-K06 / N-06 fresh-capture review

**Verdict: PASS for B2-K06 and N-06.** Evidence root:
`/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-K06-N06-three-fresh-captures-rerun2`.

The harness creates a unique row-owned AVD with `--no-boot`, then performs
three cycles of ensure/boot, explicit APK install, first verbose JSON diff
capture, and targeted force teardown. Each teardown reports `killed: true`.
The three archived qemu process inventories have distinct PIDs 46819, 47215,
and 47543, proving three separate emulator processes rather than three
captures in one boot. Cleanup removes the owned AVD and retains the primary.

Every first capture exits 0, returns all five configured screens, and records
all eight present steps as passed. All five PNGs are retained for every cycle.
No capture exposes a raw socket/connection-refused error, and every cycle has
zero settings-restore warnings. This directly satisfies N-06 and the successful
reproduction branch of B2-K06.

The decoder's `coldBootCommands: false` is an invalid proxy, not a product or
evidence failure. The row requires freshly booted emulator processes; it does
not require the literal qemu `-no-snapshot-load` flag. This AVD was newly
created before cycle one, every prior qemu process was killed before the next
ensure, and the recorded invocations use `-no-snapshot-save`. A missing
`-no-snapshot-load` substring does not erase the three distinct boots.

Exact runner head `fd9d8e8` supplies the conditional failure semantics:
`pkg/uiautomator2/transport_retry_test.go` proves screenshot recovery after
refused connections and a persistent refusal error naming UIAutomator2, the
device, and the retry without repeating the raw cause;
`pkg/driver/uiautomator2/not_found_message_test.go` proves the rendered step
names the unavailable server once. Since all three live first captures pass,
the failure-only runtime branch is properly covered by these named semantic
assertions rather than an induced device failure.
