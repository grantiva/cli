# CLI-007 candidate5 clause assessment

Verdict: **PASS**.

Expected: Each exits 0; `simulator ensure` shows `--boot/--no-boot (default: --boot)`; `emulator teardown` shows `--serial`, `--all`, `--force`; `emulator delete` `--name`, `--force` (help: simulator_*.txt, emulator_*.txt)

Clause checks: [True, True, True, True]. Evidence commands: `CLI-007/emulator-cleanup.command.json`, `CLI-007/emulator-delete.command.json`, `CLI-007/emulator-ensure.command.json`, `CLI-007/emulator-sessions.command.json`, `CLI-007/emulator-teardown.command.json`, `CLI-007/simulator-cleanup.command.json`, `CLI-007/simulator-delete.command.json`, `CLI-007/simulator-ensure.command.json`, `CLI-007/simulator-sessions.command.json`, `CLI-007/simulator-teardown.command.json`.
