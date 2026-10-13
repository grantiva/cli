# Android build/install contracts review

## Findings

### B-A10.2 is complete under the matrix's documentation substitution

The runtime clauses pass: AND-021 JSON has `applicationId`, absolute `appPath`, `status: installed`, and owned device name/serial; BA03 run narration uses Android module/variant/device terminology; Android build failures contain no `Scheme:` line. The matrix-wide ruling at lines 924–925 says criteria asking for CHANGELOG entries are checked against README/docs/release notes because CLI CHANGELOG.md was removed in #179. README:252–255 documents the platform-specific JSON shapes. B-A10.2 is therefore a supported pass.

No documentation defect or new brief is warranted.

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

Result: all ten runtime grades are supported; B-A09.2 is a false failure; AND-022 is an unexercisable expectation with the signed fixture; B-A10.2 passes under the binding documentation substitution.
