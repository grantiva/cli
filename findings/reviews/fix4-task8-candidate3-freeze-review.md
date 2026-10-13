# Task 8 candidate 3 freeze review

## Verdict

**Specification verdict: APPROVED.** Frozen candidate manifest SHA-256 `e9cfc7dce72ba8125b7c55df8d3dec355925003de24a4131c6510b9e67c51ebf` is internally consistent and matches the current bytes, complete artifact manifests, clean source checkouts, raw build records, upgrade records, and preserved-cache evidence. Candidate 3 is suitable as the immutable identity input for documentation and device provisioning.

**Evidence-quality verdict: APPROVED.** The controller records exact argv, cwd, isolated homes, API-key-unset state, session, timestamps, exit status, and raw streams for each build/release operation. Its assertions bind promotion and upgrade to the artifacts later frozen in `candidate.json`. No identity or provenance gap was found.

This approves identity/build/upgrade freeze only. It is not Task 8 acceptance; candidate 3 still requires the planned complete device, transport, lifecycle, and cleanup smoke.

## CLI source, build, and promotion

- The manifest names merged CLI HEAD `6ba12ed37658228a3ce87cb64e1f5d88dda38e07` at `release-round4-candidate3`. The checkout currently resolves to that HEAD with empty porcelain status, matching both source-before and source-after records.
- The release build used exact argv `swift build -c release --scratch-path /private/tmp/grantiva-round4-candidate3-9lkulx9q/swift-build-scratch`, a separate empty build home, API key unset, and session `fix4-8-c3`. It exited zero after about 61.5 seconds. The separate show-bin-path record resolves beneath that scratch tree.
- The source-after record binds the produced binary to SHA-256 `1b6a973b63a750691bcb76a710a97f346d331fe44ef60f6c50bef0f6d35e4731`; the promoted QA binary has those exact bytes and reports version `2.1.0`.
- The QA adjacent bundle has exactly four files. Recomputing every file digest and the canonical manifest digest yields `b03433043f01599928e47b016e1dbd5b7efd3fbeddb47380db37b7711f31607d`, matching both the build output and frozen candidate.
- Before promotion, the controller required the QA binary and bundle to match candidate 2, copied them into `previous-qa-candidate2`, and verified the backup. Independent byte comparison confirms the backup binary and complete bundle still match the candidate 2 manifest.

## Runner upgrade and cache

- The runner source checkout is clean at `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`. Every declared file in the approved uncached metadata-complete Go proof still matches its frozen SHA-256.
- The extracted packaged runner and installed runner are byte-identical at SHA-256 `9342b8a3d17b9063c399ecab6cd8681cefa3bce91a21de65473147b54ef9a37b`. Both version records identify `1.1.28-grantiva.15`, commit `ba9008f`, Go 1.27.1, and darwin/arm64; the installed path carries stamp `1.1.28-grantiva.15+android-drivers-2`.
- The APFS clone command and record preserve the pre-upgrade owner tree: source-before and clone-before contain the same 8,593 rows. A fresh read of the clone finds no mismatched file, size, digest, or symlink target. All 8,069 pre-existing cache entries remain intact.
- The approved WDA manifest contains 800 files across four configurations, 200 each. Rehashing both extracted bundle content and installed runner-home content against that manifest finds zero mismatches. Upgrade acceptance correctly marks all four configurations complete and bundle-added.

## Demo builds

- The demo checkout is clean at `84af7581b75134b0e417b254e4317d565f7b73c6`. Both fresh build records bind their start/result source identity to this commit, use the isolated candidate session and empty homes, finish at the same clean HEAD, and exit zero.
- The iOS build uses its explicit fresh derived-data path and records `** BUILD SUCCEEDED **`. Its app has exactly five files; recomputed hashes and canonical manifest digest equal frozen digest `b9619e1d41004db3edcd1537381f5b1285925071546a762ff6af06f8d14e2074`.
- The Android build uses `./gradlew clean assembleFreeDebug --no-daemon`, records `BUILD SUCCESSFUL`, and its APK bytes match SHA-256 `5891bf3753eade9ce28a391ec5d8d3d289d195af951e967b67bb1928e06d988a`.
- Every demo build-proof path in the candidate manifest currently hashes to its declared value.

## Scope

This was a read-only review of the approved controller, frozen manifest, source state, artifact bytes, and raw build/upgrade evidence. I did not build, test, provision a device, run a live helper, or modify release artifacts.
