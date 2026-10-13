# Task 6 CI fix 1 independent review

Review range: `bc10deb87fd687d7449866376f671888ee148548..ce23e52b892b446f913e82f1d3d4d07db710e765`

## Verdicts

- **Source/specification: PASS.** The fix preserves production behavior and makes the binding iPhone 18 fixture deterministic across Xcode device catalogs.
- **Quality: PASS.** The seam is package-internal, defaults to the real production value, and is threaded through both the booted and no-booted branches. The added tests are narrow and portable.
- **Evidence/reporting: NEEDS ONE MINOR CORRECTION.** The new `semantic-red.log` is a compile-red/API-shape failure, not a semantic test failure. Correct the report label/description before final evidence acceptance. The original CI log remains valid semantic failure provenance. New CI run 38422710253 was queued and remains an external gate.

## Finding

1. **Minor — classify the fix-1 red accurately.** `task-6-report.md` calls `ci-fix1/semantic-red.log` a semantic red. The log never runs `DoctorTests`: Swift compilation fails on `extra argument 'defaultName' in call` because the revised tests were run before the production signature accepted the seam. The follow-on type-inference diagnostics are consequences of that missing argument. Rename/relabel this evidence as compile red (or API-shape red) and state that it proves the new test seam did not exist at the parent commit; do not claim it independently demonstrates wrong runtime behavior. The archived original CI run is the behavioral/semantic red: it executes 2,009 tests and records eight assertions failing because ambient `DefaultSimulator.name` resolved to iPhone 17 Pro while the fixture expected iPhone 18 Pro.

## Source and contract review

- The new `defaultName` parameter is internal because `checkBootedSimulator` itself is internal. No public command, flag, MCP tool, JSON key, or public Swift API changes.
- Its default expression is `DefaultSimulator.name`, so `runAllChecks` and every production caller continue to resolve the actual catalog-derived default. The source search shows the production call remains `checkBootedSimulator()` with no override.
- The injected value is used consistently in the booted ownership lookup and passed to `noBootedSimulatorCheck` when no device is booted. This avoids a split contract between the two branches.
- The binding fixture explicitly pins `iPhone 18 Pro` for both list orders, the absent-default control, and the Grantiva-owned default control. Status `.ok`, Advisory section, booted-device identity, formatter output, decoded JSON, and the exact ownership note remain covered.
- The sibling test exercises both supported catalog outcomes, iPhone 17 Pro and iPhone 18 Pro, through the full `checkBootedSimulator` entry. It confirms the seam changes only which name is treated as the default.
- Existing production-default tests still call the method without `defaultName`, which protects the default argument rather than testing only injected behavior.

## Evidence review

- The archived CI log is byte-preserved at SHA-256 `1b5083f77242e835677d1eeb05b9427c5226edfd6c156d4cc083c553c82a6877`, matching the report. It records the full suite executing 2,009 tests with eight failures; this remains truthful provenance for the portability defect.
- `focused-green.log` records 36 passing Doctor tests after the fix, and its isolated runner-home inventory is empty.
- `full-fresh-home.log` records the CI-equivalent fresh-home suite passing and ends with `Runner home stayed empty.` Both recorded exit files are 0; the compile-red exit is 1.
- The report records `GRANTIVA_API_KEY` unset and `GRANTIVA_SESSION_ID=fix4-6`. No device execution or owner-device mutation is part of this fix.

No broader source defect was found. Do not merge until the queued CI run succeeds and the evidence label is corrected.

## Addendum: evidence finding resolved

The corrected `task-6-report.md` now accurately labels `semantic-red.log` as a compile/API-contract red with no tests executed and limits its claim to proving the seam was absent at the parent commit. It separately identifies the original macOS 15 CI log as the behavioral red with eight runtime assertion failures. The unchanged green evidence is reported as 36 focused Doctor tests and 2,010 passing CI-equivalent fresh-home tests (281 MCP, 967 Core, 661 CLI, 101 API), with the runner home empty.

**Final scoped verdict: APPROVED for source, specification, quality, and evidence.** The only remaining gate is queued CI run 38422710253; this review does not authorize merge before that CI succeeds.
