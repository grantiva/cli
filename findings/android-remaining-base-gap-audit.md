# Android remaining base-row audit (requested families)

Date: 2026-10-13. This is a read-only prioritization audit against the 81 base IDs reported missing by `audit_coverage.py android`. It uses retained round-3 `cov3-android` artifacts only. The older `cov-android` and `cov2-android` directories are not treated as current proof. Candidate source is Grantiva CLI `8f2cff67`; runner source is `fd9d8e8`. A source assertion is joined only for a source/test clause; it does not replace an explicit runtime input.

## High-yield rows that can be joined now

| Row | Disposition | Current evidence and exact coverage |
|---|---|---|
| AND-058 | **full join** | `B2-K79-K104-D230-realpath-kill-rerun3/` kills the row-owned runner and retains immediate CLI rejection plus MCP no-session behavior; `B2-K104-realpath-ready-mcp-rerun1/` supplies the prior live-session control. This is the required dead-session-ignore/fail-fast behavior. |
| AND-080 | **full join** | `starting-session-contracts-rerun4/` records detached Android absent→starting→ready, then the ready PID/forwarded driver port/session; `B2-K86-a-handedoff-refusal-rerun2/` proves that session serves a hierarchy before cleanup. |
| AND-087 | **full join** | Current round changed/unchanged text and JSON comparisons are retained under `AND-027-065diff-exact-rerun1/` and the current X-008 audit; `MCP064-066-B2K55-D241-vrt-equivalence-type-rerun1/cli/` provides threshold/status JSON. Join only after checking the changed corpus includes both pixel and perceptual failure legs; if it contains only one, the other is the sole complement. |
| AND-100 | **full join** | `MCP056-057-emulator-list-boot-rerun1/` plus `MCP059-062-D235-emulator-lifecycle-rerun1/` exercise list, boot, name-only ensure, and delete, including created/hand-made/running/missing cases and cleanup. |
| AND-101 | **full join** | `D2-38-N3-04-mcp-build-run-rerun2/` retains MCP build/run with Android module, variant and emulator and a `Product:` APK path. |
| B-A01.1 | **full join** | Current stock D2-02 supplies seed-empty/seed-many; `B3-L49-L50-crash-waits-rerun1/` supplies repeated Android RuntimeException/app-crash behavior; retained launch-environment/logcat evidence supplies `LANDMARKS_NOTE=a=b c`. Confirm the latter path in the result row rather than citing an older verdict. |
| B-A01.3 | **full join** | The same current launch-environment/header-env capture shows delivery as Android intent extras, satisfying the criterion's decide-and-prove branch. |
| B-A02.1 | **full join** | `CF-05-swipe-forms/`/current gesture artifacts show the Lake Tahoe lookup/bounds and successful reveal; `CF-07-swipe-from-missing/` shows the named element-not-found failure. `B3-L32-L33-L59-gesture-counters-rerun2/` and exact runner source corroborate emitted gesture forms. |
| B-A07.1 | **full join** | `B2-K33-X024-verbose-processes-rerun2/` retains logcat start and terminal SIGTERM; foreground interruption evidence retains exit 130. The process inventory must be cited directly to prove no logcat remains. |
| B-C03.2 | **full join** | `B2-K56-X011-MCP076-context-resources-rerun4/` records live Android project/platform context; current lazy-reattach/other-directory controls show only the matching project/platform session is reused. |
| B-R01.1 | **full join** | `B3-L58-first-tap-parent-rerun1/` contains three exact 03-edit passes and postconditions. Join the retained full-snapshot 03-edit run only if its `cmd-005-after.png` is present; otherwise the screenshot is the sole complement. |
| B-R02.2 | **full join** | Current full-snapshot flow 02 artifact retains the after-swipe PNG with the revealed Remove action. Cite the unmodified PNG, not a crop. |
| B-R02.3 | **full join** | `CF-07-swipe-from-missing/` supplies the failing missing selector; current flow 02 client/runner log supplies the `/element` plus `/rect` lookup for Lake Tahoe. |
| N-12 | **full join** | `B2-K55-detached-vrt-equivalence-rerun1/` and `MCP064-066-B2K55-D241-vrt-equivalence-type-rerun1/` retain session capture, CLI capture/compare and live-session device selection. Grade only if decoded manifests confirm the baseline/current images are the same five screens on the same emulator; otherwise request only that explicit same-device capture complement. |
| N3-09 | **likely full join** | Foreground lifecycle and targeted teardown evidence retain a row-owned foreground start, stop marker/session cleanup and exit-0 teardown. Before grading, cite the actual 100-ms marker inventory showing `<pid>.stop.json` appears beside owner and disappears; stdout alone is insufficient. |

## Current partials and smallest complements

