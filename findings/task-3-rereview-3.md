# Task 3 scoped re-review — finding #1

Spec-compliance verdict: **ADDRESSED** for remaining finding #1. Evidence-quality verdict: **ADDRESSED** for the documentation inventory claims. This independent review did not run product, device, or test commands and did not reopen findings #12 or #13.

Paths below are relative to `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli`; `E` means `findings/evidence/cov3-cli`.

## Finding #1

The corrected v2 inventory now links only exact executed variants:

- `inventory.tsv:71` links the README doctor JSON filter to `E/CLI-157/commands.txt`, whose first command is exactly `grantiva doctor --json | jq '.[] | select(.status == "error")'`. The distinct JSON/quiet pipeline at row 73 is explicitly `EXCLUDED_EXECUTION`.
- `inventory.tsv:92` links `grantiva init --platform android` to `E/CLI-159/commands.txt`, which records that exact command.
- `inventory.tsv:158` links `grantiva diff compare --json` to `E/D2-23/commands.txt`, which records that exact variant. The named-screen approve JSON syntax at row 160 is explicitly `EXCLUDED_EXECUTION`.

The README command-summary entries at inventory rows 42 and 43 are now exactly `grantiva simulator sessions` and `grantiva simulator teardown`; the descriptive prose and explanatory flag text identified in the prior review are absent.

An independent tab-separated count finds 160 numbered entries: 25 `EXECUTED_EXISTING` and 135 `EXCLUDED_EXECUTION`. The inventory summary says `examples=160`, and `findings/cov3-cli-results.md` and `task-3-report.md` now both state 160 examples. The report also accurately describes the exact-variant links, exclusions, and prose parsing correction.

No unsupported execution claim from the prior review remains in the inspected artifacts. This verdict covers finding #1 only and is not campaign-completion approval.
