# `--quiet` and `--json` do not silence the runner: its banner, every step, the summary and report paths still print on stderr

Severity: contract
Component: cli
Platforms: both (Android AND-137/138; iOS IOS-074, IOS-152, IOS-153)
Rows: AND-137, AND-138 (android); IOS-074, IOS-152, IOS-153 (ios). The `--verbose` half of IOS-152/IOS-153 (runner launch and `log stream` never logged) is in K33.
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
README:391-393: "`--quiet` — silences progress narration. Warnings and errors still print". README:395: "`--json`
already suppresses narration on its own". Matrix rows AND-137/138 and IOS-152/153: with `--quiet` no progress
narration on stderr; `Warning:`/`Error:` lines (and a failing run's failure) still print. A JSON consumer's `error`
field must be self-contained (IOS-074).

## Actual
Only grantiva's own narration is silenced; the runner's relayed output is not. Line counts on stderr:
| row | plain | `--quiet` | notes |
|---|---|---|---|
| AND-137 `run --flow 01-browse` | 76 | 68 | `--json --quiet` also 68 (r137-jq.err) |
| AND-138 `diff capture --json` | 94 | 94 | `--quiet` silences nothing |
| IOS-152 `run --flow 01-browse --json` | 71 | 71 | also without `--json` (quiet-nojson.err: 71) |
| IOS-153 `diff capture --json` | 97 | 97 | |

`diff capture --json --quiet` stderr begins (AND-138/c138-quiet.err:1-12):
```

  grantiva-runner 1.1.28-grantiva.9 - by Grantiva
  Fast, lightweight UI test runner


Setup
────────────────────────────────────────
  ✓ Found 1 test flow(s)
  ✓ Report directory: /var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-report-43B7FE0C-...

Execution
────────────────────────────────────────
```
and continues through every step, the summary table and the `Reports:`/`Paths:` block (K18).
IOS-074: the failing `run --json` document's `error` is `"Runner failed (exit 1); see the runner output above."`,
pointing a `--json` consumer at text that `--json` is documented to suppress.

## Repro
iOS:
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k19
unset GRANTIVA_API_KEY
rm -rf /tmp/k19 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k19 && cd /tmp/k19/ios
UDID=$(grantiva simulator ensure --name "fix-k19 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
for m in "" "--quiet" "--json" "--json --quiet"; do
  grantiva run --simulator "$UDID" --no-build --flow .maestro/01-browse.yaml $m > /tmp/k19/out.txt 2> /tmp/k19/err.txt
  echo "[$m] stderr lines: $(wc -l < /tmp/k19/err.txt)  runner banner: $(grep -c 'grantiva-runner .* by Grantiva' /tmp/k19/err.txt)"
done
grantiva run --simulator "$UDID" --no-build --flow .maestro/coverage/02-exact-negative.yaml --json 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin)['error'])"
grantiva diff capture --simulator "$UDID" --no-build --json --quiet 2>&1 >/dev/null | head -12
grantiva simulator teardown --udid "$UDID"; grantiva simulator delete --name "fix-k19 iPhone 17"
```
Android: Android prelude (see K01) and the same commands with `--device "$SERIAL"`.

## Evidence
- findings/evidence/cov-android/AND-137/r137-plain.err, r137-quiet.err, r137-jq.err, r137-fail.err, r137-verbose.err, commands.txt
- findings/evidence/cov-android/AND-138/c138-plain.err, c138-quiet.err, c138-verbose.err, c138-*.json, commands.txt
- findings/evidence/cov-ios/IOS-152/plain.err, quiet.err, quiet-nojson.err, quiet-fail.err; IOS-153/plain.err, quiet.err
- findings/evidence/cov-ios/IOS-074/json-fail.out (the `error` text), json-fail.err (65 runner lines under `--json`)

## Suspected cause
- `Sources/GrantivaCore/Runner/RunnerExecution.swift:111-129`: the runner's stdout is relayed line by line to
  `FileHandle.standardError` (:121, :126) unconditionally; `RunnerExecution.Request` carries no quiet/json flag, and
  `GlobalOptions.note` (Sources/GrantivaCLI/Options.swift:32-35), which implements `--quiet`/`--json` for grantiva's own
  lines, never sees this stream.
- The `error` text comes from `RunnerSession.failureMessage` (Sources/GrantivaCore/Runner/RunnerSession.swift:17-22):
  with empty captured stderr it appends `; see the runner output above.` regardless of output mode.

## Acceptance criteria
- With `--quiet` (with or without `--json`) and with `--json` alone, stderr carries no runner banner, Setup/Execution
  headers, per-step lines, summary table or report paths for `run`, `diff capture` and `ci run`.
- A failing run under `--quiet` still prints the failing step and its message (one or a few lines) and grantiva's
  `Error:` line; under `--json` the document's `error` names the failed step and message (e.g.
  `02-exact-negative: assertVisible text="Golden Gate.*" exact=true: Element not visible ...`) and never says "see the
  runner output above".
- Plain mode (no flags) is unchanged; `--verbose` still shows the runner output.
- stdout stays byte-identical across plain/`--quiet`/`--verbose` (already true).
- GrantivaCoreTests (RunnerExecutionTests): with a quiet request, a fake runner's stdout is not written to stderr; with
  a normal request it is. GrantivaCLITests (OutputStreamContractTests): `--json` failure `error` contains the step
  message.
