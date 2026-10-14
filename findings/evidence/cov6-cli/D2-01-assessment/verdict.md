# D2-01 candidate5 joined clause assessment

Verdict: **PASS**.

Expected: Alone: fails with `The grantiva_GrantivaCore.bundle resource bundle was not found next to the grantiva executable`, non-zero; with the bundle beside it: installs (README:22-29)

Fresh `../B3-L28-run-1/` proves binary-alone bundle failure and current install behavior; current adjacent-bundle install is proved by `../B2-K45-run-2/`.

No historical runtime verdict is transferred; all runtime references above are current candidate5 captures. Source joins use `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/reviews/campaign-completion/candidate5-source-evidence-joins.json`.
