# B3-L27 candidate5 clause assessment

Verdict: **PASS**.

Expected: Every printed path (text and `--json`) is the realpath `/private/tmp/…/rh/…` form, on the run that extracts and on later runs, for relative and absolute homes, in doctor and `runner version --json` where they print it, and in the bundle warning. The default-home half is not run (Global Constraint: never write under `~/.grantiva/runner`); RunnerManager tests cover it (source check) (brief L27)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B3-L27-run-1/absolute-version.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `absolute-version.stdout`, `absolute-version.stderr` retained.
- `B3-L27-run-1/relative-first.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `relative-first.stdout`, `relative-first.stderr` retained.
- `B3-L27-run-1/relative-json.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `relative-json.stdout`, `relative-json.stderr` retained.
- `B3-L27-run-1/relative-second.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `relative-second.stdout`, `relative-second.stderr` retained.
