# CLI-077 candidate5 clause assessment

Verdict: **PASS**.

Expected: Usage error, exit 64 (help: init.txt has no `--json`)

Fresh candidate5 commands retain exact identity, argv, cwd, exit and raw streams. Explicit review confirms the init/doctor/help/Maestro parser behavior reaches the required result before any compiler or live-device action. Evidence: `CLI-077-run-1/init.command.json`.
