# Android phase-B and AND-083 rerun review

Scope: exact matrix clauses, `PHASEB-build-lifecycle-exact-rerun1`, and `AND-083-exact-rerun2`; no live/device operations.

## Finding

### Important — AND-145 does not prove settings were applied and restored

The retained AND-145 command proves `--allow-device-settings` is accepted with `--emulator cov3-android`, and the browse flow passes. Its non-verbose stderr does not show the demo-mode/animation-scale operations, and the row directory has no before/during/after settings snapshots. The phase-B group contains detailed settings get/put/restore lines for the separate verbose AND-141 run, but those do not prove the AND-145 invocation followed the same path with the flag present.

The binding criterion requires all three facts: flag accepted, demo mode and animation scales applied during the run, and restored afterward as without the flag. AND-145 is presently partial. Closure needs either retained verbose output for the exact flag invocation or explicit pre/during/post values for `sysui_demo_allowed` and the three animation scales. This is an evidence gap, not a product failure.

## Supported rows

- **AND-036:** preserved no-emulator config plus the group state establishes exactly one owned running emulator; the flagless run selects emulator-5554 and passes all eight steps.
- **AND-111:** before/after adb and QEMU inventories remain empty; `build build` runs `:app:assembleFreeDebug` and exits 0 without booting.
- **AND-114:** no-emulator config is preserved; no device is attached; the error lists both frozen AVD choices and requires `--emulator`; started-device/adb/process evidence remains empty, so nothing boots.
- **AND-113:** stopped precondition is followed by `Booting AVD cov3-android as emulator-5554`; build/install exits 0, launches, and reports the owned target.
- **AND-143:** exact emulator/headless/module flags are recorded; the stopped AVD boots as emulator-5554, build/install/launch succeeds, and the owned QEMU command includes `-no-window`.
- **AND-029:** exact stopped-AVD emulator input logs the boot and selected serial, then passes the browse flow.
- **AND-032:** exact headless/emulator input boots the owned AVD, its QEMU command includes `-no-window`, and browse passes.
- **AND-140:** exact emulator/module/freeDebug/headless capture boots headlessly, invokes `assembleFreeDebug`, captures all five screens, and prints `Emulator: cov3-android (emulator-5554)`.
- **AND-141:** frozen nonempty APK is supplied; verbose stderr shows `apkanalyzer manifest application-id`, `Using pre-built binary`, no Gradle invocation, and all five configured screens are captured.
- **AND-142:** all four exact compare-and-capture invocations reach capture and comparison. Emulator mode honors emulator/module/variant/application/headless and builds; device/no-build skips boot/build; app-file uses the frozen APK; settings flag is accepted. Their exit 1 results are expected comparison outcomes against the existing baseline at configured pixel 2% and perceptual 5.0 thresholds: every output gives per-screen threshold reasons. The phase-B helper's `aggregate-failures=4` comes from mechanically expecting zero for these four compares; it is a harness expectation defect and does not negate the preserved command behavior required by AND-142.
- **AND-083:** rerun2 closes the prior evidence gap. The frozen config competes with `application_id: configured.sentinel` and nonexistent `emulator: configured-sentinel-do-not-create`; explicit flags select `x.y` and `cov3-android`. Start/session/stop persist `x.y` on emulator-5554, proving both flags win.

## Verdict

Approve AND-036, AND-111, AND-114, AND-113, AND-143, AND-029, AND-032, AND-140, AND-141, AND-142, and corrected AND-083. Hold AND-145 as partial pending exact settings apply/restore evidence.
