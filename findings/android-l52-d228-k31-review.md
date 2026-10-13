# Android B3-L52 and D2-28/B2-K31 review

## B3-L52 [android]

**Approve pass from rerun4.** `B3-L52-keepalive-starting-rerun4/run/owner-at-start.json` proves the row-owned keep-alive owner was published before the project session existed. During that interval, `starting-hierarchy.err` and `starting-dump.err` both exit 1 with the exact retryable UIAutomator2-starting text, and `starting-mcp-tree.json` returns the same text as `isError: true`; none uses no-session advice. The saved `ready-results.json` then records success for all three surfaces after 12 attempts, and the retained final hierarchy/dump/MCP results are real trees. The stock run earns exit 0 and targeted stop exits 0. Exact-head `docs/dump-hierarchy.md:57`, `docs/mcp.md:42-56`, and `docs/android.md:202-204` describe the same shared lookup and starting behavior.

Rerun2 remains useful only for its valid starting observations. Its ready polling assumed a shared keep-alive session would be published before the terminal hold and therefore cannot grade the ready half. Rerun3 is diagnostic evidence that the slow flow retains the starting publication until its terminal hold; it has the same invalid mid-flow ready assumption. Neither is needed for the pass, and neither should be counted as a product failure. Rerun4's quick stock flow supplies the valid starting-to-ready transition and all eight decoded checks.

## D2-28 [android]

**Approve pass.** `D2-28-invalid-system-image-rerun1` executes the literal `android-99/bogus/arm64-v8a --no-boot` input and exits 1. `stderr.txt` contains one normalized Grantiva error naming the exact package, sdkmanager's `Package ... not found` reason, and the installed Android 35 image. It contains no `Creating AVD`, doubled `Error: Error:`, or trailing `null`. `decoded.json` confirms all seven checks; the before/after AVD, created-ledger, started-device, and adb snapshots prove no AVD or device was created and unrelated state was unchanged.

## B2-K31 [android]

**Approve pass by joining the same D2-28 runtime with exact-head semantics and retained successful ensures.** The runtime above covers the literal failure path. `Tests/GrantivaCoreTests/EmulatorManagerTests.swift:1018-1078` pins the zero-exit-but-missing-directory failure, prevents the avdmanager call, preserves sdkmanager's nonzero exit, captures both streams, and normalizes avdmanager's leading `Error:`/trailing `null`. Current lifecycle batches such as `MCP059-062-D235-emulator-lifecycle-rerun1` retain successful ensure/create/delete controls, satisfying the successful-install/creation branch. No further invalid-image run is needed.
