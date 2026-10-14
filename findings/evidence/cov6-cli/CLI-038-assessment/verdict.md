# CLI-038 candidate5 clause assessment

Verdict: **PASS**.

Expected: `Error: No screens or flows configured in grantiva.yml`, exit 1, before any build; no `Invalid argument:` label (`RunCommand.nothingToRunMessage`, shared with the K52 missing-config sentence, is deliberately unlabelled; K52 wording supersedes brief C18). Without `--scheme` a multi-scheme project may report the scheme error first (K52 allows it) (corrected round 3)

Current raw reaches the expected parser/platform/config outcome before any compile or live target action. Clause checks: [True]. Evidence: `CLI-038-rerun-1/run.command.json`.
