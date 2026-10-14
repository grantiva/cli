# CLI-139 candidate5 clause assessment

Verdict: **PASS**.

Expected: `--timeout must be greater than zero` (64); `--json and --format xml conflict; pass one.` (64); usage error naming xml, json (docs/dump-hierarchy.md:37-39; src HierarchyCommand.swift:58,62)

Fresh current-candidate raw confirms the required validation/result before compiler or live-device work. Evidence: `CLI-139-run-1/conflict.command.json`, `CLI-139-run-1/timeout.command.json`, `CLI-139-run-1/yaml.command.json`.
