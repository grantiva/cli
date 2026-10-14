# CLI-140 candidate5 clause assessment

Verdict: **PASS**.

Expected: `--json and --format tree conflict; pass one.` (64); usage error naming tree, json, xml (docs/dump-hierarchy.md:51; src DriverCommand.swift:718)

Fresh current-candidate raw confirms the required validation/result before compiler or live-device work. Evidence: `CLI-140-run-1/bogus.command.json`, `CLI-140-run-1/conflict.command.json`.
