# Android checkpoint d162c83f interim review

**Verdict: changes requested (one important completeness finding).**

Scope was limited to the Android additions at checkpoint `d162c83f` after the previously accepted progress rereview: the recent environment, hierarchy, MCP type/script, B2-K89, and B2-K24 rows. The uncommitted/running killed-app group was excluded. I made no live or device calls and did not re-review the already accepted targeted gesture and crash rows.

## Finding

### Important — B2-K24 is graded pass without evidence for every required leg

The B2-K24 row cites `findings/evidence/cov3-android/AND-128-maestro-format/` and says an Android Maestro-format capture parsed and ran ID selectors successfully. That runtime leg is valid: `RECOVERY/tools/controller-targeted-review-gaps.sh:56-62` backs up the normal config, copies the preserved Maestro-format fixture to both the evidence directory and the runtime `grantiva-android.yml`, runs the captured `diff capture`, preserves its outputs, then restores the config. The command need not name the fixture because the fixture is installed at the command's normal config path.

The evidence still does not establish every B2-K24 criterion:

- The retained command has no second invocation with the matrix-required explicit `--platform android`.
- The result does not cite preserved evidence for the named source-test clauses covering Android defaults (`module app`, `variant debug`, `appId`), command-line app-ID override, and ID-selector generation.
- It does not account for the incorporated B-C08.2 native-config branch, which must either fail clearly or support ID selectors on both platforms and be documented in the README.

The row should remain pending/partial until those clauses are evidenced or explicitly separated under the campaign's grading rules.

The corrected source/documentation audit is useful and uses the exact candidate checkout (`release-main` at `8f2cff676b3c12e951478920fa20e600cdca4e29`), but it covers only the documentation text and does not replace the missing clauses above.

## Accepted within this bounded review

- **B2-K89:** the new absolute audit points to the candidate README at the exact candidate HEAD, and its lines explicitly cover no-baseline and mixed-comparison exit behavior plus the `ci run` distinction. Its cited runtime/MCP evidence is consistent with that result.
- **AND-035/037/038/039/040:** the retained commands, reports, UI/logcat observations, terminal ready states, and failure-screenshot path support the stated environment and crash outcomes without a source-working-directory substitution.
- **AND-051/053/054/055/061:** the shared controller script records ready-file observation before the hierarchy calls, verifies the keep-alive process is alive, then invokes AND-061 first. `ready-observed.json` and the AND-061 output have the same recorded second, and the call completes in 0.2 seconds. The XML/JSON outputs and byte-identical JSON variants support the narrower hierarchy claims.
- **AND-096, MCP-014, MCP-026, B-C17.1:** the retained request transcript and results support append typing, the valid four-step script, stop-on-error behavior, validate-before-run behavior, and reporting both invalid steps. The candidate tool description/source cited by the evidence documents the validation decision.

The table footer is internally consistent at **141/467: 133 pass, 2 fail, 4 blocked, 2 n/a**. Correcting B2-K24 from pass to pending/blocked would require the corresponding count adjustment; this review does not prescribe a final status label because the campaign controller owns the evidence-recovery decision.
