# Validate webhook event names locally and add `console webhooks events`

Severity: contract
Platforms: cli
Found by: CLI-F17, CLI-DOCS-F07 (matrix rows CLI-096, CLI-115)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
"`grantiva console webhooks` — `list`, `create <url> --event …` ..., `retry`, and `events` (the subscribable event types).
Event names are validated before the request." Source: CHANGELOG 1.9.0 (CHANGELOG.md:76).

## Actual
A bogus event reaches the server (the bogus key is what fails), while analytics rejects a bad type locally:
```
key=qa-invalid-key console webhooks create https://x --event not.an.event | rc=1 | Error: Not authenticated. Run: grantiva auth login
key=qa-invalid-key console analytics events --type bogus | rc=64 | Error: Unknown event type 'bogus'. Expected one of: challenge_generated, ...
```
And `events` does not exist:
```
console webhooks events | rc=64 | Error: Unexpected argument 'events' Usage: grantiva console webhooks <subcommand>
```

## Repro
```
GRANTIVA_API_KEY=qa-invalid-key grantiva console webhooks create https://x --event not.an.event; echo rc=$?
GRANTIVA_API_KEY=qa-invalid-key grantiva console webhooks update wh_1 --event not.an.event; echo rc=$?
grantiva console webhooks events; echo rc=$?
```

## Evidence
- findings/evidence/cli/console-unauth.txt (lines 51, 56-67)
- help/console_webhooks.txt (SUBCOMMANDS; qa-cli worktree root)

## Suspected cause
Sources/GrantivaCLI/ConsoleOrgAdminCommands.swift:77-87 (`create.validate()`) checks only blank events and the https URL;
:134-140 (`update.validate()`) checks only the ID. No event list exists in Sources (only the example names
`device.high_risk`, `flag.updated` at :71), and no `events` subcommand is registered.

## Acceptance criteria
- Re-running the repro: create and update with `not.an.event` exit 64 before any request, listing the valid events;
  `console webhooks events` prints the subscribable types (`--json` supported).
- The valid list comes from one place (a static list kept in sync with the backend, or the API if it exposes one).
- GrantivaCLITests/ConsoleOrgAdminCommandTests: parsing `create https://x --event not.an.event` throws a ValidationError;
  `events` is a registered subcommand.
- If `events` is not added, remove it from CHANGELOG.md:76 instead.
