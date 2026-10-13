# Task 8 candidate 2 release / upgrade / freeze review

**Verdict: APPROVED.** Frozen candidate 2 is internally consistent with the reviewed release controller and approved candidate identity helper. No blocking provenance or artifact-integrity issue was found. Provisioning and live smoke may proceed after the separately running docs phase completes successfully.

This was a bounded read-only acceptance review. No build, test, device command, helper mutation, or new candidate execution was performed. The incomplete docs/output phase was explicitly excluded from this verdict.

## Frozen identity

- `candidate.json` has exact SHA-256 `6c0a8bd9da5cff886baf9aceb58394e6ca1632b5b3b10f6aa1bb066aa50be14e` and schema `grantiva.task8.candidate.v1`.
- CLI source HEAD is clean at merged commit `22055ff981ae1ffd5aaae69190d7af180f239162`. Its tree is `aff5078c66e44e973b5fed6625ff279ae62d4eec`, exactly matching reviewed pre-merge commit `53b34ea38a82426a8dfd150fa64911ebbdb901aa`. The retained merge record identifies PR 214 and successful CI run 38459262712.
- The current promoted binary hashes to `33c62e613703ddbd701a178028e099677b900deb003dceb02c74d86214555c37` and reports `2.1.0`. The current QA bundle exactly matches its four-file manifest and canonical manifest SHA-256 `da9adff34144cfe898e85d806b0a63e36be4b063b72ed902db8c8dc06efb6144`.
- Runner source HEAD is `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`. Packaged and installed native runners both hash to `9342b8a3d17b9063c399ecab6cd8681cefa3bce91a21de65473147b54ef9a37b` and currently report the frozen multiline `.15` native identity with commit `ba9008f`; the installed path and stamp are `1.1.28-grantiva.15+android-drivers-2`.
- Demo source is clean at `84af7581b75134b0e417b254e4317d565f7b73c6`. The APK currently matches SHA-256 `5891bf3753eade9ce28a391ec5d8d3d289d195af951e967b67bb1928e06d988a`; the iOS app exactly matches its five-file manifest and canonical hash `7ad95bb8fb5db89eb9d9b29950b94de880a5d4bba1fee3a8dbfbd65dca8af394`.

## Build, preservation, and upgrade evidence

- The successful release build and bin-path lookup use the same fresh explicit scratch path `/private/tmp/grantiva-round4-candidate2-ciz5f2kj/swift-build-scratch`. Raw timestamps record a build interval of approximately 62.528 seconds; the source is clean before and after, the separate build runner home remains empty, and the promoted products resolve inside that scratch directory.
- Candidate 1 was preserved before promotion. Its backup binary matches the old manifest hash, its bundle matches the complete old file manifest, and its copied `candidate.json` is byte-identical to the retained candidate 1 manifest.
- Upgrade ran through `/Users/kyle/.grantiva-qa/bin/grantiva runner install --json` with session `fix4-8`, the API key unset, the owned clone as runner home, and exit 0. The installed runner is byte-identical to the extracted packaged runner.
- Clone evidence records exact equality between the source and APFS-clone inventories at 8,593 entries. The post-upgrade review independently rechecked all 8,069 pre-existing cache entries against their frozen hashes.
- The approved Task 7 WDA manifest remains pinned by SHA-256 `48c95fede130e55ad3ec7cb018dfa487807a319dfe8274f5cf75ef6ca9390c5c`. All 800 files across the four 26.0, 26.2, 26.4, and 27.0 `wda16.12.8-r1` configurations currently match their approved hashes in the upgraded home; the controller records each as a complete bundle-added 200-file config.

## Qualification proof

- All 14 governing `go-test-uncached-metadata-complete` artifacts match the raw hashes frozen in the manifest. The approved validator's semantic runner-proof check passes against the current runner source: exact metadata-complete directory and names, clean source before/after, API unset, session `fix4-7b`, count 1, distinct fresh empty homes, exit 0, empty stderr, root no-test record, and numeric uncached success records for device, executor, report, CLI, and uiautomator2.
- Every frozen demo build-proof path/hash matches current raw evidence. iOS and Android start/result/artifact records bind to 84af, their exact build commands and fresh homes, API-unset `fix4-8`, successful exits, ending HEADs, and final clean qualification. The iOS transient Android `.kotlin` status is retained truthfully and reconciled by the post-build qualification after both concurrent builds finish cleanly.
- The approved identity helper's runner-proof, demo-source, resource-bundle, and iOS-app semantic checks pass directly against the frozen manifest and current artifacts. A complete CLI invocation is intentionally deferred because the controller-owned ownership manifest does not exist until provisioning; the reviewed phase wiring performs that full ownership/device preflight before live MCP startup, while each other reviewed helper validates before its cases.

This approval covers release build, QA preservation/promotion, runner upgrade/cache qualification, demo build provenance, and candidate freeze only. It does not grade docs/output, provisioning, live smoke, force teardown, manual physical cleanup, or the final Task 8 gate.
