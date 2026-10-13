# iOS 66b/68 and Android VRT equivalence review

Reviewed against `docs/superpowers/plans/2026-10-13-round3-coverage-matrix.md` at the controller checkout, candidate CLI `8f2cff67`, and retained round-3 raw evidence only. No device command or build was run in this review.

## Verdicts

### D2-07 [ios]: supported

The three required modes now have genuine successful JSON documents:

- `cov3-ios-attempt66/install-launch.out`: `status: launched` after build/install/launch.
- `cov3-ios-attempt66/install-no-launch.out`: `status: installed` under `--no-launch`.
- `cov3-ios-attempt66b/skipped.out`: `status: skipped` under `--no-build --no-launch`, with `bundleId`, `scheme`, simulator name/UDID, and the existing data-container path. `container-before.exit.txt` is `0`, so this is the required installed-app case rather than the invalid missing-app harness from attempt 66.

The current iOS ledger's pass is supported.

### D2-19 [ios]: supported

`cov3-ios-attempt68` covers all eight required pass/fail mode combinations. Exit codes are 0 for each passing flow and 1 for each intentional negative flow.

- `pass-quiet.err` is empty. `fail-quiet.err` contains only Grantiva's failed-step `Error:` plus hierarchy remedy; both stdout files retain Grantiva's flow result blocks under the binding L10 ruling.
- `pass-json.err` is empty. `fail-json.out` is valid JSON whose `error` names `02-exact-negative`, the exact failed `assertVisible` step, and its message; it does not refer the reader to hidden runner output. `fail-json.err` contains the same Grantiva error, but no runner banner, Setup/Execution section, runner summary, or report-path block.
- `pass-json-verbose.err` and `fail-json-verbose.err` restore the debug subprocess line and runner banner/steps, while their stdout remains valid result JSON.
- Both `*-plain-no-report.err` files contain the exact `Report not kept; pass --report-dir <dir> to keep report.json, JUnit and Allure.` notice. Neither contains a `/var/folders` or `grantiva-report-*` path.
- Preserved-report variants name their actual retained report directories.

The semantic source assertions at exact candidate head are `Tests/GrantivaCoreTests/RunnerSessionOutputTests.swift` (`testASilencedRequestRelaysNothingAndANormalOneRelaysEverything`, `testAFailureMessageNamesTheFailedStepInsteadOfPointingAtSuppressedOutput`, `testAnEphemeralReportDirectoryIsNeverPrinted`, `testAKeptReportDirectoryIsPrintedAsTheRunnerWroteIt`) and `Tests/GrantivaCLITests/OutputStreamContractTests.swift` (`testQuietLeavesProgramOutputUntouched`, `testVerboseLeavesProgramOutputUntouched`). These assert the named behavior, rather than merely sharing K18/K19 labels.

The current iOS ledger's pass is supported.

### B2-K18 / B2-K19 joins: useful, not whole-row grades by themselves

Attempt 68 directly supplies the `run` pass/fail runtime clauses and the exact semantic source assertions above. B2-K18 also names `diff capture` and `ci run`; B2-K19 requires suppression for `run`, `diff capture`, and `ci run`. This review did not find current iOS ledger rows for B2-K18 or B2-K19, and attempt 68 does not execute the diff/CI legs. It should be joined to retained exact diff/CI evidence before either compound row is graded. The attempt must not be treated as standalone proof of those whole rows.

## Android VRT equivalence batch

The finalized batch `cov3-android/findings/evidence/cov3-android/MCP064-066-B2K55-D241-vrt-equivalence-type-rerun1` reports all six commands successful. Its VRT portion supports:

