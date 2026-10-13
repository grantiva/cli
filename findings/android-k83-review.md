# Android B2-K83 scoped review

Candidate CLI source is `8f2cff676b3c12e951478920fa20e600cdca4e29`. Review scope is limited to `B2-K83-subflow-exact-rerun1`, its source join, and the B2-K83 matrix criterion. No live command was run.

## Verdict

**B2-K83 [android]: approved.** Both scalar `runFlow: sub.yaml` and mapping `runFlow: {file: sub.yaml}` forms exit 0 and return exactly `FromSub`, then `Main`; the retained inventories contain exactly those PNGs. The no-screenshot subflow contributes no separate capture and remains one `Run flow "sub.yaml"` step before `Main`. Duplicate `Main` fails before execution with an actionable collision error, and a missing subflow retains the runner's specific file/validation error.

The exact-head staging assertions cover both forms and ordered names, the no-screenshot behavior, duplicate-name rejection, and the permitted cycle/missing alternative. The matrix allows a cycle **or** missing-subflow runtime error, so the captured missing case plus cycle semantic assertion satisfies that clause. Platform-half rules allow the Android runtime to grade the Android half despite the brief's historical iOS fixture wording.

No unsupported criterion or new breakage was found.
