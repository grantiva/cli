# B2-K107-b candidate5 clause assessment

Verdict: **PASS**.

Expected: `RunnerSession.runFlowFiles` (and the single-flow capture entry) accept a lease directory, or a runner home, defaulting to the current behaviour; every test passes a temp one. • Running the full `swift test` with `GRANTIVA_RUNNER_HOME` pointed at an empty directory leaves that directory empty (or nonexistent) afterwards. • Add a guard test in `GrantivaCoreTests` (e.g. `TestHygieneTests.testSuiteDoesNotWriteIntoTheRunnerHome`), or a CI step that runs the suite with `GRANTIVA_RUNNER_HOME` set to a fresh dir and fails if anything appears in it. (brief K107-b Acceptance criteria; Platforms: n/a)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B2-K107-b-run-1/docs-source.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `docs-source.stdout`, `docs-source.stderr` retained.

Accepted exact-tree source proof join: `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/reviews/campaign-completion/candidate5-source-evidence-joins.json`; this is used only for the named source clause.
