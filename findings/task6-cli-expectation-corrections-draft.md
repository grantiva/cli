# Task 6 draft: CLI expectation and evidence corrections

Draft only. Do not edit the matrix or regrade until Task 6 review. Candidate is
`8f2cff67`; QA binary SHA256 is
`3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8`.

## Correction 1 — canonical help corpus after L63

Rows: **CLI-003, D2-47, N3-16**.

Replace the pre-L63 byte-corpus premise with a corpus regenerated from the
exact candidate. Keep every structural requirement: 172 pages, exit 0,
`OVERVIEW`, `USAGE`, and `OPTIONS`. The sole historical delta is
`simulator_teardown.txt`, whose added process-reaping sentence is the accepted
L63 behavior. Evidence:

- original disclosure: `findings/evidence/cov3-cli/CLI-003/regen.out` and
  `simulator_teardown.diff`;
- selected-page replay: `findings/evidence/cov3-cli/D2-47/`;
- documentation join: `findings/evidence/cov3-cli/N3-16/`;
- independent regeneration:
  `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/cov3-controller/help-corpus/summary.json`
  (`pages:172`, all exit zero, historical changed list only simulator teardown,
  regenerated corpus matches).

Regeneration procedure for the final correction:

1. Read the exact command list from the preserved CLI-003/controller
   `commands.json`; do not rediscover commands from current help text.
2. Run each listed `--help` against the hash-pinned QA binary in a fresh output
   directory, preserving stdout, stderr, and exit code per page.
3. Assert all three headings and exit 0 for every page.
4. Compare against the checked-in canonical `findings/help/*.txt`; update only
   files whose exact candidate output differs. The independently regenerated
   proof predicts exactly one update, `simulator_teardown.txt`.
5. Save a summary containing binary hash, page count, structural checks, and
   changed-file list. Re-run the byte comparison after the update; expected
   changed list is empty.

This is an expectation/evidence refresh, not a product change or relaxation.

## Correction 2 — accepted usage-error shape

Rows: **CLI-045** and only the mutual-exclusion leg of **CLI-145**.

Replace expected exit 1 with the binding shared-constraint shape:

> exit 64; `Error: --device and --emulator are mutually exclusive; pass one.`;
> `Usage:`; and `See '… --help'`; all before device work.

Keep CLI-145's three other-platform rejections at exit 1 with their existing
long-form wording. Existing raw evidence already satisfies the corrected
criteria. Do not generalize exit 64 to those three legs.

## Correction 3 — L29 headless inventory

Row: **D2-27**.

Change the enumerated help inventory from seven pages to the six commands that
can boot or select a device. Remove `build build` only. Retain the exact
headless/environment/CI/window wording requirement on all six pages. Use
`findings/evidence/cov3-cli/D2-27/helps_r3.out`; keep the disclosed malformed
first attempt as excluded provenance. This aligns the row with L29's accepted
removal of visible device flags from build-only help.

## Non-correction — CLI-025 remains a product failure

Do not change its Advisory expectation. Runtime and source prove the ambiguous
platform check is incorrectly assigned to Project while doctor exits 0. L67
owns the product correction. After applying the six expectation/evidence
corrections above, CLI-025 remains the sole CLI product-contract failure among
the original seven; total failures remain one until L67 is implemented and
verified.

## Expected Task 6 accounting

| Rows | Current classification | Draft disposition |
|---|---|---|
| CLI-003, D2-47, N3-16 | matrix/corpus triage fail | pass after one canonical corpus refresh |
| CLI-045, CLI-145 | matrix/ruling triage fail | pass from existing raw after narrow exit-shape correction |
| D2-27 | matrix/L29 triage fail | pass from `helps_r3.out` after six-page inventory correction |
| CLI-025 | product contract fail | remain fail pending L67 product work |

The draft changes no runtime requirement, hides no malformed or historical
capture, and does not use existence-only tests as acceptance evidence.
