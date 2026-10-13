# Task 9 CLI slice brief

Start only after the controller supplies a green Task 8 zero-gate record, frozen candidate manifest, worktree/branch, and evidence root. Account for exactly 431 CLI effective keys from the unchanged matrix. You directly execute 425. The iOS actor executes `CLI-048`, `CLI-049`, `CLI-061`, `CLI-064`, `CLI-066`, and `CLI-083`, then returns evidence and proposed verdicts to the same CLI keys. Those six are not iOS results and are not counted twice.

Use the frozen `/Users/kyle/.grantiva-qa/bin/grantiva`, bundle, runner home, demo SHA, and `GRANTIVA_SESSION_ID=cov4-cli`; unset `GRANTIVA_API_KEY`. Do not build, repack, upgrade, edit product/source/tests/docs/demo, change expectations, or fix failures. Candidate identity must be rechecked in each evidence group.

Write `findings/cov4-cli-results.md` and `findings/evidence/cov4-cli/<ROW-ID>/`. Each row needs exact commands/environment/cwd/timestamps/exit, verbatim streams and raw files, frozen provenance, scratch-input hashes, and a clause-by-clause verdict note. Preserve the first verdict forever; reruns use adjacent lines and `-rerun-N` directories. Old Task 8/Round 3 evidence and implementation reviews are patterns or context only, never a current result.

Use `pass`, `fail`, `blocked <reason>`, or `n/a <reason>`. A disputed expectation is `fail (matrix/brief error — triage)`. Add unmapped observations as failing `EXTRA-nn` lines. Source-test and provenance B4 rows require fresh output against the frozen source/candidate exactly as written.

Honor the carried blocked rules: `CLI-083` uses the controller-reserved no-booted-simulator window; run `CLI-153` only under its default-device guard and boot nothing; keep `AND-002`, `AND-012`, `AND-088`, `B-I06.2`, and `N-08` blocked unless the controller documents the required environment change. Do not count a routing note as a verdict. Do not use owner operations, global cleanup, signals, GitHub/PR actions, commits/pushes, tags, or releases. Report any fail, unexpected boot/device access, candidate mismatch, or evidence gap to the controller immediately and continue only where independent.

Execute `B4-L85.2`, `B4-L85.3`, and `B4-L85.5` directly as CLI keys. Keep their fresh frozen-source selector/transport tests and replacement-candidate provenance separate from the iOS live keys; candidate 2 evidence cannot populate them.
