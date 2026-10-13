# Task 8 candidate 3 provisioning review

## Verdict

**Specification verdict: APPROVED.** The provisioning run is bound to frozen candidate manifest SHA-256 `e9cfc7dce72ba8125b7c55df8d3dec355925003de24a4131c6510b9e67c51ebf`, created only the two candidate 3 smoke fixtures, recorded ownership before subsequent use, installed the exact frozen iOS app, and retained the protected-resource baseline needed for final cleanup.

**Evidence-quality verdict: APPROVED.** The raw command records, stdout, ownership document, installed-app manifest, emulator PID, AVD identity response, and acceptance document agree. This verdict covers provisioning only. It does not claim that either device has been cleaned up or that protected resources remain unchanged through the campaign; those comparisons belong to the final cleanup review.

## Frozen candidate and ownership binding

- `acceptance.json` records the same candidate manifest hash independently verified by the freeze review. Its embedded ownership object is byte-for-byte equivalent as parsed JSON to `ownership.json`.
- Both devices use session `fix4-8-c3`, the frozen candidate's isolated runner home, and commands with `GRANTIVA_API_KEY` unset.
- iOS ownership names UUID `33BCE8AB-B7F2-4D47-B0B8-2CB1D8A1971E`, name `smoke4-c3-ios`, runtime iOS 26.0, and the literal successful creation command using iPhone 16 Pro. The ownership timestamp precedes command execution completion, and the returned creation stdout is exactly that UUID.
- Android ownership names serial `emulator-5580`, AVD/name `smoke4-c3-android`, API 35, and PID 61153. It retains the exact successful Java 21 `avdmanager` creation command and the exact emulator launch argv with port 5580.

## Collision checks and exact operations

The pre-mutation records show no simulator named `smoke4-c3-ios`, only the protected `Pixel_8_API_35` AVD, no connected Android device at serial 5580, and an empty ADB forward table. The controller therefore had evidence that both requested names and the Android serial/port identity were unused before creation.

All recorded provisioning commands exited zero. The iOS commands target only the returned UUID for boot, readiness, install, and app-container resolution. Android creation targets only `smoke4-c3-android`; the launched process is immediately persisted as owned PID 61153, the bounded boot polling reaches `sys.boot_completed=1`, and `emu avd name` returns `smoke4-c3-android` followed by `OK`.

## Installed app identity

The iOS install command names the exact app path frozen in candidate 3. The exact-device app-container lookup returned a path under UUID `33BCE8AB-B7F2-4D47-B0B8-2CB1D8A1971E`. Its retained installed manifest identifies demo source `84af7581b75134b0e417b254e4317d565f7b73c6` and exactly matches all five paths and hashes in the frozen candidate manifest. A read-only recomputation of the current installed bundle still matches those five entries.

Provisioning intentionally does not install the Android APK. The later Android runner smoke owns that installation step and is required to bind it to the frozen APK hash before use.

## Protected baseline reserved for cleanup

The pre-provision simulator inventory records the two protected booted owners:

- iOS 26 UUID `B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C`, `iPhone 17 Pro`;
- iOS 27 UUID `FE441EE5-BBFC-4981-B68A-59C0DBCE26D6`, `iPhone 18 Pro`.

The protected Pixel configuration baseline is SHA-256 `3caad1a0f9164280a264968a81249241e183fe4981462fbabf9181e4c18eae27`; its current bytes still have that digest. The initial ADB forward baseline is empty. Final cleanup must compare these exact protected simulator states, Pixel hash, and forward baseline after physically deleting only the owned iOS UUID and Android AVD/process. This review makes no early cleanup claim.

## Scope

This was a read-only review of retained provisioning artifacts and file identities. I did not issue simulator, ADB, emulator, process-control, build, test, or live smoke commands.
