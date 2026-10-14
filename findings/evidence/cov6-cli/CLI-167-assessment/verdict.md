# CLI-167 candidate5 clause assessment

Verdict: **PENDING**.

Expected: Each refused with "Android baselines are local only until the Grantiva backend supports platforms; use local baselines" (or, for `--derived-data-path`, rejected by name as an iOS option), non-zero, before any Gradle build or emulator boot (`adb devices` unchanged); record which message `--derived-data-path` gets (docs/android.md:55-56, 71-73)

Pending exact runtime clauses because they would enter CI/build or application execution and the active authorization forbids compiler-heavy/live actions without a named root window. No prior runtime verdict transferred. Evidence: (no command launched).
