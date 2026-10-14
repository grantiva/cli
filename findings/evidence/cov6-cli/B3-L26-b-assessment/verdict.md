# B3-L26-b candidate5 clause assessment

Verdict: **PASS**.

Expected: Each exits 64 and prints `Error: --device and --emulator are mutually exclusive; pass one.` followed by the command's `Usage:` and `See … --help` lines; no `Invalid argument:`; the empty dir gives the same (the check runs before any config load or device resolution) (brief L26-b)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B3-L26-b-run-1/capture.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `capture.stdout`, `capture.stderr` retained.
- `B3-L26-b-run-1/install.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `install.stdout`, `install.stderr` retained.
- `B3-L26-b-run-1/record.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `record.stdout`, `record.stderr` retained.
- `B3-L26-b-run-1/run.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `run.stdout`, `run.stderr` retained.
- `B3-L26-b-run-1/start.command.json`: exit 64, timedOut=false, cleanupFailed=false; raw `start.stdout`, `start.stderr` retained.
