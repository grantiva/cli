# D2-33 candidate5 joined clause assessment

Verdict: **PASS**.

Expected: Exit 1 with ``Error: No active runner session. Start one with `grantiva runner start` or `grantiva run --keep-alive`, or pass --port.``; `hierarchy` omits ", or pass --port"; MCP names the project's `.grantiva/session.json` and directory; `--format bogus` is a usage error (exit 64) before any lookup (docs/dump-hierarchy.md; briefs K46, K47)

Fresh `../B2-K46-run-1/` and `../B2-K47-run-1/` prove no-session variants and format validation ordering.

No historical runtime verdict is transferred; all runtime references above are current candidate5 captures. Source joins use `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/reviews/campaign-completion/candidate5-source-evidence-joins.json`.
