# Scoped review: iOS attempt 35, Android 027/065, and cross-platform joins

Reviewed only retained round-3 evidence against the round-3 matrix. Candidate CLI provenance is `8f2cff676b3c12e951478920fa20e600cdca4e29`; historical cov2 imports were not used.

## Fresh platform grades

The iOS attempt-35 grades IOS-091/092/093/096/097/098 are supported. The harness starts with no baselines, captures three screens, observes all three as `new_screen`, approves all, proves an unchanged comparison with zero metrics, emits the documented JSON metric fields, runs `compare --capture` against explicit owned U1, and finally substitutes only Home before named approval. `baselines-before-selective.sha256` and `baselines-after-selective.sha256` prove Home alone changed; Favorites and Deep Links remained byte-identical. Commands, exits, config, captures, and final baselines are retained.

Android AND-027 is supported. `AND-027-065diff-exact-rerun1/AND-027` shows the explicit `.debug` target warning names both IDs, the base APK remains installed under its own ID, and the run then clearly fails against the absent override target. This exactly distinguishes install identity from test identity.

Android AND-065 is supported by the joined default run and default diff-capture evidence. Both have live during-command settings observations (demo mode enabled, all three animation scales zero), followed by restoration and state-file removal. The diff leg retains the portrait PNG with the fixed status bar. This grade does not depend on AND-145's different explicit-flag input.

## Cross-platform comparison map

| ID | Verdict | Current-round evidence and comparison |
|---|---|---|
| X-005 | **gap** | No non-quarantined iOS `build build --json` success capture was found. Android has current build JSON coverage, but the required top-level-key comparison needs a fresh/current iOS success document. Do not use `cov3-ios-historical-cov2-import/X-005`. |
| X-006 | **supported** | iOS `cov3-ios-attempt26/03-install-no-launch-json.out` has exactly `status, scheme, bundleId, appPath, dataContainerPath, simulator{name,udid}`. Android `build-install-contracts-exact-rerun1/AND-021/stdout.log` has `status, applicationId, appPath, device{name,serial}`. Both say `installed`; only documented platform product/device fields differ. |
| X-008 | **supported** | iOS attempt 35 retains text and JSON unchanged comparisons with screen name, baseline/capture paths, status, pixel/perceptual metrics and thresholds. Android current `AND-087-unchanged/01.out` uses the same text vocabulary and per-screen JSON fields/status words after approval; Android paths add `/android`. |
| X-009 | **supported** | iOS attempt 35 covers all-screen and Home-only approval with `approved_screens` and `.grantiva/baselines`. Android `AND-086-exact` retains all and named approval with the same result shape under `.grantiva/baselines/android`. The only path difference is the specified Android subdirectory. |
| X-011 | **supported** | iOS attempt 29 `hierarchy-xml.out` and `hierarchy-format-json.out` are the live Landmarks list: XML application root and unwrapped typed JSON tree with point frames. Current Android hierarchy evidence (the AND hierarchy/runtime batches referenced by its ledger) has `<hierarchy ...>` XML and `{type,platform,children}` JSON with dp frames. The roots are platform-specific exactly as docs describe; tree/node conventions remain comparable. |
| X-012 | **supported** | iOS attempt 14 IOS-085 retains tree/JSON/XML from detached runner start. Android `AND-081-084-exact-rerun1` retains the three formats from detached Android start. Each format describes the same live platform tree within its half, and tree conventions align. |
| X-014 | **supported** | iOS attempt 31 covers new/reused ensure: plain stdout is only UDID and JSON includes identity/state/created plus iOS geometry. Android `secondary-avd-lifecycle-exact-rerun1/AND-003` and `AND-004-007` cover new/reused ensure: plain stdout identity, human stderr, and JSON identity/state/created. Android's unbooted `--no-boot` output may be AVD name because no serial exists; that is the documented platform distinction. |
| X-016 | **supported** | iOS attempt 31's owned new-simulator lifecycle retains simulator teardown JSON; Android `secondary-avd-lifecycle-exact-rerun1` retains owned secondary-AVD teardown JSON. Both identify the target and report process/session/home cleanup using platform-specific fields. “Comparable” does not require identical key sets. |
| X-023 | **supported** | iOS `cov3-ios-attempt27b/timeout.err` and Android `AND-046-049-exact-rerun1/timeout/stderr.log` contain the identical terminal sentence: `Error: grantiva killed the runner after 30s (--timeout <seconds> to raise the cap). The runner's last output above shows how far it got.` Neither has the historical stray colon. Both use NEW:18-long-wait and reach the active flow before timeout. |

## Mapping caution

X-008 through X-016 should cite the exact current raw directories above rather than older `findings/cov-ios-results.md`, `cov-android-results.md`, or any `cov2-*` ledger. X-005 remains open because source shape or an old imported JSON document cannot replace the required current runtime comparison.
