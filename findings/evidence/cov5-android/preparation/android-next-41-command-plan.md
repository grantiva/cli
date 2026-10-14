# Android next 41-key exact command plan

Status: prepared only. The group is the AND-010 missing-clause supplement plus the exact canonical 40-key span AND-109, AND-146, AND-110, AND-019–025, AND-111–113, AND-143–144, and AND-026–050. No command in this plan has been executed.

## Frozen inputs

- Candidate manifest SHA-256: `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`.
- CLI: `/Users/kyle/.grantiva-qa/bin/grantiva`, SHA-256 `2a4e90e655b2a43234b4c1c5cac403042df17aa43e3e6bd0d011743e38fb9fb5`.
- Demo source: `/Users/kyle/Developer/landmarks-demo/.worktrees/release-round4-candidate2`, commit `84af7581b75134b0e417b254e4317d565f7b73c6`.
- Fresh build scratch: `/private/tmp/grantiva-cov5-android-core-scratch`; 75 source files copied with `.gradle`, `.kotlin`, and `app/build` excluded. The source and scratch manifests are retained under `preparation/core-scratch-manifest/`. The only prepared content change is `emulator: Pixel_8_API_35` to `emulator: cov5-android`.
- Frozen APK: `/Users/kyle/Developer/landmarks-demo/.worktrees/release-round4-candidate2/android/app/build/outputs/apk/free/debug/app-free-debug.apk`, expected SHA-256 `5891bf3753eade9ce28a391ec5d8d3d289d195af951e967b67bb1928e06d988a`.
- Environment for every recorder invocation: JDK 21, SDK roots and SDK tools PATH explicitly set; `GRANTIVA_SESSION_ID=cov5-android`, both runner-home variables `/private/tmp/grantiva-cov5-android-runner-home`, API key unset, real HOME unchanged.

## Ordered lifecycle prelude

1. AND-010 supplement: execute exactly the five-step procedure in `AND-010/supplemental-readiness.md`, including a real detached Android runner/UIAutomator2 session and recorded serial forward before one literal targeted teardown.
2. AND-109: after Grantiva has created/stopped the secondary, capture `created-avds.json`, manually run `avdmanager delete avd -n cov5-android-2`, prove physical absence, call `grantiva emulator sessions --json`, and prove the next product call prunes only that missing name from the created ledger.
3. AND-146: `grantiva emulator ensure --name cov5-android-2 --no-boot`, then `grantiva emulator delete --name cov5-android-2 --json`; decode JSON, prove it names the deleted AVD, and prove list/config absence.
4. AND-110: execute the non-global documentation examples with names rebound only to the allocated `cov5-android`/secondary and exact started serial. Preserve the `teardown --all` example as blocked without execution. Each physical action gets its own before/after ownership record.

## Serialized scratch-build block

Run in canonical order from the prepared scratch, with a fresh row-specific report/output path and the approved recorder:

- AND-019: `grantiva build build`; require `assembleFreeDebug`, exit 0, and hash the product.
- AND-020: `grantiva build install`; require build, exact allocated-device install, and launched app proof.
- AND-021: stop the app, then `grantiva build install --no-launch --json`; decode required fields and prove the package is installed but its process absent.
- AND-022: `grantiva build build --variant freeRelease`; retain `assembleFreeRelease`, product hash, and actual signing status.
- AND-023: `grantiva build build --variant paidDebug`; retain `assemblePaidDebug` and product hash.
- AND-024: text and JSON `grantiva build build --variant noSuchVariant`; retain Gradle's full reason and variants listing.
- AND-025: `grantiva build build --module app`, then `--module nosuch`; retain positive product and negative Gradle reason/modules listing.

## AND-111 shutdown compile-only control

This row runs in the same root-serialized compiler window. Before the command:

