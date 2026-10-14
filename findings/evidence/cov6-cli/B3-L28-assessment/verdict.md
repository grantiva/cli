# B3-L28 candidate5 clause assessment

Verdict: **PASS**.

Expected: Exit 0 and one `Warning:` line on stderr: `The grantiva_GrantivaCore.bundle resource bundle was not found next to the grantiva executable. The installed runner (<dir>) was left as it is, but a fresh install (a new runner home or another grantiva version) would fail. Reinstall grantiva, or keep the bundle beside the binary when copying it.`; `--json` is one document on stdout with the warning on stderr; the fresh-home install fails (exit 1) naming the bundle. • RunnerManagerTests `bundleMismatchWarning(bundle: nil, …)` exists (source check) (brief L28; ruling L28; README GRANTIVA_RUNNER_HOME row)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B3-L28-run-1/copy-current-json.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `copy-current-json.stdout`, `copy-current-json.stderr` retained.
- `B3-L28-run-1/copy-current.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `copy-current.stdout`, `copy-current.stderr` retained.
- `B3-L28-run-1/copy-fresh.command.json`: exit 1, timedOut=false, cleanupFailed=false; raw `copy-fresh.stdout`, `copy-fresh.stderr` retained.
- `B3-L28-run-1/seed-current.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `seed-current.stdout`, `seed-current.stderr` retained.
