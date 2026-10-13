# Round3 final integration review package

Scope: verify complete frozen-binary coverage accounting, failure dispositions, cleanup, and report consistency. No product source changed in this coverage pass. All slices have independent row reviews; inspect their cited raw evidence selectively to resolve concrete concerns. Do not rerun devices or builds.

Merge/input history:
```text
a1f19858 Report complete round 3 coverage and all open fix-wave findings
8848358f Apply reviewed coverage corrections without replacing original verdicts
6f4cba63 Merge complete Android round 3 coverage evidence
bba0fbfb Complete all Android coverage rows and verify final cleanup
77ca7b2b Merge CLI and iOS round 3 coverage evidence
e2f6bf30 Verify final scroll and swipe measurements and remove campaign emulators
d48f0c57 Retain independent gesture-load and timeline reviews
ea58f5a5 Verify all 172 help pages against the frozen candidate
b13ba933 Prepare evidence-backed iOS expectation corrections
580c9487 Retain excluded gesture attempt with late baseline and absent selector
be574894 Preserve executed hierarchy harnesses and transport triage
4ac7cbda Record MCP transport finding and evidence-backed matrix corrections
```

Key inputs: round3 report; task6-effective-coverage-audit.json; task6-corrected-criterion-review-map.json; task6-b2-b3-effective-rows.md; all three cov3 result ledgers; final cleanup evidence; L64-L81 briefs; retained L51/L53/L61/L62. Raw B2/B3 Android current full ledger was merged at the Android merge and remains available at findings/cov3-android-results.md. The report references full per-platform row table.

