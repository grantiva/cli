# Candidate 5 CLI direct batch 04 review

**Scope:** independent read-only review of flattened direct ordinals 76–100 against `direct-row-batches.json`, raw command/stream/identity artifacts, assessments, and the cumulative ledger. No command was rerun.

**Spec verdict: APPROVED — 25 PASS. Quality verdict: APPROVED.** The batch keys match canonical positions 76–100 exactly. Cumulative state is 96 PASS and the four prior PENDING rows (`CLI-166`–`CLI-169`). Fifty-one retained batch commands have candidate5 identity records with manifest SHA `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`; every frozen artifact match is true.

Control hashes:

- `direct-row-batches.json`: `5c94137ef743aec7a2f946e525a9efdc02815193116260d855864146a8d65a98`
- `batch-04-verdict.json`: `352c0eecce0f81f904313c42ecfbbd7d349aceb2d2de5eebae9b52c1f2550ca9`
- cumulative `results-ledger.json`: `5ee25fc42214acb03332bb7d063a5f00843991b03357a0348b71767032a6dd06`

## Findings

- `CLI-171` proves `mcp` rejects both unsupported output flags with usage exits.
- `CLI-063`, `CLI-065`, `CLI-067`, `CLI-068`, and `CLI-135` retain all 19 supported Maestro command forms plus the unsupported-command, two-screen, two `runFlow` spellings, and standard-form controls. Supported fixtures reach only proven-absent device resolution; unsupported `back` fails with its file/line diagnostic before execution. This is parser evidence and performs no live-device substitution.
- `CLI-069`–`CLI-077` and `CLI-136` cover the required iOS/Android/ambiguous/empty initialization paths, explicit values, repeat refusal, cross-platform flag rejection, absent `--json`, and placeholder-warning suppression. The output files and refusal cases support their literal clauses.
- `CLI-078`–`CLI-082`, `CLI-137`, and `CLI-138` retain the expected healthy and failing doctor outcomes, Android SDK fallback and invalid-variable warnings, malformed-config location/fix text, and git-root detection from a subdirectory.
- `CLI-084` records two successful installs in the isolated candidate5 CLI runner home, establishing idempotence without touching the default home.
- `CLI-085` exits 0 and prints the runner actually frozen into candidate5, `grantiva-runner 1.1.28-grantiva.16`. The matrix's historical `.11` literal is expressly qualified by “the literal follows the bundled runner”; candidate5 provenance and the installed runner identity bind `.16`, so the proposed PASS is correct.

No material evidence gap or product failure was found in ordinals 76–100. The four cumulative pending rows remain unchanged.
