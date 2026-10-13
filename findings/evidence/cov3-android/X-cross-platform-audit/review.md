# X-001 / X-003 current-corpus addendum

This addendum broadens the prior comparison from `AND-106` to the matching current-round Android single-flow capture `AND-043-exact-rerun1/runs/01-browse`. That exact-input corpus closes both rows. It supersedes only the X-001 and X-003 conclusions in `x001-x003-x004-cross-platform-comparison.md`; X-004 remains incomplete.

## X-001 — supported

Exact inputs:

- iOS: `cov3-ios-attempt10/pass-plain.out`, `pass-plain.err`, command recorded by attempt10 as passing `.maestro/01-browse.yaml`.
- Android: `cov3-android/AND-043-exact-rerun1/runs/01-browse/commands.txt`, `stdout.log`, `stderr.log`; the command explicitly passes `--flow .maestro/01-browse.yaml` and exits 0.

The platform outputs have the required common narration structure:

- `Resolved:` reports zero screens and one flow.
- Both announce one shared runner session for `.maestro/01-browse.yaml`.
- Both print the same eight ordered step actions and the same two named screenshots.
- Both print `Flows: 1 total, 1 passed, 0 failed` and an eight-step passing summary/table.
- Platform-specific device text differs as expected: iOS names the owned simulator/GrantivaAgent setup, while Android names `emulator-5554`, `cov3-android`, UIAutomator2, and the Android device. The complete Android stdout/stderr does not contain `GrantivaAgent`.

The runner's platform-specific connection/setup narration and timing values differ, but the matrix's named narration fields and structure align. **X-001 can be graded pass** from these exact current-round paths.

## X-003 — supported

Exact passing report directories:

- iOS: `cov3-ios-attempt10/pass-report/`
- Android: `cov3-android/AND-043-exact-rerun1/runs/01-browse/report/`

Both directories retain the required files by the same names:

- `report.json`
- `flows/flow-000.json`
- `junit-report.xml`

Normalized `report.json` JSON paths are identical across the two captures, including device/app/runner objects, flow summaries, statistics, timestamps, status, and version fields. Values that properly vary by platform, device, and timing do not alter the schema.

Both `flows/flow-000.json` files identify `01-browse` and preserve `sourceFile` exactly as passed: `.maestro/01-browse.yaml`. The iOS flow record additionally carries an element `class` field on resolved iOS elements; X-003 requires the same top-level report schema, report filenames, and preserved flow paths, not byte-identical platform-specific element metadata.

Both JUnit files are retained under the exact name `junit-report.xml`, begin with the same `testsuites` / `testsuite name="maestro-runner"` structure, and represent one passing test. **X-003 can be graded pass** from these exact current-round paths.

## Unchanged X-004 conclusion

The corpus expansion does not add an iOS interrupted ready file. X-004 still lacks the required iOS `interrupted` state and remains ungraded.
