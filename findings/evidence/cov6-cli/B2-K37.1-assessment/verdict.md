# B2-K37.1 candidate5 clause assessment

Verdict: **PASS**.

Expected: One function in GrantivaCore returns the default simulator name; ProjectResolver, DriverCommand, BuildTools, SimTools (and their schema text), InitCommand and DoctorRunner all use it. grep for `"iPhone 1[0-9]` in Sources/ finds only that function and help examples. • `init` writes a Grantiva-specific name (for example `Grantiva <newest iPhone type>`) that `simulator ensure`/`run` creates on first use, or, if it writes a stock name, warns when a simulator of that name already exists and was not created by Grantiva (provenance ledger), naming it. • GrantivaCLITests/InitIOSTests: `iosTemplate` writes the shared default; GrantivaMCPTests/ToolSchemaTests: schema defaults equal the shared default; GrantivaCoreTests/ProjectResolutionTests: no simulator flag/config resolves to it. (criteria 1, 2, 4 of 4; brief K37 Acceptance criteria; Platforms: ios)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B2-K37.1-run-1/source.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `source.stdout`, `source.stderr` retained.

Accepted exact-tree source proof join: `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/reviews/campaign-completion/candidate5-source-evidence-joins.json`; this is used only for the named source clause.
