# Round-3 expectation corrections for round 4

These corrections resolve matrix assumptions contradicted by accepted documentation, source semantics, or controlled round-3 evidence. They do not erase the original round-3 result lines. After slice merges, the controller should preserve each original verdict and add a separate corrected rerun line.

## CLI corpus and usage corrections

- **CLI-003, D2-47, N3-16:** compare help against a corpus regenerated from the exact candidate, including the accepted L63 simulator-teardown sentence.
- **CLI-045 and the mutual-exclusion leg of CLI-145:** require exit 64 plus Error, Usage, and help hint. Keep the three other-platform CLI-145 legs at exit 1.
- **D2-27:** inventory the six device-selecting/booting help pages; exclude build-only `build build` per L29.

## Shared and platform expectation corrections

- **MCP-078:** require errors from app-dependent operations after app death; allow device/UI operations to succeed with their normal schemas.
- **IOS-058:** distinguish interruption during active work from signalling a completed keep-alive hold, which preserves its earned terminal result.
- **B3-L55.1 / B3-L55.2:** prove active work from owner/session/process/stream evidence; ready-file publication is terminal, not an active-running precondition.
- **X-013:** compare shared lifecycle fields while accepting iOS `bundleId`, Android `applicationId`, and Android `serial` as platform identity names.
- **IOS-016:** after the parent is already killed, teardown must reap its orphaned helpers; it cannot kill the dead parent again.
- **B2-K103:** allow only documented equal snake_case compatibility aliases; reject undocumented underscore keys.
- **IOS-153, AND-137, AND-138:** compare decoded stable fields across separate executions and exclude genuine measurements/timestamps (and independent PNG bytes for capture).
- **B2-K19:** quiet suppresses progress, verbose wins over quiet, and stable decoded output is compared. Android CI may take its documented unsupported path; iOS authenticated CI remains credential-dependent.
- **AND-022:** require unsigned warnings only from a fixture that actually produces an unsigned release artifact.
- **B2-K25:** retain each platform's supported no-build/app-file semantics; accept Android's documented CI refusal and require iOS absent-app skipped install not to query mandatory container metadata.
- **N3-06:** final MP4 duration is authoritative; `recordedMilliseconds` is the pre-hold track end.
- **B2-L03 and B3-L51 instrumentation:** while a flow owns the runner, measure intermediate Android movement through a row-owned direct UIAutomator2 hierarchy read on the exact session/serial. Use the terminal CLI report, client log, runner log, and final CLI hierarchy as the semantic proof. Do not require a second CLI hierarchy/dump command during the pre-hold flow window, because normal CLI session ownership prevents that observation. Candidate `Sources/GrantivaCore/Android/UIAutomator2Client.swift` defines the direct hierarchy transport; the retained Android swipe evidence preserves the production client/report paths.

## Evidence and post-correction disposition

“Pass” below means the retained evidence satisfies the corrected criterion; it does not claim that a new corrected rerun was executed. Original result lines remain preserved. Rows marked “rerun” or “blocked/fail” cannot be converted to pass from the correction alone.

