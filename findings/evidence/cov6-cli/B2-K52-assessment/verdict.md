# B2-K52 candidate5 clause assessment

Verdict: **PASS**.

Expected: With no config and no `.maestro/`, `run` (with and without `--no-build`) and `diff capture` print the same sentence, from `GrantivaConfig.missingFileMessage` (path and init command, `--platform android` on Android), with the same prefix (no `Invalid argument:` on one only); exit 1; no boot. • The missing-config check runs before scheme resolution in `run`; a project that has a config but several schemes still gets the scheme error. • An empty `.maestro/` still gives `No flow files found in <dir>/.maestro` for both commands. • GrantivaCLITests/RunCommandTests: run in a temp Xcode project with two schemes and no config throws the missing-config message; DiffCommandTests: capture gives the identical string. (brief K52 Acceptance criteria; Platforms: both)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B2-K52-run-1/capture-empty-maestro.command.json`: exit 1, timedOut=false, cleanupFailed=false; raw `capture-empty-maestro.stdout`, `capture-empty-maestro.stderr` retained.
- `B2-K52-run-1/capture.command.json`: exit 1, timedOut=false, cleanupFailed=false; raw `capture.stdout`, `capture.stderr` retained.
- `B2-K52-run-1/run-empty-maestro.command.json`: exit 1, timedOut=false, cleanupFailed=false; raw `run-empty-maestro.stdout`, `run-empty-maestro.stderr` retained.
- `B2-K52-run-1/run-no-build.command.json`: exit 1, timedOut=false, cleanupFailed=false; raw `run-no-build.stdout`, `run-no-build.stderr` retained.
- `B2-K52-run-1/run.command.json`: exit 1, timedOut=false, cleanupFailed=false; raw `run.stdout`, `run.stderr` retained.
