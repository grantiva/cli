# Android N2-16 rerun4 review

Verdict: pass by joined evidence, with the harness's rejected wall-clock proxy excluded.

The exact teardown leg starts `11-slow.yaml` on the row-owned secondary and invokes `emulator teardown --serial emulator-5556 --force --json` mid-flow. Teardown returns zero, reports the exact AVD/serial and `killed: true`, and adb no longer lists that serial. The run reaches Android settings restoration and prints the required absent-device branch: it waits up to 5 seconds and then emits one warning that the serial did not return within 5 seconds.

The harness's 70.47-second teardown-to-process-exit measurement is not a restoration measurement. Most of it is subsequent runner lookup retries, report generation, and failure artifact work. It is excluded rather than treated as a product timeout.

The direct-death control isolates the same restoration branch. A saved `ps` inventory selects exactly one QEMU process by the exact `-avd cov3-android-n216-r4` argument, and the row kills that PID. The live parent-side line observer records the restoration-start message at monotonic `481714.693956125` and the matching one-warning give-up at `481720.145684375`: 5.451728 seconds. `posthoc-restoration-timing.json` preserves that calculation. Later process/report shutdown again does not redefine restoration time.

Exact-head `AndroidCaptureSettings.swift` sets `reconnectTimeout=30` for a listed/offline serial and `absentGrace=5` for a serial absent when restoration begins, removes the state file with `defer`, and sends no further settings after the one warning. `AndroidCaptureSettingsTests.swift` covers offline retry, the absent short grace, one-warning behavior, state-file removal, and a second disconnect. These close the 30-second offline clause that cannot be deterministically held by the runtime fixture.

The fresh-capture half joins `B2-K06-N06-three-fresh-captures-rerun2`: three distinct fresh QEMU processes each complete their first configured capture with all five screens/eight steps passing, targeted teardown between boots, no raw-socket failure, and no snapshot-restore warning. The N2-16 row-owned AVD is removed by the EXIT cleanup (`trap-delete.json` reports `deleted:true`); the protected primary is the only device in the retained post-teardown adb inventory.
