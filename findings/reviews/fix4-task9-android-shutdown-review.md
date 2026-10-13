# Task 9 targeted Android shutdown review

**Specification verdict: APPROVED. Evidence-quality verdict: APPROVED.** The transition proves the reserved `cov4-android` AVD is created but shut down, preserves its registration and primary ownership, and satisfies the approved source-window controller's shutdown-evidence schema and bindings. No blocking finding was identified.

This is approval of the recorded precondition transition, not source-window execution or a coverage verdict. The AVD remains owned and available for the approved AND-111 sequence and subsequent controller-managed restart.

## Authentication and exact operation

Reviewed `findings/evidence/round4-coverage/android-shutdown-transition/acceptance.json`, every command record and relevant raw streams, immutable primary ownership/provision evidence, and `task9_source_window.py`'s `validate_gate` predicates.

Before mutation, exact-PID `ps` output identifies PID 82484 as the SDK's `qemu-system-aarch64-headless` with `-avd cov4-android -port 5584 -no-window -no-audio -no-snapshot`, matching the primary emulator launch identity. The exact serial's `emu avd name` returns `cov4-android` and `OK`; the ADB inventory contains only `emulator-5584`.

The sole mutating command is SDK `adb -s emulator-5584 emu kill`. It follows the identity and baseline captures, exits 0, and returns `OK: killing emulator, bye bye` plus `OK`. There is no broad kill, device deletion or unrelated serial operation. Command records retain argv, cwd, start/end times, isolated runner home, `cov4-controller` and API key unset; stderr is empty.

## Terminal state and preservation

The final serial inventory is empty. Exact-PID polls transition to exit 1 with empty stdout, including the final poll, establishing PID 82484 absence. Those expected absence-query exits are not command failures. Both final conditions are observed before passing acceptance.

Before/after AVD enumeration is byte-identical and contains `Pixel_8_API_35` and `cov4-android`; no AVD was deleted. The retained registration hash matches current `cov4-android.ini`, whose absolute and relative paths name the owned AVD and whose target is Android 35. Before/after forward tables are byte-identical and empty; no other ADB device was present or changed.

Independently compared normalized raw simulator records for both protected owners and both Task 9 primary iOS devices. All four are present and unchanged after excluding only dynamic size fields. Recomputed protected Pixel configuration hash matches `3caad1a0f9164280a264968a81249241e183fe4981462fbabf9181e4c18eae27`.

## Source-window compatibility

Acceptance records schema `grantiva.task9.android-shutdown-transition.v1`, `passed: true`, state `created-shutdown`, and allocation `{avd: cov4-android, serial: emulator-5584, pid: 82484}`. Independently recomputed bindings match:

- Candidate: `d833797d30a794d8cfe9d2dc4646329d4f791667eb8dfa5d17cf417d827f744e`.
- Zero gate: `561d91c5377c52bb373c53527f267223553b3d8a5af6008e3f9118de4f9531c8`.
- Primary provision: `d6e638bc6ff4710c95c6e3794e43b431384cfd4bcd163992956de16e99eb7a9a`.
- Primary ownership: `02d836003f4dad703c87ccb3184880107409c604dfdd360c3b6d2f134f1a6f14`.

The referenced ownership still equals the approved provision's embedded ownership and preserves the original launch PID/argv; shutdown is represented by this separate transition rather than rewriting ownership. Its candidate/gate paths, owned Android name/serial, single PID and launch arguments satisfy the source-window validator's static predicates. The original Task 8 candidate binding remains unchanged.

Only retained files and registration/configuration bytes were read. No helper, device/process command, test, build or network operation ran. Only this review document was written.
