# Candidate 4 CLI rows 51–100 evidence review

Verdict: **APPROVED** for the next 50 previously unreviewed direct rows in `cov5-cli/findings/cov5-cli-results.md`. I found no material unsupported pass in this bounded set.

Reviewed rows, in results-file order after excluding the first review's rows: CLI-047, CLI-050–056, CLI-129–131, CLI-057–060, CLI-062, CLI-132–134, CLI-165–171, CLI-063, CLI-065, CLI-067–068, CLI-135, CLI-069–077, CLI-136, CLI-078–082, CLI-137–138, and CLI-084–085 (50 total).

The review compared each result with its exact frozen-matrix clause, read the accepted verdicts and raw streams, and checked the adjacent command and identity records. Every inspected identity binds candidate manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783` and QA executable SHA-256 `2a4e90e655b2a43234b4c1c5cac403042df17aa43e3e6bd0d011743e38fb9fb5`. No accepted capture timed out, retained a live process group, or reported cleanup failure. Where a corrected rerun is linked, the earlier insufficient fixture is not used for the pass.

CLI-063 is supported by a deliberate two-directory join. `CLI-063-run-1` supplies 18 supported Maestro commands/forms that parse through to only the proven-absent simulator diagnostic. Its verdict explicitly joins the corrected `swipe` `from:` fixture in `CLI-063-run-2`; that second capture has its own candidate-matched identity and reaches only the same device-resolution diagnostic. The superseded run-1 `swipe-from` parse error is not counted.

CLI-170 covers the complete inherited-version corpus rather than examples alone: the retained output contains 172 command/leaf paths, each records exit zero and `2.1.0`, and ends `total=172 passed=172`. CLI-085 prints `grantiva-runner 1.1.28-grantiva.15`, which is the exact runner frozen in candidate 4 and is the required substitution under the matrix's runner/version-literal interpretation.

The remaining rows' raw outputs support their required help structure, alias/equivalence behavior, parsing and pre-device failures, output stream placement, exit status, JSON schema, precedence, and runner-install/version clauses. No source-only claim or unrelated device fixture is used to fill a missing direct clause.

Material gaps: **none found**.
