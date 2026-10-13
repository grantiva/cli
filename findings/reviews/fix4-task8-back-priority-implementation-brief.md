# Task 5 follow-up implementation — L85 back-label collision

Read first: /Users/kyle/Developer/grantiva-cli/.worktrees/regression/docs/superpowers/plans/2026-10-13-coverage-issues-round4/L85-ios-back-label-selects-current-tab.md is the binding requirement. Also read SDD/task8-candidate2-back-collision-source-diagnosis.md and original round3 L66 brief for preserved contracts.

Implement only in /Users/kyle/Developer/grantiva-cli/.worktrees/fix4-back-priority, branch fix4/back-button-label-priority, base22055ff981ae1ffd5aaae69190d7af180f239162. It is clean and no AGENTS.md was found in repository/parents. Serial product implementation slot is yours. No device commands, owner-home writes, runner/demo/archive edits, QA promotion, tag/release, push/PR/merge, or reviewer dispatch. Root owns live acceptance and GitHub actions.

Fix iOS WDA within-label ambiguity narrowly: prefer an exact label-matched navigation BackButton (real identifier and actionable button type) before the broad label query, retaining label-before-identifier-before-placeholder and shared escaping/retry/error path. Avoid a generic unrelated ranking redesign. Update the public selector contract succinctly if needed. Tests must prove different competing IDs and meaningful behavior, including red-before-fix on current source.

Run focused and full Swift test suites with GRANTIVA_API_KEY unset and distinct fresh empty GRANTIVA_RUNNER_HOME/MAESTRO_RUNNER_HOME; verify they remain empty. Capture exact argv, source/commit, env, timestamps, status, raw outputs under SDD/task8-back-priority-tests (no secrets). Keep compile workload serial. Commit tested changes locally; preserve all product user changes (worktree initially clean).

Return SDD/task8-back-priority-implementation-report.md and a review diff bound to base/HEAD, with changed behavior, meaningful red/green tests/full totals, exact head, clean status, risks, and live acceptance still pending. Do not claim final acceptance from unit tests. Root will independently review and build the exact committed source for live proof before CI/merge.