| Corrected result ID(s) | Retained evidence | Post-correction disposition |
|---|---|---|
| CLI-003, D2-47, N3-16 | `cov3-cli/findings/evidence/cov3-cli/CLI-003/`, `D2-47/`, `N3-16/`; controller `findings/evidence/cov3-controller/help-corpus/summary.json` | **Rerun required:** regenerate all 172 exact-candidate pages, update only the accepted corpus delta, then prove a zero changed-file list. Do not mark pass from the draft. |
| CLI-045, CLI-145 | `cov3-cli/findings/evidence/cov3-cli/CLI-045/`, `CLI-145/` | Existing raw supports corrected mutual-exclusion exit 64; preserve CLI-145's three exit-1 platform legs. Eligible for corrected pass after merge review. |
| D2-27 | `cov3-cli/findings/evidence/cov3-cli/D2-27/helps_r3.out` | Existing six-page inventory supports corrected pass; malformed first attempt remains excluded provenance. |
| MCP-078 [ios], MCP-078 [android] | iOS attempt37 MCP responses; Android `MCP078-force-stop-rerun1/` | Mixed app-dependent errors and valid device/UI successes support corrected pass on both platforms. |
| IOS-058 | `cov3-ios/findings/evidence/cov3-ios-attempt29/keepalive.ready-before-signal`, `keepalive.ready-after-signal`, `keepalive.exit.txt` | Earned completed status is preserved and session released; corrected pass. |
| B3-L55.1 [ios], B3-L55.2 [android] | iOS `cov3-ios-attempt48b/`; Android `B3-L55-active-ready-rerun2/`; `Sources/GrantivaCore/Runner/RunnerExecution.swift` terminal publication path | Active owner/process/stream and terminal interruption evidence support corrected pass. |
| X-013 [ios], X-013 [android] | iOS attempt62 lifecycle documents; Android `X013-X015-X017-android-rerun1/` | Shared fields/types agree and platform app/device names are separately required; corrected pass. |
| IOS-016 | iOS attempt74 teardown/process/home/session artifacts; K68 source tests | Corrected orphan-helper criterion passes; no product brief is required. |
| B2-K103 [ios], B2-K103 [android] | iOS `cov3-ios-analysis-n2-07/audit.json`; Android current JSON-key audit; `LegacyJSONKeys.swift`, `JSONKeyCasingContractTests.swift` | Only documented equal aliases occur; corrected pass on both platforms. |
| IOS-153 | iOS attempt109b three successful modes and `ios109b-n12-ios153-review.md` | Stable decoded content agrees; dynamic timestamps/durations differ truthfully. Corrected pass. |
| AND-137, AND-138 | Android `output-modes-exact-rerun3/`, `output-contracts-exact-rerun1/AND-137-quiet-fail/` | Stable decoded mode behavior supports corrected pass. |
| B2-K19 [android] | Android output-mode directories above plus `B2-K25-ci-correction-rerun2/` | Supported local modes and documented Android CI refusal satisfy corrected Android criterion; corrected pass. |
| B2-K19 [ios] | iOS attempts109b, 127, and 68 | Local run/diff and verbose precedence satisfy corrected portions, but authenticated CI quiet/JSON clauses remain unavailable at the real authentication gate. **Corrected whole row remains blocked**, while the original literal row remains fail; do not auto-pass it. |
| AND-022 | Android `build-install-contracts-exact-rerun1/AND-022/` | Fixture is proven debug-signed; corrected signing-aware criterion passes without inventing an unsigned warning. |
| B2-K25 [android] | Android `B2-K25-full-exact-rerun1/`, `B2-K25-ci-correction-rerun2/` | Supported local semantics and documented CI refusal support corrected Android pass. |
| B2-K25 [ios] | iOS attempts65, 65b, 66, 66b; L71 | **Still product-failing:** absent-app skipped install queries the missing data container. Correction clarifies the compound but does not waive L71 or produce a pass. |
| N3-06 [android] | Android `N3-06-ten-recordings-rerun1/`, ffprobe audit, `B3-K111-record-frames-rerun1/` | Ten final MP4s are exactly 3 seconds; corrected pass. |
| B2-L03, B3-L51 | Android `B2-K07-N03-B2-L03-scroll-renderers-rerun1/` and `B3-L51-four-forms-rerun9/`; production client/report logs; `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Android/UIAutomator2Client.swift` and `Sources/GrantivaCore/Runner/RunnerReportSteps.swift` | Instrumentation-only correction. Re-evaluate each row from direct in-flow hierarchy measurements plus terminal CLI semantic artifacts; do not infer a pass from this document alone. |

## Result IDs for corrected reruns

The controller should add corrected rerun result lines for these exact existing IDs after merges, without replacing original lines:

`CLI-003`, `D2-47`, `N3-16`, `CLI-045`, `CLI-145`, `D2-27`, `MCP-078 [ios]`, `MCP-078 [android]`, `IOS-058`, `B3-L55.1 [ios]`, `B3-L55.2 [android]`, `X-013 [ios]`, `X-013 [android]`, `IOS-016`, `B2-K103 [ios]`, `B2-K103 [android]`, `IOS-153`, `AND-137`, `AND-138`, `B2-K19 [ios]`, `B2-K19 [android]`, `AND-022`, `B2-K25 [ios]`, `B2-K25 [android]`, `N3-06 [android]`, `B2-L03`, and `B3-L51`.

Product failures owned by L64–L79 remain unchanged and require product fixes rather than expectation reruns.

## Executed help-corpus verification

Task 6 regenerated all 172 preserved help commands against QA binary SHA256 `3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8`. Every command exited0 and retained OVERVIEW, USAGE, and OPTIONS. The canonical corpus already contained the earlier candidate refresh: this replay changed no canonical file and found zero byte mismatches. Exact argv, stdout, stderr and exits are preserved under `findings/evidence/cov3-controller/help-corpus-task6/`; `summary.json` records the checks. The corpus prerequisite for CLI-003, D2-47 and N3-16 is now satisfied; their original failure lines remain preserved.
