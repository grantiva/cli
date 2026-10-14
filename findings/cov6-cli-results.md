# Candidate 5 CLI coverage results

Frozen candidate manifest SHA-256: `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`.
Session: `candidate5-cli`. Runner home: `/private/tmp/grantiva-candidate5-coverage-qjr26z3g/cli-runner-home`.

The direct CLI ledger contains exactly 425 canonical keys in matrix order: 419 PASS, 3 PENDING, and 3 N/A. Each runtime grade points to current-candidate command metadata and retained stdout/stderr, or to an explicit current-candidate join assessment. Historical runtime verdicts were not transferred.

Pending direct keys:

- `CLI-091`: strict auth diagnostic still needs an owned named iOS target for prevalidation. The fresh attempt stopped earlier at the host default-name ownership guard, which is insufficient for this row.
- `CLI-156`: four pre-built examples parsed, but absent artifact checks/default-name ownership preceded authentication. Exact auth outcomes need an owned named-target fixture with existing placeholder artifacts.
- `B4-L85.5`: root-owned replacement-candidate/full-campaign final gate, pending by design.

The six original iOS handoffs (`CLI-048`, `CLI-049`, `CLI-061`, `CLI-064`, `CLI-066`, `CLI-083`) are outside this 425-direct ledger and remain root-integrated separately.

Ledger: `findings/evidence/cov6-cli/results-ledger.json`.
