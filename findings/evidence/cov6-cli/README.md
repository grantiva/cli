# Candidate 5 CLI coverage preparation

Status: **prepared only; do not execute before the candidate5 smoke gate and fresh CLI runner-home allocation**.

The collector is the approved cov5 helper with four binding substitutions only: candidate manifest path, immutable manifest SHA-256 `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`, session `candidate5-cli`, and runner home `PENDING_CANDIDATE5_CLI_RUNNER_HOME`. Ruby syntax validation passes. Root must replace the pending home consistently in the collector and both plan files, then rehash them before execution.

`direct-row-batches.json` derives 425 direct rows in canonical matrix order from `completion-candidate5/coverage/required-keys.json`, in 17 batches of at most 25. The six iOS handoffs remain CLI-048, CLI-049, CLI-061, CLI-064, CLI-066, and CLI-083. `first-batch-recipes.json` preserves the exact command, fixture/precondition, expected clauses, and capture template for direct ordinals 1–25 (CLI-001 through CLI-023 in canonical order).

No command, fixture setup, product test, build, device action, verdict, or source-proof join was executed or transferred. Each eventual row requires fresh capture and clause review. The proposed candidate5 source map may join only after its post-freeze validation and controller disposition.
