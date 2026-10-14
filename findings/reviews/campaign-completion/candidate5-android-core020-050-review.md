# Candidate 5 Android core AND-020–050 review

## Decision

**APPROVED: 36 PASS.** Commit `7cc03cdfe` supports every proposed row in `core020-050-verdicts.md`: AND-020–025, AND-111–113, AND-143, AND-144, and AND-026–050. This was a read-only review; no build, device, emulator, or product command was run.

## Integrity and provenance

All 489 files indexed by `core020-050-artifact-manifest.json` exist and match their recorded SHA-256 and byte count. Command records retain argv, cwd, environment, start/end times, exit/signal state, timeout state, and raw stream paths. Current identity records bind candidate manifest SHA-256 `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`, and their expected/actual CLI, bundle, archive, and installed-runner hashes match. No collector timeout, process-group cleanup failure, or invented exit status appears.

Initial incomplete fixture captures are retained beside corrected `run2`/`run3` evidence for AND-020–025 and AND-048. They are not used as passes. The checkpoint preserves the expected-negative exits rather than grading from exit code alone.

## Clause review

The build/install group is complete:

- AND-020 builds, installs, and launches. AND-021's corrected JSON contains the required status, application ID, APK path, device name and serial; the process is absent before and after, proving `--no-launch`.
- AND-022 invokes `assembleFreeRelease`, retains the APK, and the successful `apksigner` inspection proves v2 signing by one Android Debug signer. The matrix's unsigned warning is therefore inapplicable. AND-023 invokes `assemblePaidDebug`.
- AND-024's text and JSON modes both exit nonzero and retain Gradle's task-not-found/What-went-wrong detail. AND-025 proves module `app` succeeds and module `nosuch` fails with Gradle's reason.
- AND-111 compiles while adb inventory is byte-identical and empty before/after. AND-112 names the unattached requested serial and attached-device state. AND-113 and AND-143 retain the expected boot narration and resulting normal/headless process identities. AND-144's copied iOS config has explicit nonselection markers while the successful Android install uses the Android config.

The run/config group is complete:

- AND-026 warns that the configured `.paid` target differs and tests the APK's own ID. AND-027 correctly exercises the explicit override: the warning names both IDs, installation uses the APK's own ID, and launch of the overridden `.debug` target fails as expected. AND-028 skips Gradle with the APK path and resolves its own ID. AND-029 boots the named stopped AVD, while AND-030 targets the explicit serial.
- AND-031 and AND-033 fail in 0.02 seconds before boot/build and retain the required failed-ready or invalid-ready diagnostic. AND-032 proves `-no-window`. AND-034 proves stale-ready replacement.
- AND-035 retains the exact `a=b c` extra in logcat and app behavior. AND-036 uses the sole running emulator, AND-037 delivers `hello`, AND-038 delivers both repeated environment values, and both CLI and flow-header paths in AND-039 reach the empty state.
- AND-040 exits 1 with exact `app_crash`, the launch exception, skipped later steps, failed ready status, report, and failure PNG. AND-041's quoted Mount Denali tap passes. AND-042 reports 12/12. AND-043 runs each stock flow separately and each passes. AND-044 preserves the Unicode arrow label. AND-045 skips Gradle.
- AND-046 exits 1 but proves the subsequent browse flow ran and passed after the crash flow. This is the required continue-on-failure behavior.

Snapshot, report, timeout, and JSON behavior is also complete:

- AND-047 retains three separate failing runs. `failure` records only the failed-step screenshot; `trailing` records the last-good and failed-step screenshots; `full` records before/after screenshots for every executed step. Each report consistently records one failed flow and preserves its hierarchy/log-tail artifacts.
- AND-048's corrected adjacent observation proves `.grantiva/captures` was absent before and after, while the separate report directory contains the report and captures. The earlier `find` no-path observations remain preserved.
- AND-049 exits 1 after 31.46 seconds for the literal 30-second cap, writes ready status `failed` with no running flow, and emits the complete kill message without a stray colon.
- Both AND-050 stdout documents parse as JSON-only results. The passing result reports `allPassed: true`; the failing result reports `allPassed: false`, the failed step/message, and the top-level error, with exit 1.

The retained final-state evidence restores the frozen APK, records the healthy owned primary generation, and leaves no extra AVD/device, forward, or Grantiva session. This final state is consistent with the targeted operations in the checkpoint and does not rely on a protected/default device action.
