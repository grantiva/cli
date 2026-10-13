# Task 9 AND-111 compile collector preparation

Status: **PREPARATION ONLY; HELPER NOT EXECUTED.** No Grantiva command, build, source test, device query/action, network request, install, boot, launch, repack, substitution, or product edit occurred.

## Prepared collector

`task9_and111_compile.py` is a single-purpose controller for the reviewed AND-111 recipe. It pins:

- candidate manifest `d833797d30a794d8cfe9d2dc4646329d4f791667eb8dfa5d17cf417d827f744e`;
- primary provision `d6e638bc6ff4710c95c6e3794e43b431384cfd4bcd163992956de16e99eb7a9a`;
- shutdown transition `03b5b8fdf03ac0d00cd618223cb9fd1676b9a16ef6d5d292fbce2890d54a31b3`;
- approved inputs `99ffb154834385c0be096d5022ee468bc0db8cc78801e68e7c31751c58375e27` and their Markdown review `31205f9a4eefc21a076673e77ff42d59b8d64b007e672272c702d9562072a296`;
- scratch cwd `/private/tmp/grantiva-round4-and111-v87ic72y/android`, frozen CLI `/Users/kyle/.grantiva-qa/bin/grantiva`, frozen runner homes `/private/tmp/grantiva-round4-candidate3-9lkulx9q/runner-home`, JDK 21, and the fixed Android SDK.

The only mutating command encoded is the exact argv `[/Users/kyle/.grantiva-qa/bin/grantiva, build, build]`, with no device argument. `GRANTIVA_API_KEY` is removed. Both runner-home variables are identical and frozen. `GRADLE_USER_HOME` is confined beneath the fresh evidence output.

Before and after compilation, the collector retains bounded raw streams and command metadata for exact CLI/demo HEAD and empty-status checks, `adb devices -l`, `adb forward --list`, AVD registration, PID `82484` absence, and `simctl list devices --json`. It normalizes and compares both protected simulators plus owned `cov4-ios-26` and `cov4-ios-27`. It hashes the protected Pixel config, `cov4-android.ini`, `cov4-android.avd/config.ini`, frozen CLI/bundle/APK/iOS app, and the complete frozen runner-home tree.

The approved scratch manifest must begin with exactly 75 tracked inputs and no generated files. The declared config rewrite hash is checked separately. After the command, every tracked hash must remain unchanged; generated scratch files may occur only below `app/build/` or root `build/`, and at least one generated APK is hashed into `generated-apks.json`. Any other scratch output, device/forward/AVD/PID/iOS/frozen-artifact delta, source drift, timeout, nonzero exit, missing APK, pre-existing output, or input hash mismatch refuses acceptance.

On success the helper writes `acceptance.json` with schema `grantiva.task9.and111.v1`, `passed: true`, exact `candidateManifestSHA256`, `shutdownTransitionSHA256`, `primaryProvisionSHA256`, inputs hash, generated APK manifest, and explicit unchanged/no-install-boot-launch claims. Those candidate and shutdown fields match the source-window helper's external-join contract.

## Fake verification

Exact preparation-only command:

```text
python3 -m py_compile .superpowers/sdd/2026-10-13-round4-fix-wave/task9_and111_compile.py .superpowers/sdd/2026-10-13-round4-fix-wave/task9_and111_compile_fixtures.py && python3 .superpowers/sdd/2026-10-13-round4-fix-wave/task9_and111_compile_fixtures.py
```

Exact output:

```text
...
----------------------------------------------------------------------
Ran 3 tests in 0.042s

OK
```

The fixtures used only temporary files and local fake Python subprocesses. They verify exact stream/result retention and overwrite refusal; the rewritten-config/tracked-input contract; permitted APK output and unexpected-output rejection; and refusal on adb or frozen-identity deltas. They did not invoke the collector's live entry point or any Grantiva, git, adb, emulator, simctl, build, device, or network command.

Root owns execution after Go and independent static review. The helper creates no device and contains no install, boot, launch, shutdown, kill, cleanup, repack, or candidate-write command.
