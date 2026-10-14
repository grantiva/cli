# Candidate 5 CLI coverage results

Frozen candidate manifest SHA-256: `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`.
Session: `candidate5-cli`. Runner home: `/private/tmp/grantiva-candidate5-coverage-qjr26z3g/cli-runner-home`.

The direct CLI ledger contains exactly 425 canonical keys in matrix order: 421 PASS, 1 PENDING, and 3 N/A. Each runtime grade points to current-candidate command metadata and retained stdout/stderr, or to an explicit current-candidate join assessment. Historical runtime verdicts were not transferred.

Pending direct key:

- `B4-L85.5`: root-owned replacement-candidate/full-campaign final gate, pending by design.

`CLI-091` and `CLI-156` are now PASS from fresh device-free authentication prevalidation against the explicit owned `cov6-ios-26` target, with valid copied frozen-app fixtures and byte-identical simulator inventories before/after.

The six original iOS handoffs (`CLI-048`, `CLI-049`, `CLI-061`, `CLI-064`, `CLI-066`, `CLI-083`) are outside this 425-direct ledger and remain root-integrated separately.

Ledger: `findings/evidence/cov6-cli/results-ledger.json`.
