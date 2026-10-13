# AND-137/138 output-mode triage

Verdict: both retained failures are literal matrix-expectation conflicts, not product defects. Preserve the fail rows until Task 6 updates the acceptance text.

All three invocations for each row used the same cwd, config, emulator, input, and output path, but they were three separate live executions. The only stdout differences are truthful per-execution measurements:

- AND-137: `screens[].steps[].duration` values.
- AND-138: top-level `duration`, `screens[].steps[].duration`, and `screens[].timestamp`.

After removing exactly those dynamic measurement fields, canonical sorted JSON for plain, quiet, and verbose has one identical SHA-256 per row:

- AND-137: `b6bf77b21b4f5a5bf08237dbd60d41bdfd991d69391368cda03f4b508fec1671`
- AND-138: `73a710064ee8a59518920355cb6469794474232e44ee03c0fa59dccf73ed8064`

No schema, status, action, screen, target, directory, path, size, compatibility alias, or error-content difference remains. Quiet stderr is empty on the successful cases. Verbose adds timestamped debug/subprocess detail only to stderr. The separately retained AND-137 quiet failure still prints its user-facing error while suppressing progress narration.

Exact-head source confirms these fields are intentionally dynamic rather than verbosity-dependent output mutations: `Sources/GrantivaCore/Diff/DiffResult.swift` defines measured `StepResult.duration`, capture `timestamp` defaulting to `Date()`, and `CaptureResult.duration`; `Sources/GrantivaCLI/DiffCommand.swift:214-215` supplies elapsed wall time. `OutputStreamContractTests.testQuietLeavesProgramOutputUntouched` and `testVerboseLeavesProgramOutputUntouched` use deterministic commands, so their byte-equality assertion does not imply independently executed device runs must reproduce timings.

Proposed Task 6 wording for both rows:

> Plain, `--quiet`, and `--verbose` preserve the same stdout result schema and semantic values. Compare parsed JSON after excluding documented per-execution measurements (`duration`, step durations, and capture timestamps). `--quiet` suppresses progress narration on stderr but retains warnings/errors; `--verbose` adds timestamped labels and subprocess/exit details on stderr only.

For non-JSON commands without dynamic result fields, byte-identical stdout can remain the rule. Requiring literal byte equality across separate live executions would require falsifying or suppressing legitimate measurements and is inconsistent with the documented result schema.
