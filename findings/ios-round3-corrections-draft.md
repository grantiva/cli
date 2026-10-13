# iOS round-3 Task 6 expectation-correction draft

This is a review draft only. It does not edit the controller matrix, regrade a row, or replace any L64–L79 product brief. The completed ledger has 21 base-row failures, 10 blocked rows, and one additional side-finding failure (`IOS3-OBS-01`). Five blocked rows use the more specific ledger status `blocked owner simulators booted`.

## Proposed matrix corrections

| Row | Exact replacement criterion | Basis |
|---|---|---|
| MCP-078 | After app termination, every session tool that requires an application element/session returns a tool-level `isError` without a JSON-RPC error. `grantiva_screenshot` may succeed when the device remains available; require a valid image if it does. | Attempt 37 records six tool errors and a valid post-termination screenshot. The old “every session tool errors” wording conflates app-scoped operations with a device screenshot. |
| IOS-058 | If SIGINT arrives while a keep-alive command is still executing work, its terminal ready document becomes `interrupted`. If all configured work has already completed and the command is only holding the session open, preserve the completed `passed` ready document while releasing the session and exiting through the signal path. | Attempt 29 captured a byte-equivalent completed `passed` document before and after signalling the post-completion keep-alive hold. |
| B3-L55.1 [ios] | Establish an active flow using the live owner/session record and owned process liveness. Do not require the terminal ready file to exist or say `running` while the flow is active. After stop, require exit 130, terminal `interrupted`, and removal of session residue. | Attempt 48b passes all stop outcomes. `RunCommand.swift` writes the ready document after report completion or interruption, so the former precondition was impossible on the candidate. |
| X-013 | Compare the common lifecycle fields and their types across platforms. Permit the platform application-identity field to be named `bundleId` on iOS and `applicationId` on Android, just as device identity fields may differ. | Attempt 62 and the paired Android rerun agree on shared fields. The platform-specific names are independently required by B2-K16, D2-13, and N2-07. |
| IOS-016 | Kill the row-owned keep-alive parent first, then require targeted force teardown to reap orphaned WDA/diagnose children, remove owned homes/staging/session state, and leave no owned process. Do not require teardown to kill the already-dead parent runner. | Attempt 74 satisfies this behavior and binding K68 says children exit with a killed parent. |
| B2-K103 [ios] | No undocumented snake_case JSON key may appear. During the compatibility window, permit only the documented snake_case aliases when an equal camelCase twin is present. | The current recursive audit found exactly the 16 documented equal aliases; `LegacyJSONKeys.swift` and `JSONKeyCasingContractTests.swift` enforce this contract. |
| IOS-153 | For separate plain, quiet, and verbose JSON captures with identical semantic input, compare decoded documents after excluding execution-dependent timestamps and durations. Require identical stable fields and results; quiet adds no diagnostics and verbose may add diagnostics only on stderr. | Attempt 109b differs only in timestamps/durations while all stable five-screen results agree. Literal byte identity across separate executions is not a mode contract. |
| B2-K19 [ios] | `--quiet` suppresses ordinary progress when used alone. `--verbose` enables diagnostics and takes precedence when both flags are supplied. JSON controls stdout shape independently. Authenticated CI variants remain required only in an environment with authorized credentials. | Attempts 109b/127 show quiet behavior and intentional verbose precedence; CI reaches the real authentication gate. |

These eight rows should remain recorded as literal-matrix failures in the completed ledger until the controller applies the replacement wording.

## Product or documentation failures retained unchanged

| Row(s) | Disposition and tracking |
|---|---|
| B3-L15.2 [ios] | Keep the exact error-text criterion; product says `'steps' array is required` rather than `'steps' is required`. Tracked by `L65-script-missing-steps-error-contract.md`. |
| IOS-102, B2-K78 [ios], D2-36 [ios] | Keep accessibility-identifier fallback requirements. The live MCP `heart` selector fails while the runner identifier path succeeds. Tracked by `L66-ios-identifier-tap-fallback.md`. |
| N3-03 [ios] | Keep explicit `"port": null` for an already-running session that is still starting. Tracked by `L69-starting-runner-json-omits-null-port.md`. |
| B-I16.2 [ios] | Runtime migration is correct; retain the missing public rename/migration-note failure. Tracked by `L70-baseline-filename-migration-documentation.md`. |
| D2-08 [ios], B2-K25 [ios] | Keep the absent-app `--no-build --no-launch` skipped-result contract. The data-container lookup incorrectly exits NSPOSIX2. Tracked by `L71-no-build-no-launch-queries-absent-ios-container.md`. |
| N2-15 [ios] | Keep foreground-start SIGINT exit 130 and cleanup requirements. Startup currently emits a false WDA timeout and exits 1. Tracked by `L72-foreground-start-sigint-during-startup-reports-wda-timeout.md`. |
| D2-20 [ios] | Keep live force-teardown JSON reporting, including `runnerSessionStopped`. Cleanup occurs but the result omits it. Tracked by `L73-force-simulator-teardown-omits-stopped-runner-result.md`. |
| B-C22.2 [ios] | Keep the public ISO-8601 change-note clause. Runtime/source behavior passes but public documentation is absent. Tracked by `L74-iso8601-json-date-change-lacks-public-note.md`. |
| B3-L20 [ios] | Keep project-relative cycle-chain display. Subdirectory cycles expose containing-file-relative `../` hops. Tracked by `L75-subdirectory-cycle-hops-use-containing-file-relative-operands.md`. |
| IOS3-OBS-01 | Keep as a side-finding failure. Force teardown may signal an unrelated process solely because its arguments contain the Grantiva path and UDID. Tracked by `L76-force-teardown-matches-unrelated-process-arguments.md`. |
| IOS-064 | Keep the no-orphan-at-command-return contract. The SIGINT path returns while its reparented log stream remains alive briefly. Tracked by `L78-interrupted-run-returns-before-log-stream-exits.md`. |

The product/documentation set above accounts for 13 base-row failures plus the one side finding. Together with the eight matrix-correction rows, it accounts for all 21 base failures and `IOS3-OBS-01`. L64, L67, L68, L77, and L79 track Android-only observations and remain untouched by this iOS correction draft.

## Blocked rows

| Row | Remaining unavailable condition |
|---|---|
| B3-L08.1 | The guarded no-simulator MCP build could not be sent while protected owner simulators were booted. |
| B3-L08.2 | The guarded default-path CLI calls could not be sent while protected owner simulators were booted. |
| B2-K37.2 [ios] | The default-device guard prohibited the no-simulator call while protected owner simulators were booted. |
| N3-12 | The guarded MCP calls required a no-owner-device environment that was unavailable. |
| N3-13 | The required empty booted-device list was unavailable; the guarded MCP build was not sent. |
| B-I06.2 [ios] | Direct observation distinguishing `/session/{id}/wda/keys` from its 404 fallback. |
| B-C21.1 [ios] | A genuine no-booted-simulator environment; protected owner simulators could not be shut down during the campaign. |
| N-08 [ios] | Root-level developer-install-directory/PATH isolation. |
| B2-K36 [ios] | Working-toolchain/no-boot runtime in a no-booted-simulator environment. |
| B2-K18 [ios] | Authorized CI preservation behavior; supported commands stop at the real authentication gate. |

`B2-K19` is counted as a failure in the ledger, not as an additional blocked row, because the observable quiet-plus-verbose conflict independently determines its literal verdict. Its authenticated CI quiet/JSON subclauses remain unavailable at the credential boundary. These 10 blocked rows are base-ledger verdicts; cross-platform handoffs awaiting evidence from another slice are not additional iOS blocked verdicts.
