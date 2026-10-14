# CLI-143 candidate5 clause assessment

Verdict: **PASS**.

Expected: `Error: --duration must be greater than zero` with the usage line, exit 64 (usage error: K41 moved range checks into validation; B2-K41 expects the same for `--duration -1`) (corrected round 3)

Fresh current-candidate raw confirms the required validation/result before compiler or live-device work. Evidence: `CLI-143-run-2/zero.command.json`.
