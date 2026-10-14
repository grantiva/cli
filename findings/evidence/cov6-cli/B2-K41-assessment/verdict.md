# B2-K41 candidate5 clause assessment

Verdict: **PASS**.

Expected: `grantiva run --timeout -1`: exit 64 with `--timeout must be at least 30 seconds.` (same as `--timeout=-1` and `--timeout 5`), and `--ready-file` given with it is written with `"status": "failed"` and that `error`. • `grantiva hierarchy --timeout -1` and `grantiva record --duration -1`: exit 64 with their own range message. • GrantivaCLITests/RunCommandTests: `RunCommand.parse(["--timeout", "-1"])` (or `parseAsRoot`) yields the range error, not "Missing value". (brief K41 Acceptance criteria; Platforms: n/a)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B2-K41-run-1/equals.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `equals.stdout`, `equals.stderr` retained.
- `B2-K41-run-1/hierarchy.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `hierarchy.stdout`, `hierarchy.stderr` retained.
- `B2-K41-run-1/ready.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `ready.stdout`, `ready.stderr` retained.
- `B2-K41-run-1/record.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `record.stdout`, `record.stderr` retained.
- `B2-K41-run-1/space.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `space.stdout`, `space.stderr` retained.
