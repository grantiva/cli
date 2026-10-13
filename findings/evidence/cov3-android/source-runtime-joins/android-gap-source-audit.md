# Android round-3 retained-evidence gap audit

This audit compares the current matrix with `cov3-android-results.md` and uses only retained round-3 Android evidence plus exact candidate source at `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main` HEAD `8f2cff676b3c12e951478920fa20e600cdca4e29`. It does not grade rows. Historical `cov2-*` and unqualified `cov-android` captures are excluded.

The strongest currently missing candidates are below. “Runtime complete” means the named retained files appear to cover the full row as written; the Android worker should still perform its normal raw-integrity check. “Source clause complete” applies only where the matrix row itself is a source/docs/test clause.

| Row | Candidate state | Retained round-3 evidence / exact semantic assertion |
|---|---|---|
| B-A13.2 | Runtime complete | `findings/evidence/cov3-android/AND-106/01.out` shows the stock screen capture reaches both Lakes and Detail; `AND-106/report/report.json` preserves the five screen records. |
| B-R01.2 | Runtime complete | `AND-106/01.out` shows `03-edit` taps Done, then sees `Golden Gate Bridge Renamed` and passes. `AND-106/report/client.log` is the retained request trace for confirming the Done click coordinate is above the keyboard, as the clause requires. |
| N-14 | Runtime complete by explicit join | `AND-106/01.out` and `AND-106/report/report.json` show `03-edit` appends and completes without an input warning. `CF-crash1/` through `CF-crash5/` preserve current crash results; use the report JSON whose failed wait carries `error.type: app_crash`. Do not cite the B-R01.3 pointer file alone. |
| N-17 | Runtime complete | `AND-106/01.err`, `AND-106/01.out`, and `AND-106/report/report.json` preserve live, summary/table, and JSON durations for the same stock steps and flows. Compare shared display precision explicitly in the ledger note. |
| X-001 | Runtime complete | `AND-106/01.out` plus `01.err` preserve the passing Android narration: five screens, twelve flows, per-step results and summary; the output uses Android device/UIAutomator2 vocabulary and contains no GrantivaAgent narration. |
| X-003 | Runtime complete | `AND-106/report/` contains `report.json`, `flows/`, `junit-report.xml`, Allure/assets, while `commands.txt` preserves the requested report directory and stock flow paths. |
| B2-K04 | Runtime complete | `AND-106/report/maestro-runner.log` per-flow headers identify `google sdk_gphone64_arm64 (android 35 Emulator)`; `report/report.json` records `isSimulator: true`. Join an iOS retained control only if the worker treats the row as requiring both-platform runtime rather than Android regression plus unchanged iOS evidence. |
| B2-K110 | Runtime complete for default Android leg | `AND-106/report/maestro-runner.log:4` is exactly `Driver: uiautomator2`; `report/report.json` supplies the corresponding driver/device metadata. The explicit-driver leg is separate and must be located before a whole-row grade if the row is read strictly. |
| B2-K13 | Likely runtime complete; inspect narration count | `AND-106/01.out` contains five named screen blocks and exactly twelve named stock flow blocks. Use `AND-106/01.err` to confirm the initial narration separately names five screens and twelve flows and never says 13. The flows-only/screens-only/`--flow` variants are not supplied by this one capture; grade only if retained focused captures cover them. |
| S2-03 | Runtime complete | `findings/evidence/cov3-android/S2-03/commands.txt`, `01.out`, and `01.err` are the exact stock-screens plus failing-flow repro. The stdout contains the screen and flow summaries despite failure. |
| B-A01.2 | Source/docs clause complete | Candidate `docs/android.md:88-94` states that `--env` becomes `launchApp.arguments`, merges an existing map, and is passed as launch-intent extras. This identifies the selected implementation route required by the row. |
| B-A01.4 | Exact semantic source clause complete | `Tests/GrantivaCoreTests/FlowEnvironmentTests.swift:143-170` covers bare/scalar/mapping launchApp and values with spaces/equals; `FlowGeneratorTests.swift:42-58` covers Android screens-flow injection. These assertions match the named clause, rather than merely matching test names. |
| B-A04.2 | Source/docs clause complete | `Sources/GrantivaCore/Runner/FlowGenerator.swift` (locate generated post-action settle emission) and the exact tests below establish one bounded settle before screenshot. The worker should cite the production lines alongside the assertions, not the tests alone. |
| B-A04.3 | Exact semantic source clause complete | `FlowGeneratorTests.swift:135-151` asserts a settle between tap and screenshot; lines 186 onward assert every generated screenshot is preceded by exactly one settle. |
| B-A05.3 | Exact semantic source clause complete | `Tests/GrantivaCLITests/RecordCommandTests.swift:227-260` exercises a static Android recording held to the requested duration and extracts an in-range requested frame; `:293` rejects a frame beyond the requested duration before recording. Retained runtime `cov3-android/B-A05.1/` separately demonstrates the 2 s/1000 ms behavior. |
| B-A08.2 | Source/docs clause complete | `docs/android.md:121-130` documents start-at-current-time and the default/info/debug priority table; `AndroidPlatform.swift:208-227` implements `-T <time>` and the mapped priority with no buffer clear. |
| B-A08.4 | Exact semantic source clause complete | `AndroidPlatformTests.swift:145-169` asserts start-now/no-clear/UID filtering and all level mappings; `RunCommandTests.swift:223` rejects values outside the documented enum. |
| B-A13.3 | Exact semantic source clause complete | `FlowGeneratorTests.swift:198` decodes the exact mapping form and asserts the emitted selector retains `exact: true`. Confirm the adjacent config-decoding assertion in the same test body before grading the entire source clause. |

## Rows that should not be recovered from nearby evidence

- `B-A01.1`: current `cov3-android/B-A01.1/` contains only one `10-seed-many` command. It does not contain the required launch-environment logcat, seed-empty, and crash legs.
- `B-R01.1`: AND-106 proves append and final assertion, but this row also demands a `--snapshot full` image after inputText. The retained stock run was not full snapshot evidence.
- `B2-K13`: AND-106 alone does not establish the flows-only and screens-only narration variants.
- `B2-K110`: the default driver line is present, but do not infer the explicit `--driver` clause without its raw command/log.
- Broad stock success does not satisfy timing, concurrency, settings restoration, teardown, pointer-overlay, or multi-run stability clauses.

These candidates intentionally stop below 30 because the remaining missing rows generally require distinct runtime variants rather than a source join.
