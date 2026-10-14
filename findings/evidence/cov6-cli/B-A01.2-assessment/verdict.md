# B-A01.2 candidate5 clause assessment

Verdict: **PASS**.

Expected: On Android, `--env` is delivered as string intent extras: either FlowEnvironment writes `arguments:` (merging with any existing `arguments:` map) when the platform is Android, or the bundled runner maps `environment` to extras. Pick one and say which in CHANGELOG and docs/android.md. (brief A01)

Fresh candidate5 docs/public behavior or exact current-source inspection evidence satisfies the named clause; source-only evidence is used only for a source-only key. Evidence: `B-A01.2-run-1/inspect-corrected.command.json`, `B-A01.2-run-1/inspect.command.json`.
