# Bring README §Commands in line with help: add emulator, console, and runner dump-hierarchy; fix the cleanup wording; add delete/sessions abstracts; drop the iOS-only wording

Severity: docs
Platforms: cli
Found by: CLI-DOCS-F03, CLI-DOCS-F05, CLI-DOCS-F06 (matrix rows CLI-111, CLI-113, CLI-114, CLI-003)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
README §Commands covers every top-level command and subcommand, and agrees with help. Source: README §Commands
(README.md:261-287); help: grantiva, runner, simulator.

## Actual
- README has no line for `emulator` ("Provision, inspect, and tear down Android emulators."), `console`, or
  `runner dump-hierarchy`, all in help.
- README: `grantiva record  Record a simulator ...` and `grantiva build  Build the app via xcodebuild for a simulator`;
  help: "Record a simulator or emulator ...", and README.md:7 says `build` works on Android.
- `simulator cleanup`: README "Delete unavailable and stale Grantiva-managed simulators"; help "Delete Grantiva-created
  simulators that are shut down and not part of an active session." (SIMULATOR-LIFECYCLE.md agrees with help).
- `grantiva simulator --help` shows empty descriptions:
  ```
    delete
    sessions
  ```
  and their own `--help` pages have no OVERVIEW line.

## Repro
```
sed -n 261,287p README.md
grantiva --help; grantiva runner --help; grantiva simulator --help; grantiva simulator cleanup --help
```

## Evidence
- help/grantiva.txt (SUBCOMMANDS), help/runner.txt, help/record.txt:1, help/simulator.txt:14-15,
  help/simulator_delete.txt:1, help/simulator_sessions.txt:1, help/simulator_cleanup.txt:1-2 (qa-cli worktree root)
- README.md:263-288; SIMULATOR-LIFECYCLE.md:21

## Suspected cause
README not updated with the Android/console work. Sources/GrantivaCLI/SimulatorCommand.swift:69 (`Delete`) and :80
(`Sessions`) have no `static let configuration` with an `abstract`.

## Acceptance criteria
- README §Commands lists `emulator ensure|delete|sessions|teardown`, `console` (pointing at `grantiva console --help`),
  and `runner dump-hierarchy`; `run`/`record`/`build` lines say "simulator or emulator".
- `simulator cleanup` wording matches help.
- `Delete` and `Sessions` get abstracts "Explicitly delete a named simulator." and "List Grantiva-managed simulator
  capacity slots."; GrantivaCLITests/SimulatorCommandTests asserts every simulator subcommand has a non-empty abstract.
