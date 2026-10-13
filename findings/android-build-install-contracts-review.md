# Android build/install contracts review

## Findings

### Important — B-A10.2 is missing its required CHANGELOG note

The runtime clauses pass: AND-021 JSON has `applicationId`, absolute `appPath`, `status: installed`, and owned device name/serial; BA03 run narration uses Android module/variant/device terminology; Android build failures contain no `Scheme:` line. But the binding criterion also says to note the JSON change in CHANGELOG. The exact CLI candidate at `8f2cff67` has no CHANGELOG, and the exact runner `fd9d8e8` CHANGELOG has no entry for this CLI install-document change. The current pass does not cite such an entry. Grade B-A10.2 fail for the documentation omission unless Task 6 has an accepted correction withdrawing that clause.

This is a product documentation defect, suitable for the next free brief (L69 if still free): document the Android `build install --json` shape and the `applicationId` plus `device.name`/`device.serial` change in the release changelog. Runtime behavior needs no fix.

### B-A09.2 should pass; the current failure contradicts its own raw evidence

Both unknown-target paths enumerate what exists:

- AND-024 text and JSON include `Variants of :app: freeDebug, freeRelease, paidDebug, paidRelease.`
- AND-025 nosuch-module includes `Modules: app.`

Exact-head `GradleBuildRunner.availableTargetsLine` performs the bounded `:app:tasks --all` or `projects` query and appends these parsed lines; `GradleBuildRunnerTests` asserts the variant line. This is precisely the criterion, beyond merely suggesting `./gradlew tasks --all`. Change B-A09.2 from fail to pass. No defect brief is warranted.

### AND-022 is a matrix/fixture conflict, not demonstrated product failure

The command invokes `:app:assembleFreeRelease`, exits 0, and produces the expected release APK. The frozen demo's `app/build.gradle.kts` explicitly assigns the debug signing config to the release build type, so this APK is not an unsigned-release case. `Warnings: 1` is a count of Gradle warning lines; it is not an unsigned diagnostic and should not be interpreted as one.

The literal “unsigned-release behaviour reported clearly” clause cannot be exercised with this signed fixture. Preserve the present fail until Task 6, then either:

1. change the fixture to an actually unsigned release and state the expected diagnostic, or
2. make the acceptance conditional: report unsigned behavior clearly **when the produced APK is unsigned**, while this signed demo only proves `assembleFreeRelease` and product discovery.

There is no supported CLI defect from this capture and no new brief should be filed for AND-022.

## Other row verdicts

- **AND-021:** pass supported. JSON shape is complete, package path exists, `pidof` is empty after `--no-launch`.
- **AND-023:** pass supported. Exact `:app:assemblePaidDebug` invocation and paid-debug APK path are retained.
- **AND-024 / B-A09.1:** pass supported. Text and JSON both exit 1 and retain the full Gradle cannot-locate-task reason through the What-went-wrong block; JSON exposes the same reason in `errors`.
- **AND-025:** pass supported. `--module app` builds `:app:assembleFreeDebug`; `nosuch` retains Gradle's missing-project reason and exits 1.
- **AND-028:** pass supported. The frozen APK hash and apkanalyzer ID are retained; output says `Using pre-built binary`, no Gradle command runs, the exact package ID is installed, and all eight flow steps pass.
- **AND-144:** pass supported. Both config files exist, the shared iOS config has unusable sentinels, and explicit Android selects the Android config and installs on owned emulator-5554.
- **B-A03.1/B-A03.2:** passes supported. Paid run and install warn with both configured and APK IDs plus both remedies, use/install `com.kylebrowning.landmarks.paid`, and the run report's flow/device artifacts correspond to the paid execution. Preserved `pm path` proves the paid package for each command.

Result: ten runtime grades are supported except B-A10.2's documentation clause; B-A09.2 is a false failure; AND-022 is an unexercisable expectation with the signed fixture.
