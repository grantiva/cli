# Candidate 5 CLI batch 08 fix 1 review

Scope: `B-A10.4` and `B-A12.3` supplements only. The original broad-name assessments remain preserved; the other 23 batch08 rows were not reopened.

## Verdict

- **Spec: APPROVED**
- **Evidence quality: APPROVED**
- **B-A10.4: PASS**
- **B-A12.3: PASS**

`B-A10.4-supplement-1/exact-tests.stdout` retains the exact test bodies and assertions for all three canonical requirements:

- `testAndroidOwnershipErrorNamesTheEmulatorCommands` asserts the Android ownership message names the emulator and both `grantiva emulator` recovery commands.
- `testAndroidInstallResultJSONUsesAndroidKeys` asserts the exact Android JSON key set plus `applicationId` and device name/serial, and excludes iOS keys.
- `testFailedAndroidBuildPrintsNoSchemeLine` asserts a failed Android build contains neither `Scheme:` nor `APK:`.

The capture also records current file hashes `b6bfc7bebfb5c13cb87d1ca4c41a8c05ab0f8169dc1ca02744f44b0edeff6bfd`, `3d44ca473eb9c317dab0bd9a546b14662400b13ea4bc7b61cfbeb1f2ebd4f67a`, and `d308cf01d7fd01321b965cfb73acd45a165540adefeeb226ac5976855eb27098`. Its output SHA-256 is `e1b0a1b0c9d158211e440754331c04545261f9734d53f45ecc33d1609619053a`.

`B-A12.3-supplement-1/exact-tests.stdout` retains `testGitCheckPassesInASubdirectoryOfAWorkTree`, including the nested-directory setup and detected/OK assertions, and `testGitCheckWarnsWithNoAncestorGitEntry`, including warning and `Run: git init` assertions. The current `DoctorTests.swift` hash is `f5408dd044a343cd528a806030ca369ef1f3b8de5441ed3820bdb2292616b8ce`; the capture output hash is `022e6e4a46a269dd4df4d3206b2c979be8021953477c4fd9284febbc225b96de`.

The accepted candidate5 full Swift proof directly records all five named tests passing and completes with 2,027 tests and zero failures. Its stdout SHA-256 is `96e0e82c1b8ac6eec5d975c8a465ea46efa9cdee9675fa81476e97ca591ef552`; exit proof SHA-256 `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa` records exit 0. The candidate5 source evidence map binds that suite to the functional source baseline and the bounded packaging-only candidate delta.

Both supplement captures bind candidate manifest SHA-256 `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c` through identity record SHA-256 `eab8f2b9c63ee0526e92f967e5c9b3e4e116df607069bedf0e4d00635f92e047`. Corrected verdict hashes are `7441eced65b75d3e18052231f38f37f653de2c97f20d52ef3599fcc65e36bbc0` and `7335ba539f55e03f0bd97d480b98664b3515e7f7980961a374f9147f2ccccfde`.

These supplements close both gaps from the initial batch08 review. Batch08 is now supported at 25 PASS.
