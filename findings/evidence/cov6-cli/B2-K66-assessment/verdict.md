# B2-K66 candidate5 clause assessment

Verdict: **PASS**.

Expected: README "From source" copies both: `cp -R .build/release/grantiva .build/release/grantiva_GrantivaCore.bundle /usr/local/bin/` (or installs into a prefix directory and links the binary), and says why the bundle must sit beside the binary. • Following the new steps exactly, `grantiva runner install` exits 0. (brief K66 Acceptance criteria; Platforms: n/a)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B2-K66-run-1/docs-source.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `docs-source.stdout`, `docs-source.stderr` retained.

Accepted exact-tree source proof join: `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/reviews/campaign-completion/candidate5-source-evidence-joins.json`; this is used only for the named source clause.
