# Candidate 5 CLI direct batch 01 review

**Scope:** independent read-only review of flattened direct ordinals 1–25, from `CLI-001` through `CLI-023` with inserted `CLI-123`–`CLI-126`, against `first-batch-recipes.json`, the raw command/stream/identity artifacts, corrected assessments, and `results-ledger.json`. No command was rerun.

**Spec verdict: APPROVED — 25 PASS, 0 FAIL, 0 N/A, 0 pending. Quality verdict: APPROVED.** The ledger contains exactly the first 25 canonical recipes in the same flattened order. All 70 recorded commands are bounded captures with candidate5 identity evidence, session `candidate5-cli`, equal explicit runner homes, and an unset API key. Every identity document binds manifest SHA `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c` and reports all frozen binary/bundle/installed-runner hashes matched.

The reviewed control hashes are:

- `first-batch-recipes.json`: `308e78116ffaaa61f575a5e8ea18c4e418f667582695021daf6ae87360c4447c`
- `batch-01-verdict.json`: `3f80652c0c511dd2c793291d68712352c53c274cbdb434445822cf30188c8545`
- `results-ledger.json`: `fab5031415bafa3b40bfb7b385dea6919412d97f0be5fec96019e608887cd94c`

## Clause review

- `CLI-001`–`CLI-002`, `CLI-004`–`CLI-005`, `CLI-007`, `CLI-009`–`CLI-010`, `CLI-123`, `CLI-125`, `CLI-011`–`CLI-017`, `CLI-019`–`CLI-021`, `CLI-126`, and `CLI-023` have the required literal command variants, expected exit/output-channel behavior, and clause-specific help, JSON, quiet/verbose, platform-selection, or runner-result content in their retained streams. The raw commands match their canonical recipes; no substituted source-only assertion is used.
- `CLI-003` preserves its first local fixture failure (`fixture-failure.md` SHA `c59cc2db04157576e7cfa4cfec0f3c1306bf668ad4d8ef3ffeded6b12c12dec5`): the missing local `findings/help` corpus caused the glob to remain literal and the command exited 1. That attempt does not support the PASS and remains excluded. The corrected verdict (SHA `63d5b89317a9e1fea153259f061a2b2ea3dbf2e29ce6390f3044f7d5e6a2c628`) instead joins the exact-current-candidate docs-output smoke: acceptance SHA `191a86d56f9616d6f04f6220c9050d1513f4e1277a6f1d1fde21c8fddf5ae3bd` records 172 generated pages, 16 corpus tests, zero failures, and the candidate manifest; the uncached corpus-test result SHA `9174d53b8ceb650c9a7dbcd6e673e4d7a7939f80d66195bbffd2a88724261bd6` exits 0. This is an explicit same-candidate evidence join, not a transfer from an older candidate.
- The original `CLI-006`, `CLI-008`, and `CLI-124` FAIL assessments remain preserved. Each was a matcher defect: the raw help streams contain the literal required semantics and every command exits 0. The corrected assessments are narrow semantic readings of those unchanged raw artifacts, with hashes `4d4f865d5c8ee06e8aef5535517455f39bd6db59f6cc5d002760989edd25a1be`, `de3e6ab8427fc05592b0fa7d9e34c1cbbde467bb92014343c3de1c67e163ab09`, and `4f998ffd1e91c5cc3b00bfbda223687deb5d4735efb4d4ac94d8f2e396b68128`. They do not rely on a source change or a rerun.
- `CLI-023` retains both literal `doctor` and `init` commands in the Xcode-only fixture and supports the iOS selection clauses; its verdict hash is `063a390dfc9c5e3e46bb5473e3c9aeb125e134604f699ea9dde939de2d23316a`.

## Gaps

No grading gap remains in direct ordinals 1–25. The only non-passing first attempt is the preserved `CLI-003` missing-corpus fixture, and its PASS is independently supported by the accepted candidate5 172-page docs-output evidence. The three initial matcher failures are assessment defects with complete raw semantic support, not product failures.
