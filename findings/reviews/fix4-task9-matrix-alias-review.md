# Task 9 L53 alias correction review

## Verdicts

- **Matrix specification: PASS.** The governing interpretation now matches the corrected binding documents: preserve the existing runner `--udid` alias, validate empty and whitespace values through canonical `--device` parsing, keep `--serial` unknown, and require final bundled-candidate repetition in Task 8.
- **Matrix quality: PASS.** The change is confined to the three corrected governing quotations, their indexed rows, governing metadata, and explanatory prose. It does not weaken a criterion or invent a result.
- **Report metadata: NEEDS ONE TRIVIAL CORRECTION.** `task-9-matrix-alias-fix-report.md` describes `64dd5188b0ba981bd71c0ec9ad3e104def2db5d6` as “merged CLI”; it is the merged runner commit. Replace “merged CLI” with “merged runner.” This does not affect the matrix content or verdict.

## Review details

- `B4-L53.F` retains the original brief Fix-direction quotation exactly, including its historical request for `--device`, `--udid`, and `--serial`. Only the governing application prose changes: existing `--udid` is preserved as compatibility, while no `--serial` alias is added.
- `B4-L53.P1` matches the current reviewed-plan ruling in the corrected acceptance inventory. It expressly preserves existing aliases and keeps malformed simulator-UDID and unknown-flag controls.
- `B4-L53.P2` matches the current Task 3 Step 2 quotation: real-app empty/whitespace `--device` cases, the same canonical validation through existing `--udid`, and `--serial` as the unknown-flag control.
- `B4-L53.P3` matches the current scoped Task 3 Step 6 quotation. It limits pre-merge installation to the task-scoped cloned home and keeps final Task 8 repetition mandatory; the exact empty-device command must still exit 64 before signing.
- The index changes exactly those three governing source quotations. The report records the intentional full source-criteria hash change and the stable hash when those three are excluded. The inherited extraction hash remains unchanged.
- The 1,170 inherited row bodies, including historical B3-L53, remain untouched. Old brief quotations remain present rather than being rewritten to look current.
- Counts remain 1,293 logical rows and 1,468 expanded results. Candidate fields remain `UNKNOWN`, results remain empty, future Task 3 proof remains pending, and Task 8 remains the final bundled-candidate gate.

## Boundary

This was a scoped matrix metadata review. I did not rerun structural checks, tests, device operations, or a broader source audit.
