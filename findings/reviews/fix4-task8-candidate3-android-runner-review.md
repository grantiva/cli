# Task 8 candidate 3 Android runner-smoke review

**Specification verdict: APPROVED for the complete candidate-3 Android runner phase.** The fresh phase passes healthy stock, five bounded matching-PID crash decisions, all four L51 gesture forms, five favorite removals, literal `clearState` plus bare `stopApp`, optional/required result semantics in text and JSON, and the canonical subdirectory cycle control.

**Evidence-quality verdict: APPROVED.** Candidate, runner, demo, device, fixture, command, report, timing, movement, output-surface, and cleanup evidence agree. No unsupported success claim or material contradiction was found. This verdict covers `02-runner-android` only and does not assess the concurrently running lifecycle phase or overall Task 8 completion.

## Frozen identity and inputs

- Helper provenance binds candidate manifest SHA-256 `e9cfc7dce72ba8125b7c55df8d3dec355925003de24a4131c6510b9e67c51ebf`, CLI `6ba12ed37658228a3ce87cb64e1f5d88dda38e07` / binary `1b6a973b…`, runner source `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, packaged and installed runner hash `9342b8a3…`, install stamp `1.1.28-grantiva.15+android-drivers-2`, and demo `84af7581b75134b0e417b254e4317d565f7b73c6`.
- The APK hash is the required `5891bf3753eade9ce28a391ec5d8d3d289d195af951e967b67bb1928e06d988a`. The device identity command returns exactly `smoke4-c3-android` on `emulator-5580`.
- The top-level invocation uses the candidate-3 evidence-local fixture tree, cloned runner home, `fix4-8-c3`, and an unset API key. All 13 copied fixture files exist and match their recorded hashes; no screenshot was imported as an input.

## Healthy and crash behavior

- Healthy stock exits 0 with a passed report before crash testing.
- All five crash invocations exit with the expected failure, retain failed raw reports, and match a fatal log entry to the launch PID. None reports launch success.
- Each repetition has before/after host-device clock probes. Probe RTTs are 18–25 ms, and the conservative fatal-to-decision intervals are respectively 0.164–0.189, 0.377–0.400, 0.174–0.198, 0.194–0.214, and 0.210–0.228 seconds, all well inside the two-second bound.
- Recorded one-minute host load at each crash start remains below 15. The log-clear, raw logcat, report, stdout/stderr, and clock-calibration artifacts are retained separately for every run.

## Gestures and favorite stability

- Direction, coordinates, element, and explicit `engine: adb` forms each exit 0 and show app-row movement. Median vertical movement is -955, -957, -1174, and -1288 pixels respectively.
- The three non-ADB forms are classified as live held actions. The ADB form has no W3C action in its live client log and is paired with the frozen runner source/unit proof that binds explicit `engine: adb` to the shell route. The evidence accurately records that an external ADB argv was not independently visible live rather than claiming otherwise.
- Five independent favorite runs pass with their own raw reports and prove removal of the target row after the stable-target interaction.

## Lifecycle and result surfaces

- The L77 fixture contains literal `clearState` and bare `stopApp`; its report passes all four commands. The postcondition shows the Landmarks package PID absent, Settings as the focused application, a Settings UIAutomator2 hierarchy, and an intentional non-crash stop result.
- Optional misses run three times in text mode and three times in JSON mode. Every process exits 0, every flow/report remains passed with exactly one warned command, JUnit reports zero failures, useful missing-element detail is retained, and the following required command executes.
- The text and JSON required controls each exit 1, retain failed reports and one JUnit failure, record one failed plus one skipped command, and do not convert the error into a warning.
- The cycle command exits 1 with the expected canonical diagnostic: `subdirectory/a.yaml -> subdirectory/b.yaml -> a.yaml -> b.yaml`.

## Scoped cleanup

The helper completes with no stale project session from its direct runner cases and preserves the controller-owned emulator for the later serial phases. It performs no global teardown, protected-target operation, or default-home write. Final physical device cleanup remains the separate Task 8 cleanup phase.

This was a read-only review of retained raw evidence. I did not rerun a test, invoke the runner or CLI, build an artifact, or perform a device operation.
