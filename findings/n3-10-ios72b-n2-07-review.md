# N3-10, iOS attempt 72b, and N2-07 review

Reviewed against the round-3 matrix at `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/docs/superpowers/plans/2026-10-13-round3-coverage-matrix.md`, candidate CLI `8f2cff676b3c12e951478920fa20e600cdca4e29`, and the preserved current-round evidence named below. This is a scoped evidence review, not a review of either whole platform slice.

## Verdicts

### N3-10 [android]: supported

`/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/N3-10-driver-start-timeout-rerun1/commands.txt` records the exact paired `01-browse` invocations. Both exit 0 and both terminal reports have one passed flow. The complete verbose runner command in `with-env/runner-lines.txt` includes `--driver-start-timeout 45`; the corresponding command in `without-env/runner-lines.txt` omits the option. The source bundle pins candidate HEAD `8f2cff67`, the documented environment variable, production forwarding, and its semantic test. The Android ledger's pass is fully supported.

### iOS attempt 72b: completed and valid

`completed.txt` records terminal completion at `2026-10-13T08:10:41Z`, and all five iterations have both exit files. In every iteration both simultaneous ensures exit 0, return the same UUID, split exactly one `created:true` and one `created:false`, and leave exactly one simulator with the requested name. The wait messages identify the same named device, UUID, and booting Grantiva PID and contain no capacity message. Each `simulator sessions --json` document records that UUID active with `bootedByGrantiva:true`.

The row-owned lifecycle is also complete: each UUID occurs in the preserved QA-home `simulator-capacity/created.json`, each session teardown returns `deleted:true`, each immediate post-teardown inventory omits the UUID, and final guarded cleanup contains none of the five names. Exact-head `SimulatorManagerTests.testBootWaitingOnATwinsBootIssuesNoSecondBoot`, `testATwinWaitIsNotReportedAsACapacityWait`, and `SimulatorCapacityTests.testAPendingRecordOfAnotherLiveProcessUnderTheLimitIsADeviceWait` supply the two named semantic source assertions.

Accordingly, the new `B2-K67 [ios]` and `D2-21 [ios]` pass rows are supported. The attempt does not need an additional completion or cleanup observation.

### N2-07 [ios]: supported

`/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-analysis-n2-07/audit.json` recursively decodes the exact retained JSON from ensure, capture, unchanged and changed compare, approve, runner start, and runner stop. It records 53 alias occurrences, all equal to their camelCase twin; its observed key set equals the 16 aliases in exact-head `Sources/GrantivaCore/Output/LegacyJSONKeys.swift`; and `unlistedSnakeCaseKeys` is empty. The runner start and stop files each contain equal `bundleId`/`bundle_id`, so the lifecycle writer is covered rather than inferred from VRT output.

The README names the same 16 pairs and commands. `JSONKeyCasingContractTests.testEveryJSONDocumentUsesCamelCaseKeys` recursively rejects any other snake_case key, while `testTheReadmeListsEveryLegacyAlias` ties the README list to the production alias table. The iOS ledger's platform-half pass is supported. Android's platform-specific `applicationId` twin remains a separate Android-half obligation.

## No material findings

The reviewed ledger grades match the matrix. The evidence is current-round, the source excerpts identify the exact candidate HEAD, and attempt 72b's terminal marker plus per-iteration and final inventories remove the earlier in-progress ambiguity.
