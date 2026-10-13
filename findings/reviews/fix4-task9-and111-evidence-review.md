# Task 9 AND-111 completed evidence review

**APPROVED as AND-111 compile-only evidence within the reviewed observation boundary.** The actual command compiled successfully with the required shutdown precondition and unchanged before/after device and frozen-input records. No retained-evidence integrity defect was found. This does not make the candidate or whole source window clean: the preserved Swift full-suite NONPASS remains authoritative.

Acceptance SHA-256 independently verified: `d0bc4396e95c2c4bdfdf633afbab7bc3c410b4e2c96848508d03726ff22cd921`.

## Raw evidence integrity and command

All 62 retained files in `findings/evidence/round4-coverage/source-window/and111` independently match the originals under `/private/tmp/grantiva-round4-source-window-1stf8uih/and111`. All 19 command result records have matching stdout/stderr hashes, expected exits and no timeout. The invocation record identifies reviewed helper `d1cdc4073e5a26a57d63d246b8840fc655b6d670b4f0ea61fcd920138ac588c9` and controller session `cov4-controller`.

Actual compile argv is exactly `[/Users/kyle/.grantiva-qa/bin/grantiva, build, build]`, without a device argument, from `/private/tmp/grantiva-round4-and111-v87ic72y/android`. Command-start records API key unset, both candidate runner homes, JDK21, the approved SDK and an isolated evidence-root Gradle home. Compilation exited 0 in 87.416 seconds. Raw stdout reports `Build succeeded`, the scratch APK path and 87.4-second duration; stderr reports building `:app:assembleFreeDebug`. Compile stdout/stderr hashes are respectively `90cf5943b529fe6e724d9221e327f3d19316030e9da2174a1b712c0402d471fd` and `f1a2c124583e5ca8b6142ceafce5021459b5116ee753816ad5027d70c9fdad63`.

## Shutdown and protected-state evidence

The underlying raw captures, rather than acceptance booleans alone, establish:

- Before and after AVD lists contain both `Pixel_8_API_35` and literal `cov4-android`, in identical output.
- Both raw `adb devices -l` streams are byte-identical `List of devices attached\n\n`: no attached serial exists, including `emulator-5584`.
- Both exact `ps -p 82484 -o pid= -o command=` queries exit 1 with empty stdout, showing the recorded owned emulator PID absent at both observations.
- Forward lists are byte-identical, each a newline with no forwarding entry.
- Recomputing the normalized records from raw simctl JSON reproduces each snapshot's four selected iOS records. Both protected iOS devices and owned `cov4-ios-26`/`cov4-ios-27` remain identical after excluding only the documented dynamic size fields.
- Snapshot Pixel-config, owned AVD config and registration hashes are unchanged. Pixel and registration hashes match the pinned independently accepted shutdown transition. The registered AVD therefore existed rather than being omitted to simulate a shutdown precondition.

All snapshot top-level fields other than scratch generated outputs are equal before/after.

## Candidate, source and scratch provenance

Candidate, provision, shutdown and input-manifest files independently rehash to acceptance bindings. Candidate is `d833797d30a794d8cfe9d2dc4646329d4f791667eb8dfa5d17cf417d827f744e`; input manifest is `99ffb154834385c0be096d5022ee468bc0db8cc78801e68e7c31751c58375e27`.

Raw before/after Git records show frozen CLI `6ba12ed37658228a3ce87cb64e1f5d88dda38e07` and demo `84af7581b75134b0e417b254e4317d565f7b73c6`, both with empty porcelain status. Frozen snapshots agree for CLI, bundle, installed runner, APK, iOS app and runner home. CLI/APK/installed-runner hashes match the candidate. The runner-home manifest contains 12,580 entries, including the actual version/cache symlink target and modes; its serialized digest was independently recomputed and agrees before/after.

The before scratch snapshot has exactly 75 declared tracked inputs and no generated files. The after snapshot preserves all 75 hashes, including the approved `emulator: cov4-android` config, and has no unexpected links or special entries. Its 827 generated files are confined to the allowed build and project-cache roots. Current scratch tracked files were independently rehashed and still match those captured values.

The sole generated APK is retained only in the scratch build path. Its 9,168,893 bytes independently hash to `5891bf3753eade9ce28a391ec5d8d3d289d195af951e967b67bb1928e06d988a`, matching `generated-apks.json` and acceptance. Equality with the frozen candidate APK hash is reproducibility evidence; the scratch product does not replace the candidate artifact, and the frozen snapshot remains unchanged.

## Limits and disposition

The exact compile-only command, successful assembly output, empty device/forward inventories and unchanged shutdown/protected records support the no-install/no-boot/no-launch claim under the approved before/after protocol. These are endpoint observations, not a continuous process or adb event trace; they do not independently exclude an unrecorded transient external action. No such action is evidenced. The recorded CLI output reports one warning without printing its detail; no Gradle warning text or complete nested subprocess event log is invented here.

The archive intentionally excludes the Gradle user cache and retains build products separately in scratch. The actual APK was checked; this review does not claim to have rehashed every generated intermediate or every runner-home file from the live filesystem. Protected file hashes and frozen-tree comparisons are captured collector evidence, while raw device streams, candidate references, archive equality, runner-manifest digest and scratch input/APK bytes were independently checked as described above.

No rerun, build, device query, network operation, source change or matrix grade was performed. Only local retained evidence and scratch files were read, and only this review document was added. Aggregate closeout must retain the Swift failure and outstanding non-source joins separately.
