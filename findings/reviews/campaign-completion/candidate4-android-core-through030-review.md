# Candidate4 Android core-through-030 evidence review

Status: CHANGES REQUIRED, five narrow evidence gaps; no confirmed product failure.

Reviewed the candidate4 raw command records and actual surviving fixture contents for AND010 supplemental, AND106–108, AND109/146/110, AND019–030, AND111–113/143/144. Candidate manifest is `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`. Rows after AND018 were not yet in the durable Android ledger when this review was written; this review therefore does not approve an absent ledger transition.

## Required evidence corrections

1. **AND021 lacks the literal no-launch process observation.** `install-no-launch-json.stdout` proves `status`, `applicationId`, `appPath`, device name and serial, but the row contains no stopped-before/not-running-after observation. Add a narrow adjacent capture around the same command; preserve the original result.
2. **AND022 does not record signing status.** The command proves `assembleFreeRelease`, exit 0 and the produced release APK. `Warnings: 1` does not identify whether the APK is signed or unsigned, so it cannot decide whether the unsigned warning is applicable. Add a read-only signing inspection of the exact retained APK and bind it to the command.
3. **AND107 does not retain the machine classification.** The rerun proves the exact `LANDMARKS_CRASH_ON_LAUNCH` message at `launchApp`, exit 1 and a roughly 4.7-second failure. Retain the already-produced report/ready document showing `error.type == app_crash` if available; do not rerun solely to manufacture a new field when the original artifact already contains it.
4. **AND108 does not retain the five visual artifacts.** The successful rerun proves 5/5 and names Home, Favorites, Deep Links, Lakes and Detail, but the row has no screenshot files, hashes or inspection record establishing that Lakes and Detail are the intended screens. Add a read-only copy/hash/inspection of the original captures.
5. **AND144's fixture cannot distinguish config selection.** `config-hashes.stdout` shows `grantiva.yml` and `grantiva-android.yml` are byte-identical. A successful `--platform android` install therefore does not prove which file was selected. Add a distinguishing fixture/output or an exact retained selection trace; identical inputs cannot support the literal clause.

## Supported rows

- AND010 supplemental evidence now establishes a live UIAutomator2 session, two serial-scoped forwards before teardown, empty forwards after teardown, runner/session stop and owned-emulator kill. The earlier empty-forward capture remains preserved.
- AND106 proves the preserved initial missing-install failure, then a frozen-APK install and 12/12 stock pass. The output explicitly includes `Remove from favorites`, the 03-edit flow and the 12/12 summary.
- AND109 and AND146 prove manual deletion prunes `created-avds.json`, and Grantiva deletion returns valid JSON and removes the stopped created AVD.
- AND110 matches the documented examples. `--no-boot` correctly returns a serial when the named AVD is already running; the prohibited `--all` example remains blocked.
- AND019, AND020 and AND023 prove the intended Gradle tasks and the default install/launch behavior. AND024 and AND025 retain Gradle's actual task/project reasons for invalid variant/module failures.
- AND026 uses a surviving fixture whose config actually contains `.paid`; output metadata identifies the built app's own ID, prints both IDs in the warning, tests the app ID and passes.
- AND027 is the accepted negative interpretation: the override warning correctly names the app's own ID and `.debug` override, the APK installs under its own ID, and launch of the explicit nonexistent override fails. This is not a product failure.
- AND028 proves the frozen APK path skips build, derives the application ID, installs and passes. AND029 proves named-AVD boot and pass. AND030 proves the explicit attached serial is targeted and passes.
- AND111 is accepted under the root ruling: exact before/after adb and forward inventories remain empty, the configured AVD remains stopped, and build succeeds without boot. AND112 names the requested missing serial and attached set. AND113 boots the configured AVD and installs/launches.
- AND143 proves the named AVD boots headless, with the process argv containing the headless binary/`-no-window`, then installs and launches.

No reviewed command record reports collector timeout or failed process-group cleanup. Original fixture failures and adjacent reruns remain preserved. After the five corrections and durable ledger rows exist, rereview only those corrections and the ledger bindings.
