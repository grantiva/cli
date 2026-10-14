# CLI-065 candidate5 clause assessment

Verdict: **PASS**.

Expected: Rejected before the run: `grantiva.yml:5: unsupported Maestro command 'back'` (file and line, no enum text) (README:172; brief C07)

Fresh candidate5 commands retain exact identity, argv, cwd, exit and raw streams. Explicit review confirms the init/doctor/help/Maestro parser behavior reaches the required result before any compiler or live-device action. Evidence: `CLI-065-run-1/unsupported.command.json`.
