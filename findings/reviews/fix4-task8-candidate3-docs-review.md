# Task 8 candidate 3 docs/output evidence review

**Specification verdict: APPROVED for the candidate-3 docs/output phase.** The retained evidence satisfies Task 8's documentation/output smoke: all 172 help pages were freshly enumerated from the frozen candidate, the 16 selected help-corpus and docs-contract tests passed with zero failures, normal and ambiguous doctor text/JSON agree, the ambiguous platform result remains an Advisory warning with exit 0, and every required public migration phrase is present. This verdict covers phase 06 only; provisioning and the remaining candidate-3 phases are outside this review.

**Evidence-quality verdict: APPROVED.** The raw commands, streams, results, generated files, hashes, source identity, isolated environment, and aggregate acceptance record agree. No unsupported pass claim or blocking discrepancy was found.

## Candidate and execution binding

- `acceptance.json` names candidate manifest SHA-256 `e9cfc7dce72ba8125b7c55df8d3dec355925003de24a4131c6510b9e67c51ebf`, which matches the current frozen manifest bytes and the independently approved freeze review.
- The manifest binds CLI merge `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`, version `2.1.0`, and QA binary SHA-256 `1b6a973b63a750691bcb76a710a97f346d331fe44ef60f6c50bef0f6d35e4731`. The current QA binary has that exact hash, and the source checkout remains at the manifest HEAD with clean status.
- The executed controller independently hashes the candidate binary before work. Every retained doctor/help command uses `/Users/kyle/.grantiva-qa/bin/grantiva`; records include argv, cwd, timestamps, exit, API-key-unset state, `fix4-8-c3`, and the scoped runner home.

## Help corpus and generated output

- `help/manifest.json` contains 172 rows, 172 unique command paths, and 172 unique filenames. Each generated help file exists and matches its recorded SHA-256.
- There are exactly 172 paired `help-commands/*/{start,result}.json` captures. Every result exits 0. The breadth-first parser handles comma-delimited aliases while recording only canonical subcommand names, and the required root, runner-start, run, and doctor pages are present.
- All 172 files copied to `findings/help/` match the phase manifest hashes; the destination contains exactly 172 `.txt` pages.

## Tests and isolated home

- `corpus-tests/start.json` and `result.json` agree on the exact command, source checkout, scratch path, start time, API-key-unset state, session, and fresh unit runner home. The command exited 0.
- Raw stdout reports `DocsContractTests` at 12/0 and `HelpCorpusTests` at 4/0, with the selected aggregate at 16 tests and zero failures. The later zero-test API target does not alter that count.
- The controller required the separate `corpus-test-home` to be empty before and after the run. The aggregate records `freshUnitHomeEmptyAfter: true`; read-only inspection also finds no child entry there. Build-time deprecation warnings in stderr are non-failing and do not contradict the test result.

## Doctor and migration contracts

- Normal text and JSON commands both exit 0 with empty stderr. The `Booted Simulator` JSON message appears verbatim in text and identifies the unowned-default condition while reporting the selected iPhone 17 Pro.
- The isolated ambiguous project contains both Xcode and Gradle markers and no Grantiva config. Its text and JSON commands both exit 0 with empty stderr. JSON records `Platform` in `Advisory`, status `warning`, the exact ambiguity message, and the `--platform ios|android` / `GRANTIVA_PLATFORM` remedy; the message appears verbatim in text.
- `docs-inspection.json` binds inspection to source `6ba12ed…` and records all required public compatibility terms: legacy baseline naming, percent encoding and ambiguous `%`, migration on approval, ISO 8601 with the epoch example, selector priority, and the lifecycle JSON keys `runnerSessionStopped`, `leftoverProcesses`, and `reapedProcesses`.

This was a read-only review of already captured evidence. I did not rerun tests, build, invoke the CLI, or perform device work.
