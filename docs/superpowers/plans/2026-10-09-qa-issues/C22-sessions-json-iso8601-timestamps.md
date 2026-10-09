# Emit Unix or ISO 8601 timestamps in sessions --json

Severity: ux
Platforms: cli, ios, android
Found by: CLI-F25 (matrix rows CLI-015, CLI-016)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
A timestamp a script can read, matching the ISO 8601 `finishedAt` that `run --ready-file` writes. Source: README
§Agent-Native Features (`--ready-file` example); help: simulator sessions, emulator sessions (`--json`).

## Actual
Swift reference-date seconds (since 2001-01-01); read as Unix time they land in 1995:
```
    "acquiredAt" : 813129327.501302,
    "startedAt" : 813271244.347498
```

## Repro
```
grantiva simulator sessions --json
grantiva emulator sessions --json
```
(needs at least one managed simulator session or Grantiva-started emulator).

## Evidence
- findings/evidence/cli/json/simulator_sessions.out, findings/evidence/cli/json/emulator_sessions.out

## Suspected cause
Sources/GrantivaCore/Output/JSONOutput.swift:4-8: the shared encoder sets no `dateEncodingStrategy`, so `Date` fields
(`SimulatorCapacity.swift:11 acquiredAt`, `EmulatorManager.swift:22 startedAt`) use the default. ReadyFile.swift:100 and
KeepAliveSessionStore.swift:86 already use `.iso8601`.

## Acceptance criteria
- Re-running the repro prints `"acquiredAt" : "2026-10-09T13:15:27Z"`-style strings.
- Set `.iso8601` on `JSONOutput.encoder`; check other `--json` outputs with dates and note the change in CHANGELOG.
- GrantivaCoreTests/JSONOutputTests: encoding a struct with `Date(timeIntervalSince1970: 0)` yields `"1970-01-01T00:00:00Z"`.
