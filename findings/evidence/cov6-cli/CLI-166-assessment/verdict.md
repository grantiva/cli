# CLI-166 candidate5 clause assessment

Verdict: **PENDING**.

Expected: stderr `Error: Not authenticated. Run: grantiva auth login`; stdout empty; exit 1 (README:373-376; src GrantivaError.swift:42)

Pending exact runtime clauses because they would enter CI/build or application execution and the active authorization forbids compiler-heavy/live actions without a named root window. No prior runtime verdict transferred. Evidence: (no command launched).
