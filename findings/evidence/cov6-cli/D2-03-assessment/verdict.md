# D2-03 candidate5 joined clause assessment

Verdict: **PASS**.

Expected: The `simulator:` line is optional (written with the comment or the newest type); when a simulator of that name exists that Grantiva did not create, init warns naming it (README:112 and the "When neither a flag nor `simulator:` names one" paragraph). Do not run a device command with that default here when it resolves to `iPhone 17 Pro` (Global Constraint)

Fresh `../CLI-153-run-1/` init output proves optional/default simulator output and warning without target action.

No historical runtime verdict is transferred; all runtime references above are current candidate5 captures. Source joins use `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/reviews/campaign-completion/candidate5-source-evidence-joins.json`.
