# B2-K19 Android triage and JSON grade review

Scope: retained `output-contracts-exact-rerun1` evidence and candidate source at `8f2cff67`; no live/device operations.

## B2-K19 classification: expectation conflict, not a product defect

The recorded failure is real output, but it does not violate the candidate's established flag-precedence contract.

`JSON-fail/commands.txt` runs:

```text
grantiva run ... --json --quiet --verbose ...
```

It exits 1 with a valid single JSON document. Its 18,846-byte stderr contains debug subprocess lines and runner narration. That is exactly what the candidate deliberately implements when `--verbose` is present:

- `Sources/GrantivaCore/Output/LogVerbosity.swift:15-20` explicitly says and implements that `--verbose` wins over `--quiet`.
- `Sources/GrantivaCore/Runner/RunnerNarration.swift:26-30` repeats the same precedence and computes `(json || quiet) && !verbose`.
- `Sources/GrantivaCLI/Options.swift:37-43` applies those three flags through that function before runner execution.
- The matrix's own B2-K19 acceptance text says “`--verbose` still shows the runner output.”

The row's input column includes `--quiet --verbose`, but the acceptance bullets never say quiet wins that conflict. The Android ledger's statement “quiet therefore did not win over verbose as required” contradicts both binding acceptance prose and exact-head semantics. This should not become L69 or another product defect.

Recommended Task 6 correction: state explicitly that `--verbose` wins over `--quiet`, including with `--json`; grade the combined-flags capture as precedence evidence. Preserve the existing raw output and failed verdict until that correction is reviewed.

The capture does **not** establish all of B2-K19. `AND-137-quiet-fail/stderr.log` proves quiet-only failure output is reduced to the useful failure/Error lines, and `JSON-fail/stdout.log` proves the structured error names the exact flow/step/message. The current group does not separately capture `--json` alone and `--json --quiet` without verbose for run, nor the required diff-capture and ci-run quiet/JSON variants. Those remain evidence gaps, not defects.

## Scoped grade review

### AND-031 — supported

`AND-031/commands.txt` uses the preserved empty Android config, `--report-dir`, and `--ready-file` without a device selector. It exits 1 immediately; stderr contains only `No screens or flows configured in grantiva-android.yml`. `ready.json` is terminal `failed`, has no flows, names the error, and retains the requested absolute report path. This satisfies the pre-device failure contract.

### B2-K21-a [android] — Android runtime half supported

`JSON-pass/stdout.log` and `JSON-fail/stdout.log` both retain the requested absolute `reportDir`; success omits `error`, failure includes it. Candidate semantic coverage exists in `Tests/GrantivaCLITests/RunSessionContractTests.swift:208-217` and `JSONKeyCasingContractTests.swift:220-222`, covering pass/fail report-dir presence and absence without a report dir. The Android suffix is important: the matrix row is both-platform, so this capture cannot close the unsuffixed row alone.

### B2-K21-b [android] — Android runtime half supported

The pass and fail JSON documents both use one `screens` entry of `kind: flow` with the same keys: `kind`, `name`, `passed`, `screenshots`, and `steps`. Both carry real runner commands; failure adds the failed-step message and success carries named screenshots without changing entry kind. `Tests/GrantivaCLITests/RunSessionContractTests.swift:221-237` asserts the common key set and screenshot placement. Again, this supports the Android half; the binding row also requires iOS parity and the documented examples.

## Defect-brief recommendation

Do **not** draft L69 from this capture. If the campaign nevertheless chooses to change precedence so quiet wins, that is a new product/UX decision requiring updates to `LogVerbosity`, `RunnerNarration`, help/docs, and tests; it is not a regression proven against the current B2-K19 acceptance contract.
