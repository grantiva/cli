# Report "not logged in" from auth logout when there are no credentials

Severity: ux
Platforms: cli
Found by: CLI-F03 (matrix rows CLI-090)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
`auth logout` "Remove[s] stored credentials"; with none stored it succeeds and says there was nothing to remove. Source:
help: auth logout; README §Commands.

## Actual
```
== [neither] ls ~/.grantiva/auth.json; $G auth logout; echo rc=$?
 OUT| Logged out. Credentials removed from ~/.grantiva/auth.json
 OUT| rc=0
 ERR| ls: /Users/kyle/.grantiva/auth.json: No such file or directory
```

## Repro
Back up any real credentials first.
```
mv ~/.grantiva/auth.json /tmp/auth.json.bak 2>/dev/null
grantiva auth logout; echo rc=$?
grantiva auth logout --json
mv /tmp/auth.json.bak ~/.grantiva/auth.json 2>/dev/null
```

## Evidence
- findings/evidence/cli/auth-logout-and-bad-platform.txt

## Suspected cause
Sources/GrantivaCore/Auth/AuthStore.swift:77-80: `delete` returns silently when the file is missing, and
Sources/GrantivaCLI/AuthCommand.swift:242-250 prints the success line unconditionally.

## Acceptance criteria
- Re-running the repro prints `Not logged in; no credentials at ~/.grantiva/auth.json.` and exits 0; `--json` emits
  `{"success": true, "message": "No stored credentials"}` (or a `removed: false` field).
- `AuthStore.delete` reports whether a file was removed.
- GrantivaCLITests/AuthCommandTests: with a fake store reporting no file, assert the not-logged-in message.