Task6 review diff (raw binary artifacts excluded; immutable preserved evidence available under findings/evidence):
```diff
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/00-expectation-corrections-round3.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/00-expectation-corrections-round3.md
index cac71c36..b27db829 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/00-expectation-corrections-round3.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/00-expectation-corrections-round3.md
@@ -29,7 +29,7 @@ These corrections resolve matrix assumptions contradicted by accepted documentat
 
 | Corrected result ID(s) | Retained evidence | Post-correction disposition |
 |---|---|---|
-| CLI-003, D2-47, N3-16 | `cov3-cli/findings/evidence/cov3-cli/CLI-003/`, `D2-47/`, `N3-16/`; controller `findings/evidence/cov3-controller/help-corpus/summary.json` | **Rerun required:** regenerate all 172 exact-candidate pages, update only the accepted corpus delta, then prove a zero changed-file list. Do not mark pass from the draft. |
+| CLI-003, D2-47, N3-16 | `cov3-cli/findings/evidence/cov3-cli/CLI-003/`, `D2-47/`, `N3-16/`; controller `findings/evidence/cov3-controller/help-corpus/summary.json` | **Corrected pass:** the fresh Task 6 replay in `findings/evidence/cov3-controller/help-corpus-task6/summary.json` proves all 172 commands exit0, required headings, and zero canonical byte mismatches. |
 | CLI-045, CLI-145 | `cov3-cli/findings/evidence/cov3-cli/CLI-045/`, `CLI-145/` | Existing raw supports corrected mutual-exclusion exit 64; preserve CLI-145's three exit-1 platform legs. Eligible for corrected pass after merge review. |
 | D2-27 | `cov3-cli/findings/evidence/cov3-cli/D2-27/helps_r3.out` | Existing six-page inventory supports corrected pass; malformed first attempt remains excluded provenance. |
 | MCP-078 [ios], MCP-078 [android] | iOS attempt37 MCP responses; Android `MCP078-force-stop-rerun1/` | Mixed app-dependent errors and valid device/UI successes support corrected pass on both platforms. |
@@ -37,7 +37,7 @@ These corrections resolve matrix assumptions contradicted by accepted documentat
 | B3-L55.1 [ios], B3-L55.2 [android] | iOS `cov3-ios-attempt48b/`; Android `B3-L55-active-ready-rerun2/`; `Sources/GrantivaCore/Runner/RunnerExecution.swift` terminal publication path | Active owner/process/stream and terminal interruption evidence support corrected pass. |
 | X-013 [ios], X-013 [android] | iOS attempt62 lifecycle documents; Android `X013-X015-X017-android-rerun1/` | Shared fields/types agree and platform app/device names are separately required; corrected pass. |
 | IOS-016 | iOS attempt74 teardown/process/home/session artifacts; K68 source tests | Corrected orphan-helper criterion passes; no product brief is required. |
-| B2-K103 [ios], B2-K103 [android] | iOS `cov3-ios-analysis-n2-07/audit.json`; Android current JSON-key audit; `LegacyJSONKeys.swift`, `JSONKeyCasingContractTests.swift` | Only documented equal aliases occur; corrected pass on both platforms. |
+| B2-K103 [ios], B2-K103 [android] | iOS `cov3-ios-analysis-n2-07/audit.json`; Android `N2-07-legacy-json-alias-audit-current/`; `LegacyJSONKeys.swift`, `JSONKeyCasingContractTests.swift` | Only documented equal aliases occur; corrected pass on both platforms. |
 | IOS-153 | iOS attempt109b three successful modes and `ios109b-n12-ios153-review.md` | Stable decoded content agrees; dynamic timestamps/durations differ truthfully. Corrected pass. |
 | AND-137, AND-138 | Android `output-modes-exact-rerun3/`, `output-contracts-exact-rerun1/AND-137-quiet-fail/` | Stable decoded mode behavior supports corrected pass. |
 | B2-K19 [android] | Android output-mode directories above plus `B2-K25-ci-correction-rerun2/` | Supported local modes and documented Android CI refusal satisfy corrected Android criterion; corrected pass. |
@@ -46,15 +46,15 @@ These corrections resolve matrix assumptions contradicted by accepted documentat
 | B2-K25 [android] | Android `B2-K25-full-exact-rerun1/`, `B2-K25-ci-correction-rerun2/` | Supported local semantics and documented CI refusal support corrected Android pass. |
 | B2-K25 [ios] | iOS attempts65, 65b, 66, 66b; L71 | **Still product-failing:** absent-app skipped install queries the missing data container. Correction clarifies the compound but does not waive L71 or produce a pass. |
 | N3-06 [android] | Android `N3-06-ten-recordings-rerun1/`, ffprobe audit, `B3-K111-record-frames-rerun1/` | Ten final MP4s are exactly 3 seconds; corrected pass. |
-| B2-L03, B3-L51 | Android `B2-K07-N03-B2-L03-scroll-renderers-rerun1/` and `B3-L51-four-forms-rerun9/`; production client/report logs; `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Android/UIAutomator2Client.swift` and `Sources/GrantivaCore/Runner/RunnerReportSteps.swift` | Instrumentation-only correction. Re-evaluate each row from direct in-flow hierarchy measurements plus terminal CLI semantic artifacts; do not infer a pass from this document alone. |
+| B2-L03, B3-L51 | Android `B2-L03-per-step-hierarchy-rerun10/` with `B2-K07-N03-B2-L03-scroll-renderers-rerun1/` join, and `B3-L51-four-forms-rerun12/`; `findings/android-b2l03-rerun10-final-review.md` and `findings/android-b3l51-rerun12-final-review.md`; production client/report logs; `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Android/UIAutomator2Client.swift` and `Sources/GrantivaCore/Runner/RunnerReportSteps.swift` | Instrumentation-only correction. Both rows already have independently reviewed valid passes from the named final captures; no duplicate corrected rerun line is added. |
 
 ## Result IDs for corrected reruns
 
 The controller should add corrected rerun result lines for these exact existing IDs after merges, without replacing original lines:
 
-`CLI-003`, `D2-47`, `N3-16`, `CLI-045`, `CLI-145`, `D2-27`, `MCP-078 [ios]`, `MCP-078 [android]`, `IOS-058`, `B3-L55.1 [ios]`, `B3-L55.2 [android]`, `X-013 [ios]`, `X-013 [android]`, `IOS-016`, `B2-K103 [ios]`, `B2-K103 [android]`, `IOS-153`, `AND-137`, `AND-138`, `B2-K19 [ios]`, `B2-K19 [android]`, `AND-022`, `B2-K25 [ios]`, `B2-K25 [android]`, `N3-06 [android]`, `B2-L03`, and `B3-L51`.
+`CLI-003`, `D2-47`, `N3-16`, `CLI-045`, `CLI-145`, `D2-27`, `MCP-078 [ios]`, `MCP-078 [android]`, `IOS-058`, `B3-L55.1 [ios]`, `B3-L55.2 [android]`, `X-013 [ios]`, `X-013 [android]`, `IOS-016`, `B2-K103 [ios]`, `B2-K103 [android]`, `IOS-153`, `AND-137`, `AND-138`, `B2-K19 [ios]`, `B2-K19 [android]`, `AND-022`, `B2-K25 [ios]`, `B2-K25 [android]`, `N3-06 [android]`.
 
-Product failures owned by L64–L79 remain unchanged and require product fixes rather than expectation reruns.
+Product failures owned by L64–L80 remain unchanged and require product fixes rather than expectation reruns.
 
 ## Executed help-corpus verification
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L64-android-launch-passes-after-fatal.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L64-android-launch-passes-after-fatal.md
index 0c1eb6e9..007a780e 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L64-android-launch-passes-after-fatal.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L64-android-launch-passes-after-fatal.md
@@ -6,7 +6,7 @@ Platforms: android
 Rows: B3-L57
 Regresses: L57, addressed in runner #23; retain the revised acceptance criteria and withdrawn wall-time target.
 Candidate: CLI 8f2cff67, runner fd9d8e8 / 1.1.28-grantiva.13.
-Status: evidence-backed triage during the incomplete round-3 coverage pass; not a round-completion statement.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 
 ## Expected
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L65-script-missing-steps-error-contract.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L65-script-missing-steps-error-contract.md
index 32ce2bcb..c59faead 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L65-script-missing-steps-error-contract.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L65-script-missing-steps-error-contract.md
@@ -6,7 +6,7 @@ Platforms: ios and android, observed with live sessions
 Rows: B3-L15.2 [ios], B3-L15.2 [android]
 Regresses: L15's exact missing-required-argument criterion from the round-3 fix wave.
 Candidate: CLI 8f2cff67, runner 1.1.28-grantiva.13.
-Status: evidence-backed triage during the incomplete round-3 coverage pass.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 
 ## Expected
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L66-ios-identifier-tap-fallback.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L66-ios-identifier-tap-fallback.md
index acfe4555..aa024986 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L66-ios-identifier-tap-fallback.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L66-ios-identifier-tap-fallback.md
@@ -4,7 +4,7 @@ Severity: wrong-result
 Component: mcp / iOS WDA selector
 Rows: IOS-102, B2-K78, D2-36 [ios]
 Candidate: CLI 8f2cff67, runner 1.1.28-grantiva.13, demo 75acc87.
-Status: evidence-backed triage during the incomplete round-3 coverage pass.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 
 ## Expected
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L67-doctor-ambiguous-platform-section.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L67-doctor-ambiguous-platform-section.md
index 6d9a129e..d3fcffb7 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L67-doctor-ambiguous-platform-section.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L67-doctor-ambiguous-platform-section.md
@@ -4,7 +4,7 @@ Severity: contract
 Component: cli / doctor
 Row: CLI-025
 Candidate: CLI 8f2cff67.
-Status: evidence-backed triage during the incomplete round-3 coverage pass.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 
 ## Expected
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L68-android-detached-start-ready-before-app.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L68-android-detached-start-ready-before-app.md
index 732499a4..bb7743ab 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L68-android-detached-start-ready-before-app.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L68-android-detached-start-ready-before-app.md
@@ -4,7 +4,7 @@ Severity: contract
 Component: cli / runner lifecycle
 Row: AND-127
 Candidate: CLI 8f2cff67, runner fd9d8e8 / 1.1.28-grantiva.13.
-Status: evidence-backed triage during the incomplete round-3 coverage pass.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 
 ## Expected
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L69-starting-runner-json-omits-null-port.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L69-starting-runner-json-omits-null-port.md
index ccb67d05..4bafd799 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L69-starting-runner-json-omits-null-port.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L69-starting-runner-json-omits-null-port.md
@@ -4,7 +4,7 @@ Severity: contract
 Component: cli / runner lifecycle JSON
 Rows: N3-03 [ios], N3-03 [android]
 Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29.
-Status: evidence-backed triage during the incomplete round-3 coverage pass.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 Regression: round-3 L38-a starting-state contract and N3-03; the row originates in the round-3 fix wave (CLI #200–#203, with #205 lifecycle addendum).
 
 ## Expected
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L70-baseline-filename-migration-documentation.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L70-baseline-filename-migration-documentation.md
index ee7e63b8..c6b45e2b 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L70-baseline-filename-migration-documentation.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L70-baseline-filename-migration-documentation.md
@@ -4,7 +4,7 @@ Severity: contract
 Component: public baseline and capture documentation
 Rows: B-I16.2 [ios]
 Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29.
-Status: evidence-backed triage during the incomplete round-3 coverage pass.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 
 ## Expected
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L71-no-build-no-launch-queries-absent-ios-container.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L71-no-build-no-launch-queries-absent-ios-container.md
index ad4222ca..8c793c4c 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L71-no-build-no-launch-queries-absent-ios-container.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L71-no-build-no-launch-queries-absent-ios-container.md
@@ -4,7 +4,7 @@ Severity: contract
 Component: cli / build install
 Rows: D2-08 [ios], B2-K25 [ios] (with D2-07 status contract)
 Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29.
-Status: evidence-backed triage during the incomplete round-3 coverage pass.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 
 ## Expected
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L72-foreground-start-sigint-during-startup-reports-wda-timeout.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L72-foreground-start-sigint-during-startup-reports-wda-timeout.md
index cdf7f98d..de12c170 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L72-foreground-start-sigint-during-startup-reports-wda-timeout.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L72-foreground-start-sigint-during-startup-reports-wda-timeout.md
@@ -4,7 +4,7 @@ Severity: contract
 Component: cli / runner lifecycle
 Rows: N2-15 [ios] (B3-L37 [ios] notice remains passing)
 Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29.
-Status: evidence-backed triage during the incomplete round-3 coverage pass; steady-ready control passed.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 
 ## Expected
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L73-force-simulator-teardown-omits-stopped-runner-result.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L73-force-simulator-teardown-omits-stopped-runner-result.md
index 30e22410..ef51b04c 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L73-force-simulator-teardown-omits-stopped-runner-result.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L73-force-simulator-teardown-omits-stopped-runner-result.md
@@ -4,7 +4,7 @@ Severity: contract
 Component: CLI / simulator teardown JSON
 Rows: D2-20 [ios], leg (d)
 Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29.
-Status: evidence-backed triage during the incomplete round-3 coverage pass.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 
 ## Expected
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L74-iso8601-json-date-change-lacks-public-note.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L74-iso8601-json-date-change-lacks-public-note.md
index 99808b2d..34f3afe4 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L74-iso8601-json-date-change-lacks-public-note.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L74-iso8601-json-date-change-lacks-public-note.md
@@ -4,7 +4,7 @@ Severity: contract
 Component: CLI JSON output documentation
 Rows: B-C22.2 [ios], B-C22.2 [android]
 Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29.
-Status: evidence-backed triage during the incomplete round-3 coverage pass.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 
 ## Expected
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L75-subdirectory-cycle-hops-use-containing-file-relative-operands.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L75-subdirectory-cycle-hops-use-containing-file-relative-operands.md
index bb0dd8ec..9e9b5aba 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L75-subdirectory-cycle-hops-use-containing-file-relative-operands.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L75-subdirectory-cycle-hops-use-containing-file-relative-operands.md
@@ -4,7 +4,7 @@ Severity: contract
 Component: CLI runner-output path rewriting
 Rows: B3-L20 [ios], B3-L20 [android] (platform-independent source path)
 Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29; runner fd9d8e8d1cb109eda6116f4221da10257b9838e3.
-Status: evidence-backed triage during the incomplete round-3 coverage pass.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 
 ## Expected
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L76-force-teardown-matches-unrelated-process-arguments.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L76-force-teardown-matches-unrelated-process-arguments.md
index 8ceb8d6c..a83fbc7d 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L76-force-teardown-matches-unrelated-process-arguments.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L76-force-teardown-matches-unrelated-process-arguments.md
@@ -4,7 +4,7 @@ Severity: wrong-result
 Component: iOS simulator force teardown
 Rows: IOS3-OBS-01 (round-3 side finding)
 Candidate: CLI `8f2cff676b3c12e951478920fa20e600cdca4e29`.
-Status: evidence-backed triage during the incomplete round-3 coverage pass.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 
 ## Expected
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L77-android-stop-app-reports-success-with-app-still-running.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L77-android-stop-app-reports-success-with-app-still-running.md
index 62a46a76..96bb5de2 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L77-android-stop-app-reports-success-with-app-still-running.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L77-android-stop-app-reports-success-with-app-still-running.md
@@ -4,7 +4,7 @@ Severity: wrong-result
 Component: runner Android app lifecycle
 Rows: B3-L49 [android]
 Candidate: runner `fd9d8e8` bundled by CLI `8f2cff676b3c12e951478920fa20e600cdca4e29`.
-Status: evidence-backed triage during the incomplete round-3 coverage pass.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 
 ## Expected
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L78-interrupted-run-returns-before-log-stream-exits.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L78-interrupted-run-returns-before-log-stream-exits.md
index 5cb159da..70f7d02c 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L78-interrupted-run-returns-before-log-stream-exits.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L78-interrupted-run-returns-before-log-stream-exits.md
@@ -5,7 +5,7 @@ Component: cli / log lifecycle
 Platforms: iOS
 Rows: IOS-064
 Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29; QA binary SHA256 3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8.
-Status: independently confirmed during incomplete round-3 verification; cleanup lag is transient, not a persistent leak.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 
 ## Expected
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L79-optional-tap-failure-exits-nonzero.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L79-optional-tap-failure-exits-nonzero.md
index 78fe1a95..9ba5fbcf 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L79-optional-tap-failure-exits-nonzero.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L79-optional-tap-failure-exits-nonzero.md
@@ -5,7 +5,7 @@ Component: runner command report / CLI result aggregation boundary
 Platforms: Android (reproduced); shared runner semantics
 Rows: AND3-OBS-01 (side finding; no matrix row invented)
 Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29; runner fd9d8e8; QA binary SHA256 3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8.
-Status: independently confirmed during round-3 verification.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 
 ## Expected
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L80-mcp-concurrent-large-responses-interleave-on-stdout.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L80-mcp-concurrent-large-responses-interleave-on-stdout.md
index 8493d708..18c5e0b1 100644
--- a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L80-mcp-concurrent-large-responses-interleave-on-stdout.md
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L80-mcp-concurrent-large-responses-interleave-on-stdout.md
@@ -5,7 +5,7 @@ Component: MCP stdio response transport
 Platforms: Android reproduced; shared MCP server transport
 Rows: AND3-OBS-02 (side finding; no matrix row invented)
 Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29; QA binary SHA256 3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8.
-Status: independently confirmed during round-3 verification.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
 
 ## Expected
 
diff --git a/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L81-doctor-default-ownership-note-hidden-by-booted-simulator.md b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L81-doctor-default-ownership-note-hidden-by-booted-simulator.md
new file mode 100644
index 00000000..68e2fc1a
--- /dev/null
+++ b/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L81-doctor-default-ownership-note-hidden-by-booted-simulator.md
@@ -0,0 +1,58 @@
+# Doctor hides the default-simulator ownership note when another simulator is booted
+
+Severity: contract
+Component: doctor simulator diagnostics
+Platforms: iOS host check
+Rows: N3-15
+Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29.
+Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
+
+## Expected
+
+N3-15 requires `doctor` and `doctor --json` to say that a simulator with Grantiva's default name is not used as the default when that simulator exists but Grantiva did not create it:
+
+`("iPhone 18 Pro" (<udid>) was not created by Grantiva, so it is not used as the default)`
+
+The check remains advisory and the note does not change the command's exit code. The row is read-only and does not require every simulator to be shut down.
+
+## Actual
+
+After final campaign cleanup, the host still has two owner simulators booted:
+
+- `iPhone 17 Pro` `B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C`, iOS 26.0;
+- default-named `iPhone 18 Pro` `FE441EE5-BBFC-4981-B68A-59C0DBCE26D6`, iOS 27.0, the exact user-created simulator identified by L08 and absent from Grantiva's created-simulator ledger.
+
+Both doctor forms exit 0. Text prints only:
+
+```text
+✓ Booted Simulator  iPhone 17 Pro — iOS 26.0
+```
+
+JSON likewise contains a single successful `Booted Simulator` record whose message names only the iPhone 17 Pro. Neither output names the iPhone 18 Pro, its UDID, or the required ownership/default note. Booted inventories before and after are byte-identical, so the valid read-only rerun touched neither owner device.
+
+## Evidence
+
+- `findings/evidence/cov3-controller/N3-15-after-final-cleanup/text.out`
+- `findings/evidence/cov3-controller/N3-15-after-final-cleanup/json.out`
+- `findings/evidence/cov3-controller/N3-15-after-final-cleanup/booted-before.json`
+- `findings/evidence/cov3-controller/N3-15-after-final-cleanup/booted-after.json`
+- `findings/evidence/cov3-controller/N3-15-after-final-cleanup/commands.json`
+- `findings/controller-N3-15-final-environment-review.md`
+- Retained L08 ownership proof for the exact iPhone 18 Pro and UDID: `docs/superpowers/plans/2026-10-12-coverage-issues-round2/L08-mcp-build-default-takes-user-simulator.md:19-35`.
+
+## Supported cause
+
+`Sources/GrantivaCore/Doctor/DoctorRunner.swift:94-115` lists simulators and immediately returns an `.ok` check for `devices.first(where: \.isBooted)`. It calls `noBootedSimulatorCheck` only when no simulator is booted. The default-name ownership lookup and note at lines 119-128 therefore run only in the no-booted branch.
+
+`Tests/GrantivaCoreTests/DoctorTests.swift:252-269` calls `noBootedSimulatorCheck` directly with a shutdown, unowned default-named simulator. The production-entry test at lines 279-285 covers one booted device separately. No test calls the full `checkBootedSimulator` entry point with both a booted non-default device and an unowned default-named device.
+
+## Acceptance criteria
+
+- Call the full `DoctorRunner.checkBootedSimulator` production entry with a booted non-default iPhone 17 Pro and an unowned default-named iPhone 18 Pro. The returned check names the booted simulator and also contains `"iPhone 18 Pro" (USER-DEFAULT) was not created by Grantiva, so it is not used as the default`.
+- Repeat with the two devices in the opposite list order. The ownership note is present in both orders; simulator-list ordering cannot hide it.
+- Doctor text and `--json` expose the same note. The check remains in `Advisory`, its status remains `ok` when a simulator is booted, and the note does not change either command's exit code.
+- When no simulator with the default name exists, a booted non-default simulator remains the ordinary concise success with no ownership note.
+- When the default-named simulator's UDID is in the active runner home's created ledger, no `was not created by Grantiva` note is emitted.
+- Preserve the existing no-booted behavior, including its ownership-aware ensure fix, and preserve the `Could not list simulators` failure branch.
+- Add focused `GrantivaCoreTests/DoctorTests` coverage through `checkBootedSimulator`, not only direct tests of `noBootedSimulatorCheck`.
+
diff --git a/docs/superpowers/plans/2026-10-13-round3-coverage-report.md b/docs/superpowers/plans/2026-10-13-round3-coverage-report.md
new file mode 100644
index 00000000..734cc2ac
--- /dev/null
+++ b/docs/superpowers/plans/2026-10-13-round3-coverage-report.md
@@ -0,0 +1,95 @@
+# Round 3 coverage report
+
+**ROUND 3: 22 findings — round 4 fix wave required.** This comprises 18 newly confirmed findings, L64–L81, and four retained open findings, L51, L53, L61 and L62. A pass on a current-behavior measurement does not close an explicitly open fix brief.
+
+## Candidate and scope
+
+- CLI 2.1.0, source `8f2cff676b3c12e951478920fa20e600cdca4e29`; QA executable SHA256 `3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8`.
+- Runner `1.1.28-grantiva.13+android-drivers-2`, source `fd9d8e8d1cb109eda6116f4221da10257b9838e3`.
+- Demo source `75acc87`; real iOS 26.0/27.0 and Android API35 campaign-owned simulators/emulators. The protected owner devices were not used for flows.
+- Matrix: 1,170 logical rows; 384 CLI, 319 iOS-only, 308 Android-only and 159 shared. Expanding shared rows produces 1,329 effective slice results: CLI384, iOS478, Android467. Auth/console operations and real hardware are outside scope; static help inspection does not authenticate or mutate accounts.
+- Verification used the frozen QA executable. Product source trees remained unchanged. Unit-test acceptance clauses were checked against exact candidate source; this pass did not run Swift/Go builds or test suites. Scratch demo builds and real flows supply the runtime evidence.
+
+## Results and accounting
+
+| Slice | Effective rows | Original pass | Original fail | Original blocked | N/A | Final pass | Final fail | Final blocked |
+|---|---:|---:|---:|---:|---:|---:|---:|---:|
+| CLI | 384 | 368 | 7 | 5 | 4 | 375 | 2 | 3 |
+| iOS | 478 | 447 | 21 | 10 | 0 | 454 | 13 | 11 |
+| Android | 467 | 442 | 17 | 6 | 2 | 452 | 7 | 6 |
+| Total | 1329 | 1257 | 45 | 21 | 6 | 1281 | 22 | 20 |
+
+Original means the completed slice results before Task6 adjudication. Final means the latest additive corrected-criterion review or Task6 completion observation, with every original line retained. Twenty-five corrected-criterion lines comprise 23 passes, one credential block, and one still-failing L71 row. B3-L29 is subsequently closed by its retained runtime/exact-source join; N3-15 is subsequently failed by the post-cleanup read-only doctor reproduction. These two completion observations are not expectation corrections.
+
+Three side findings remain separate from the 1,329 denominator: IOS3-OBS-01→L76, AND3-OBS-01→L79, and AND3-OBS-02→L80. Thus there are 25 final failing observations including side findings; several rows share one root-cause brief. The iOS 27.0 flow-command repeats (39) and six CLI handoffs are retained separately, not counted as extra matrix rows. Historical reruns and invalid harness attempts are never silently substituted for original evidence.
+
+The reproducible counts, source hashes, raw-line/repeat counts and original-versus-final derivation are in `findings/task6-effective-coverage-audit.json`, generated by `findings/tools/task6_effective_coverage.py`. Every B2 regression and B3 brief/platform result appears in `findings/task6-b2-b3-effective-rows.md`; that table is part of this report's per-brief verification record. Corrected rows and reasons are mapped in `findings/task6-corrected-criterion-review-map.json` and `2026-10-13-coverage-issues-round3/00-expectation-corrections-round3.md`.
+
+## Review Focus verdicts
+
+| Focus | Verdict | Evidence and implication |
+|---|---|---|
+| 1. Prior-pass/B2 regressions | Not clean | Most regression rows pass, but iOS identifier fallback, absent-app install and other mapped contract failures remain. The complete B2 table records each platform separately. |
+| 2. Round3 brief acceptance and open behavior | Not clean | B3 missing-steps, nested cycle paths, Android stopApp/crash decisions and starting-port JSON expose L64/L65/L69/L75/L77. Open L51/L53/L61/L62 remain scheduled even where current-behavior measurements pass. |
+| 3. Cross-platform output/session consistency | Not clean | Documented platform identity names and truthful dynamic measurements are accepted through reviewed corrections; explicit-null starting port and public date migration contracts still fail. |
+| 4. Documented flow behavior and crash truthfulness | Not clean | Stock/gesture/selector controls pass extensively, but L64, L77 and optional-report inconsistency L79 prevent a clean verdict. |
+| 5. MCP tools, states and resources | Not clean | Detached starting→ready and dead-sidecar behavior are verified; script wording, iOS identifier matching and concurrent large-response corruption remain L65/L66/L80. |
+
+## Findings carried into Round4
+
+| Brief | Finding | Round4 owner |
+|---|---|---|
+| L51 | Screen/coordinate gestures still use the shell swipe engine | Runner gestures |
+| L53 | Explicit empty device value reaches discovery/signing instead of usage validation | Runner and CLI argument boundaries |
+| L61 | Failure-artifact collection needs bounded concurrent cancellation | Runner capture |
+| L62 | Favorite removal intermittently fails on faster Android devices | Runner/demo isolation |
+| L64 | Android launch can pass after a matching fatal | Runner crash decision |
+| L65 | Missing script steps error differs from the required contract | CLI MCP |
+| L66 | iOS identifier fallback is omitted | CLI WDA selectors |
+| L67 | Ambiguous-platform doctor check uses the wrong section | CLI diagnostics |
+| L68 | Android detached readiness precedes app readiness | CLI lifecycle |
+| L69 | Starting lifecycle JSON omits explicit null port | CLI lifecycle output |
+| L70 | Baseline filename migration lacks public guidance | CLI documentation |
+| L71 | Skipped absent-app install queries a nonexistent data container | CLI build/install |
+| L72 | Startup SIGINT is reported as a WDA timeout | CLI lifecycle |
+| L73 | Force teardown omits stopped-runner metadata | CLI teardown |
+| L74 | JSON ISO8601 date change lacks a public compatibility note | CLI documentation |
+| L75 | Nested cycle hops use containing-file operands | CLI output rewriting |
+| L76 | Force reaper classifies unrelated executable arguments as Grantiva | CLI process ownership |
+| L77 | stopApp reports success while the app remains running | Runner Android lifecycle |
+| L78 | Interrupted run returns before its simulator logging child exits | CLI log cleanup |
+| L79 | Optional miss passes runner flow but fails command/report/CLI aggregation | Runner reporting/integration |
+| L80 | Concurrent large MCP responses interleave stdout bytes | MCP transport |
+| L81 | A booted simulator hides the unowned-default doctor note | CLI diagnostics |
+
+L80 was discovered by a strict transport harness: two ready hierarchy responses interleave at a 65,536-byte boundary. Sequential requests from the same session pass; that control closes lifecycle evidence without waiving transport corruption. L81 was discovered after final cleanup: doctor text/JSON both exit0, but the booted-owner branch skips the required default-ownership note. Its before/after device inventories are unchanged.
+
+## Remaining blocks
+
+| Slice | IDs | Reason |
+|---|---|---|
+| CLI | CLI-083 | Owner simulators remain booted; the no-booted-device prerequisite cannot be created under campaign constraints. |
+| CLI | CLI-153 | Required no-simulator smoke guard was unavailable while protected owner simulators were booted. |
+| CLI | B3-L53 | Empty-selector observation reaches discovery rather than the brief's environment-dependent signing branch; raw acceptance of the empty value remains recorded and the fix remains open. |
+| iOS | B-C21.1, B2-K36 | No-booted-device runtime controls require shutting down protected owner simulators. |
+| iOS | B2-K37.2, B3-L08.1, B3-L08.2, N3-12, N3-13 | Default-device smoke prerequisite is unavailable with protected owner devices booted. |
+| iOS | B-I06.2 | Required WDA endpoint-versus-fallback distinction is not observable in this environment. |
+| iOS | B2-K18, B2-K19 | Local behavior is verified; authenticated CI clauses require unavailable credentials. |
+| iOS/Android | N-08 | Root-level environment isolation is unavailable. |
+| Android | AND-002 | No suitable additional system image under the campaign's download constraint. |
+| Android | AND-012, AND-110, B-C02.1 | Literal global teardown clauses are prohibited; safe scoped halves remain recorded. |
+| Android | AND-088 | Credentials unavailable. |
+
+Previously blocked IOS-018 is verified with its isolated runner-home ledger. CLI-083/B-C21.1 remain blocked after actual campaign cleanup because the owner devices remain booted. CLI-153 and the other default-device guards remain blocked for their stated prerequisites. The inherited AND-002/AND-012/AND-088/B-I06.2/N-08 blocks remain explicit. B3-L29's earlier worker-sandbox block is closed by the reviewed exact-source/runtime join. N3-15's earlier campaign-device block is replaced by the real post-cleanup failure, not preserved as an obsolete excuse.
+
+## Final cleanup and evidence qualifications
+
+Android `FINAL-primary-delete-rerun4` exits0 with all seven checks true: adb is empty; no campaign AVD, created/started record, or global session file remains; `cov3-android` is deleted; unrelated `Pixel_8_API_35` remains. iOS final targeted cleanup removes both campaign UUIDs and their device homes/sessions/processes; the owner iPhone17Pro and iPhone18Pro remain booted and untouched. The later read-only doctor before/after inventories confirm their unchanged state.
+
+L03's final software/GPU runs each end at Landmark28, with per-step direct movement 1,179–1,195px and 23/23 app semantic nodes matching the CLI after density conversion. L51's final four forms all pass with pre-gesture baselines; measured stability-read windows and travel are retained per form. Numeric-only late baselines and the nonexistent Landmark5 selector in prior attempts are explicitly excluded. An outer L03 shell interpolation error occurred only after both successful runs and scoped GPU deletion; retained raw and an additive qualification establish the result. The dead-emulator restoration row measures the restoration branch itself at5.452s rather than incorrectly using the roughly70s whole failed-process duration.
+
+The report does not infer product success from a wrapper exit alone. Independent row reviews qualify schema mistakes, invalid fixtures, historical timing proxies and source joins. Raw captures remain unedited. Correction review is `findings/round3-task6-corrections-review.md`; final slice cleanup is `findings/android-round3-final-summary.md` and the retained iOS cleanup record.
+
+## Next action
+
+Execute `2026-10-13-round4-fix-wave.md` after its independent plan review is resolved: all22 open briefs, reviewed fix PRs, green CI and authorized merges; runner repack; fresh APFS-clone upgrade; release-candidate smoke and coverage. This round does not meet the zero-findings exit criterion. Release/tagging remains the owner's decision.
diff --git a/findings/cov3-cli-results.md b/findings/cov3-cli-results.md
index e717dcee..1628f5a0 100644
--- a/findings/cov3-cli-results.md
+++ b/findings/cov3-cli-results.md
@@ -435,3 +435,19 @@ behaviour is in the note.
 ## Counts
 
 384 unique matrix IDs in the CLI slice; using the latest verdict for rows with preserved reruns: pass 368, fail 7 (1 product contract failure, 6 pending matrix/corpus corrections), blocked 5, n/a 4. Step 3 v2 separately inventories 160 complete user-facing README/docs command examples against all 172 current help pages, with 0 unknown-flag and 0 malformed examples; each entry links exact-variant evidence or records an explicit syntax-only execution exclusion. Platform result lines are split for all matrix rows marked both. The ledger retains the original blocked observations beside later handoff/full-access rerun lines, so it contains 414 result lines while the unique-ID totals use the latest rerun verdict.
+
+## Task 6 corrected-criterion reviews
+
+Original observations above remain unchanged. These additive rerun lines re-evaluate retained raw evidence under the published corrections; they do not claim new device executions. The help-corpus trio additionally uses the fresh 172-command replay.
+
+| ID | result | evidence | note |
+|---|---|---|---|
+| CLI-003 rerun corrected round 4 | pass | findings/evidence/cov3-cli/CLI-003/regen.out, findings/evidence/cov3-controller/help-corpus-task6/summary.json | All 172 hash-pinned candidate help pages rerun: exit0, required headings, zero canonical byte mismatches. The original stale-corpus failure remains preserved. |
+| D2-47 rerun corrected round 4 | pass | findings/evidence/cov3-cli/D2-47/, findings/evidence/cov3-controller/help-corpus-task6/summary.json | All 172 hash-pinned candidate help pages rerun: exit0, required headings, zero canonical byte mismatches. The original stale-corpus failure remains preserved. |
+| N3-16 rerun corrected round 4 | pass | findings/evidence/cov3-cli/N3-16/, findings/evidence/cov3-controller/help-corpus-task6/summary.json | All 172 hash-pinned candidate help pages rerun: exit0, required headings, zero canonical byte mismatches. The original stale-corpus failure remains preserved. |
+| CLI-045 rerun corrected round 4 | pass | findings/evidence/cov3-cli/CLI-045/ | Corrected-criterion review under docs/superpowers/plans/2026-10-13-coverage-issues-round3/00-expectation-corrections-round3.md; retained raw supports the revised contract. Original verdict and evidence are preserved. |
+| CLI-145 rerun corrected round 4 | pass | findings/evidence/cov3-cli/CLI-145/ | Corrected-criterion review under docs/superpowers/plans/2026-10-13-coverage-issues-round3/00-expectation-corrections-round3.md; retained raw supports the revised contract. Original verdict and evidence are preserved. |
+| D2-27 rerun corrected round 4 | pass | findings/evidence/cov3-cli/D2-27/ | Corrected-criterion review under docs/superpowers/plans/2026-10-13-coverage-issues-round3/00-expectation-corrections-round3.md; retained raw supports the revised contract. Original verdict and evidence are preserved. |
+
+| B3-L29 rerun task6 completion | pass | findings/evidence/cov3-cli/B3-L29/, findings/b3l29-unblock-review.md | Retained hidden-option invocations enter the same Gradle task path with no device boot; exact candidate BuildCommandTests, AndroidCommandTests and AndroidPlatformTests establish no-effect headless/emulator semantics and explicit-device ABI selection. This source/runtime join closes the earlier worker-sandbox evidence gap; no successful new build or device run is claimed. |
+| N3-15 rerun task6 completion | fail | findings/evidence/cov3-controller/N3-15-after-final-cleanup/, findings/controller-N3-15-final-environment-review.md | Final read-only doctor text and JSON both exit 0 with owner iPhone 17 Pro, while the simultaneously present unowned default-named iPhone 18 Pro FE441… is omitted with no `not used as the default` note. Before/after booted inventories are byte-identical. Exact DoctorRunner source returns the first booted device before evaluating the ownership-note branch. The original blocked observation remains preserved above. |
diff --git a/findings/cov3-ios-results.md b/findings/cov3-ios-results.md
index aa96422d..4a8b7198 100644
--- a/findings/cov3-ios-results.md
+++ b/findings/cov3-ios-results.md
@@ -672,3 +672,19 @@ Only raw captures known to predate the invalid historical import and the explici
 Matrix base rows recorded: 478 of 478 (pass 447, fail 21, blocked 10, n/a 0). Round-3 side observations: 1 fail (IOS3-OBS-01). iOS 27.0 repeat lines: 39 pass. Handed CLI rows: 6 pass (CLI-048/049/061/064/066 and N3-11 [ios]). Unrun matrix base rows: 0. MCP-031's guarded no-device behavior is graded only by B3-L08.1/N3-13. Attempt 2's explicit-scheme build/run/test captures remain input-variation evidence; attempt 6 closes the omitted-scheme criteria using only the safety-required explicit owned simulator. Attempt 47 closes the actual-starting tool/resource cases and exposes N3-03's missing JSON `port: null`; N3-01 joins attempt 16c's successful screenshot after an explicit detached start returned. CLI-061 grades only byte-preserving parsing/staging; its intentionally absent runtime label is excluded from that verdict.
 
 The stock and coverage batches may support additional matrix rows, but those rows remain unrun in this ledger until their exact input/expectation is mapped to raw output. No round-2 outcome is used as a round-3 verdict.
+
+## Task 6 corrected-criterion reviews
+
+Original observations above remain unchanged. These additive rerun lines re-evaluate retained raw evidence under the published corrections; they do not claim new device executions. The help-corpus trio additionally uses the fresh 172-command replay.
+
+| ID | result | evidence | note |
+|---|---|---|---|
+| MCP-078 rerun corrected round 4 | pass | findings/evidence/cov3-ios-attempt16c/mcp/transcript.txt | Corrected-criterion review under docs/superpowers/plans/2026-10-13-coverage-issues-round3/00-expectation-corrections-round3.md; retained raw supports the revised contract. Original verdict and evidence are preserved. |
+| IOS-058 rerun corrected round 4 | pass | findings/evidence/cov3-ios-attempt29/keepalive.ready-before-signal, findings/evidence/cov3-ios-attempt29/keepalive.ready-after-signal, findings/evidence/cov3-ios-attempt29/keepalive.exit.txt | Corrected-criterion review under docs/superpowers/plans/2026-10-13-coverage-issues-round3/00-expectation-corrections-round3.md; retained raw supports the revised contract. Original verdict and evidence are preserved. |
+| B3-L55.1 [ios] rerun corrected round 4 | pass | findings/evidence/cov3-ios-attempt48b/slow-stop-1.observation.json, findings/evidence/cov3-ios-attempt48b/slow-stop-1.ready-before-release.absent, findings/evidence/cov3-ios-attempt48b/slow-stop-1.stop.out, findings/evidence/cov3-ios-attempt48b/slow-stop-1.exit.txt, findings/evidence/cov3-ios-attempt48b/slow-stop-1.ready-final, findings/evidence/cov3-ios-attempt48b/slow-stop-2.ready-before-release.absent, findings/evidence/cov3-ios-attempt48b/slow-stop-3.ready-before-release.absent, /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/RunCommand.swift | Corrected-criterion review under docs/superpowers/plans/2026-10-13-coverage-issues-round3/00-expectation-corrections-round3.md; retained raw supports the revised contract. Original verdict and evidence are preserved. |
+| X-013 rerun corrected round 4 | pass | findings/evidence/cov3-ios-attempt62/start-text.out, findings/evidence/cov3-ios-attempt62/stop-text.out, findings/evidence/cov3-ios-attempt62/start-json.out, findings/evidence/cov3-ios-attempt62/stop-json.out, findings/evidence/cov3-ios-attempt62/stop-no-session-json.out, /Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/X013-X015-X017-android-rerun1 | Corrected-criterion review under docs/superpowers/plans/2026-10-13-coverage-issues-round3/00-expectation-corrections-round3.md; retained raw supports the revised contract. Original verdict and evidence are preserved. |
+| IOS-016 rerun corrected round 4 | pass | findings/evidence/cov3-ios-attempt74/run.exit.txt, findings/evidence/cov3-ios-attempt74/lock-before-kill.bin, findings/evidence/cov3-ios-attempt74/teardown.out, findings/evidence/cov3-ios-attempt74/homes-before-teardown.txt, findings/evidence/cov3-ios-attempt74/homes-after-teardown.txt, findings/evidence/cov3-ios-attempt74/session-after.txt, /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/SimulatorReaperTests.swift | Corrected-criterion review under docs/superpowers/plans/2026-10-13-coverage-issues-round3/00-expectation-corrections-round3.md; retained raw supports the revised contract. Original verdict and evidence are preserved. |
+| B2-K103 [ios] rerun corrected round 4 | pass | findings/evidence/cov3-ios-analysis-n2-07/audit.json, /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/README.md, /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Output/LegacyJSONKeys.swift, /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/JSONKeyCasingContractTests.swift, /Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli/findings/bc22-k103-ios76d-77-review.md | Corrected-criterion review under docs/superpowers/plans/2026-10-13-coverage-issues-round3/00-expectation-corrections-round3.md; retained raw supports the revised contract. Original verdict and evidence are preserved. |
+| IOS-153 rerun corrected round 4 | pass | findings/evidence/cov3-ios-attempt109b/plain.out, findings/evidence/cov3-ios-attempt109b/quiet.out, findings/evidence/cov3-ios-attempt109b/verbose.out, findings/evidence/cov3-ios-attempt109b/plain.err, findings/evidence/cov3-ios-attempt109b/quiet.err, findings/evidence/cov3-ios-attempt109b/verbose.err, findings/evidence/cov3-ios-attempt109b/stdout.sha256, findings/evidence/cov3-ios-attempt109b/plain-quiet.cmp, findings/evidence/cov3-ios-attempt109b/plain-verbose.cmp, /Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli/findings/ios109b-n12-ios153-review.md | Corrected-criterion review under docs/superpowers/plans/2026-10-13-coverage-issues-round3/00-expectation-corrections-round3.md; retained raw supports the revised contract. Original verdict and evidence are preserved. |
+| B2-K19 [ios] rerun corrected round 4 | blocked credentials required | findings/evidence/cov3-ios-attempt127/diff-quiet.out, findings/evidence/cov3-ios-attempt127/diff-quiet.err, findings/evidence/cov3-ios-attempt127/ci-quiet.err, findings/evidence/cov3-ios-attempt127/ci-json.err, findings/evidence/cov3-ios-attempt109b/quiet.out, findings/evidence/cov3-ios-attempt109b/quiet.err, findings/evidence/cov3-ios-attempt109b/verbose.out, findings/evidence/cov3-ios-attempt109b/verbose.err, findings/evidence/cov3-ios-attempt68 | Local quiet/JSON/verbose clauses satisfy the corrected contract; authenticated CI remains blocked by unavailable credentials. Original literal failure is preserved. |
+| B2-K25 [ios] rerun corrected round 4 | fail | findings/evidence/cov3-ios-attempt65/build-install.out, findings/evidence/cov3-ios-attempt65/run.out, findings/evidence/cov3-ios-attempt65/capture.out, findings/evidence/cov3-ios-attempt65/ci.err, findings/evidence/cov3-ios-attempt65/skipped.out, findings/evidence/cov3-ios-attempt65/skipped.err, findings/evidence/cov3-ios-attempt65/skipped.exit.txt, findings/evidence/cov3-ios-attempt65b/skipped.out, findings/evidence/cov3-ios-attempt65b/skipped.exit.txt, findings/evidence/cov3-ios-attempt66/install-launch.out, findings/evidence/cov3-ios-attempt66/install-no-launch.out, findings/evidence/cov3-ios-attempt66b/skipped.out, /Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/BuildCommand.swift, /Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli/findings/ios-b2-current-evidence-gap-audit.md | The correction does not waive the absent-app container lookup failure: L71 remains open and this row remains fail. |
diff --git a/findings/round3-task6-corrections-review.md b/findings/round3-task6-corrections-review.md
new file mode 100644
index 00000000..78dd4700
--- /dev/null
+++ b/findings/round3-task6-corrections-review.md
@@ -0,0 +1,24 @@
+# Round-3 Task 6 corrections final review
+
+Reviewed the applied bookkeeping amendments only: the published expectation-correction document, the 25 additive corrected-criterion lines in the three merged slice ledgers, `task6-corrected-criterion-review-map.json`, and the fresh help replay summary.
+
+## Verdict
+
+**Approved.** The previously reported bookkeeping findings are addressed:
+
+- CLI-003, D2-47, and N3-16 now cite the Task 6 replay and are classified as corrected passes. `help-corpus-task6/summary.json` records 172 pages, all exits zero, valid required headings, no canonical changes, and no post-update mismatches.
+- B2-L03 and B3-L51 are excluded from the additive correction map and result-line append. Their existing Android pass rows remain the sole current verdicts and cite final rerun10/rerun12 evidence and reviews.
+- The correction document now cites B2-L03 rerun10 joined to the renderer repetitions, B3-L51 rerun12, and the exact Android K103 alias-audit directory.
+- Product failures L64–L80 remain unchanged. In particular, L80 / AND3-OBS-02 is not reclassified.
+
+## Accounting
+
+The map has 25 unique `(slice, ID)` entries, and each maps to exactly one appended corrected-criterion line:
+
+- CLI: 6 pass.
+- Android: 10 pass.
+- iOS: 7 pass, 1 blocked (`B2-K19`, credentials required), and 1 fail (`B2-K25`, L71 remains open).
+
+There are no B2-L03/B3-L51 entries in the map, no hidden pass for either retained iOS exception, and no duplicate corrected IDs within a slice. The map dispositions, appended line counts, and correction-document ID list agree. `git diff --check` passes for the reviewed files.
+
+No further correction bookkeeping change is required before the controller commits these files.
diff --git a/findings/tools/task6_effective_coverage.py b/findings/tools/task6_effective_coverage.py
new file mode 100755
index 00000000..1875742d
--- /dev/null
+++ b/findings/tools/task6_effective_coverage.py
@@ -0,0 +1,131 @@
+#!/usr/bin/env python3
+"""Derive Round-3 effective coverage from matrix IDs and result rows; never edits ledgers."""
+from __future__ import annotations
+import argparse, collections, hashlib, json, re
+from pathlib import Path
+
+VERDICTS=('pass','fail','blocked','n/a')
+RANK={'fail':3,'blocked':2,'pass':1,'n/a':0}
+PLATFORM_RE=re.compile(r'\|\s*(cli|ios|android|both)\s*\|\s*(CLI|iOS|Android|iOS\+Android)\s*\|')
+FOOTERS={
+ 'cli':re.compile(r'384 unique matrix IDs.*?pass (\d+), fail (\d+).*?blocked (\d+), n/a (\d+)',re.S),
+ 'ios':re.compile(r'Matrix base rows recorded:\s*(\d+) of (\d+) \(pass (\d+), fail (\d+), blocked (\d+), n/a (\d+)\)'),
+ 'android':re.compile(r'(\d+) of (\d+) slice rows recorded:\s*(\d+) pass, (\d+) fail, (\d+) blocked, (\d+) n/a')}
+
+def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
+def cells(line): return [x.strip() for x in line.strip().strip('|').split('|')]
+def verdict(s):
+ for v in VERDICTS:
+  if s==v or s.startswith(v+' ') or s.startswith(v+' ('): return v
+ return None
+
+def read_matrix(path):
+ rows={}; by_platform=collections.Counter(); by_slice=collections.Counter()
+ for no,line in enumerate(path.read_text().splitlines(),1):
+  m=PLATFORM_RE.search(line)
+  if not m: continue
+  c=cells(line); rid=c[0].removesuffix(' (changed)')
+  if rid in rows: raise SystemExit(f'duplicate matrix ID {rid}')
+  rows[rid]={'id':rid,'declared_platform':m.group(1),'slice':m.group(2),'line':no}
+  by_platform[m.group(1)]+=1; by_slice[m.group(2)]+=1
+ if len(rows)!=1170: raise SystemExit(f'matrix has {len(rows)} rows')
+ return rows,dict(by_platform),dict(by_slice)
+
+def canonicalize(label, ids):
+ # Longest prefix prevents B2-K1 from capturing B2-K10; suffixes preserve rerun/platform variants.
+ for rid in ids:
+  if label==rid or (label.startswith(rid) and label[len(rid):len(rid)+1] in (' ','[' ,'(')):
+   return rid
+ return None
+
+def platform_variant(label):
+ m=re.search(r'\[(ios|android)(?:[^]]*)\]',label,re.I)
+ return m.group(1).lower() if m else 'generic'
+
+def expected_ids(matrix, platform):
+ if platform=='cli': return {r for r,x in matrix.items() if x['slice']=='CLI'}
+ own='iOS' if platform=='ios' else 'Android'
+ return {r for r,x in matrix.items() if x['slice'] in (own,'iOS+Android')}
+
+def derive(path, matrix, platform, mode="final"):
+ expected=expected_ids(matrix,platform); sorted_ids=sorted(matrix,key=len,reverse=True)
+ latest={}; raw=0; excluded=[]
+ for no,line in enumerate(path.read_text().splitlines(),1):
+  c=cells(line)
+  if len(c)<2 or not verdict(c[1]): continue
+  raw+=1
+  is_repeat='@27.0' in c[0]
+  is_task6=('rerun corrected round 4' in c[0] or 'rerun task6 completion' in c[0])
+  if is_repeat or (mode=='original' and is_task6):
+   excluded.append({'line':no,'label':c[0],'reason':'iOS 27 repeat' if is_repeat else 'Task 6 appended adjudication'})
+   continue
+  rid=canonicalize(c[0],sorted_ids)
+  if rid not in expected:
+   excluded.append({'line':no,'label':c[0],'reason':'side/repeat/handoff or another execution slice'})
+   continue
+  key=(rid,platform_variant(c[0])); latest[key]={'line':no,'label':c[0],'verdict':verdict(c[1]),'evidence':c[2] if len(c)>2 else '', 'reason':c[3] if len(c)>3 else ''}
+ derived={}; sources={}
+ for rid in sorted(expected):
+  variants=[x for (r,_),x in latest.items() if r==rid]
+  if not variants: continue
+  winner=max(variants,key=lambda x:RANK[x['verdict']])
+  derived[rid]=winner['verdict']; sources[rid]=variants
+ counts=collections.Counter(derived.values())
+ return {'expected_ids':expected,'derived':derived,'sources':sources,'counts':{v:counts[v] for v in VERDICTS},
+         'recorded':len(derived),'expected':len(expected),'missing':sorted(expected-set(derived)),'raw_result_lines':raw,'excluded':excluded}
+
+def footer(path,platform):
+ text=path.read_text(); m=FOOTERS[platform].search(text)
+ if not m: return None
+ n=list(map(int,m.groups()))
+ if platform=='cli': p,f,b,na=n; return {'recorded':384,'expected':384,'pass':p,'fail':f,'blocked':b,'n/a':na}
+ rec,exp,p,f,b,na=n; return {'recorded':rec,'expected':exp,'pass':p,'fail':f,'blocked':b,'n/a':na}
+
+def main():
+ ap=argparse.ArgumentParser();
+ for x in ('controller','cli','ios','android','output','table'): ap.add_argument('--'+x,type=Path,required=True)
+ a=ap.parse_args(); matrix_path=a.controller/'docs/superpowers/plans/2026-10-13-round3-coverage-matrix.md'
+ matrix,declared,slices=read_matrix(matrix_path)
+ paths={'cli':a.cli/'findings/cov3-cli-results.md','ios':a.ios/'findings/cov3-ios-results.md','android':a.android/'findings/cov3-android-results.md'}
+ audits={}; footer_checks={}; original_maps={}; final_maps={}; original_detail={}; final_detail={}
+ for p,path in paths.items():
+  od=derive(path,matrix,p,'original'); fd=derive(path,matrix,p,'final')
+  original_maps[p]=od['derived']; final_maps[p]=fd['derived']; original_detail[p]=od; final_detail[p]=fd
+  f=footer(path,p)
+  osummary={'recorded':od['recorded'],'expected':od['expected'],**od['counts']}
+  fsummary={'recorded':fd['recorded'],'expected':fd['expected'],**fd['counts']}
+  audits[p]={'original':{**osummary,'missing':od['missing'],'excluded_result_lines':len(od['excluded'])},
+             'final':{**fsummary,'missing':fd['missing'],'excluded_result_lines':len(fd['excluded'])},
+             'raw_result_lines':od['raw_result_lines'],'path':str(path),'sha256':sha(path)}
+  footer_checks[p]={'original_footer':f,'derived_original':osummary,'matches_original':f==osummary}
+ review_map_path=a.controller/'findings/task6-corrected-criterion-review-map.json'
+ review_map=json.loads(review_map_path.read_text()) if review_map_path.exists() else []
+ actual_task6={(p,rid) for p,d in final_detail.items() for rid,items in d['sources'].items() for x in items if 'rerun corrected round 4' in x['label'] or 'rerun task6 completion' in x['label']}
+ mapped={(x['slice'],x['id']) for x in review_map}
+ map_validation={'path':str(review_map_path),'entries':len(review_map),'actual_task6_rows':len(actual_task6),
+                 'mapped_without_actual_row':sorted(f'{p}:{r}' for p,r in mapped-actual_task6),
+                 'actual_rows_without_mapping':sorted(f'{p}:{r}' for p,r in actual_task6-mapped)}
+ def totals(mapping):
+  c=collections.Counter(v for x in mapping.values() for v in x.values()); return {**{v:c[v] for v in VERDICTS},'total':sum(c.values())}
+ report={'matrix':{'path':str(matrix_path),'sha256':sha(matrix_path),'logical_rows':len(matrix),
+          'by_declared_platform':declared,'by_execution_slice':slices,
+          'effective_by_slice':{p:len(expected_ids(matrix,p)) for p in paths},
+          'effective_total':sum(len(expected_ids(matrix,p)) for p in paths)},
+         'derived_slices':audits,'original_footer_validation':footer_checks,
+         'original_effective_totals':totals(original_maps),'task6_review_map_validation':map_validation,
+         'final_effective_totals':totals(final_maps),'side_findings':'excluded because their IDs are absent from the 1170-row matrix',
+         'remaining_fail_blocked':[{'platform':p,'id':rid,'verdict':v,'sources':final_detail[p]['sources'][rid]} for p in paths for rid,v in sorted(final_maps[p].items()) if v in ('fail','blocked')],
+         'ready':all(not x['original']['missing'] and not x['final']['missing'] for x in audits.values()),
+         'note':'Original excludes @27.0 repeats and Task 6 appended rows. Final excludes @27.0 repeats and includes actual Task 6 appended rows. Latest observation wins per ID/platform variant; variants collapse fail > blocked > pass > n/a.'}
+ a.output.parent.mkdir(parents=True,exist_ok=True); a.output.write_text(json.dumps(report,indent=2)+'\n')
+ lines=['# Task 6 B2/B3 effective row audit','','Derived from result rows; no ledger edits.','','| ID | Platform | Original | Final | Source line(s) |','|---|---|---|---|---|']
+ for rid in sorted((r for r in matrix if r.startswith(('B2-','B3-')))):
+  for p in paths:
+   if rid not in expected_ids(matrix,p): continue
+   original=original_maps[p].get(rid,'missing'); fin=final_maps[p].get(rid,'missing')
+   src=final_detail[p]['sources'].get(rid,[])
+   refs='<br>'.join(f"{paths[p]}:{x['line']} ({x['label']}); evidence: {x['evidence']}; reason: {x['reason']}" for x in src)
+   lines.append(f'| {rid} | {p} | {original} | {fin} | {refs} |')
+ a.table.write_text('\n'.join(lines)+'\n')
+ print(json.dumps({'output':str(a.output),'table':str(a.table),'ready':report['ready'],'original_footer_validation':footer_checks,'original':report['original_effective_totals'],'final':report['final_effective_totals'],'review_map':map_validation},indent=2))
+if __name__=='__main__': main()

```
