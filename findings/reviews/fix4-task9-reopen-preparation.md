# Task 9 reopened matrix fix review

**Verdict: APPROVED.** The missing L82 acceptance bullet 5 is now represented exactly and independently. The scoped comparison against `task9-reopen-fix-base` contains only that row, its criterion/index mapping, and the resulting count updates. No new defect was found.

`B4-L82.5` quotes the complete fifth acceptance bullet and requires focused/full fresh-home tests, independent review, CI, merge, exact rebuilt-candidate provenance, and continued blocking of clean Task 8/9 verdicts while the candidate leaks. `L82.acceptance.5` maps only to that row, and `rowIndex` identifies it as CLI/L82.

The corrected arithmetic is consistent: 1,305 logical rows, 1,480 expanded results, 135 B4 rows, 151 expanded B4 results, 116 brief criteria, and 19 controls. CLI increases by one to 425 total logical/results and 41 B4 logical/results; iOS, Android, and shared totals are unchanged. Candidate fields remain `UNKNOWN`, all result cells remain blank, and the Task 8 green-smoke execution gate remains intact.

This was a bounded static re-review. No device action, matrix execution, product edit, or test rerun was performed.
