# Task 7 Step 1 independent compatibility review

## Verdicts

- **Spec: PASS.** The range `03cee568869c45077c3015f97f8b75d19ea822c4..520ddba0a7074ed2f159c499dbc926ba78c9c7e8` implements the authorized Step 1 scope. `RunnerReportSteps` now decodes the fixed artifact fields, `logTail`, the string note map, and recursive `subCommands` without losing the enclosing commands or their failure objects. `RunnerSession` exports only report-referenced log tails and retains their bytes after report-directory deletion. No Step 2+ version, bundle, WDA, stamp, packaging, or release work appears in the range.
- **Source quality: PASS.** I found no actionable correctness or security defect in the changed production source. Log-tail discovery is recursive but attributes nested artifacts to the enclosing top-level command for trailing selection. A physical asset is accepted only when its basename is report-referenced and its normalized report-relative reference equals that attributed flow's asset path; the existing `artifactURL` check then retains symlink/report-root containment. Existing attribution, stable collision handling, PNG/XML behavior, and generic finalization/rewriting remain exercised by the compatibility suite.
- **Evidence: NEEDS FOLLOW-UP (non-source, release-gate evidence gap).** The retained RED/GREEN logs establish behavior, but do not themselves record the promised fresh runner-home path, unset credential state, or a post-test assertion that the new home remained empty.

## Findings

No source/spec finding blocks Step 1.

### E1 — environment isolation claim is not independently auditable from retained output

`findings/evidence/fix4-7/compat/commands.txt` states that every command used a fresh `GRANTIVA_RUNNER_HOME` and unset `GRANTIVA_API_KEY`/`GRANTIVA_TOKEN`, while none of the six retained logs prints those values or a before/after runner-home inventory. In particular, the required “must leave empty” condition has no retained check.

**Exact remediation:** before treating Step 1 evidence as complete, add one small metadata artifact for the retained GREEN runs (or rerun the focused compatibility command once) that records: the exact command, the unique temporary runner-home path, explicit confirmation that both API variables were unset, exit status, and `find "$GRANTIVA_RUNNER_HOME" -mindepth 1 -print` after the test with empty output. Keep this artifact off the product branch with the rest of the campaign evidence. No source change is requested.

## Evidence assessment

- `semantic-red.log` is a real semantic RED against untouched base source: the production-shaped flow decodes to zero commands and loses the failure message. This satisfies the requirement that RED not rely only on a compile failure.
- `focused-red.log` separately captures the compile-contract incompatibility of the prior `[String: String]?` API.
- `focused-green.log`, `report-trace-green.log`, and `fixture-green.log` show the named compatibility checks passing; the combined report/session/trace run reports 29 tests and zero failures.
- The production-shaped fixture covers command and failure survival plus `logTail` and nested `notes` preservation through generic finalization and rewriting. The trace test covers top-level and nested-command filenames, unreferenced-log exclusion, non-text bytes, and successful reads after deleting the ephemeral report directory.
- Existing traversal, attribution, symlink, collision, old-report, and PNG/XML tests remain in the 29-test compatibility run. The new traversal test also rejects an escaping log-tail reference.
- `git diff --check` is clean. The product range contains only the two production sources, two tests, and two fixtures; campaign evidence/controller files are absent from the product-branch net diff.

## Scope note

Task 6 merge/CI and Task 7 Steps 2–7 are explicitly deferred and are not Step 1 defects.

## Final Step 1 evidence verdict

**Evidence: PASS.** The new `verification-final` package closes E1 without changing product HEAD. `start.json` and `result.json` agree on commit `520ddba0a7074ed2f159c499dbc926ba78c9c7e8`, the exact focused-suite argv, runner home `/tmp/grantiva-fix4-7-final.KX4Mog`, and explicitly unset API credentials. `home-before.txt` and `home-after.txt` are both zero bytes, establishing that the isolated runner home began and remained empty. `result.json` records exit code 0, while `stdout.log` independently records the expected 29 tests with zero failures; `stderr.log` contains only build progress and an existing compiler deprecation warning.

E1 is resolved. The final Step 1 verdict is **Spec PASS / Source quality PASS / Evidence PASS**, with no actionable compatibility finding. The separately discovered Task 6 default-name fixture portability issue and the later main merge/full combined test remain outside this unchanged compatibility-source review.
