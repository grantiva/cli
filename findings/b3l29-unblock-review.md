# B3-L29 unblock review

B3-L29 can close **PASS** from retained runtime plus exact candidate source/tests; no new Gradle or device execution is required.

The retained `findings/evidence/cov3-cli/B3-L29/` proves the literal public/parse surfaces:

- `build build --help` omits `--headless`, `--emulator`, and `--allow-device-settings` while retaining `--device` with its split-APK ABI help.
- The six device-selecting/booting help pages retain `--headless`.
- Both hidden invocations, `build build --headless --module NoSuchModule` and `build build --emulator cov-missing --module NoSuchModule`, parse and enter the identical Gradle build path (`Building :NoSuchModule:assembleFreeDebug...`). They never attempt device resolution or emulator boot; the later Gradle lock denial is a worker-sandbox artifact common to both invocations.

Exact-head tests close the semantics that a third redundant Gradle execution would only corroborate:

- `BuildCommandTests.testBuildBuildHelpOffersNoBootFlags` asserts the hidden flags still parse while help hides them, and preserves the `--device` ABI help.
- `AndroidCommandTests.testBuildBuildOnAndroidNeverBootsTheConfiguredEmulator` proves a configured/parsed emulator has no effect and the call list contains only `build(...)`.
- `AndroidCommandTests.testBuildBuildOnAndroidWithADevicePassesTheSerialWithoutBooting` proves explicit `--device` is checked as attached, passed as the build device ID for ABI choice, and never enters `bootDevice`.
- `AndroidPlatformTests.testBuildWithoutADeviceReadsNoDeviceAndPicksTheHostABI` proves the no-device branch issues no adb call and chooses the host-emulator ABI split.
- `AndroidPlatform.build` uses `request.deviceID` only for `adb getprop ro.product.cpu.abi`, then passes that ABI to Gradle output selection. It contains no boot path.

The regenerated corpus already matches the candidate and `docs/android.md` documents that build-only never resolves or boots a device. The row was blocked solely because the original CLI worker could not acquire its Gradle distribution lock; that environmental limitation does not leave a literal behavioral clause unsupported after the exact semantic joins above.
