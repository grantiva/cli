# B-A08.2 candidate5 clause assessment

Verdict: **PASS**.

Expected: `--logs-level` becomes a validated enum shared by iOS and Android, with an explicit Android mapping table (default -> `*:I` or `*:W`, info -> `*:I`, debug -> `*:D`) documented in docs/android.md. (brief A08)

Fresh candidate5 docs/public behavior or exact current-source inspection evidence satisfies the named clause; source-only evidence is used only for a source-only key. Evidence: `B-A08.2-run-1/inspect.command.json`.
