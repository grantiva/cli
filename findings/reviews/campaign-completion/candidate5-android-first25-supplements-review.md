# Candidate 5 Android first-25 supplements review

## Decision

**APPROVED.** The narrow supplements close the three evidence gaps identified in `candidate5-android-first25-review.md`. AND-001, AND-007, and AND-010 may retain their proposed PASS grades when the original evidence and these supplements are assessed together.

This was a read-only review. It did not review rows AND-020 onward and did not execute product, build, emulator, or device commands.

## Clause closure

### AND-001: `pixel_8` creation definition

The original evidence remains intact and proves the AVD was absent, `grantiva emulator ensure --name cov6-android` created and booted it, stdout was only `emulator-5554`, the AVD name was `cov6-android`, and the owned generation was PID 79955. The adjacent `AND-001/config-current.*` supplement reads only that named AVD's `config.ini` and returns:

- `hw.device.name=pixel_8`
- `image.sysdir.1=system-images/android-35/google_apis/arm64-v8a/`

The command exits 0 without timeout or cleanup failure. This supplies the missing resulting-device-definition observation. It is linked to the original owned generation by the unchanged `cov6-android` AVD identity and the preserved original `ownership.json`; the supplement does not recreate, boot, stop, or replace that AVD.

### AND-007: default image selection

`AND-007/supplement-1/create-default.command.json` repeats the literal default-selection setup: `emulator ensure --name cov6-android-2 --no-boot`, with no `--system-image` and no config image override. It exits 0, stdout is `cov6-android-2`, and stderr says the AVD was created and left Shutdown. The immediately adjacent read-only `config.command.json` inspects that created AVD and records:

- `hw.device.name=pixel_8`
- `image.sysdir.1=system-images/android-35/google_apis/arm64-v8a/`

That path is the config-file representation of the canonical `system-images;android-35;google_apis;arm64-v8a` value. This closes the exact default-image clause. The original `join-and004.stderr` remains preserved rather than rewritten.

### AND-010: exact forward removal

`AND-010/supplement-1` establishes a fresh owned `cov6-android-2` generation on `emulator-5556`, installs the frozen demo APK, and starts the current runner session PID 94920. Its before-list contains exactly two forwards owned by that serial: the UIAutomator2 local filesystem forward and `tcp:57231 -> tcp:6790`. The public `grantiva emulator teardown --serial emulator-5556` exits 0 and explicitly reports stopping PID 94920 and killing `cov6-android-2`. The global `adb forward --list` after-capture is empty, and the adb device after-capture contains only the separate primary `emulator-5554`. This closes the previously missing after-observation and preserves the original AND-010 command set.

The supplement is internally generation-consistent: ensure selects `cov6-android-2`/`emulator-5556`; runner start, both forward observations, teardown, and adb absence use the same serial, while the runner PID and dynamic port match between runner-start output, forward list, and teardown output.

## Provenance and preservation

Every supplement command records exact argv, cwd, environment, times, exit status, and raw streams. All supplement identity files bind immutable candidate manifest SHA-256 `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`; all expected/actual binary, bundle, archive, and installed-runner hashes match. The only nonzero read-only observations in the original AND-001 directory are the intentional no-match preflight scans (`pid-scan-after` and `ports-before`), not supplement failures.

The initial first-25 checkpoint, its manifest, raw commands, and the first independent CHANGES REQUIRED review remain preserved. These supplements add evidence; they do not conceal or overwrite the earlier gaps.

## Committed evidence binding

The correction is committed as `360e15bb8`. Its `first25-fix1-manifest.json` has SHA-256 `ff7f1c03f9c734549017c9c7db121fa9a89cd7b7da6dd385c040cb5999ef7b8d`; all 40 listed artifacts exist and match their recorded SHA-256 and byte count. The manifest itself is intentionally the enclosing index rather than a self-entry.
