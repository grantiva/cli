# B-C01.3 candidate5 clause assessment

Verdict: **PASS**.

Expected: GrantivaCoreTests/RunnerManagerTests: a test with a fake `extract` and a seeded `locks/lease` file asserts the lock survives `installIfNeeded`, and a test with a throwing `extract` asserts the previous install is intact. (brief C01)

Fresh candidate5 docs/public behavior or exact current-source inspection evidence satisfies the named clause; source-only evidence is used only for a source-only key. Evidence: `B-C01.3-run-1/source-inspection.command.json`.
