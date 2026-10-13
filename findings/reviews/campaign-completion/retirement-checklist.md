# Campaign-owned retirement checklist

Task 1 inventory only. Current targeted observations are retained in adjacent `retirement-inventory/`, with argv, timestamps, exits and raw-stream hashes. No device was changed, signaled, shut down or deleted. No build, test or coverage command ran. This checklist is not a cleanup receipt.

## Current authenticated targets

| Resource | Current observation | Ownership/provenance | Retirement checklist |
|---|---|---|---|
| `cov4-ios-26`, `3B3BBFDB-D435-454F-9DDC-E0CC5EE99E42` | Booted, available, iPhone 17, iOS 26.0 | Root primary-provision ownership, session `cov4-controller` | After actor quiescence and immediate UUID recheck, targeted shutdown then delete this UUID only; preserve before/after metadata. |
| `cov4-ios-27`, `989B2045-96AE-46BF-8E13-C76B563FC6F5` | Booted, available, iPhone 17, iOS 27.0 | Root primary-provision ownership, session `cov4-controller` | Same exact-UUID shutdown/delete procedure; do not confuse with the protected iOS 27 device. |
| `cov4-ios-3`, `C3EEA3D3-9CBF-4E3B-8722-A382CADB0212` | Booted, available, iPhone 17, iOS 26.0 | Actor IOS-008 output and return record; current private created/session registries name this UUID with `sessionId: cov4-ios`, active, `bootedByGrantiva: true` | Target this final UUID only, not earlier same-name generations. Reconcile its private bookkeeping after actual retirement using owned APIs/records. |
| `cov4-ios-4 Pin`, `24A4324A-FFF4-4536-9D3C-982390F3E436` | Booted, available, iPhone 17, iOS 27.0 | Actor IOS-003 ensure output and return record; same private registries record created/active/owned-boot state | Target this UUID only. Preserve source row captures and generation history. |
| Android `cov4-android`, generation 2 | `emulator-5554` attached as `device`; PID 9321 exists, start `Tue Oct 13 15:32:25 2026`, exact qemu argv names `-avd cov4-android -port 5554`; PGID 9321 | Root `android-generation2-reconciliation/ownership.json` matches PID/start/AVD/port; actor returned this running allocation | Reauthenticate same live serial/AVD/PID/start immediately before exact serial-scoped shutdown. Verify serial and PID disappear, then delete only registered `cov4-android` if retirement authority is exercised. Never target prior PID 82484 or serial 5584 for this generation. |
| Android `cov4-android-2`, generation 3 | Registration and `.avd` directory exist. No serial 5556 in current adb inventory. Last recorded PID 17487 is absent. | Root quiet-window return says shutdown-registered generation 3; actor AND-017 retains its launch PID/start/serial and successful targeted teardown; returned created-AVD list includes this name | No live owned PID currently authenticated, so no process signal is justified. Revalidate exact registration/directory identity and no newly acquired lease/session or live serial before deleting this stopped AVD. |

## Process and stale-record distinctions

The primary Android process is currently authenticated against the retained generation-2 record, not inferred from a generic emulator name. Its current `ps` line has parent 1 and the same start time/AVD/port as the original reconciliation. Current adb has exactly one attached device, `emulator-5554`. Current `adb forward --list` is empty.

Recorded prior Android generation-1 PID 82484 is absent; its generation was already retired and its old ownership remains history. Extra Android PID 17487 is absent, consistent with retained AND-017 teardown. No new extra process identity is assumed from the name alone.

The iOS session records still list historical command owner PIDs 9575 and 13506, respectively for Pin and extra3. Both targeted PID checks exit 1 with empty output. These are stale command-owner PIDs, not live simulator-host identities or signal targets. Their absence does not negate the explicit created UUIDs and true boot-ownership records. No CoreSimulator host process identity was collected or inferred; exact simctl UUID operations are the appropriate future retirement boundary.

## Android registration identity

Current read-only local registration/config observations are saved as `retirement-inventory/avd-files.json`:

- `cov4-android.ini` points to `/Users/kyle/.android/avd/cov4-android.avd`, SHA-256 `10c05554067a6a96ae686938dacdc9628201a1fdbf050af27300bb7b4fc99c6e`.
- `cov4-android-2.ini` points to `/Users/kyle/.android/avd/cov4-android-2.avd`, SHA-256 `03fb6c83c69d13e596b960dcf487d111f29975b4f8cbe7415f08d167fb65fafe`.
- Both owned config files currently hash to `3caad1a0f9164280a264968a81249241e183fe4981462fbabf9181e4c18eae27`. This equals the template/protected Pixel config content; equal bytes alone do **not** prove ownership. Paths, creation/return records and generation-specific process provenance establish the distinction.

The extra AVD's stopped status is supported by retained targeted teardown, current absence of its recorded PID and absence of serial 5556. This bounded inventory did not perform a broad process scan, so it does not claim to exclude an unrecorded process on an unexpected port. Any conflicting future observation requires stopping and identifying it, not broad cleanup.

## Protected resources — never targets

- `B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C`, iPhone 17 Pro, iOS 26.0: currently Booted.
- `FE441EE5-BBFC-4981-B68A-59C0DBCE26D6`, iPhone 18 Pro, iOS 27.0: currently Booted.
- `Pixel_8_API_35`: registration/config remain present; no operation against this name is included. Config hash is retained as the protected baseline.

Keep these UUIDs/name, records and files unchanged. Do not use blanket simulator shutdown/delete, pattern kills, adb global cleanup, or name-prefix cleanup.

## Controller retirement sequence to complete later

1. Confirm actors and helper preparation have no active device measurements or launches. Preserve candidate3 raw failures and original ownership files.
2. Recheck the exact targets and protected baselines above immediately before each mutation. Treat mismatched PID/start/UUID/path or new lease/session as unresolved; do not infer continued ownership from stale identity.
3. Retire the four authenticated iOS UUIDs and two Android generations using only exact targeted operations. Running Android generation 2 must be shut down and disappearance verified before its AVD is deleted; the stopped extra has no signal target.
4. Retain per-operation argv/times/exit/raw output, after inventories, protected-state comparisons and updated separate retirement records. Reconcile owned private capacity/provenance/lease records without overwriting historical ownership or deleting unrelated state.
5. Verify only campaign-owned targets disappeared, adb forwards have no unexpected delta, and protected devices/configs are unchanged. Report any unresolved identity or leftover artifact rather than declaring retirement complete.

Current capture includes only simctl device JSON, adb device/forward inventory, targeted ps for five recorded PIDs, and relevant local ownership/registration files. No broad process argv/environment dump was made. Original historical broad captures were not opened or republished.
