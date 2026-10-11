# `simulator teardown` usage errors carry the "Invalid argument:" runtime-error prefix

Severity: ux
Component: cli
Platforms: ios
Rows: CLI-058 (cli); same shape in CLI-059 (cli, passed row)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Usage errors (exit 64, followed by the usage line) read `Error: <message>` like the other teardown usage errors
(CLI-060 `Error: --session-id and --udid are mutually exclusive; pass one.`, CLI-062 `Error: Pass --session-id <id> or
--udid <UDID>.`). `Invalid argument:` is the `GrantivaError.invalidArgument` prefix used for exit-1 failures.

## Actual
findings/evidence/cov-cli/CLI-058/empty_udid.err (exit 64):
```
Error: Invalid argument: --udid is empty. Pass a simulator UDID — if this came from a shell variable, it was unset.
Usage: grantiva simulator teardown [--json] [--verbose] [--quiet] [--session-id <session-id>] [--udid <udid>] [--force]
```
Same prefix for `--udid not-a-udid-at-all` and `--session-id ""` (findings/evidence/cov-cli/CLI-059/bad_udid.err,
empty_session.err).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=fix-k42
grantiva simulator teardown --udid "" --force; echo "exit $?"
grantiva simulator teardown --udid not-a-udid-at-all --force; echo "exit $?"
grantiva simulator teardown --session-id ""; echo "exit $?"
grantiva simulator teardown --udid 00000000-0000-0000-0000-0000000000C1 --session-id x; echo "exit $?"   # plain "Error:"
```
No device is touched; all four exit 64 before any work.

## Evidence
- findings/evidence/cov-cli/CLI-058/commands.txt, empty_udid.err
- findings/evidence/cov-cli/CLI-059/commands.txt, bad_udid.err, empty_session.err
- findings/evidence/cov-cli/CLI-060/both.err, findings/evidence/cov-cli/CLI-062/neither.err (the plain form)

## Suspected cause
- Sources/GrantivaCLI/SimulatorCommand.swift:128-134 (`Teardown.validate`): catches the `GrantivaError` thrown by
  `SimulatorUDID.validate` / `validateSessionID` and wraps `error.errorDescription` in `ValidationError`; that
  description is already `"Invalid argument: " + message` (Sources/GrantivaCore/GrantivaError.swift:51-52).
  (The cluster map's SimulatorCommand.swift:164 is a different, exit-1 error.)
- Other `validate()` methods call `DeviceID.validate` without converting (HierarchyCommand.swift:60,
  DriverCommand.swift:716, EmulatorCommand.swift:152): check they report the same shape and exit code.

## Acceptance criteria
- The three repro commands print `Error: --udid is empty. ...`, `Error: --udid not-a-udid-at-all is not a simulator
  UDID. ...`, `Error: --session-id is empty. ...` with exit 64 and the usage line; no `Invalid argument:`.
- `hierarchy --udid ""` and `runner dump-hierarchy --udid ""` give the same shape (exit 64, no prefix), or are listed
  as intended exceptions.
- GrantivaCLITests/SimulatorCommandTests: `Teardown.parse(["--udid", "", "--force"])` throws a `ValidationError` whose
  message starts with `--udid is empty`.
