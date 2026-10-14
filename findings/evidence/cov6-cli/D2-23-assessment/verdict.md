# D2-23 candidate5 joined clause assessment

Verdict: **PASS**.

Expected: No baselines: `? No baselines: <n> new screens. Run: grantiva diff approve`, exit 1, `--json` `"passed": false`; some missing: `? Visual diff incomplete: …`, exit 1; a failure line reads like `Failed: perceptual=63.6 exceeds perceptual_threshold 5.0 (pixel=0.03%, threshold 2.00%)`; `ci run` keeps `new_screen` without failing (README diff section; briefs K89, K108)

Fresh current-candidate synthetic comparison clauses are joined from earlier candidate5 diff rows; accepted current-tree Swift source proof covers the nonfailing CI new-screen sibling.

No historical runtime verdict is transferred; all runtime references above are current candidate5 captures. Source joins use `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/reviews/campaign-completion/candidate5-source-evidence-joins.json`.
