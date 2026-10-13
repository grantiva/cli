# Task 9 Android generation 1 retirement review

**APPROVED as the completed bounded retirement evidence.** The owned stopped generation-1 `cov4-android` was deleted by the exact targeted command; its name is now absent and reserved for the separately governed AND-001 allocation. This review does not create or dispatch a replacement allocation, change result ownership, or override the preserved Swift NONPASS.

Acceptance SHA-256: `ffaec0ff163344c5aba89ed3a694cf12d6d06e986d139d81f3a87cd718150306`.

## Authentication and preconditions

The original primary ownership file independently rehashes to `02d836003f4dad703c87ccb3184880107409c604dfdd360c3b6d2f134f1a6f14`, the guard's expected value. It authenticates owned AVD `cov4-android`, serial `emulator-5584`, PID 82484 and exact launch `-avd cov4-android -port 5584`. The shutdown transition rehashes to `03b5b8fdf03ac0d00cd618223cb9fd1676b9a16ef6d5d292fbce2890d54a31b3`; the bound closeout review rehashes to `93da47591c2c64b7de452695137a9c144f938771819f8217dbdf711fee85518c`.

The retirement guards' registration/config hashes agree with the preceding accepted shutdown/activation records. Retained exact-PID query exits 1 with empty stdout. Retained executable-process inventory contains no emulator or qemu-system executable. Before adb output has no attached serial, and the AVD list still includes the owned name. Guards record the target lease absent and session registry empty. Root identified the exact checked paths as `/private/tmp/grantiva-round4-candidate3-9lkulx9q/runner-home/locks/emulator-5584.lock` and regular files directly under `/tmp/grantiva-sessions`, searched for either target identity. Read-only corroboration confirms the lease is absent and that registry currently has zero regular files or matching records. The historical checks remain controller-recorded observations; this review does not invent a separately retained historical listing.

## Actual command and after-state

The recorded mutation is exactly:

```text
/Users/kyle/Library/Android/sdk/cmdline-tools/latest/bin/avdmanager delete avd --name cov4-android
```

It exited 0 in approximately 0.640 seconds and reported `AVD 'cov4-android' deleted.` No broad deletion or protected AVD target appears in that argv.

Raw before/after adb and forward outputs match byte-for-byte. After AVD output contains only `Pixel_8_API_35`, exactly the before list minus `cov4-android`. Re-normalizing the retained simctl JSON reproduces the acceptance's unchanged four protected/owned iOS records. Pixel config hashes match before/after and the prior guards; a read-only current hash also matches `3caad1a0f9164280a264968a81249241e183fe4981462fbabf9181e4c18eae27`.

Local filesystem inspection independently confirms both `/Users/kyle/.android/avd/cov4-android.ini` and `/Users/kyle/.android/avd/cov4-android.avd` are absent at review time. The primary ownership file still has its original hash; retirement is represented by this separate record rather than rewriting ownership history.

All retained command metadata have expected successful exits except the deliberate absent-PID query's exit 1. The raw records support the narrowly stated deletion and unchanged surrounding-state claims. They are endpoint captures, not a continuous device-event trace.

## Scope

Only existing JSON/raw evidence, ownership/review hashes and local file presence/hash checks were read. No device/process command was rerun, no build/test/network operation occurred, and no source or ownership record was changed. Only this review document was added.
