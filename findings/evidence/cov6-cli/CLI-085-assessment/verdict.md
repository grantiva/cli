# CLI-085 candidate5 clause assessment

Verdict: **PASS**.

Expected: Prints `grantiva-runner 1.1.28-grantiva.11` (the runner bundled with c65fc17, #199; the literal follows the bundled runner); exit 0 (help: runner_version.txt) (corrected round 3)

Fresh candidate5 commands retain exact identity, argv, cwd, exit and raw streams. Explicit review confirms the init/doctor/help/Maestro parser behavior reaches the required result before any compiler or live-device action. Evidence: `CLI-085-run-1/version.command.json`.
