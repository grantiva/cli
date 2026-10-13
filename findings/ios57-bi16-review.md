# iOS attempt 57: B-I16 review

Candidate: Grantiva CLI `8f2cff67`. No live calls were made.

## B-I16.1

The pass is supported. `capture.out` records a fresh explicit-U1 capture whose literal path is `.grantiva/captures/Deep Links.png`. `compare-changed.out` identifies the same literal capture and `.grantiva/captures/diffs/Deep Links_diff.png`; `changed-files.txt` and `final-grantiva/` preserve the exact files. This directly satisfies the filename and JSON-path criterion.

## B-I16.2

The implementation and runtime migration clauses are supported:

- Candidate `Sources/GrantivaCore/Diff/BaselineStore.swift:6-28,48-52,92-110` limits new filename encoding, decodes legacy filenames, and migrates legacy baselines during save/approve.
- `Tests/GrantivaCoreTests/ScreenArtifactTests.swift:24-28,35-43,60-64,73-101` semantically covers literal/legacy names, `%` ambiguity, loading, and migration.
- Attempt57 starts with `Deep%20Links.png`; `compare-legacy.out` resolves it as screen `Deep Links` while preserving the legacy baseline path. `approve-migrate.out` approves `Deep Links`, and the before/after inventories show the legacy filename removed and literal `Deep Links.png` present.

The documentation clause is **not supported at exact HEAD**. `CHANGELOG.md` was removed by #179. Under the binding matrix lines 924-925, the required rename note must therefore appear in README, public docs, or release notes. Recursive searches of README and public `docs/` found no note describing literal-space filenames, accepted `%20` legacy files, or approve-time migration. Source comments and tests do not substitute for a user-facing release note.

Therefore B-I16.2 should remain ungraded or be graded **fail** on the literal criterion pending Task 6/product documentation handling. The runtime behavior itself passes; the sole missing clause is the required public rename note.