1. Authenticate primary PID 56881/start/executable/argv and AVD name, target `grantiva emulator teardown --serial emulator-5554`, and prove its PID and serial are absent while `cov5-android` remains present and Shutdown.
2. Capture exact `adb devices -l`, `adb forward --list`, Grantiva started/created ledgers, emulator inventory, primary config hash, protected Pixel config hash, host load, and a bounded inventory of owned compiler/emulator/runner processes.
3. Confirm scratch config contains `emulator: cov5-android`; pass no `--device`, `--emulator`, install, or run flag.

Execute `grantiva build build` once. Capture exact argv/environment/cwd, compiler child PID/argv, streams, exit, duration, and product manifest. Immediately repeat every before inventory and require byte-equivalent ADB serial/forward inventories, primary still Shutdown, no new emulator PID, no app install/launch, no row runner/session/lease, and no remaining compiler process. Any boot is a row failure and stops dependent device work.

## Remaining build/install selectors

- AND-112: `grantiva build build --device emulator-5999`; require the attached-device error and no boot/install.
- AND-113: with authenticated primary Shutdown, default `grantiva build install`; require `Booting AVD cov5-android as <serial>`, bind the new PID/serial before use, and prove install/launch.
- AND-143: return primary to authenticated Shutdown, then `grantiva build install --emulator cov5-android --headless --module app`; bind new PID and require `-no-window`, install, and launch.
- AND-144: make a row-local copy containing both config filenames, retain their contents/hashes, then `grantiva build install --platform android`; prove `grantiva-android.yml` selection and exact-primary install.

After the scratch install block, stop row-owned app/session state and restore the frozen APK on the exact primary. Hash before install, install with exact serial, verify package path/version, and retain the frozen APK hash again. No later ordinary behavior row may consume the scratch product.

## AND-026–050 behavior block

Use a row-local config/flow copy for each mutation and the frozen APK with `--no-build` whenever the literal clause permits. Preserve literal build behavior for clauses that require it.

- AND-026–030: exercise application-ID metadata mismatch, CLI override, explicit frozen app file, stopped-AVD boot by name, and exact serial targeting in order.
- AND-031: empty screens/flows with fresh report and ready paths; prove failure before build/boot and ready status failed.
- AND-032: authenticated primary Shutdown, literal `--headless --emulator cov5-android`; bind new PID and prove `-no-window` before running.
- AND-033: literal nonexistent parent ready path; prove no Gradle child or boot occurred.
- AND-034: precreate stale ready content, run the passing flow, and prove startup deletion followed by a newly written terminal record.
- AND-035–039: execute the literal environment values and flow-header/step combinations; retain decoded app-visible values and exact logcat extras where required.
- AND-040: crash-on-launch plus ready file; retain nonzero exit, `app_crash` identity/message at launch or first post-launch step, failure screenshot, failed ready state, and time-to-failure.
- AND-041: flow 12 and quoted Denali tap passes.
- AND-042: configured 12-flow run yields 12/12 pass.
- AND-043: twelve distinct `--flow` invocations in filename order, each reporting only its selected flow and passing.
- AND-044: row-local flow with the Unicode arrow label taps successfully.
- AND-045: installed frozen APK plus `--no-build`; prove no Gradle/compiler child and unchanged scratch build outputs.
- AND-046: crash flow first plus `--continue-on-failure`; prove later flows execute and overall exit is nonzero.
- AND-047: separate failure/trailing/full snapshot runs with exact screenshot count/step attribution.
- AND-048: fresh explicit report dir; prove required report contents and unchanged `.grantiva/captures` manifest.
- AND-049: exclusive quiet timing leg with `--timeout 30 --ready-file`; retain host load, about-30-second bound, terminal failed ready record, no running flow/process, and exact kill message punctuation.
- AND-050: passing and failing `--json` runs; validate stdout as JSON-only and grade the failing error contract against its referenced IOS-074 clause.

Every row retains candidate/device/process identities, config/flow and app hashes, before/after inventories, exact raw streams, report/screens, cleanup, and a clause-level verdict. No source test, CLI/runner build, protected-device operation, global teardown, pattern signal, or unallocated target is part of this plan.
