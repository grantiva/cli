# CLI-087 candidate5 clause assessment

Verdict: **PASS**.

Expected: `Error: No active runner session. Start one with `grantiva runner start` or `grantiva run --keep-alive`, or pass --port.`, exit 1, stdout empty (both commands in backticks, no `Invalid argument:` label: K46; docs/dump-hierarchy.md:57; src DriverCommand.swift:736) (corrected round 3)

Fresh current-candidate raw confirms the required validation/result before compiler or live-device work. Evidence: `CLI-087-run-1/dump.command.json`.
