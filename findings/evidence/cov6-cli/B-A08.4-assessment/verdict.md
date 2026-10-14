# B-A08.4 candidate5 clause assessment

Verdict: **PASS**.

Expected: GrantivaCoreTests/AndroidPlatformTests: `logStream(level:)` for nil/default/info/debug yields the mapped `-s *:X` arguments and never `logcat -c`; GrantivaCLITests/RunCommandTests: `--logs-level warning` fails validation. (brief A08)

Fresh candidate5 docs/public behavior or exact current-source inspection evidence satisfies the named clause; source-only evidence is used only for a source-only key. Evidence: `B-A08.4-run-1/source-inspection.command.json`.