- MCP-066: `mcp-no-session/capture.json` returns five configured Android screens from `.grantiva/captures/android`, with Android emulator identity and relative capture paths, equivalent in schema and stable fields to `cli/capture.json` from `diff capture --platform android --no-build --json`.
- MCP-064 is **partial, not a pass**: `mcp-live/capture.json` succeeds during the row-owned keep-alive session and returns those same five screen names, relative paths, emulator identity/dimensions, and per-step action/status structure. The five-screen config exercises text selectors only. Matrix row MCP-064 additionally requires Android `content-desc`, `hint`, and `id:` selectors in whole-resource and post-`/` suffix forms. Neither this batch nor the exact retained artifacts reviewed here proves all of those selector families through live-session VRT capture.
- Dynamic values are correctly different between independent captures: total/step durations and timestamps, and two later PNG byte sizes. “Same JSON” therefore supports the same contract/schema and matching stable values, not literal byte equality across separate UI executions.
- `mcp-type/capture.json` is a separate D2-41 negative and does not contribute VRT equivalence.

The batch contains capture only. It does not close MCP-064's selector-family clause, MCP-069 (pre-execution refusal), MCP-071 (compare metrics and Android capture/baseline paths), or MCP-074 (selective/all approval); those require their respective retained evidence.

### X-022 cross-platform join: supported

X-022 requires live-session and no-session MCP capture to have the `diff capture --json` document contract on each platform.

- Android supplies the strongest same-input comparison in this batch: `cli/capture.json`, `mcp-no-session/capture.json`, and `mcp-live/capture.json` all use the frozen five-screen config and agree on the full stable shape and values described above.
- iOS attempt 56 supplies the same-input live-session comparison: decoded `mcp/mcp-capture.json` and `bare-capture.out` have the same top-level keys, five ordered screen entries, relative paths, simulator shape/identity/dimensions, and step action/status fields. Attempt 22 supplies the no-session form for its frozen three-screen config; its decoded MCP content has that same contract, correct three configured screens and iOS paths/device object. The screen-count difference reflects the two frozen configs, not a shape difference.
- On both platforms, duration/timestamp fields are measurements from distinct executions. Literal byte equality is not a reasonable reading of “same JSON”; decoded key/type shape and stable values match.

This join supports X-022 [ios] and X-022 [android]. MCP-064 remains partial because X-022 does not add its Android-selector-family requirement.

### B2-K55 [android]: runtime input gap

The batch strongly proves the shape defect is fixed for a row-owned Android **keep-alive run** session: CLI, no-session MCP, and live-session MCP all expose `directory`, `duration`, `emulator`, `screens`, and `simulator`, and `emulator` equals `simulator`. The retained exact-head `SessionLifecycleTests.swift` semantic test also asserts the shared session capture shape for Android and absence of `emulator` on iOS.

However, B2-K55's prescribed runtime input is `runner start --detach` followed by MCP capture. The batch used `run --keep-alive`; it did not execute detached start. These modes may reach the same session capture implementation, but source equivalence does not replace the explicitly named runtime variant. The current B2-K55 [android] pass should therefore be withheld or qualified partial until a retained current-round detached-session capture supplies the missing leg. The iOS clause is a semantic source guard within this Android row, not a separately gradeable platform half.

For any later VRT equivalence review, compare decoded MCP `result.content[0].text` with the CLI JSON as follows:

1. Capture: identical top-level field types; configured screen order/names; Android relative directory/path prefix; emulator identity/dimensions; step action/status; allow measured durations, timestamps, and PNG byte sizes to vary.
2. Compare: identical per-screen verdict vocabulary and pixel/perceptual metric field names/types; Android `captures/android` and `baselines/android` paths; allow measured metric values to vary only where different captures were intentionally used.
3. Approve: exact requested screen set for selective approval, all configured captures for empty arguments, matching approved-count/path shape, and filesystem inventory proving no unrequested baseline was written.
4. Errors/refusals: MCP `result.isError: true` with content text and no JSON-RPC `error`; prove the next request still succeeds where the row requires transport recovery.

## Evidence paths

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt66b/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt68/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/MCP064-066-B2K55-D241-vrt-equivalence-type-rerun1/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/RunnerSessionOutputTests.swift`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCLITests/OutputStreamContractTests.swift`
