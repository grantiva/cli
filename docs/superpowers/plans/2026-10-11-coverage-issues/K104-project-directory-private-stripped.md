# owner.json `projectDirectory` drops the `/private` prefix, the opposite of the documented "symlinks resolved"

Severity: contract (re-graded from wrong-result: session matching still works because both sides use the same helper; the recorded and displayed value contradicts docs/dump-hierarchy.md:21)
Component: cli
Platforms: both (KeepAliveOwner is written for iOS and Android keep-alive runs alike; observed on iOS)
Rows: IOS-OBS-04 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
docs/dump-hierarchy.md:21: grantiva writes `<pid>.owner.json` "recording … `projectDirectory` (the directory the run
started in, absolute with symlinks resolved)". On macOS `/tmp` is a symlink to `private/tmp`, so a run started in
`/private/tmp/x` (or in `/tmp/x`) records `/private/tmp/x`, the path `realpath(3)` returns. The MCP no-session text,
which names the project's `.grantiva/session.json`, should spell the directory the same way.

## Actual
The run was started with cwd `/private/tmp/claude-501/…/cov-ios/ios`; owner.json recorded the `/tmp` spelling
(`findings/evidence/cov-ios/IOS-OBS-04/projectdir.txt`, from IOS-052/newest.out and IOS-052/commands.txt):
```
== IOS-052/newest.out (owner.json)
"projectDirectory":"\/tmp\/claude-501\/-Users-kyle-Developer-grantiva-cli\/b9f2e919-f7a5-4b94-a1bc-202f523560f4\/scratchpad\/cov-ios\/ios"
== run cwd (IOS-052/commands.txt)
# cwd: /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov-ios/ios
```
The MCP server started with `--project-dir /private/tmp/…/p027` names `/tmp/…/p027/.grantiva/session.json` in its
no-session text (`findings/evidence/cov-ios/MCP-079/other-dir/transcript.txt:21`, see K100).

The same page also says "the directory comparison is an exact, case-sensitive string match, so start the run and the
server from the same path spelling", which the canonicalisation (`/tmp` and `/private/tmp` compare equal) already
makes untrue for this symlink.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k104
unset GRANTIVA_API_KEY
rm -rf /private/tmp/k104 && git clone -q /Users/kyle/Developer/landmarks-demo /private/tmp/k104 && cd /private/tmp/k104/ios   # main 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k104 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
grantiva run --simulator "$UDID" --no-build --flow .maestro/01-browse.yaml --keep-alive --ready-file /private/tmp/k104/ka.ready > /private/tmp/k104/ka.log 2>&1 &
KA=$!; until [ -f /private/tmp/k104/ka.ready ]; do sleep 1; done
pwd -P; grep -ho '"projectDirectory":"[^"]*"' /tmp/grantiva-sessions/*.owner.json
kill -INT $KA; wait $KA
printf '%s\n' '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}' \
  '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Home"}}}' \
  | (cat; sleep 3) | grantiva mcp --platform ios --project-dir /private/tmp/k104/ios | grep -o 'No active runner session at [^ ]*'
grantiva simulator delete --name "fix-k104 iPhone 17"
```
Today: `pwd -P` prints `/private/tmp/k104/ios`, owner.json holds `\/tmp\/k104\/ios`, and the MCP text says
`No active runner session at /tmp/k104/ios/.grantiva/session.json.`

## Evidence
- findings/evidence/cov-ios/IOS-OBS-04/projectdir.txt, commands.txt
- findings/evidence/cov-ios/IOS-052/newest.out (owner.json), IOS-052/commands.txt (cwd)
- findings/evidence/cov-ios/MCP-079/other-dir/transcript.txt line 21 (MCP no-session text, `/tmp` spelling)
- findings/cov-ios-results.md rows IOS-OBS-04 and B-C03.2

## Suspected cause
- Sources/GrantivaCore/Runner/KeepAliveSessionStore.swift:64-66: `canonicalDirectory` is
  `URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path`. Foundation documents that both
  `standardizingPath` and `resolvingSymlinksInPath` strip a leading `/private` when the shorter path still exists, so
  the result is `/tmp/...`: the `/tmp` → `/private/tmp` link is undone rather than resolved. `recordOwner`
  (KeepAliveSessionStore.swift:111-116) stores that value; MCPServer.swift:175 compares against it.
- Sources/GrantivaMCP/MCPServer.swift:139-141: `resolveProjectDirectory` uses `.standardizedFileURL`, which strips
  `/private` the same way, so the no-session text at MCPServer.swift:188 prints the `/tmp` spelling.
- The same Foundation behaviour gives C105 its `/tmp` spelling (FlowReferenceResolver.swift:117-119 uses
  `standardizedFileURL`).
- Tests/GrantivaCoreTests/KeepAliveSessionStoreTests.swift:139-141 only asserts that `/tmp` and `/private/tmp`
  canonicalise to the same string, not which one.

Fix direction: implement `canonicalDirectory` with `realpath(3)` (falling back to the standardized path when the
directory does not exist), use it in `resolveProjectDirectory`, and when reading owner files canonicalise the
recorded value too, so sidecars written by 2.1.0 (`/tmp/...`) still match.

## Acceptance criteria
- A keep-alive run started in `/private/tmp/x` or in `/tmp/x` records `"projectDirectory":"/private/tmp/x"`.
- The MCP no-session text for `--project-dir /tmp/x` names `/private/tmp/x/.grantiva/session.json`.
- An MCP server for `/tmp/x` still attaches to a keep-alive session recorded as `/private/tmp/x`, and to one recorded
  as `/tmp/x` by grantiva 2.1.0.
- docs/dump-hierarchy.md:21 is consistent with the behaviour (drop or correct "exact … same path spelling").
- Unit tests in `GrantivaCoreTests/KeepAliveSessionStoreTests.swift`: extend
  `testCanonicalDirectoryResolvesSymlinks` to assert `canonicalDirectory("/tmp") == "/private/tmp"`; add
  `testOwnerRecordedWithTheTmpSpellingStillMatches`; and in `GrantivaMCPTests/MCPServerTests.swift`
  `testResolveProjectDirectoryKeepsThePrivatePrefix`.
