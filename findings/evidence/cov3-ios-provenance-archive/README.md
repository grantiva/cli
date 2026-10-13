# Round-2 comparison manifests preserved for the round-3 integrity audit

These two files are byte-for-byte copies (preserving source mtimes) of the controller's comparison manifests created during the round-3 evidence-integrity audit:

- `ios-round2-identical-files.txt`
- `ios-round2-different-files.txt`

`SHA256SUMS` records the copied bytes. They identify which then-present `cov3-ios` files compared byte-identically with or differed from `cov2-ios`. They support exclusion and investigation of the accidental historical import. They do **not** prove that a differing file is genuine round-3 evidence, do not reconstruct the pre-import directory, and do not make any file eligible for a round-3 verdict. Eligibility still requires a recorded current `.13` command/output with adequate row-specific evidence.

Source at copy time: `.worktrees/regression/.superpowers/sdd/2026-10-13-round3-coverage-pass/`.
