# Task 7 Step 1 — report and trace compatibility

## Result

The CLI now decodes the runner's structured command artifacts, including `logTail` and the nested `notes` map, without dropping commands or failure details. Trace export copies only log-tail files explicitly referenced by the attributed flow report. Top-level and nested-command filenames are preserved, and the copied bytes remain available after the ephemeral report directory is removed.

Existing flow attribution, report path containment, symlink containment, duplicate destination handling, PNG/XML trace behavior, report rewriting, and finalization remain in place.

## Production fixture

`TestFixtures/GrantivaCore/failure-artifacts/` is shaped from the live round-4 crash report: a failed command contains screenshot, hierarchy, and log-tail paths plus a structured artifact-note map. The contract test verifies command decoding, step/failure rendering, and preservation through generic rewrite/finalization.

The trace fixture adds both top-level (`cmd-002-log-tail.txt`) and nested (`nested-007-log-tail.txt`) references, byte content that cannot round-trip through a text conversion, an unreferenced log file, and a traversal reference.

## Verification

- Semantic RED: `findings/evidence/fix4-7/compat/semantic-red.log` runs the production-shaped decode assertion against untouched base `03cee568`; the old decoder returns zero commands and no failure detail.
- Compile-contract RED: `findings/evidence/fix4-7/compat/focused-red.log` also records the old `[String: String]` API rejecting the structured artifact fields.
- Focused GREEN: `findings/evidence/fix4-7/compat/focused-green.log` — 2 tests, 0 failures.
- Report/session/trace GREEN: `findings/evidence/fix4-7/compat/report-trace-green.log` — 29 tests, 0 failures.
- Production fixture GREEN: `findings/evidence/fix4-7/compat/fixture-green.log` — 1 test, 0 failures.

Every test command used a new empty `GRANTIVA_RUNNER_HOME`, unset API credentials, and made no device, runner bundle, version, or default-home changes.

## Deferred scope

Runner version selection, runner build, WDA cache generation, bundle replacement, stamp updates, packaging tests, PR work, and release work remain deferred to Task 7 Step 2 and later authorization.
