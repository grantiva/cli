# N2-04 candidate5 joined clause assessment

Verdict: **PASS**.

Expected: With the stray: `diff approve` approves A and B only and lists the stray under `ignored`; `diff compare` compares A and B only, same `ignored`; text output prints a note naming it. Without strays `ignored` is omitted. Only strays: the error names the configured screens that have no capture. Exit codes per README (compare exits 1 when a screen has no baseline) (plan N2-04; README diff section "any other file in `.grantiva/captures/` ... is listed in a note (and under `ignored` in `--json`)"; docs/mcp.md vrt_compare/vrt_approve)

Fresh synthetic A/B fixture in this directory proves configured-only approve/compare, stray `ignored`, omitted `ignored` without a stray, and only-stray configured-screen diagnostic.

No historical runtime verdict is transferred; all runtime references above are current candidate5 captures. Source joins use `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/reviews/campaign-completion/candidate5-source-evidence-joins.json`.
