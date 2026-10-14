# CLI-008 candidate5 clause assessment

Verdict: **FAIL**.

Expected: Each exits 0; `dump-hierarchy` shows `-p/--port`, `-f/--format` (tree, json, xml; default tree), `--udid`; `record` marks `--duration` required (help: runner_*.txt, hierarchy.txt, record.txt)

Clause checks: [True, True, False]. Evidence commands: `CLI-008/dump.command.json`, `CLI-008/hierarchy.command.json`, `CLI-008/install.command.json`, `CLI-008/record.command.json`, `CLI-008/start.command.json`, `CLI-008/stop.command.json`, `CLI-008/version.command.json`.
