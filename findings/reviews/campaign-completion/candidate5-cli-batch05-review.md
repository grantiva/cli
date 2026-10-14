# Candidate 5 CLI direct batch 05 review

**Scope:** independent read-only review of flattened direct ordinals 101–125 against `direct-row-batches.json`, raw command/stream/identity evidence, assessments, and the cumulative ledger. No command was rerun.

**Spec verdict: NOT APPROVED AS PROPOSED.** Supported state is **18 PASS, 7 PENDING** for this batch. The six proposed pending rows remain pending, and `CLI-142` must also be PENDING. **Quality verdict: NEEDS EVIDENCE CORRECTION.** The other 18 PASS rows have matching canonical commands, candidate5 provenance, and clause support.

## Material gap: CLI-142

`CLI-142` requires a copy of the current candidate binary beside a resource bundle from another release, then a failure naming both versions and the mismatched bundle while preserving the existing install.

- The first attempt under `CLI-142-run-1` has mismatch-looking raw text, but it has no `command.json`, no recorded start/end/exit, and no immutable execution-time hashes for the copied binary and mismatched bundle. Per the campaign ruling, this interrupted old-recipe attempt is preserved and excluded.
- The adjacent graded attempt is `CLI-142-run-2/install-current.command.json` (SHA `4dd903343aa93f77a4b74ce91e3680a840b441b818f106d91043009bb58ba8df`). It exits **0**, stderr is empty, and stdout says the `.16` runner is already installed. This does not exercise a mismatch and does not satisfy the row.
- The rerun identity document authenticates the frozen QA binary/bundle and installed runner, but the executed argv points to a copied binary in the scratch fixture. It does not record hashes of that copied binary and adjacent scratch bundle at execution time. Current read-only inspection finds the run-2 scratch bundle hashes equal the candidate5 bundle hashes, which is consistent with the exit-0 current-install result, not the required other-release fixture.

Therefore the `CLI-142` PASS assessment is unsupported. This is a fixture/evidence gap, not a product failure. A corrected attempt must bind the copied current binary hash, the intentionally different bundle file manifest/version, the existing installed `.16` bytes before/after, and full command metadata.

## Other rows

- `CLI-086`–`CLI-088`, `CLI-139`–`CLI-141`, `CLI-101`–`CLI-104`, `CLI-143`, `CLI-145`, `CLI-147`, `CLI-149`–`CLI-151`, `CLI-106`, and `CLI-107` are supported by 28 retained bounded commands with current candidate identity. Their raw outcomes establish the requested no-session, formatting, relative-home, recording validation, platform-option, emulator/simulator argument, missing-capture, missing-screen, and pre-build rejection clauses.
- `CLI-091`, `CLI-108`, `CLI-144`, `CLI-146`, `CLI-148`, and `CLI-105` correctly remain PENDING. Their required build/live/default-target guards were not authorized or executed; no older result should be transferred.

The proposed batch record currently says 19 PASS/6 PENDING and must be corrected to 18 PASS/7 PENDING until `CLI-142` receives valid adjacent evidence. Consequently the proposed cumulative count of 115 PASS/10 PENDING should be 114 PASS/11 PENDING at ordinal 125.