| Row(s) | Retained current proof | Smallest missing runtime evidence |
|---|---|---|
| AND-011, B-C02.1 | Current owned/unowned lifecycle tests cover refusal wording and ownership source semantics. | One row-created, hand-started AVD: refusal without force and successful force teardown. `--all` remains explicitly blocked by the campaign constraint for B-C02.1. |
| AND-013, B-C02.3 | Current stale/missing record pruning and ownership source tests. | Reuse a serial with a different live pid after the recorded pid dies; show record pruning and non-force refusal. |
| AND-015 | `MCP059-062-D235-emulator-lifecycle-rerun1/` has hand-made delete/refusal pairs through MCP. | Exact CLI `emulator delete --name ...` refusal then `--force` success, unless its captured shell controls already contain both. |
| AND-016 | Current running-primary refusal exists in the MCP lifecycle batch. | Exact CLI `emulator delete --name <running> --force` refusal and proof the AVD/process remain. |
| AND-017 | Timeout parsing/source coverage exists. | Cold boot with `GRANTIVA_EMULATOR_BOOT_TIMEOUT_SECONDS=5`, elapsed/error capture and row-owned cleanup. |
| AND-018 | Ownership source tests and outside-owner refusal controls exist. | One externally started AVD used by both `--device` and `--emulator`, with before/after started-record proof that run cleanup never records or kills it. |
| AND-057 | Current hierarchy batches prove successful XML/JSON and context. | Before/during/after `adb forward --list` around one hierarchy call, proving the temporary port to 6790 is removed. |
| AND-068 | Current settings runs prove normal save/restore. | Kill the row-owned run mid-flow, then a second run showing the interrupted-settings warning and restoration before execution. |
| AND-110 | Current emulator commands individually exist. | A syntax/example inventory tied to docs/android.md:166-171 plus exact current outputs; preserve the `--all` exclusion rather than execute it. |
| AND-115 | Current no-config/device selection runs exist. | Begin while the row-owned AVD is actually `offline`/booting, with no `emulator:` config, and retain the wait narration followed by a passing flow. |
| AND-122 | Current keepalive/hierarchy XML+JSON runs exist. | A docs-line inventory proving commands 104-106 were run as written; existing exact captures can satisfy this without another device run if their argv match. |
| B-A02.2, B-R02.1, N2-17 | Current one-off swipe/reveal and exact source rule are strong partials. | One immutable 10-run K09 loop with pointer overlay: far-side start, edge-margin end, and 10/10 row reveal. No existing single-run proof establishes the required 10/10. |
| B-C02.2 | Source/tests cover `choosePort` and ownership matching. | Hold a console port, boot the row-owned AVD on the skipped port's successor, and retain spawned-pid/serial ownership before the record is written. |
| D2-05 | Current runFlow scalar/mapping/inline and waits exist across `flow-contracts-bulk-exact-rerun3/` and wait/runFlow batches. | One Maestro-format screens config joining scroll direction+timeout, all three runFlow forms, subflow screenshot becoming a screen, extended-wait timeout, and Android `appId`. Individual fragments do not prove the compound config. |
| D2-09 | App-file install/no-launch and capture evidence exist separately. | Shut-down row-owned device, then exact `diff capture --no-build --app-file` showing boot, install of that APK, and five captures. |
| D2-11 | `B3-K111-record-trim-rerun1/` and `N3-06-ten-recordings-rerun1/` prove idle held-frame JSON and ffprobe duration. | One late-change-at-about-3.5s recording proving the held-frame note is absent, plus the exact verbose diagnostic fields if not already retained. |
| D2-28 | sdk/system-image source validation exists. | Invalid Android-99 image run: error names package, sdkmanager reason and installed images, with pre/post AVD inventory proving none created. |
| D2-29 | B2-K15 teardown JSON supplies runner stopped/session removal; lifecycle batches supply delete JSON. | Exact unknown `emulator-5598 --force` no-op and missing-AVD record-prune case; join pretty delete JSON. |
| N-02 | MCP build output/current build source exists. | Begin with configured AVD shut down; prove `grantiva_build {}` succeeds while `adb devices` and emulator process inventory remain unchanged. |
| N-03 | Current seed-many stock runs exist. | Same flow on one freshly created secondary and primary, retaining the last landmark after four bare scrolls for each; do not substitute a warm-only stock run. |
| N-06 | Current successful first captures exist, but not three fresh boots as one criterion. | Three row-owned fresh boots, first capture on each, recording first-attempt success or the required driver-named retry/failure. |
| N2-06 | Headless parsing/source tests exist. | Seven row-owned boots with exact env matrix and each spawned emulator argv; captured stdout alone must remain windowed. |
| N2-13 | `B3-L49-L50-crash-waits-rerun1/` has 15 crash variants and repeated app-crash classifications. | Check its five forms exactly match 99-crash x3 plus the four named first-step waits. If yes this is a full join; if `waitForAnimationToEnd` or the three 99-crash repeats are absent, run only those missing forms. |
| N2-16 | Current settings and first-capture evidence exist separately. | Three fresh-boot first captures plus a row-owned mid-flow teardown showing restore gives up in ~5s when absent and waits up to 30s when offline. |
| B-R02.1 / N2-17 | See B-A02.2. | Same single 10-run far-side overlay batch closes all three. |

## Rows not supported by the recent retained groups

`AND-013`, `AND-017`, `AND-018`, `B-C02.2`, `D2-28`, `N2-06`, and `N2-16` require specialized lifecycle inputs and should be scheduled as explicit row-owned fixtures. `AND-011`/`B-C02.1` and `AND-015`/`AND-016` can be grouped into one external-AVD ownership fixture. `B-A02.2`/`B-R02.1`/`N2-17` should be one ten-repeat gesture fixture. `D2-11` needs only the late-change recording complement. `D2-29` needs only the unknown-serial and missing-record controls.

This audit does not regrade any worker ledger. Rows marked “full join” still require the worker to cite the exact raw files and decoded fields in its result line; conditional notes above identify the only checks that can demote them to partial.
