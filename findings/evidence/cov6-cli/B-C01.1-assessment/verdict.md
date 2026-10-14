# B-C01.1 candidate5 clause assessment

Verdict: **PASS**.

Expected: Re-running the repro exits non-zero with a `GrantivaError` naming the missing resource bundle, no SIGTRAP, and leaves `~/.grantiva/runner` exactly as it was. (brief C01)

Fresh candidate5 docs/public behavior or exact current-source inspection evidence satisfies the named clause; source-only evidence is used only for a source-only key. Evidence: `B-C01.1-run-1/missing-bundle.command.json`.
