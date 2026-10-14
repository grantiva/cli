# B4-L53.F candidate5 clause assessment

Verdict: **PASS**.

Expected: Source criterion: “Validate `--device`, `--udid` and `--serial` values as non-empty (and, for simulators, UDID-shaped) at flag parsing; one test per flag. Also check the CLI never forwards an empty device value (CLI side: refuse with the Invalid argument line). Schedule: round 4 unless a `B3-L`/`N3` row fails on it.” Apply it under the corrected governing ruling: preserve the runner's existing `--udid` alias and validate its empty/whitespace values through canonical `--device` parsing; `--serial` remains unknown and no alias is added. This is compatibility preservation, not a new alias. (source: original Fix direction retained exactly; corrected inventory/plan and controller ledger ruling)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B4-L53.F-run-1/source.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `source.stdout`, `source.stderr` retained.

Accepted exact-tree source proof join: `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/reviews/campaign-completion/candidate5-source-evidence-joins.json`; this is used only for the named source clause.
