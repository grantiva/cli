# B-C16.1 candidate5 clause assessment

Verdict: **PASS**.

Expected: Webhook event names are validated by the server, not locally: `create`/`update` with `not.an.event` reach the server (no local ValidationError listing events), and `console webhooks events` is not a subcommand; `testUnknownWebhookEventsAreLeftToTheServer` exists in Tests/GrantivaCLITests/ConsoleOrgAdminCommandTests.swift (00-expectation-corrections.md; brief C16 Correction: criteria 1 and 3 withdrawn) (corrected round 2)

Fresh candidate5 public/docs or exact-current-source evidence satisfies the named clause without compiler/live work. Evidence: `B-C16.1-run-1/source-inspection.command.json`, `B-C16.1-run-1/events-help.command.json`.
