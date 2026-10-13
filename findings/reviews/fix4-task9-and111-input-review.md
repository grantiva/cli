# Task 9 AND-111 scratch-input and recipe review

**APPROVED as prepared input and command recipe.** No input-copy or recipe defect found. This is not an AND-111 row verdict, proof of compilation, or approval of future execution independently of the controller's remaining gates and scheduling.

Reviewed input manifest: `findings/evidence/round4-coverage/and111-inputs/manifest.json`, SHA-256 `99ffb154834385c0be096d5022ee468bc0db8cc78801e68e7c31751c58375e27`.

Candidate manifest SHA-256 independently matched `d833797d30a794d8cfe9d2dc4646329d4f791667eb8dfa5d17cf417d827f744e`.

## Input verification

- Frozen demo real checkout is `/Users/kyle/Developer/landmarks-demo/.worktrees/release-round4-candidate2`, currently at `84af7581b75134b0e417b254e4317d565f7b73c6` with empty porcelain status.
- The retained NUL-delimited tracked-input list exactly matches the 75 Android paths in the frozen HEAD tree and the manifest order. Retained inventory stderr is empty.
- `/private/tmp/grantiva-round4-and111-v87ic72y` contains exactly those 75 files, with no extra files or symlink files. All current source hashes match the manifest, and all source/copy mode bits agree. The copied `android/gradlew` remains executable, mode `0755`.
- All current scratch file hashes match their source except `android/grantiva-android.yml`. Its sole byte change is `emulator: Pixel_8_API_35` to `emulator: cov4-android`. The retained before/after configs exactly match the source/current scratch configs. The scratch config hash is `ff9bfdb640cc8894eeee6de2df6d200c266c10c5feb9d06698a28b5cac7d63c5`. The manifest's per-file copied hash represents the copy before this declared rewrite; its separate config entry records the final scratch hash.

## Reviewed future command recipe

The matrix AND-111 compile-only criterion and approved source-window preparation govern this root-owned operation at the end of the source window. The manifest's `argv` is the completed input-inventory command, not the proposed compilation command. The controller's supplied compile recipe is fixed here as:

```json
{
  "argv": ["/Users/kyle/.grantiva-qa/bin/grantiva", "build", "build"],
  "cwd": "/private/tmp/grantiva-round4-and111-v87ic72y/android",
  "unset": ["GRANTIVA_API_KEY"],
  "environment": {
    "GRANTIVA_RUNNER_HOME": "/private/tmp/grantiva-round4-candidate3-9lkulx9q/runner-home",
    "MAESTRO_RUNNER_HOME": "/private/tmp/grantiva-round4-candidate3-9lkulx9q/runner-home",
    "JAVA_HOME": "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home",
    "ANDROID_HOME": "/Users/kyle/Library/Android/sdk",
    "ANDROID_SDK_ROOT": "/Users/kyle/Library/Android/sdk"
  }
}
```

There is no `--device` argument. The executable's current SHA-256 matches candidate value `1b6a973b63a750691bcb76a710a97f346d331fe44ef60f6c50bef0f6d35e4731`; both home paths match the candidate. The named JDK21 and SDK directories exist. The command compiles the scratch Android project and does not substitute the frozen CLI, runner, app, or APK.

Before and after the future command, root retains responsibility for fresh existing-AVD/shutdown identity proof, exact owned PID absence, byte-preserving adb inventories, forwards, protected iOS and AVD-config comparisons, bounded command metadata/raw streams and scratch build artifact hashes. Successful compilation with unchanged shutdown/device state remains unproven until that evidence exists; no install, boot, launch or candidate substitution is authorized by this review.

## Review boundary

Only small local file/hash/mode comparisons and read-only Git HEAD/status/tree inspection were performed. No tests, builds, device queries, live operations, network calls, source edits or helper edits occurred. Only this review document was added.
