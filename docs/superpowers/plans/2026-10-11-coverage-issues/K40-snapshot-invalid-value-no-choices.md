# `run --snapshot bogus` does not list the valid values

Severity: ux
Component: cli
Platforms: n/a (argument parsing)
Rows: CLI-055 (cli)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
A usage error naming `failure`, `trailing`, `full`, exit 64 (matrix CLI-055; help: run.txt), like the other enum
options, which say `Please provide one of ...` (`--platform`, `--logs-level`).

## Actual
findings/evidence/cov-cli/CLI-055/snap.err, exit 64:
```
Error: The value 'bogus' is invalid for '--snapshot <snapshot>'
Help:  --snapshot <snapshot>  Snapshot policy: failure (default — one shot after failure), trailing (last-good step + failure step), full (every step).
Usage: grantiva run <options>
```
The values appear only inside the echoed help sentence.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"
rm -rf /tmp/k40 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k40 && cd /tmp/k40/ios
grantiva run --snapshot bogus; echo "exit $?"
grantiva run --platform bogus; echo "exit $?"          # for comparison: lists ios, android
grantiva hierarchy --format bogus; echo "exit $?"      # same enum shape, check it too
```

## Evidence
- findings/evidence/cov-cli/CLI-055/commands.txt, snap.err

## Suspected cause
- Sources/GrantivaCLI/RunCommand.swift:39-43: `enum SnapshotMode: String, ExpressibleByArgument` lacks `CaseIterable`,
  so ArgumentParser has no `allValueStrings` to list. `Platform` and `LogStreamLevel` are `CaseIterable`
  (Sources/GrantivaCore/Platform/Platform.swift:3, Sources/GrantivaCore/Platform/DevicePlatform.swift:45), which is why
  their errors list the choices.
- Same shape: Sources/GrantivaCLI/HierarchyCommand.swift:51-54 (`OutputFormat`, no `CaseIterable`).

## Acceptance criteria
- `grantiva run --snapshot bogus`: exit 64 and the error line names `failure`, `trailing`, `full` (ArgumentParser's
  `Please provide one of 'failure', 'trailing' or 'full'.` or equivalent).
- Every `ExpressibleByArgument` enum in Sources/GrantivaCLI is `CaseIterable` (grep check), so `hierarchy --format bogus`
  also lists `xml`, `json`.
- GrantivaCLITests/RunCommandTests: parsing `--snapshot bogus` throws an error whose message contains all three values;
  GrantivaCLITests/HierarchyCommandTests the same for `--format`.
