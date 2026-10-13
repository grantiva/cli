# Task 9 reopened matrix preparation report

Status: **DRAFT PREPARATION COMPLETE; COVERAGE EXECUTION REMAINS BLOCKED ON TASK 8 GREEN SMOKE.** Candidate identity remains `UNKNOWN`. No build, source test, coverage command, simulator/AVD action, product edit, canonical publication, tag, release, or device query was performed.

## Scope added

- L82 is represented by five exact acceptance-bullet rows. `B4-L82.1`, `.2`, and `.5` are CLI-only production-path/source-test and candidate-provenance obligations. `B4-L82.3` and `.4` are Android-live obligations and separately pin ready-state SIGINT cleanup, normal foreground stop, clean-baseline absent-app cleanup, and survival of an unrelated forward. `B4-L82.5` independently requires focused/full fresh-home tests, review, CI, merge, and rebuilt-candidate proof and prevents a clean Task 8/9 verdict on the leaking candidate.
- L83 is represented by four exact acceptance-bullet rows. `B4-L83.1`, `.2`, and `.4` are CLI/runner source-test and candidate-provenance obligations. `B4-L83.3` is Android-live and requires the no-rebind unrelated `tcp:6790`→`tcp:16790` forward to survive healthy stock exit, ready-state SIGINT, and normal foreground stop while owned forwards and sessions disappear. Both UIAutomator2 and analogous DeviceLab cleanup are explicit in the source criterion.
- Reopened L66 gains three controls without changing `B4-L66.1`–`.5`: `B4-PC.14` pins the real persistent Favorites button while cold-launch unselected; `B4-PC.15` pins the same button through selected/unselected transitions; `B4-PC.16` repeats exact identity after app relaunch and runner/MCP restart across both persisted initial selections. Offscreen/content identity, aliases, symbol-prefix matching, and label fallback cannot satisfy these controls.

## Preservation and totals

The original pre-edit drafts are preserved under `task9-reopen-base/`; the incomplete 1,304-row reopened drafts and their scoped diff/report are preserved under `task9-reopen-fix-base/`. All 1,293 pre-existing logical rows, including the original 1,170 inherited rows and 123 earlier B4 rows, remain byte-for-byte present with blank results. The corrected reopened delta adds 12 logical rows: CLI 6, iOS 3, Android 3, shared 0.

The resulting draft has 1,305 logical rows: CLI 425, iOS 359, Android 346, shared 175. It expands to 1,480 slice results: CLI 425, iOS 534, Android 521. The complete B4 delta is 135 logical rows and 151 expanded results.

The criteria index now contains 116 exact brief criteria, 19 public/review controls, and 135 indexed B4 rows. All five L82 bullets, all four L83 bullets, and all three reopened L66 controls map to existing row IDs. Candidate fields remain `UNKNOWN`; the Task 8 green-smoke execution gate is unchanged.

## Structural verification

- JSON parses successfully.
- Blank-result row count changed only from 1,293 to 1,305.
- Every pre-edit blank-result row is still present exactly; zero prior rows are missing or changed.
- Index platform totals are CLI 41, iOS 40, Android 38, shared 16 for the 135-row B4 delta and agree with the matrix count table.
- Every source-criterion and control row ID exists in `rowIndex`; missing mappings: 0.
- L82 indexed criteria: 5; L83 indexed criteria: 4; reopened L66 controls: 3.

These are preparation-only structural checks. They do not establish product behavior or satisfy any result cell.
