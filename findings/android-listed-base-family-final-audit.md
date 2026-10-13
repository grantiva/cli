# Android listed base-family final audit

Scope: only `AND-087`, `AND-110`, `AND-122`, `B-A01.1`, `B-A01.3`, `B-A02.1`, `B-A07.1`, `B-C03.2`, `B-R01.1`, `B-R02.2`, `B-R02.3`, `B-I16.1`, and `N-12`. Runtime evidence is retained round-3 Android evidence; no cov2 result or runtime output is used. Candidate CLI provenance is `8f2cff67`; runner provenance is `fd9d8e8`.

## Ready to grade

| Row | Verdict | Exact evidence and criterion mapping |
|---|---|---|
| `B-A01.1` | **PASS** | `AND-035-exact/01.out` ends with the exact delivered extra `extras=[LANDMARKS_NOTE=a=b c]`; `AND-035-exact/report/` is the passing qa-note flow. `D2-02-stock-ready-pass-rerun1/ready.json` and `report/flows/flow-008.json` plus flow 009 prove `09-seed-empty` and `10-seed-many` passed in the complete current stock run. `B3-L49-L50-crash-waits-rerun1/runs/crash-page-source-1/report/flows/flow-000.json` records `type: app_crash` and the app `RuntimeException: LANDMARKS_CRASH_ON_LAUNCH` at `launchApp`. |
| `B-A02.1` | **PASS** | `D2-02-stock-ready-pass-rerun1/report/client.log` lines 34–37 show the successful `Lake Tahoe` element lookup followed by its `/rect`; flow 02 passed and its retained capture is `report/captures/02-favorite-cmd-008-Remove.png`. `CF-07-swipe-from-missing/run.out`, `report/flows/flow-000.json`, and `report/client.log` prove exit 1 and exact `Element not found for swipe: text='No Such Row'`. The successful swipe implementation/source semantics are also exercised by `CF-05-swipe-forms/report/`. |
| `B-R01.1` | **PASS** | `S2-01-inputtext-three-runs-rerun1/run-{1,2,3}` are three current successful edit runs. `run-1/stdout.txt` and `report/flows/flow-000.json` prove `assertVisible: text="Golden Gate Bridge Renamed"`; `duration-snapshot-contracts-exact-rerun1/pass-full/run-captures/android/03-edit-cmd-008-Edited.png` is the retained full-snapshot edit capture and shows the renamed value. |
| `B-R02.2` | **PASS** | The current complete full-snapshot run retains `duration-snapshot-contracts-exact-rerun1/pass-full/run-captures/android/02-favorite-cmd-008-Remove.png`; its flow-02 report passed. This is the required post-swipe revealed action image. |
| `B-R02.3` | **PASS** | `CF-07-swipe-from-missing/run.out` and `report/flows/flow-000.json` show exit 1 and exact `Element not found for swipe`. `D2-02-stock-ready-pass-rerun1/report/client.log` lines 34–37 supplies the successful flow-02 `Lake Tahoe` lookup and `/rect` behavior; the negative log shows the repeated `/element` lookup sequence for `No Such Row`. |
| `B-I16.1` | **PASS** | `AND-027-065diff-exact-rerun1/AND-065-diff/captures/android/Deep Links.png` and `captures/android/diffs/Deep Links_diff.png` have the literal required names. `flow-contracts-bulk-exact-rerun3/K17-capture-json/capture.json` retains the current JSON path fields for the same names, and that command completed successfully. |

## Not yet fully supported

| Row | Current evidence | Smallest missing evidence |
|---|---|---|
| `AND-087` | `AND-087-unchanged/01.out` proves unchanged text and valid JSON pass with both threshold fields. | A current deliberately changed-pixel corpus compared in text and JSON that demonstrates failure under **both** configured threshold dimensions. `AND-027-065diff-exact-rerun1/AND-065-diff` is capture/settings evidence, not that comparison. |
| `AND-110` | Other lifecycle groups prove individual emulator commands, but no retained transcript runs the docs/android.md 166–171 example sequence as written with campaign name `cov-android`, `Pixel_8_API_35`, and the returned started serial. | Execute/document those exact examples and their comment outcomes. The campaign-global `--all` action remains excluded by the safety ruling and should be recorded blocked, not executed. |
| `AND-122` | `AND-059`/`AND-060` and later keep-alive groups prove keep-alive behavior, but they do not execute the three docs/android.md 104–106 example lines as written and compare each printed result with its comment. | One retained transcript of the exact three documented commands and outputs. |
| `B-A01.3` | `AND-035-exact` proves CLI `--launch-environment` becomes an Android intent extra. | A flow-header `env:` run proving whether it is delivered to the Android app, or public documentation explicitly limiting it to `${VAR}` substitution. The existing CLI-extra run does not decide this separate branch. |
| `B-A07.1` | Foreground and verbose-process groups exercise SIGINT and logcat lifecycle/source behavior. | A retained process inventory tied to an exact `run --logs` invocation showing exit 130 and no matching `adb ... logcat` after command exit. Existing `B2-K33-X024-verbose-processes-rerun2` runs are normal terminal runs, not the required SIGINT leg. |
| `B-C03.2` | `B2-K56-X011-MCP076-context-resources-rerun4` proves a valid same-project Android keep-alive context and stored platform/device fields. | Runtime evidence that a session from another project directory is not reused, plus the platform-mismatch branch (or exact semantic tests for that conditional branch if the plan permits source verification). Same-project success alone does not prove exclusivity. |
| `N-12` | `MCP064-066-B2K55-D241-vrt-equivalence-type-rerun1` proves five-screen MCP and CLI capture on `emulator-5554`, including live-session device selection. | A retained `diff compare` using one five-screen corpus as baseline and the other as current, with every screen passing configured thresholds and explicit placeholder/hint-text coverage. Parallel successful captures alone do not establish the comparison result. |

## Count

- Fully supported and ready to grade: **6**.
- Still missing an exact criterion leg: **7**.

