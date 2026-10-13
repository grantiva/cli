# Scoped rereview — corrected Android targeted evidence

Scope: rereview only of the unresolved findings in `cov3-android-progress-review.md`: AND-075, AND-202, AND-209/N-11, AND-210, B2-K01, preservation of exact input flows, and stable table counts. No broader Android or VRT review and no device/tool reruns.

## Disposition

**ADDRESSED.** The corrected targeted evidence supports the active verdicts, B2-K01 is no longer graded, and no new breakage was found in this scope.

## Verification

### AND-075 — genuine failure leg added

`AND-075-rerun-failure/input/99-crash.yaml` is the genuine crash flow with `LANDMARKS_CRASH_ON_LAUNCH: "1"`. The preserved command runs it with `--logs`, explicit `emulator-5554`, `--no-build`, and its own report directory. Raw output records:

- FATAL EXCEPTION in the streamed log;
- `launchApp` failing with `app_crash`;
- flow exit 1 (`run-exit=1`);
- no output from the immediate post-run `ps ... grep '[a]db.*logcat'`, meaning no matching logcat process remained.

Combined with the previously reviewed success exit 0 and SIGINT exit 130 captures in `AND-075-rerun`, this closes the missing terminal path. The ledger now cites both directories and accurately describes all three paths.

### AND-202 — exact text-map input added

`AND-202-targeted/input/and-202-text-map.yaml` preserves the requested `tapOn: {text: "Lake Tahoe"}` without `exact`. The flow also runs the string form as a control. Both taps and their following Lake Tahoe assertions pass, with the exact step inputs preserved in the report log. This resolves the changed-input concern.

### AND-210 — required zero-tap initial and final states added

`AND-210-targeted-retry/input/and-210-double-first.yaml` enters Gesture Lab, first asserts `Taps: 0` and `Double taps: 0`, performs `doubleTapOn: {id: "gesture-pad"}`, then asserts `Double taps: 1` and `Taps: 0`. Every step passes in terminal and runner-log evidence. This matches the matrix criterion exactly and replaces the earlier input-variation limitation.

### AND-209 and N-11 — observable post-edge state added

`AND-209-targeted-retry/input/and-209-edge-land.yaml` performs the two exact edge point taps. After each, `assertVisible: "Gesture Lab"` passes and a separately named screenshot is captured (`edge-100`, `edge-0`). The report retains both PNGs and the runner log preserves the order. This supplies observable app-screen state after each accepted tap and closes the earlier evidence gap for AND-209 and the Android half of N-11.

### B2-K01 — premature verdict removed

There is no B2-K01 row in the current active Android table. Its absent absolute-coordinate, point-double/long, cross-platform-equality, and unit-test criteria are therefore no longer overgraded. This is the correct interim treatment.

### Exact inputs and counts — addressed

Each targeted retry now stores its source YAML under its evidence directory, resolving the input-provenance concern for these rows.

The stable footer says 120 recorded rows: 114 pass, 2 fail, 4 blocked, 0 n/a. Parsing the current table produces exactly the same totals. There is no count drift in this snapshot.

## Interim conclusion

All prior findings in the requested subset are resolved. This disposition covers only the corrected rows above and does not approve the unfinished Android slice or VRT work.
