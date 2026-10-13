# Task 8 candidate 2 docs retry and provisioning review

**Bounded verdict: APPROVED.** Completed docs attempt 2 and provisioning evidence satisfy their reviewed controller contracts and remain bound to frozen candidate SHA-256 `6c0a8bd9da5cff886baf9aceb58394e6ca1632b5b3b10f6aa1bb066aa50be14e`. This is not a full Task 8 acceptance verdict.

## Docs/output attempt 2

- `acceptance.json` reports pass with 172 help pages, 16 corpus tests, zero failures, empty fresh unit home after testing, doctor text/JSON agreement, public migration-note inspection, and successful ambiguous-project text/JSON checks.
- Independent reconstruction from all retained raw help outputs reaches exactly the same 172 unique canonical command paths in manifest order. Every generated help file matches its manifest SHA-256 and corresponding command stdout byte-for-byte; every recorded help invocation exits 0.
- The restored `console flags` subtree contains exactly 22 canonical pages. The comma-rendered `featureflags` alias is correctly not traversed as an additional command. Required representative root, runner-start, run, and doctor pages are present.
- Corpus evidence uses the explicit reviewed Swift scratch path and separate `corpus-test-home`; raw output contains `Executed 16 tests, with 0 failures`, exit is 0, and the fresh runtime home remains empty.
- Normal and ambiguous doctor text/JSON invocations all exit 0. The ambiguous JSON Platform row is an Advisory warning with the exact `Found both an Xcode project and Gradle settings` message, and that message appears in text output. The source-bound docs inspection records every required README and MCP compatibility term and its source lines at CLI SHA `22055ff981ae1ffd5aaae69190d7af180f239162`.
- The initial parser-failure directory `06-docs-output` remains preserved with exactly 150 generated help files and no acceptance record. Attempt 2 is isolated in `06-docs-output-attempt2`; it did not rewrite the failed evidence.

## Provisioning

- Provisioning acceptance passes against the same frozen candidate. Ownership schema/session are exact, and acceptance embeds the same ownership document written during provisioning.
- The new iOS target is exclusively `smoke4-ios`, runtime iOS 26.0, UDID `553C67C6-7C11-4976-85A0-148C9C8AC278`. Create, boot, boot-status, install, and installed-container commands all exit 0.
- The installed Landmarks container records demo source `84af7581b75134b0e417b254e4317d565f7b73c6` and exactly matches the frozen candidate's five-file iOS manifest. All three prepared iOS project configs bind bundle ID `com.kylebrowning.Landmarks` to this new UDID.
- The new Android target is exclusively AVD/name `smoke4-android`, API 35, serial `emulator-5580`, with provision-recorded emulator PID `21620`. Creation uses the exact reviewed system image/device and Java home; wait and exact AVD-identity commands exit 0.
- Pre-provision evidence shows no existing `smoke4-ios`, `smoke4-android`, or `emulator-5580`, and retains the complete simulator, AVD, Android-device, and forward baselines. No stale candidate-1 UDID, PID, source, or configuration binding appears in the provisioning evidence or new iOS configs.
- Both protected owner simulators are present, available, and Booted in the baseline: `B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C` and `FE441EE5-BBFC-4981-B68A-59C0DBCE26D6`. The protected `Pixel_8_API_35` config remains byte-identical to recorded baseline SHA-256 `3caad1a0f9164280a264968a81249241e183fe4981462fbabf9181e4c18eae27` at review time.

This was a raw/static, read-only review. No test, device command, process inspection/change, helper mutation, or live phase was run. The concurrently active Android phase was not inspected or graded.
