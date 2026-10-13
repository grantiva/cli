# Task 9 primary provision preparation review

## Verdict

**Specification compliance: CHANGES REQUIRED.** The controller is correctly gated and narrowly provisions the intended three devices, but its final acceptance does not prove protected resources remained unchanged.

**Code quality and safety: CHANGES REQUIRED.** Command timeouts are not captured as terminal evidence, and Android boot polling can take far longer than the stated bounded readiness interval because every poll inherits the 240-second command timeout.

This is a static preparation verdict. Candidate 2 remains failed, the Task 9 zero gate remains absent, and this controller must not be executed.

## Findings

### P1 — final acceptance does not verify protected state after mutation

`task9_primary_provision.py:69-72` captures the two protected simulator records and protected Pixel config hash before the first create, which is the correct baseline. After provisioning starts, however, the controller never captures another simulator inventory or hashes the Pixel config again. Lines 112-113 write `passed: true` while only pointing back to the pre-mutation baseline.

The helper therefore cannot support the required `protected unchanged` claim. An unexpected mutation to either protected simulator or `Pixel_8_API_35.avd/config.ini` during provisioning would still produce a passing acceptance file.

Before writing acceptance, capture fresh simulator and AVD/device inventories and a fresh Pixel config hash. Require both protected simulator records to equal `baseline.json` after excluding only the same dynamic size fields, require the protected Pixel hash to match, and require the three newly owned identities to be the only expected additions. Persist the post-provision records and comparisons even if a comparison fails.

### P1 — timeout failures lose terminal command evidence and boot polling is not tightly bounded

`run()` at lines 50-53 calls `subprocess.run(..., timeout=timeout)` without catching `subprocess.TimeoutExpired`. On timeout it has written only `*-start.json`; it does not persist the exception's partial stdout/stderr or a `*-result.json` recording timeout, end time, and non-success outcome. This affects readiness, install, and inventory commands and falls short of the requested failure capture.

The Android readiness loop at lines 105-109 also calls `run()` without a smaller timeout, so each `getprop sys.boot_completed` poll inherits 240 seconds. The `range(120)` plus one-second sleeps is consequently not a roughly two-minute readiness bound and could stall for hours if adb accepts the serial but individual shell requests hang.

Catch `TimeoutExpired` inside `run()`, persist available stdout/stderr and a terminal result with `timedOut: true`, configured timeout, and end epoch, then re-raise or return a failure that cannot be mistaken for success. Give each boot-property poll a short explicit timeout and enforce one monotonic overall boot deadline; record the terminal timeout against that deadline.

## Correctly implemented controls

- The helper requires a fresh output directory and validates the future Task 9 candidate schema, literal passing Task 8 zero-gate schema, candidate-manifest hash binding, hash-bound review and cleanup artifacts, and a passing cleanup JSON before any command or mutation.
- Frozen CLI, bundle, iOS app and Android APK hashes/manifests and the explicit runner home are validated before inventory. The environment removes `GRANTIVA_API_KEY` and binds both runner-home variables and session `cov4-controller`.
- Simulator names, AVD name, Android serial, emulator ports, protected simulator completeness, Pixel config and all baseline inventories are checked before the first create.
- The requested identities are exact: iPhone 17 on iOS 26 and iOS 27, plus `cov4-android` on Android 35 at `emulator-5584`. There are no broad shutdown, kill, teardown or source-build operations.
- Pending ownership records precede each create. Successful iOS UDIDs are persisted before boot; Android AVD ownership is persisted after create and the exact emulator PID/argv before readiness. These records are suitable for conservative cleanup of partial runs.
- Both iOS installations require complete installed bundle-manifest equality, while Android records the frozen APK hash and requires the package path after installation.

## Scope

I reviewed only `task9_primary_provision.py`, its preparation report and baseline diff. I did not execute the helper, access devices, create a gate, inspect the separate L85 matrix work, or modify product code.

## Scoped P1 fix re-review

**Original P1 findings: RESOLVED.** Helper SHA-256 `ba6f5c9225d50aaa2c56ca9962e85b3e7f11511188b1cd4085a8db03c10e7e87` catches `TimeoutExpired`, normalizes partial streams to bytes, writes stdout/stderr plus terminal timeout metadata, and then re-raises. Boot-property probes use at most three seconds each under a 120-second monotonic deadline, with a durable ready/timeout record. Fresh post-provision simulator inventories and Pixel hashing are persisted before enforcement; protected simulator metadata and the protected Pixel hash must match before acceptance.

**Scoped verdict: CHANGES REQUIRED for one new P2 omission.** The post-state code captures `forwards-after` and puts the before/after filenames into `post-provision-comparison.json`, but it never compares their contents. `onlyExpectedAdditions` checks simulator IDs, AVD names and adb serials only. A changed forward table would therefore still allow `passed: true`, contrary to the fix report's fresh-inventory/no-other-changes claim and the controller's lack of any expected forward mutation.

Add an exact normalized forward-table equality result to the comparison document and require it before acceptance. This is a narrow addition; the repaired timeout, deadline, protected-state and exact owned-device predicates should remain unchanged. No other new breakage was found in the scoped revision.

## Final P2 fix re-review

**Final verdict: APPROVED for future gated execution.** Helper SHA-256 `72be0a9f59c6516549c61cd72b0605510ad41ed07145380732c46e1257c75d8b` resolves the remaining omission without weakening the earlier controls.

`normalized_forwards()` trims and collapses whitespace per nonempty row and sorts the resulting list. It does not convert the list to a set, so duplicate rows and every serial/local/remote field remain significant. The controller now retains the complete raw before/after files, embeds both normalized tables and `forwardsUnchanged` in the durable post-provision comparison, and requires equality before writing acceptance. Ordering and formatting noise cannot fail the run, while an added, removed, changed or duplicated forward does.

The forward check is sequenced with the existing protected-state and exact owned-device predicates after fresh inventories and before acceptance. Gate validation, ownership journaling, timeout evidence, boot deadline, protected simulator/Pixel comparison, and expected device additions are unchanged. No new breakage was found. This approval remains static and does not authorize execution before the future hash-bound Task 8 zero gate exists.
