# Round-3 D2/N missing-ID gap audit

Generated from the current iOS and Android ledgers after the latest graded additions. This lists only matrix IDs absent from each platform ledger; it does not import round-2 evidence or infer whole-row passes from source.

## iOS missing IDs (11)

| ID | Current-round reusable proof | Smallest unresolved clause |
|---|---|---|
| N2-05 | Attempt 70c and current runner lifecycle captures prove ordinary foreground cleanup; attempt 47/runner lifecycle captures supply numeric lifecycle documents | One exact two-device keep-alive `sessions[]` stop, plus join to an ordinary detached stop and killed-before-stop document with all keys |
| N2-09 | Attempt 10 has passing/failing no-report and retained-report run artifacts; attempt 35 has current diff approval/compare behavior | Join filesystem inventories proving run captures never enter `.grantiva/captures` or VRT `ignored`; otherwise one scratch filesystem-only rerun |
| N2-18 | Current lifecycle evidence covers ordinary signal cleanup but no retained current blocked-mask/nohup SIGHUP sequence was identified | Exact blocked-mask detached start and nohup SIGHUP runtime remain |
| D2-13 | Attempts 47, 62 and 70c provide starting/started/already-running/stopped/not-running shapes | Identify an `exited` condition or record its absence as required, then compare every required key/value type |
| D2-20 | Current teardown evidence is distributed across attempts 31, 42c and 71b | Join exact four variants: free force, dead keep-alive reclaim/temp dirs, sessionless non-force, live runner session stop; do not substitute 71b session teardown for UDID variants |
| D2-30 | Attempt 25 supplies project isolation/owner-sidecar evidence and later lifecycle attempts supply detached survival/cleanup | Exact `/tmp` vs `/private/tmp` attach plus kill-parent lifeline and detached control need one documented join |
| D2-38 | Current MCP build/run attempts exist in the retained MCP batches | Join exact build and run response texts, product path and device naming from full raw; do not infer from CLI build JSON |
| D2-39 | Attempt 32/current context evidence covers config/session fields | Join `.maestro`-only, Android-only under iOS, and live-session variants; list exact source text and driver port fields |
| D2-41 | Current device-free VRT failures exist; attempt 56 proves live VRT but not its no-focus type screen | A live iOS VRT screen whose `type` step has no focus, with exact screen/step error, remains unless retained K86/K102 raw contains it |
| D2-45 | Current notification batches exist in later MCP attempts | Audit exact ordering around subscribe, successful tap, rejected call, partly-run script and unsubscribe; a notification count alone is insufficient |
| N3-09 | Attempt 42c teardown lifecycle likely supplies the foreground stop outcome | Must preserve observed `<pid>.stop.json` between request and cleanup on iOS; final absence alone is insufficient |

## Android missing IDs (26)

| ID | Current-round reusable proof | Smallest unresolved clause |
|---|---|---|
| N2-01 | N3-06 ten-recording batch proves exact 3 s hold behavior | Five 4 s recordings plus `--frames-at 4000` last-frame resolution are still distinct inputs |
| N2-05 | `N2-05-B3L13-dead-runner-stop-json-rerun2` proves killed-before-stop; ordinary stops recur in lifecycle batches | Two simultaneous keep-alive sessions from one project on two row-owned devices and a joined ordinary stop remain |
| N2-06 | No complete current headless truth-table batch identified | Run baseline, CI true/1/0/false/empty and explicit headless on a row-owned secondary AVD; inspect emulator argv |
| N2-07 | Current VRT and lifecycle JSON now carry fixed stop metadata | Decode every README alias pair across ensure/VRT/start/stop and scan for unlisted snake_case; likely analysis-only |
| N2-08 | Output-contract run pass/fail and K17/K81 capture JSON supply durations | Audit every step for present positive-or-null duration, including live-session capture; analysis-only if files complete |
| N2-11 | B2-K55 detached live capture proves stock session capture | Add/refind the cfg/screens-steps `runFlow` refusal while the detached session remains alive, then stop it |
| N2-13 | Crash/wait batches exist but earlier results varied by wait type | Exact current 3x crash plus all four named wait variants and `app_crash` timing/type remain a compound runtime check |
| N2-16 | Settings restoration batches prove normal restore | Three fresh-first captures and teardown-mid-flow 5 s/offline 30 s branches remain unless exact retained timing files cover both |
| N2-17 | Existing swipe evidence covers far-side geometry but open-row reliability varies | Ten exact K09 runs plus pointer trace and runner selector-doc source are required together |
| D2-02 | Combined screens/flows runs exist in startup/output batches | Join one pass and one fail ready file with `screens` first and existing explicit report dirs |
| D2-05 | Flow-contract v3/K22/K23 batches cover many Maestro forms | Join all named forms, nested screenshot and timeout preservation in one exact config audit; avoid CI-refusal substitution |
| D2-07 | Build-install contract batch has launched/installed; skipped controls exist | Decode all three status documents and Android `applicationId`, `appPath`, device name/serial fields |
| D2-09 | App-file capture/build batches exist | Exact shut-down-device boot + supplied APK install + five-screen capture must be joined from one row-owned sequence |
| D2-11 | N3-06 proves idle note/fields but uses 3 s and no late change | Exact 4 s verbose idle and late-change/no-note pair remains |
| D2-12 | Recording/output batches cover path and usage modes | Join past-duration exit64-before-recording and relative/absolute text+JSON paths |
| D2-13 | X-013/X-017 lifecycle batch and dead-runner stop give most statuses/keys | Record `exited` condition/absence and verify all started/already/stopped/not-running app/device aliases |
| D2-18 | Output-contract batch provides pass/fail JSON; bad-device JSON exists | Compare full entry/key shape and add pre-flow failure if not already in that batch |
| D2-28 | Emulator lifecycle evidence contains missing-image failures | Need exact sdkmanager reason, installed-image list and before/after AVD inventory in one retained refusal |
| D2-29 | Teardown/delete lifecycle batches cover several variants | Join runnerSessionStopped, unknown serial, stale missing-AVD record drop, and pretty delete JSON |
| D2-30 | Owner-sidecar/foreground batches cover live metadata | Exact realpath attach, killed-parent lifeline and detached survival control need one documented join |
| D2-35 | MCP emulator lifecycle batches likely contain both refusals | Join running-AVD delete refusal (AVD survives) and missing-AVD boot exact errors |
| D2-38 | Current MCP build/run batches exist | Join success/duration/warnings/errors/product plus run module/variant/ID/device; prove build leaves adb inventory unchanged |
| D2-39 | `B2-K56-X011-MCP076-context-resources-rerun4` proves live keep-alive context | Add configured source and Android-only-dir queried as iOS; preserve `(forwarded on attach)` wording |
| N3-04 | MCP build/run batches have device lines | Join Android build (no boot) and run `Device: name (serial)` from exact responses |
| N3-05 | Current ensure/emulator MCP batches exist | Join CLI reused stderr/stdout and MCP `Emulator reused...already running` for same AVD |
| N3-09 | Foreground teardown batches prove outcomes | Need observed stop-marker file before cleanup, not merely final absence |

## Priority analysis joins

Before scheduling device work, workers can close or sharply narrow Android N2-07, plus N2-08, N2-09, D2-02, D2-07, D2-13, D2-18, D2-38, D2-39, N3-04 and N3-05 by decoding the listed current raw artifacts. Rows involving two devices, exact signal masks, fresh boots, late recording changes, or transient stop-marker observation still need their named runtime conditions. iOS N2-07 and D2-21, and Android N3-10, were removed after their finalized evidence was independently reviewed.
