# CLI-009 candidate5 clause assessment

Verdict: **PASS**.

Expected: Lists flags (alias `featureflags`), envs, analytics, devices, apps, claims, vrt, releases, feedback, support, webhooks, alerts, keys, team, audit, org, open; `console featureflags --help` equals `console flags --help` (help: console.txt)

Clause checks: [True, True, True]. Evidence commands: `CLI-009/console.command.json`, `CLI-009/featureflags.command.json`, `CLI-009/flags.command.json`.
