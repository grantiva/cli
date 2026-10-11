# `runner dump-hierarchy --format bogus` is not rejected as a usage error

Severity: ux
Component: cli
Platforms: both
Rows: CLI-140 (cli)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
`--format bogus` is a usage error naming `tree`, `json`, `xml`, exit 64, before any session lookup (matrix CLI-140;
docs/dump-hierarchy.md:51; the option's help: "Output format: tree, json, or xml").

## Actual
findings/evidence/cov-cli/CLI-140/bogus.err, exit 1:
```
Error: Invalid argument: No active runner session. Start one with 'grantiva runner start' or `grantiva run --keep-alive`, or pass --port.
```
The format is never checked when no session exists; with a session it is checked only after attaching to the driver.
The `--json --format tree` conflict is a proper usage error (jsontree.err, exit 64).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"
cd /tmp && grantiva runner dump-hierarchy --format bogus; echo "exit $?"
grantiva runner dump-hierarchy --json --format tree; echo "exit $?"
grantiva runner dump-hierarchy --format XML; echo "exit $?"     # case: accepted today (lowercased), keep accepting it
```

## Evidence
- findings/evidence/cov-cli/CLI-140/commands.txt, bogus.err, jsontree.err

## Suspected cause
- Sources/GrantivaCLI/DriverCommand.swift:702-703: `--format` is a `String?`, not an enum.
- DriverCommand.swift:715-720 (`validate`): checks only the `--json` conflict.
- The value is rejected only in `dump` / `render` (DriverCommand.swift:830, :844), after `resolveTarget` (:740-747)
  has already failed or attached.

## Acceptance criteria
- `grantiva runner dump-hierarchy --format bogus`: exit 64, usage error naming `tree`, `json`, `xml`, with or without a
  session; no session lookup happens.
- `--format XML`/`Tree` still work (case-insensitive), or the help says lowercase only.
- Prefer a `CaseIterable` `ExpressibleByArgument` enum (see K40) so ArgumentParser lists the choices.
- GrantivaCLITests/DumpHierarchyCommandTests: `DumpHierarchyCommand.parse(["--format", "bogus"])` throws a
  validation error naming the three values.
