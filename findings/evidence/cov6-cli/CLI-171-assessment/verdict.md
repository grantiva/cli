# CLI-171 candidate5 clause assessment

Verdict: **PASS**.

Expected: Usage error, exit 64: `mcp` has neither flag (help: mcp.txt lists only `--project-dir`, `--platform`)

Fresh candidate5 commands retain exact identity, argv, cwd, exit and raw streams. Explicit review confirms the init/doctor/help/Maestro parser behavior reaches the required result before any compiler or live-device action. Evidence: `CLI-171-run-1/verbose.command.json`, `CLI-171-run-1/quiet.command.json`.
