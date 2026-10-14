# B2-K38 candidate5 clause assessment

Verdict: **PASS**.

Expected: Re-running the repro: init either writes no scheme guess and warns `Several schemes found: Landmarks, Landmarks (UI Testing). Set scheme in grantiva.yml or pass --scheme.` (exit 0, file written with a placeholder comment), or writes the first and warns naming the others; `grantiva init --scheme "Landmarks (UI Testing)"` writes that scheme silently. • With exactly one shared scheme, init writes it with no warning. • init uses the same scheme detection as ProjectResolver (one shared function), so `init` then `run` never disagree. • GrantivaCLITests/InitIOSTests: `iosTemplate` (or the new detection seam) with two detected schemes produces the warning; with one, none. (brief K38 Acceptance criteria; Platforms: ios)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B2-K38-run-1/source.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `source.stdout`, `source.stderr` retained.

Accepted exact-tree source proof join: `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/reviews/campaign-completion/candidate5-source-evidence-joins.json`; this is used only for the named source clause.
