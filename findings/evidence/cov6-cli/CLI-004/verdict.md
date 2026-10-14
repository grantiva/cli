# CLI-004 candidate5 clause assessment

Verdict: **PASS**.

Expected: Flags exactly as help: run.txt; every flag README:76-99 and docs/android.md:54-55 name is present; no `--auto-accept-alerts`, `--no-auto-accept-alerts`, `--wait-for-idle-timeout`; `run --wait-for-idle-timeout 5` is a usage error, exit 64 (help: run.txt; README:76-99)

Clause checks: [True, True, True, True]. Evidence commands: `CLI-004/help.command.json`, `CLI-004/rejected-flag.command.json`.
