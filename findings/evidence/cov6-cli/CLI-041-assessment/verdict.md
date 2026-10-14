# CLI-041 candidate5 clause assessment

Verdict: **PASS**.

Expected: `--scheme is an iOS option, but this is an Android project (resolved from --platform, GRANTIVA_PLATFORM, the config file, or the directory).`, before any build (docs/android.md:55-56; src TargetOptions.swift:66)

Current raw reaches the expected parser/platform/config outcome before any compile or live target action. Clause checks: [True]. Evidence: `CLI-041-rerun-1/run.command.json`.
