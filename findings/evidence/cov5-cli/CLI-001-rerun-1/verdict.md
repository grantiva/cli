# CLI-001 cov5 clause assessment

Verdict: **pass**.

Current evidence was freshly executed against candidate4 manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`; each command has adjacent identity and exit capture. The following observations are from this directory’s current stdout/stderr and command records:
- `help.command.json` records exit 0. `help.stdout` contains the exact overview sentence, and names all 14 required subcommands: build, run, record, simulator, emulator, hierarchy, ci, diff, auth, console, doctor, runner, init, and mcp. `help.stderr` is empty.
- `version.command.json` records exit 0. `version.stdout` is exactly `2.1.0` plus its line ending. `version.stderr` is empty.

No device command or default-device resolution is involved in this row.
